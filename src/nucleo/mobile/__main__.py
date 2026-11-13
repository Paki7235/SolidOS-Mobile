"""Interfaccia del telefono di SolidOS Mobile.

Uso: python3 -m nucleo.mobile [--schermo-intero]
"""

from __future__ import annotations

import configparser
import os
import sys
import time
from pathlib import Path

from .. import branding
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..sistema import config_utente, leggi_json, scrivi_json

PREDEFINITE = {
    "tema": "scuro",          # scuro | chiaro
    "testo": 1,               # 0 piccolo, 1 normale, 2 grande
    "accento": "#3F7CF5",
    "sfondo": "notte",        # notte | alba | oceano
    "orologio": "League Spartan",
    "icone": 1,               # 0 piccole, 1 normali, 2 grandi
    "navigazione": "gesti",   # gesti | tasti
    "dock": ["telefono", "messaggi", "web", "musica"],
    "non_disturbare": False,
}

# Categorie del menu di sistema → cartelle della Libreria app
CARTELLE = [
    ("Social", T("Social"), ("Chat", "InstantMessaging", "Email", "Telephony", "ContactManagement")),
    ("Produttività", T("Produttività"), ("Office", "TextEditor", "WordProcessor", "Calendar", "Spreadsheet")),
    ("Foto e video", T("Foto e video"), ("Graphics", "Photography", "AudioVideo", "Audio", "Video", "Player")),
    ("Internet", T("Internet"), ("Network", "WebBrowser", "FileTransfer")),
    ("Utility", T("Utility"), ("Utility", "Accessories", "FileManager", "Calculator", "Archiving")),
    ("Sistema", T("Sistema"), ("System", "Settings", "Monitor", "TerminalEmulator", "Security")),
    ("Giochi", T("Giochi"), ("Game",)),
]
# Nomi brevi delle app di sistema (Dock, Personalizza) → file .desktop
ALIAS = {
    "telefono": "telefono", "messaggi": "messaggi", "web": "web", "musica": "lettore",
    "foto": "foto", "note": "note", "file": "file", "dove": "dove", "impostazioni": "impostazioni",
    "store": "store", "vicina": "condividi", "calcolatrice": "calcolatrice", "fotocamera": "cattura",
}


# App interne all'interfaccia (si aprono subito e non occupano memoria in più)
IN_ARRIVO = {
    "telefono": {"id": "interno:telefono", "nome": T("Telefono"), "icona": "call-start", "categorie": ["Telephony"]},
    "messaggi": {"id": "interno:messaggi", "nome": T("Messaggi"), "icona": "internet-chat", "categorie": ["Chat"]},
    "contatti": {"id": "interno:contatti", "nome": T("Contatti"), "icona": "x-office-address-book", "categorie": ["ContactManagement"]},
}


class CentroNotifiche:
    """Le notifiche del telefono: quelle delle app (server D-Bus standard, come la shell del PC)
    più quelle del telefono stesso (SMS, chiamate perse). Se un altro server è già attivo
    (es. anteprima dentro SolidOS per PC) restano solo quelle del telefono."""

    def __init__(self, avvisa):
        self._avvisa = avvisa
        self.server = None
        self.interne: list[dict] = []
        self._prossimo = 100000
        self.non_disturbare = False

    def avvia(self) -> None:
        try:
            import dbus

            from ..dbusutil import inizializza
            from .notifiche import ServerNotifiche

            inizializza()
            self.server = ServerNotifiche(dbus.SessionBus(), lambda e, d: self._avvisa(e, d))
            self.server.non_disturbare = self.non_disturbare
            self.server.storico = self.interne + self.server.storico
        except Exception:  # noqa: BLE001 — niente bus di sessione o nome già preso
            self.server = None

    def imposta_non_disturbare(self, si: bool) -> None:
        self.non_disturbare = bool(si)
        if self.server:
            self.server.non_disturbare = self.non_disturbare

    def elenco(self) -> list:
        return list(self.server.storico) if self.server else list(self.interne)

    def aggiungi(self, app: str, titolo: str, testo: str, icona: str = "", apri: str = "") -> None:
        azioni = [{"chiave": "apri:" + apri, "testo": T("Apri")}] if apri else []
        if self.server:
            coppie = [x for a in azioni for x in (a["chiave"], a["testo"])]
            self.server.Notify(app, 0, icona, titolo, testo, coppie, {"x-apri": apri} if apri else {}, -1)
            return
        self._prossimo += 1
        n = {"id": self._prossimo, "app": app, "icona": icona, "titolo": titolo, "testo": testo, "azioni": azioni,
             "urgenza": 1, "valore": -1, "residente": False, "transitoria": False, "scadenza": 6000,
             "ora": time.strftime("%H:%M")}
        self.interne.insert(0, n)
        del self.interne[60:]
        self._avvisa("notifica", {"notifica": n, "mostra": not self.non_disturbare})

    def chiudi(self, ident: int) -> None:
        if self.server:
            self.server.rimuovi_da_storico(int(ident))
            self.server.chiudi(int(ident))
        self.interne = [n for n in self.interne if n["id"] != int(ident)]

    def svuota(self) -> None:
        if self.server:
            for n in list(self.server.storico):
                self.server.chiudi(int(n["id"]))
            self.server.svuota_storico()
        self.interne = []

    def azione(self, ident: int, chiave: str) -> None:
        if self.server and not chiave.startswith("apri:"):
            self.server.azione(int(ident), chiave)


def _impostazioni_file() -> Path:
    return config_utente("mobile.json")


CARTELLE_DESKTOP = [Path.home() / ".local/share/applications", Path("/usr/share/applications"),
                    Path("/var/lib/flatpak/exports/share/applications"),
                    Path.home() / ".local/share/flatpak/exports/share/applications"]


def _app_installate() -> list[dict]:
    viste, app = set(), []
    for cartella in CARTELLE_DESKTOP:
        if not Path(cartella).is_dir():
            continue
        for f in sorted(Path(cartella).glob("*.desktop")):
            if f.stem in viste:
                continue
            viste.add(f.stem)
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(f, encoding="utf-8")
                v = c["Desktop Entry"]
            except (configparser.Error, KeyError, UnicodeDecodeError):
                continue
            if v.get("Type", "Application") != "Application" or v.get("NoDisplay", "").lower() == "true" \
                    or v.get("Hidden", "").lower() == "true" or v.get("Terminal", "").lower() == "true":
                continue
            categorie = [x for x in v.get("Categories", "").split(";") if x]
            app.append({"id": f.stem, "nome": v.get("Name[it]") or v.get("Name", f.stem),
                        "icona": v.get("Icon", "application-x-executable"), "categorie": categorie})
    app.sort(key=lambda a: a["nome"].lower())
    return app


def _batteria() -> dict:
    for b in sorted(Path("/sys/class/power_supply").glob("BAT*")):
        try:
            cap = int((b / "capacity").read_text().strip())
            stato = (b / "status").read_text().strip()
            return {"presente": True, "livello": cap, "carica": stato in ("Charging", "Full")}
        except (OSError, ValueError):
            continue
    return {"presente": False, "livello": 100, "carica": True}


class BackendMobile(Backend):
    def __init__(self):
        self._app: list[dict] | None = None
        self.centro = CentroNotifiche(lambda e, d: self.emetti(e, d))
        self.centro.non_disturbare = bool(self.impostazioni().get("non_disturbare"))
        from . import telefonia

        if telefonia.DEMO:
            self.centro.aggiungi(T("Messaggi"), "Mamma", "A che ora arrivi stasera? Ho preparato la cena", "internet-chat", "messaggi")
            self.centro.aggiungi(T("Telefono"), T("Chiamata persa"), "Giulia Rossi", "call-start", "telefono")
            self.centro.aggiungi(T("Calendario"), T("Riunione con Marco"), T("Tra un'ora · Studio"), "x-office-calendar")

    # ── Notifiche ────────────────────────────────────────────────────────
    def notifiche(self) -> list:
        return self.centro.elenco()

    def chiudiNotifica(self, ident: int) -> None:
        self.centro.chiudi(int(ident))

    def svuotaNotifiche(self) -> None:
        self.centro.svuota()

    def azioneNotifica(self, ident: int, chiave: str) -> None:
        self.centro.azione(int(ident), chiave)

    def nonDisturbare(self, si: bool) -> None:
        self.centro.imposta_non_disturbare(bool(si))
        self.imposta("non_disturbare", bool(si))

    def controllaSms(self) -> int:
        """Nuovi SMS dal modem → archivio e notifica (chiamato dall'interfaccia ogni 20 secondi)."""
        from . import telefonia

        arrivati = telefonia.sincronizza_sms()
        for numero, testo in arrivati:
            self.centro.aggiungi(T("Messaggi"), telefonia.nome_di(numero) or numero, testo, "internet-chat", "messaggi")
        return len(arrivati)

    # ── Personalizza ─────────────────────────────────────────────────────
    def impostazioni(self) -> dict:
        conf = dict(PREDEFINITE)
        conf.update(leggi_json(_impostazioni_file(), {}))
        return conf

    def imposta(self, chiave: str, valore) -> dict:
        if chiave not in PREDEFINITE:
            return self.impostazioni()
        conf = leggi_json(_impostazioni_file(), {})
        conf[chiave] = valore
        scrivi_json(_impostazioni_file(), conf)
        return self.impostazioni()

    def avvio(self) -> dict:
        """--schermata=home|libreria|controllo|notifiche|personalizza e --tema=chiaro|scuro
        (per la prova automatica e per aprire direttamente una schermata)."""
        risultato = {}
        for a in sys.argv[1:]:
            if a.startswith("--schermata="):
                risultato["schermata"] = a.split("=", 1)[1]
            elif a.startswith("--tema="):
                risultato["tema"] = a.split("=", 1)[1]
            elif a.startswith("--foto="):
                risultato["foto"] = a.split("=", 1)[1]
        return risultato

    def cartellaSfondi(self) -> str:
        return os.environ.get("NUCLEO_SFONDI", f"/usr/share/backgrounds/{branding.id_os()}")

    def schermoIntero(self) -> bool:
        return "--schermo-intero" in sys.argv

    def utente(self) -> str:
        import pwd

        u = pwd.getpwuid(os.getuid())
        return (u.pw_gecos.split(",")[0] or u.pw_name).split(" ")[0]

    # ── App ──────────────────────────────────────────────────────────────
    def app(self) -> list:
        if self._app is None:
            self._app = _app_installate()
        return self._app

    def _per_id(self, breve: str) -> dict | None:
        if breve in IN_ARRIVO:
            return IN_ARRIVO[breve]
        desktop = branding.comando(ALIAS.get(breve, breve))
        tutte = self.app()
        return next((a for a in tutte if a["id"] == desktop), None) \
            or next((a for a in tutte if a["id"].endswith(breve)), None)

    def home(self) -> list:
        """Le app della Home: quelle di SolidOS più usate, nell'ordine del design."""
        ordine = ["fotocamera", "foto", "contatti", "note", "file", "dove", "musica", "store", "vicina", "calcolatrice", "impostazioni"]
        risultato = [a for a in (self._per_id(x) for x in ordine) if a]
        dock = set(self.impostazioni()["dock"])
        for a in self.app():
            if len(risultato) >= 16:
                break
            if a not in risultato and not any(a is self._per_id(d) for d in dock):
                risultato.append(a)
        return risultato

    def dock(self) -> list:
        return [a for a in (self._per_id(x) for x in self.impostazioni()["dock"]) if a]

    def libreria(self) -> list:
        cartelle = []
        usate = set()
        for chiave, nome, categorie in CARTELLE:
            dentro = [a for a in self.app() if a["id"] not in usate and any(c in categorie for c in a["categorie"])]
            usate.update(a["id"] for a in dentro)
            if dentro:
                cartelle.append({"id": chiave, "nome": nome, "app": dentro})
        altre = [a for a in self.app() if a["id"] not in usate]
        if altre:
            cartelle.append({"id": "altre", "nome": T("Altre"), "app": altre})
        return cartelle

    def avvia(self, ident: str) -> dict:
        if ident.startswith("interno:"):
            return {"ok": True, "interna": ident.split(":", 1)[1]}
        from ..sistema import avvia_desktop

        ok = avvia_desktop(ident)
        return {"ok": ok, "messaggio": "" if ok else T("Impossibile aprire l'app")}

    # ── Stato (barra in alto, widget, Centro di controllo) ───────────────
    def stato(self) -> dict:
        from ..hw import bluetooth, rete

        try:
            r = rete.stato_breve()
        except Exception:  # noqa: BLE001
            r = {"wifi": False, "connesso": False, "tipo": "", "nome": ""}
        try:
            bt = bluetooth.attivo()
        except Exception:  # noqa: BLE001
            bt = False
        return {"batteria": _batteria(), "rete": r, "bluetooth": bt, "ora": time.strftime("%H:%M")}

    def dispositivi(self) -> list:
        """Batterie dei dispositivi collegati al Solid ID (widget della Home)."""
        try:
            from .. import solidid

            if not solidid.collegato():
                return []
            return [{"nome": d["nome"], "tipo": d.get("tipo", "computer"), "batteria": d.get("batteria")}
                    for d in solidid.dispositivi() if d.get("batteria") is not None][:3]
        except Exception:  # noqa: BLE001
            return []

    def wifi(self, attivo: bool) -> None:
        from ..hw import rete

        rete.imposta_wifi(bool(attivo))

    def bluetooth(self, attivo: bool) -> None:
        from ..hw import bluetooth

        bluetooth.imposta(bool(attivo))

    def luminosita(self) -> int:
        from ..hw import schermo

        return schermo.luminosita() or 70

    def impostaLuminosita(self, valore: int) -> None:
        from ..hw import schermo

        schermo.imposta_luminosita(int(valore))

    def volume(self) -> int:
        from ..hw import audio

        try:
            return int(audio.volume().get("volume", 50))
        except Exception:  # noqa: BLE001
            return 50

    def impostaVolume(self, valore: int) -> None:
        from ..hw import audio

        audio.imposta_volume(int(valore))

    # ── Telefonia: chiamate, rubrica, registro, SMS ──────────────────────
    def modem(self) -> dict:
        from . import telefonia

        return telefonia.stato_modem()

    def contatti(self) -> list:
        from . import telefonia

        return telefonia.contatti()

    def salvaContatto(self, nome: str, numero: str, ident: str = "", email: str = "", note: str = "") -> dict:
        from . import telefonia

        return telefonia.salva_contatto(nome, numero, ident, email, note)

    def cercaVcard(self) -> list:
        from . import telefonia

        return telefonia.cerca_vcard()

    def importaVcard(self, percorso: str) -> dict:
        from . import telefonia

        return telefonia.importa_vcard(percorso)

    def esportaVcard(self) -> dict:
        from . import telefonia

        return telefonia.esporta_vcard()

    def preferito(self, ident: str, si: bool) -> None:
        from . import telefonia

        telefonia.preferito(ident, si)

    def eliminaContatto(self, ident: str) -> None:
        from . import telefonia

        telefonia.elimina_contatto(ident)

    def registro(self) -> list:
        from . import telefonia

        return telefonia.registro()

    def cancellaRegistro(self) -> None:
        from . import telefonia

        telefonia.cancella_registro()

    def _chiamate(self):
        from . import telefonia

        if not hasattr(self, "_ch"):
            self._ch = telefonia.Chiamate()
            self._ch.persa = lambda numero: self.centro.aggiungi(
                T("Telefono"), T("Chiamata persa"), telefonia.nome_di(numero) or numero, "call-start", "telefono")
        return self._ch

    def chiama(self, numero: str) -> dict:
        return self._chiamate().chiama(numero)

    def chiamata(self) -> dict:
        return self._chiamate().stato()

    def rispondi(self) -> None:
        self._chiamate().rispondi()

    def riaggancia(self) -> None:
        self._chiamate().riaggancia()

    def tono(self, cifra: str) -> None:
        self._chiamate().tono(cifra)

    def muto(self, si: bool) -> None:
        self._chiamate().imposta_muto(si)

    def vivavoce(self, si: bool) -> None:
        self._chiamate().imposta_vivavoce(si)

    def conversazioni(self) -> list:
        from . import telefonia

        telefonia.sincronizza_sms()
        return telefonia.conversazioni()

    def conversazione(self, numero: str) -> dict:
        from . import telefonia

        return telefonia.conversazione(numero)

    def inviaSms(self, numero: str, testo: str) -> dict:
        from . import telefonia

        return telefonia.invia_sms(numero, testo)

    def blocca(self) -> None:
        from ..sistema import avvia

        avvia([branding.comando("blocca")])


def main() -> int:
    from ..qmlapp import esegui_app

    def contesto(app):
        # Tema di icone (fuori da SolidOS, es. nella prova su GitHub: NUCLEO_TEMA_ICONE=Papirus-Dark)
        if os.environ.get("NUCLEO_TEMA_ICONE"):
            from PyQt6.QtGui import QIcon

            QIcon.setThemeName(os.environ["NUCLEO_TEMA_ICONE"])
        backend = BackendMobile()
        ponte = crea_ponte(backend)
        backend.centro.avvia()
        return {"ponte": ponte}

    return esegui_app("mobile", "Mobile/Main.qml", contesto)


if __name__ == "__main__":
    sys.exit(main())
