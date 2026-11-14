"""Gestore di Condivisione Vicina: backend, dispositivi, trasferimenti, conferme e D-Bus.

Nota: niente «from __future__ import annotations» in questo file: dbus-next legge le
annotazioni di tipo D-Bus («s», «as»…) dei metodi esportati.
"""

import asyncio
import json
import logging
import socket
import subprocess
import time
from pathlib import Path

from dbus_next import BusType, Variant
from dbus_next.aio import MessageBus
from dbus_next.service import PropertyAccess, ServiceInterface, dbus_property, method, signal

from .. import branding
from ..i18n import T
from ..sistema import cartella_utente, config_utente, leggi_json, scrivi_json
from . import DURATA_TUTTI
from .modelli import Dispositivo, Trasferimento

log = logging.getLogger("condivisione")

ORDINE_PREDEFINITO = ["quickshare", "localsend", "qr"]


class Notifiche:
    """Client minimo di org.freedesktop.Notifications con attesa delle azioni."""

    def __init__(self, bus: MessageBus):
        self.bus = bus
        self.iface = None
        self._attese: dict[int, asyncio.Future] = {}
        self._azioni: dict[int, callable] = {}

    async def prepara(self):
        intro = await self.bus.introspect("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
        oggetto = self.bus.get_proxy_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications", intro)
        self.iface = oggetto.get_interface("org.freedesktop.Notifications")
        self.iface.on_action_invoked(self._azione)
        self.iface.on_notification_closed(self._chiusa)

    def _azione(self, ident, chiave):
        fut = self._attese.pop(ident, None)
        if fut and not fut.done():
            fut.set_result(chiave)
        cb = self._azioni.pop(ident, None)
        if cb:
            cb(chiave)

    def _chiusa(self, ident, _motivo):
        fut = self._attese.pop(ident, None)
        if fut and not fut.done():
            fut.set_result("")

    async def mostra(self, titolo, testo, icona="document-send", azioni=None, sostituisce=0, valore=None,
                     urgenza=1, residente=False, al_clic=None) -> int:
        if not self.iface:
            return 0
        suggerimenti = {"urgency": Variant("y", urgenza)}
        if valore is not None:
            suggerimenti["value"] = Variant("i", int(valore))
        if residente:
            suggerimenti["resident"] = Variant("b", True)
        if icona.startswith("/"):
            suggerimenti["image-path"] = Variant("s", icona)
        lista = []
        for chiave, etichetta in (azioni or []):
            lista += [chiave, etichetta]
        try:
            ident = await self.iface.call_notify(branding.nome(), sostituisce, icona if not icona.startswith("/") else "document-send",
                                                 titolo, testo, lista, suggerimenti, 0 if urgenza == 2 or residente else 8000)
        except Exception:  # noqa: BLE001 — server notifiche assente
            return 0
        if al_clic:
            self._azioni[ident] = al_clic
        return ident

    async def chiedi(self, titolo, testo, azioni, icona="document-send", timeout=60) -> str:
        ident = await self.mostra(titolo, testo, icona, azioni, urgenza=2)
        if not ident:
            return ""
        fut = asyncio.get_running_loop().create_future()
        self._attese[ident] = fut
        try:
            return await asyncio.wait_for(fut, timeout)
        except asyncio.TimeoutError:
            await self.chiudi(ident)
            return ""

    async def chiudi(self, ident):
        if self.iface and ident:
            try:
                await self.iface.call_close_notification(ident)
            except Exception:  # noqa: BLE001
                pass


class Gestore:
    def __init__(self):
        self.conf = {}
        self.backend: dict[str, object] = {}
        self.dispositivi: dict[str, Dispositivo] = {}
        self.trasferimenti: dict[str, Trasferimento] = {}
        self.visibilita = "nessuno"
        self._ritorno: asyncio.TimerHandle | None = None
        self.bus: MessageBus | None = None
        self.notifiche: Notifiche | None = None
        self.interfaccia: InterfacciaDBus | None = None
        self.carica_configurazione()

    # ── Configurazione ──────────────────────────────────────────────────────
    def carica_configurazione(self):
        self.conf = leggi_json(config_utente("condivisione.json"), {})
        self.conf.setdefault("associati", {})
        self.conf.setdefault("preferisci_stabili", True)

    def salva_configurazione(self):
        scrivi_json(config_utente("condivisione.json"), self.conf)

    @property
    def nome_dispositivo(self) -> str:
        return self.conf.get("nome") or T("{s} di {u}", s=branding.nome(),
                                          u=Path.home().name.capitalize()) or socket.gethostname()

    @property
    def cartella(self) -> Path:
        return Path(self.conf.get("cartella") or cartella_utente("DOWNLOAD", "Scaricati") / T("Ricevuti"))

    # ── Avvio ───────────────────────────────────────────────────────────────
    async def avvia(self):
        from .backend.localsend import BackendLocalSend
        from .backend.qr import BackendQR
        from .backend.quickshare import BackendQuickShare

        self.bus = await MessageBus(bus_type=BusType.SESSION).connect()
        self.notifiche = Notifiche(self.bus)
        try:
            await self.notifiche.prepara()
        except Exception as e:  # noqa: BLE001
            log.warning("notifiche non disponibili: %s", e)
        self.interfaccia = InterfacciaDBus(self)
        self.bus.export(branding.percorso_dbus("Condivisione1"), self.interfaccia)
        await self.bus.request_name(branding.nome_dbus("Condivisione1"))

        for cls in (BackendQuickShare, BackendLocalSend, BackendQR):
            b = cls(self)
            self.backend[b.nome] = b
            ok, motivo = b.disponibile()
            if ok:
                try:
                    await b.avvia()
                except Exception as e:  # noqa: BLE001 — un backend guasto non ferma gli altri
                    log.exception("avvio %s non riuscito: %s", b.nome, e)
            else:
                log.info("backend %s non disponibile: %s", b.nome, motivo)
        await self.imposta_visibilita(self.conf.get("visibilita", "nessuno"), salva=False)

    def stato_backend(self) -> dict:
        return {nome: list(b.disponibile()) for nome, b in self.backend.items()}

    # ── Visibilità ──────────────────────────────────────────────────────────
    async def imposta_visibilita(self, modalita: str, salva: bool = True):
        if modalita not in ("nessuno", "associati", "tutti10", "tutti"):
            return
        precedente = self.visibilita if self.visibilita != "tutti10" else self.conf.get("visibilita_base", "nessuno")
        self.visibilita = modalita
        if self._ritorno:
            self._ritorno.cancel()
            self._ritorno = None
        if modalita == "tutti10":
            self.conf["visibilita_base"] = precedente
            loop = asyncio.get_running_loop()
            self._ritorno = loop.call_later(DURATA_TUTTI, lambda: asyncio.ensure_future(
                self.imposta_visibilita(self.conf.get("visibilita_base", "nessuno"))))
        elif salva:
            self.conf["visibilita"] = modalita
        if salva:
            self.salva_configurazione()
        for b in self.backend.values():
            if b.disponibile()[0]:
                try:
                    await b.visibilita(modalita)
                except Exception:  # noqa: BLE001
                    log.exception("visibilità %s", b.nome)
        if self.interfaccia:
            self.interfaccia.emit_properties_changed({"Visibilita": modalita})

    # ── Dispositivi ─────────────────────────────────────────────────────────
    def dispositivo_trovato(self, d: Dispositivo):
        nuovo = d.id not in self.dispositivi
        self.dispositivi[d.id] = d
        if nuovo and self.interfaccia:
            self.interfaccia.DispositiviCambiati()

    def dispositivo_perso(self, ident: str):
        if self.dispositivi.pop(ident, None) and self.interfaccia:
            self.interfaccia.DispositiviCambiati()

    def elenco_dispositivi(self) -> list[dict]:
        """Unisce i dispositivi visti da più backend e sceglie il migliore per ciascuno."""
        ordine = list(ORDINE_PREDEFINITO)
        if self.conf.get("preferisci_stabili", True):
            ordine = ["quickshare", "localsend", "qr"]
        adesso = time.time()
        per_nome: dict[str, list[Dispositivo]] = {}
        for d in self.dispositivi.values():
            if adesso - d.visto < 120:
                per_nome.setdefault(d.nome.strip().lower(), []).append(d)
        risultato = []
        for gruppo in per_nome.values():
            gruppo.sort(key=lambda x: ordine.index(x.backend) if x.backend in ordine else 99)
            migliore = gruppo[0].pubblico()
            migliore["alternative"] = [g.id for g in gruppo[1:]]
            risultato.append(migliore)
        return sorted(risultato, key=lambda x: x["nome"].lower())

    async def scopri(self, secondi: int = 20):
        await asyncio.gather(*(b.scopri(secondi) for b in self.backend.values() if b.disponibile()[0]),
                             return_exceptions=True)

    # ── Ricezione ───────────────────────────────────────────────────────────
    def associato(self, ident_mittente: str) -> bool:
        return ident_mittente in self.conf.get("associati", {})

    async def chiedi_conferma(self, t: Trasferimento, ident_mittente: str, utente_avviato: bool = False) -> bool:
        """Conferma esplicita dell'utente. Mai ricezione automatica da sconosciuti."""
        if not utente_avviato:
            if self.visibilita == "nessuno":
                return False
            if self.visibilita == "associati" and not self.associato(ident_mittente):
                return False
        t.totale = sum(f.dimensione for f in t.file)
        from .sicurezza import rischioso, spazio_sufficiente

        if not spazio_sufficiente(self.cartella, t.totale):
            await self.notifiche.mostra(T("Spazio insufficiente"), T("Non c'è abbastanza spazio per ricevere i file."), "dialog-error")
            return False
        nomi = [f.nome for f in t.file[:5]]
        elenco = "\n".join(f"• {n}" + (" ⚠️" if rischioso(n) else "") for n in nomi)
        if len(t.file) > 5:
            elenco += "\n" + T("…e altri {n}", n=len(t.file) - 5)
        dimensione = f"{t.totale / 1048576:.1f} MB"
        testo = T("{d} vuole inviarti {n} file ({m}) tramite {b}.", d=t.dispositivo, n=len(t.file), m=dimensione,
                  b=NOMI_BACKEND.get(t.backend, t.backend)) + "\n" + elenco
        if t.codice:
            testo += "\n" + T("Codice di verifica: {c} (deve essere uguale sul telefono)", c=t.codice)
        if any(rischioso(n) for n in [f.nome for f in t.file]):
            testo += "\n⚠️ " + T("Contiene programmi o script: accetta solo se ti fidi del mittente.")
        azioni = [("accetta", T("Accetta")), ("rifiuta", T("Rifiuta"))]
        if ident_mittente and not self.associato(ident_mittente):
            azioni.insert(1, ("ricorda", T("Accetta e ricorda")))
        risposta = await self.notifiche.chiedi(T("File in arrivo"), testo, azioni, icona=t.anteprima or "document-send")
        accettato = risposta in ("accetta", "ricorda", "default")
        if risposta == "ricorda" and ident_mittente:
            self.conf["associati"][ident_mittente] = {"nome": t.dispositivo, "backend": t.backend}
            self.salva_configurazione()
        t.stato = "accettato" if accettato else "rifiutato"
        self.trasferimenti[t.id] = t
        if not accettato:
            self.registra(t)
        return accettato

    async def avanzamento(self, t: Trasferimento, ident_notifica: list):
        """Aggiorna la notifica di avanzamento (al massimo una volta al secondo)."""
        adesso = time.monotonic()
        if getattr(t, "_ultimo", 0) and adesso - t._ultimo < 1 and t.trasferiti < t.totale:
            return
        t._ultimo = adesso
        titolo = T("Ricezione da {d}", d=t.dispositivo) if t.direzione == "ricevi" else T("Invio a {d}", d=t.dispositivo)
        ident_notifica[0] = await self.notifiche.mostra(titolo, f"{t.percentuale()}%", "document-send",
                                                        [("annulla", T("Annulla"))], ident_notifica[0], t.percentuale(),
                                                        residente=True, al_clic=lambda k: self._annulla_da_notifica(t, k))
        if self.interfaccia:
            self.interfaccia.Avanzamento(t.id, t.trasferiti, t.totale)

    def _annulla_da_notifica(self, t: Trasferimento, chiave: str):
        if chiave == "annulla":
            t.annullato = True

    async def completato(self, t: Trasferimento, ident_notifica: list, errore: str = ""):
        await self.notifiche.chiudi(ident_notifica[0])
        if errore:
            t.stato = "annullato" if t.annullato else "errore"
            await self.notifiche.mostra(T("Trasferimento non riuscito"), errore, "dialog-error")
        else:
            t.stato = "completato"
            if t.direzione == "ricevi":
                cartella = str(self.cartella)
                from .sicurezza import dopo_ricezione

                avvisi = [p for p in t.percorsi if dopo_ricezione(Path(p))["ingannevole"]]
                testo = T("{n} file salvati in {c}", n=len(t.percorsi), c=cartella)
                if avvisi:
                    testo += "\n⚠️ " + T("Attenzione: almeno un file ha un'estensione che non corrisponde al contenuto.")
                await self.notifiche.mostra(T("File ricevuti da {d}", d=t.dispositivo), testo, "document-send",
                                            [("default", T("Apri cartella"))],
                                            al_clic=lambda _k: subprocess.Popen(["xdg-open", cartella]))
            else:
                await self.notifiche.mostra(T("Inviato a {d}", d=t.dispositivo),
                                            T("{n} file inviati", n=len(t.file)), "document-send")
        self.registra(t)
        if self.interfaccia:
            self.interfaccia.TrasferimentoFinito(t.id, t.stato)

    def registra(self, t: Trasferimento):
        try:
            from ..privacy.registro import Registro

            nomi = [Path(str(getattr(f, "nome", f))).name for f in t.file]
            Registro().aggiungi("trasferimento", NOMI_BACKEND.get(t.backend, t.backend),
                                f'{"Ricevuti da" if t.direzione == "ricevi" else "Inviati a"} {t.dispositivo}: '
                                f'{", ".join(nomi[:5])} ({t.totale // 1024} KB) — {t.stato}')
        except Exception:  # noqa: BLE001
            log.exception("registro privacy")

    # ── Invio ───────────────────────────────────────────────────────────────
    def invia(self, file: list[str], ident: str) -> str:
        d = self.dispositivi.get(ident)
        if not d:
            return ""
        percorsi = [Path(f.removeprefix("file://")) for f in file]
        t = Trasferimento(direzione="invia", backend=d.backend, dispositivo=d.nome, file=percorsi,
                          totale=sum(p.stat().st_size for p in percorsi if p.is_file()))
        self.trasferimenti[t.id] = t
        asyncio.ensure_future(self._invia_con_ripiego(d, t))
        return t.id

    async def _invia_con_ripiego(self, d: Dispositivo, t: Trasferimento):
        candidati = [d] + [self.dispositivi[a] for a in self.elenco_alternative(d) if a in self.dispositivi]
        ultimo_errore = ""
        for c in candidati:
            t.backend = c.backend
            notifica = [0]
            try:
                await self.backend[c.backend].invia(c, t)
                if t.stato == "rifiutato":
                    await self.notifiche.mostra(T("Invio rifiutato"), T("{d} ha rifiutato i file.", d=c.nome), "dialog-information")
                    self.registra(t)
                    return
                await self.completato(t, notifica)
                return
            except Exception as e:  # noqa: BLE001 — si prova il backend successivo
                log.exception("invio via %s", c.backend)
                ultimo_errore = str(e)
                if t.annullato:
                    break
        await self.completato(t, [0], ultimo_errore or T("Dispositivo non raggiungibile"))

    def elenco_alternative(self, d: Dispositivo) -> list[str]:
        return [x.id for x in self.dispositivi.values()
                if x.id != d.id and x.nome.strip().lower() == d.nome.strip().lower()]


NOMI_BACKEND = {"quickshare": "Quick Share", "localsend": "LocalSend", "qr": T("codice QR")}


def _iface_nome() -> str:
    return branding.nome_dbus("Condivisione1")


class InterfacciaDBus(ServiceInterface):
    """org.<OS_ID>.Condivisione1 — i dati complessi viaggiano come JSON."""

    def __init__(self, gestore: Gestore):
        super().__init__(_iface_nome())
        self.g = gestore

    @method()
    def Dispositivi(self) -> "s":
        return json.dumps(self.g.elenco_dispositivi(), ensure_ascii=False)

    @method()
    def Scopri(self, secondi: "i"):
        asyncio.ensure_future(self.g.scopri(int(secondi) or 20))

    @method()
    def Invia(self, file: "as", dispositivo: "s") -> "s":
        return self.g.invia(list(file), dispositivo)

    @method()
    def InviaConQr(self, file: "as") -> "s":
        return json.dumps(self.g.backend["qr"].sessione(list(file), ricevi=False))

    @method()
    def RiceviConQr(self, hotspot: "b") -> "s":
        return json.dumps(self.g.backend["qr"].sessione([], ricevi=True, hotspot=bool(hotspot)))

    @method()
    def FermaQr(self):
        asyncio.ensure_future(self.g.backend["qr"].chiudi_sessione())

    @method()
    def Annulla(self, ident: "s"):
        t = self.g.trasferimenti.get(ident)
        if t:
            t.annullato = True

    @method()
    def ImpostaVisibilita(self, modalita: "s"):
        asyncio.ensure_future(self.g.imposta_visibilita(modalita))

    @method()
    def StatoBackend(self) -> "s":
        return json.dumps(self.g.stato_backend(), ensure_ascii=False)

    @method()
    def RicaricaConfigurazione(self):
        self.g.carica_configurazione()

    @signal()
    def DispositiviCambiati(self):
        pass

    @signal()
    def Avanzamento(self, ident, fatto, totale) -> "stt":
        return [ident, int(fatto), int(totale)]

    @signal()
    def TrasferimentoFinito(self, ident, stato) -> "ss":
        return [ident, stato]

    @dbus_property(access=PropertyAccess.READ)
    def Visibilita(self) -> "s":
        return self.g.visibilita

    @dbus_property(access=PropertyAccess.READ)
    def CartellaRicevuti(self) -> "s":
        return str(self.g.cartella)
