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
from . import strumenti
from ..ponte import Backend, crea_ponte
from ..sistema import config_utente, leggi_json, scrivi_json

PREDEFINITE = {
    "tastiera": True,
    "protezione_furto": True,   # codice + un'ora di attesa per le cose importanti lontano da casa
    # Widget della Home (in ordine): tipo oggi|batterie|meteo|calendario|musica|foto|note|orologio, misura piccolo|medio|grande
    "widget": [{"tipo": "oggi", "misura": "piccolo"}, {"tipo": "batterie", "misura": "piccolo"}],
    "ordine_home": [],          # ordine delle app della Home scelto spostandole (vuoto = quello di SolidOS)
    "nascoste_home": [],        # app tolte dalla Home (restano nella Libreria)
    "citta_meteo": "",          # vuota = la posizione del telefono
    "widget_blocco": [],        # widget sotto l'orologio della schermata di blocco (meteo, batterie, oggi, musica)
    "stile_icone": "vetro",     # vetro | colori | scure | tinta
    "app_automatiche": True,    # Store: scarica da sola le app prese con lo stesso Solid ID sul PC           # tastiera sullo schermo quando si tocca un campo di testo
    "riduci_movimento": False,   # Accessibilità: animazioni istantanee
    "tema": "scuro",          # scuro | chiaro
    "testo": 1,               # 0 piccolo, 1 normale, 2 grande
    "accento": "#4C7DFF",
    "sfondo": "notte",        # notte | alba | oceano | aurora | grafite, o una foto
    "orologio": "Inter",
    "icone": 1,               # 0 piccole, 1 normali, 2 grandi
    "navigazione": "gesti",   # gesti | tasti
    "dock": ["telefono", "messaggi", "fotocamera", "musica"],
    "non_disturbare": False,
    "vibrazione": True,
    "silenzioso": False,
    "suoneria": "Alba",
    "blocco_auto": 2,          # minuti prima che lo schermo si spenga (0 = mai)
    "sempre_acceso": False,
    "dati_mobili": True,
    "roaming": False,
    "sim_dati": "1",
    "risparmio": False,
    "segreteria": "",          # numero della segreteria dell'operatore
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


# App interne all'interfaccia (si aprono subito e non occupano memoria in più).
# Icone: set proprio di SolidOS Mobile (src/dati/icone, generato da scripts/genera-icone.py):
# tessera con sfumatura sobria e simbolo bianco pieno, uguale per tutte le app interne.
IN_ARRIVO = {
    "telefono": {"id": "interno:telefono", "nome": T("Telefono"), "icona": "nucleo-telefono", "categorie": ["Telephony"]},
    "messaggi": {"id": "interno:messaggi", "nome": T("Messaggi"), "icona": "nucleo-messaggi", "categorie": ["Chat"]},
    "contatti": {"id": "interno:contatti", "nome": T("Contatti"), "icona": "nucleo-contatti", "categorie": ["ContactManagement"]},
    "dove": {"id": "interno:dove", "nome": T("Dov'è"), "icona": "nucleo-dove", "categorie": ["Utility"]},
    "mappe": {"id": "interno:mappe", "nome": T("Mappe"), "icona": "nucleo-mappe", "categorie": ["Maps", "Utility"]},
    "impostazioni": {"id": "interno:impostazioni", "nome": T("Impostazioni"), "icona": "nucleo-impostazioni", "categorie": ["Settings"]},
    "fotocamera": {"id": "interno:fotocamera", "nome": T("Fotocamera"), "icona": "nucleo-fotocamera", "categorie": ["Photography"]},
    "foto": {"id": "interno:foto", "nome": T("Foto"), "icona": "nucleo-foto", "categorie": ["Graphics", "Photography"]},
    "musica": {"id": "interno:musica", "nome": T("Musica"), "icona": "nucleo-musica", "categorie": ["Audio", "Player"]},
    "note": {"id": "interno:note", "nome": T("Note"), "icona": "nucleo-note", "categorie": ["Office", "TextEditor"]},
    "file": {"id": "interno:file", "nome": T("File"), "icona": "nucleo-file", "categorie": ["FileManager", "Utility"]},
    "calcolatrice": {"id": "interno:calcolatrice", "nome": T("Calcolatrice"), "icona": "nucleo-calcolatrice", "categorie": ["Calculator", "Utility"]},
    "store": {"id": "interno:store", "nome": T("Store"), "icona": "nucleo-store", "categorie": ["System"]},
    "vicina": {"id": "interno:vicina", "nome": T("Vicina"), "icona": "nucleo-vicina", "categorie": ["Network", "FileTransfer"]},
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


def _colori_sfondo(indirizzo: str, proporzione: float, fasce: int = 48) -> list:
    from PyQt6.QtCore import QRectF, Qt, QUrl
    from PyQt6.QtGui import QColor, QImage, QPainter

    percorso = QUrl(indirizzo).toLocalFile() if indirizzo.startswith("file:") else indirizzo
    if not percorso or not Path(percorso).is_file():
        return []
    if percorso.endswith(".svg"):
        from PyQt6.QtSvg import QSvgRenderer

        r = QSvgRenderer(percorso)
        vb = r.viewBoxF()
        immagine = QImage(int(vb.width()), int(vb.height()), QImage.Format.Format_RGB32)
        immagine.fill(QColor("black"))
        p = QPainter(immagine)
        r.render(p, QRectF(0, 0, vb.width(), vb.height()))
        p.end()
    else:
        immagine = QImage(percorso)
        if immagine.isNull():
            return []
    # Ritaglio al centro con le proporzioni dello schermo (come PreserveAspectCrop)
    w, h = immagine.width(), immagine.height()
    if w / h > proporzione:
        nw = max(1, int(h * proporzione))
        immagine = immagine.copy((w - nw) // 2, 0, nw, h)
    else:
        nh = max(1, int(w / proporzione))
        immagine = immagine.copy(0, (h - nh) // 2, w, nh)
    colonna = immagine.scaled(1, fasce, Qt.AspectRatioMode.IgnoreAspectRatio, Qt.TransformationMode.SmoothTransformation)
    return [colonna.pixelColor(0, y).name() for y in range(fasce)]


class BackendMobile(Backend):
    def __init__(self):
        self._app: list[dict] | None = None
        self.centro = CentroNotifiche(lambda e, d: self.emetti(e, d))
        self.centro.non_disturbare = bool(self.impostazioni().get("non_disturbare"))
        from . import telefonia

        if telefonia.DEMO:
            self.centro.aggiungi(T("Messaggi"), "Mamma", "A che ora arrivi stasera? Ho preparato la cena", "nucleo-messaggi", "messaggi")
            self.centro.aggiungi(T("Telefono"), T("Chiamata persa"), "Giulia Rossi", "nucleo-telefono", "telefono")
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
            self.centro.aggiungi(T("Messaggi"), telefonia.nome_di(numero) or numero, testo, "nucleo-messaggi", "messaggi")
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
            elif a.startswith("--dimensione="):   # es. 427x757 (schermo del telefono virtuale)
                try:
                    l, h = a.split("=", 1)[1].lower().split("x")
                    risultato["larghezza"], risultato["altezza"] = int(l), int(h)
                except ValueError:
                    pass
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
            # App interne del telefono + app installate (.desktop), in ordine alfabetico
            self._app = sorted(list(IN_ARRIVO.values()) + _app_installate(), key=lambda a: a["nome"].lower())
        return self._app

    def _per_id(self, breve: str) -> dict | None:
        if breve in IN_ARRIVO:
            return IN_ARRIVO[breve]
        desktop = branding.comando(ALIAS.get(breve, breve))
        tutte = self.app()
        return next((a for a in tutte if a["id"] == desktop), None) \
            or next((a for a in tutte if a["id"].endswith(breve)), None)

    def home(self) -> list:
        """Le app della Home: l'ordine scelto spostandole, oppure quello di SolidOS; senza quelle tolte."""
        conf = self.impostazioni()
        nascoste = set(conf.get("nascoste_home") or [])
        risultato = []
        for ident in conf.get("ordine_home") or []:
            a = next((x for x in self.app() if x["id"] == ident), None)
            if a and a["id"] not in nascoste and a not in risultato:
                risultato.append(a)
        ordine = ["fotocamera", "foto", "contatti", "note", "file", "dove", "mappe", "musica", "store", "vicina", "calcolatrice", "impostazioni"]
        for a in (self._per_id(x) for x in ordine):
            if a and a["id"] not in nascoste and a not in risultato:
                risultato.append(a)
        dock = set(conf["dock"])
        for a in self.app():
            if len(risultato) >= 16:
                break
            if a not in risultato and a["id"] not in nascoste and not any(a is self._per_id(d) for d in dock):
                risultato.append(a)
        return risultato

    # ── Widget ───────────────────────────────────────────────────────────
    def meteo(self) -> dict:
        return strumenti.meteo(self.impostazioni().get("citta_meteo", ""))

    def orologi(self) -> list:
        """Ora nelle città del widget Orologio."""
        from datetime import datetime, timedelta, timezone

        citta = [("Londra", "Europe/London", 0), ("New York", "America/New_York", -5), ("Tokyo", "Asia/Tokyo", 9)]
        risultato = []
        for nome, zona, riserva in citta:
            try:
                from zoneinfo import ZoneInfo

                ora = datetime.now(ZoneInfo(zona))
            except Exception:  # noqa: BLE001 — senza tzdata: fuso fisso
                ora = datetime.now(timezone.utc) + timedelta(hours=riserva)
            risultato.append({"citta": T(nome), "ora": ora.strftime("%H:%M")})
        return risultato

    def notaRecente(self) -> dict:
        n = strumenti.note()
        return n[0] if n else {}

    def fotoRicordo(self) -> dict:
        """Una foto per il widget Foto: una dello stesso giorno degli anni passati, o una a caso."""
        import random

        elenco = strumenti.foto()
        if not elenco:
            return {}
        oggi = time.strftime("%m-%d")
        vecchie = [f for f in elenco if time.strftime("%m-%d", time.localtime(f["quando"])) == oggi
                   and time.localtime(f["quando"]).tm_year < time.localtime().tm_year]
        f = dict(random.choice(vecchie or elenco))
        anni = time.localtime().tm_year - time.localtime(f["quando"]).tm_year
        f["titolo"] = (T("Un anno fa") if anni == 1 else T("{n} anni fa", n=anni)) if vecchie else T("Dalle tue foto")
        return f

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

    # ── Compositore: le app dello Store si aprono dentro SolidOS ─────────
    def compositorePronto(self, socket: str) -> None:
        """L'interfaccia fa da compositore Wayland: le app che avvia si collegano a lei."""
        if not socket:
            return
        os.environ["WAYLAND_DISPLAY"] = socket
        os.environ["GDK_BACKEND"] = "wayland"
        os.environ["QT_QPA_PLATFORM"] = "wayland"
        os.environ["SDL_VIDEODRIVER"] = "wayland"
        os.environ["MOZ_ENABLE_WAYLAND"] = "1"
        if os.environ.get("QT_QUICK_BACKEND") == "software":     # niente scheda video: disegno a software
            os.environ["GSK_RENDERER"] = "cairo"
            os.environ["LIBGL_ALWAYS_SOFTWARE"] = "1"
        # la grandezza la decide il compositore (fattore di scala dell'uscita), non Qt nelle app
        for k in ("QT_SCALE_FACTOR", "QT_QUICK_BACKEND", "QT_QPA_GENERIC_PLUGINS", "QT_QPA_FB_HIDECURSOR"):
            os.environ.pop(k, None)
        self._compositore = socket

    # ── Widget dalle app: la musica che suona in qualsiasi app (MPRIS) ───
    def _mpris(self):
        import dbus

        bus = dbus.SessionBus()
        nomi = [n for n in bus.list_names() if str(n).startswith("org.mpris.MediaPlayer2.")]
        return bus, nomi

    def mpris(self) -> dict:
        try:
            import dbus

            bus, nomi = self._mpris()
            for nome in nomi:
                o = bus.get_object(nome, "/org/mpris/MediaPlayer2")
                prop = dbus.Interface(o, "org.freedesktop.DBus.Properties")
                meta = prop.Get("org.mpris.MediaPlayer2.Player", "Metadata")
                stato = str(prop.Get("org.mpris.MediaPlayer2.Player", "PlaybackStatus"))
                artisti = meta.get("xesam:artist", [])
                try:
                    app = str(prop.Get("org.mpris.MediaPlayer2", "Identity"))
                except Exception:  # noqa: BLE001
                    app = str(nome).rsplit(".", 1)[-1]
                return {"titolo": str(meta.get("xesam:title", "")), "artista": ", ".join(str(a) for a in artisti),
                        "suona": stato == "Playing", "app": app, "copertina": str(meta.get("mpris:artUrl", "")), "nome": str(nome)}
        except Exception:  # noqa: BLE001 — niente bus o nessun lettore
            pass
        return {}

    def mprisComando(self, comando: str) -> None:
        metodi = {"play": "PlayPause", "avanti": "Next", "indietro": "Previous"}
        if comando not in metodi:
            return
        try:
            import dbus

            bus, nomi = self._mpris()
            if nomi:
                o = bus.get_object(nomi[0], "/org/mpris/MediaPlayer2")
                getattr(dbus.Interface(o, "org.mpris.MediaPlayer2.Player"), metodi[comando])()
        except Exception:  # noqa: BLE001
            pass

    def scalaSchermo(self) -> float:
        try:
            return float(os.environ.get("SOLIDOS_SCALA_SCHERMO") or os.environ.get("QT_SCALE_FACTOR") or 1)
        except ValueError:
            return 1.0

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
        from . import telefonia
        from ..hw import audio

        if telefonia.DEMO:   # foto della prova: un valore realistico
            return 60

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

    # ── Tastiera sullo schermo: i tasti arrivano al campo come quelli di una tastiera vera ──
    def tasto(self, testo: str, nome: str = "") -> None:
        from PyQt6.QtCore import QCoreApplication, QEvent, Qt
        from PyQt6.QtGui import QGuiApplication, QKeyEvent

        finestra = QGuiApplication.focusWindow() or next(iter(QGuiApplication.topLevelWindows()), None)
        if finestra is None:
            return
        tasti = {"invio": Qt.Key.Key_Return, "cancella": Qt.Key.Key_Backspace, "sinistra": Qt.Key.Key_Left,
                 "destra": Qt.Key.Key_Right}
        codice = tasti.get(nome, Qt.Key.Key_unknown)
        if nome == "invio":
            testo = "\r"
        elif nome == "cancella":
            testo = "\b"
        for tipo in (QEvent.Type.KeyPress, QEvent.Type.KeyRelease):
            QCoreApplication.sendEvent(finestra, QKeyEvent(tipo, codice, Qt.KeyboardModifier.NoModifier, testo))

    def contatti(self) -> list:
        from . import telefonia

        return telefonia.contatti()

    def salvaContatto(self, nome: str, numero: str, ident: str = "", email: str = "", note: str = "") -> dict:
        from . import telefonia

        return telefonia.salva_contatto(nome, numero, ident, email, note)

    def salvaScheda(self, dati: dict) -> dict:
        from . import telefonia

        return telefonia.salva_scheda(dati)

    def miaScheda(self) -> dict:
        from . import telefonia

        return telefonia.mia_scheda()

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
                T("Telefono"), T("Chiamata persa"), telefonia.nome_di(numero) or numero, "nucleo-telefono", "telefono")
        return self._ch

    def chiama(self, numero: str) -> dict:
        return self._chiamate().chiama(numero)

    # ── Chiamate via Internet (SIP) ──────────────────────────────────────
    def voipAccount(self) -> dict:
        from . import voip, telefonia

        if telefonia.DEMO:
            return {"utente": "0812345678", "dominio": "sip.messagenet.it", "server": "", "nome": "Pasquale", "attivo": True,
                    "haPassword": True, "disponibile": True, "registrato": True, "errore": ""}
        return {**voip.account(), **voip.linea().stato()}

    def voipSalva(self, utente: str, password: str, dominio: str, server: str = "", nome: str = "", attivo: bool = True) -> dict:
        from . import voip

        return voip.salva(utente, password, dominio, server, nome, attivo)

    def voipAvvia(self) -> None:
        """All'avvio dell'interfaccia: si collega all'account SIP (se attivo)."""
        from . import voip, telefonia

        if not telefonia.DEMO and not voip.linea().attiva:
            voip.linea().avvia()

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

    # ── Impostazioni del telefono ────────────────────────────────────────
    def wifiStato(self, scansiona: bool = False) -> dict:
        from . import impostazioni

        return impostazioni.wifi(bool(scansiona))

    def wifiAcceso(self, si: bool) -> None:
        from . import impostazioni

        impostazioni.imposta_wifi(si)

    def connettiWifi(self, ssid: str, password: str) -> dict:
        from . import impostazioni

        return impostazioni.connetti_wifi(ssid, password)

    def dimenticaWifi(self, ssid: str) -> dict:
        from . import impostazioni

        return impostazioni.dimentica_wifi(ssid)

    def btStato(self) -> dict:
        from . import impostazioni

        return impostazioni.bluetooth()

    def btAcceso(self, si: bool) -> None:
        from . import impostazioni

        impostazioni.imposta_bluetooth(si)

    def btCerca(self) -> list:
        from . import impostazioni

        return impostazioni.cerca_bluetooth()

    def btAzione(self, indirizzo: str, azione: str) -> dict:
        from . import impostazioni

        return impostazioni.azione_bluetooth(indirizzo, azione)

    def reteMobile(self) -> dict:
        from . import impostazioni

        return impostazioni.rete_mobile(self.impostazioni())

    def datiMobili(self, si: bool) -> dict:
        from . import impostazioni

        self.imposta("dati_mobili", bool(si))
        return impostazioni.imposta_dati(bool(si))

    def sbloccaSim(self, pin: str) -> dict:
        from . import impostazioni

        return impostazioni.sblocca_sim(pin)

    def volumeSuoni(self) -> int:
        from . import impostazioni

        return impostazioni.volume()

    def impostaVolumeSuoni(self, valore: int) -> None:
        from . import impostazioni

        impostazioni.imposta_volume(valore)

    def batteriaInfo(self) -> dict:
        from . import impostazioni

        return impostazioni.batteria(self.impostazioni())

    def risparmio(self, si: bool) -> None:
        from . import impostazioni

        self.imposta("risparmio", bool(si))
        impostazioni.imposta_risparmio(bool(si))

    def sfondo(self, nome: str, chiaro: bool) -> str:
        """Indirizzo dello sfondo del PC (colline) per la schermata del telefono."""
        nome = nome if nome in ("notte", "alba", "oceano", "aurora", "grafite") else "notte"
        file = f"{nome}-chiaro.svg" if chiaro else f"{nome}.svg"
        from ..qmlapp import CARTELLA_QML

        for base in (CARTELLA_QML.parent / "sfondi", CARTELLA_QML.parent / "dati" / "sfondi"):
            if (base / file).is_file():
                return (base / file).as_uri()
        return ""

    def coloriSfondo(self, indirizzo: str, proporzione: float) -> list:
        """Colori dello sfondo dall'alto in basso (48 fasce), come si vede sullo schermo del
        telefono: servono ai pannelli di vetro, che ne prendono la sfumatura della loro zona
        (un vetro sfocato che funziona anche senza scheda video)."""
        chiave = (indirizzo, round(float(proporzione), 3))
        cache = self.__dict__.setdefault("_colori_sfondo", {})
        if chiave not in cache:
            cache[chiave] = _colori_sfondo(indirizzo, float(proporzione))
        return cache[chiave]

    def infoTelefono(self) -> dict:
        from . import aggiornamento, impostazioni

        info = impostazioni.info()
        info["aggiornamenti"] = aggiornamento.stato()
        return info

    # ── Solid ID dal telefono ────────────────────────────────────────────
    def _sid(self):
        from .. import solidid

        return solidid

    def sidAccedi(self, email: str, password: str) -> dict:
        return self._sid().accedi(email, password)

    def sidCrea(self, nome: str, email: str, password: str) -> dict:
        return self._sid().crea(nome, email, password)

    def sidReinvia(self, email: str) -> dict:
        return self._sid().reinvia_conferma(email)

    def sidPassword(self, email: str) -> dict:
        return self._sid().password_dimenticata(email)

    def sidEsci(self, codice: str = "") -> dict:
        p = self.azioneProtetta("esci", codice)
        return p if not p["ok"] else self._sid().esci()

    def sidTrova(self, si: bool, codice: str = "") -> dict:
        if not si:
            p = self.azioneProtetta("trova", codice)
            if not p["ok"]:
                return p
        return self._sid().imposta_trova(bool(si))

    # ── Protezione in caso di furto (come su iPhone) ─────────────────────
    # Lontano dai luoghi abituali (le reti Wi-Fi dove il telefono sta spesso), le cose importanti
    # chiedono il codice e poi un'attesa di un'ora: chi ruba il telefono dopo aver visto il codice
    # non può spegnere Dov'è, uscire dal Solid ID, cambiare il codice o cancellare il telefono.
    ATTESA_FURTO = 3600

    def _file_luoghi(self) -> Path:
        return config_utente("luoghi-familiari.json")

    def _impara_luogo(self) -> None:
        """Ogni rete Wi-Fi a cui il telefono è collegato conta un giorno: dopo 3 giorni è «familiare»."""
        try:
            from . import impostazioni

            reti = impostazioni.wifi(False).get("reti", [])
            rete = next((x.get("ssid") for x in reti if x.get("connessa")), "")
        except Exception:  # noqa: BLE001
            rete = ""
        if not rete:
            return
        luoghi = leggi_json(self._file_luoghi(), {})
        giorni = luoghi.get(rete, [])
        oggi = time.strftime("%Y-%m-%d")
        if oggi not in giorni:
            luoghi[rete] = (giorni + [oggi])[-30:]
            scrivi_json(self._file_luoghi(), luoghi)
        self._rete_attuale = rete

    def inLuogoFamiliare(self) -> bool:
        self._impara_luogo()
        rete = getattr(self, "_rete_attuale", "")
        return bool(rete) and len(leggi_json(self._file_luoghi(), {}).get(rete, [])) >= 3

    def protezioneFurto(self) -> dict:
        from . import telefonia

        attiva = self.impostazioni().get("protezione_furto", True)
        familiare = True if telefonia.DEMO else self.inLuogoFamiliare()
        return {"attiva": bool(attiva), "familiare": familiare, "luoghi": list(leggi_json(self._file_luoghi(), {}).keys())}

    def azioneProtetta(self, nome: str, codice: str = "") -> dict:
        """{ok} se si può fare adesso; altrimenti il motivo (codice sbagliato o attesa di sicurezza)."""
        if self.haCodice() and not self.verificaCodice(codice).get("ok"):
            return {"ok": False, "chiediCodice": True, "messaggio": T("Per farlo serve il codice di sblocco")}
        stato = self.protezioneFurto()
        if not stato["attiva"] or stato["familiare"]:
            return {"ok": True}
        attese = leggi_json(config_utente("attese-sicurezza.json"), {})
        inizio = attese.get(nome, 0)
        passato = time.time() - inizio
        if inizio and self.ATTESA_FURTO <= passato <= self.ATTESA_FURTO * 2:
            attese.pop(nome, None)
            scrivi_json(config_utente("attese-sicurezza.json"), attese)
            return {"ok": True}
        if not inizio or passato > self.ATTESA_FURTO * 2:
            attese[nome] = time.time()
            scrivi_json(config_utente("attese-sicurezza.json"), attese)
            passato = 0
        minuti = max(1, -(-int(self.ATTESA_FURTO - passato) // 60))
        return {"ok": False, "attesa": True,
                "messaggio": T("Ritardo di sicurezza: sei lontano dai luoghi abituali. Riprova tra {m} minuti (con il codice).", m=minuti)}

    def sidDispositivi(self) -> dict:
        from . import telefonia

        if telefonia.DEMO:
            return {"ok": True, "dispositivi": [
                {"id": "b", "nome": "Telefono di Pasquale", "tipo": "telefono", "batteria": 82, "questo": True},
                {"id": "a", "nome": "Portatile di Pasquale", "tipo": "portatile", "batteria": 76, "questo": False}]}
        try:
            sid = self._sid()
            questo = sid.sessione().get("dispositivo_id", "")
            return {"ok": True, "dispositivi": [{**d, "questo": d["id"] == questo} for d in sid.dispositivi()]}
        except Exception as e:  # noqa: BLE001
            return {"ok": False, "messaggio": str(e), "dispositivi": []}

    def solidId(self) -> dict:
        from . import telefonia

        if telefonia.DEMO:   # solo per le foto della prova
            return {"collegato": True, "disponibile": True, "nome": "Pasquale", "email": "pasquale@esempio.it", "trova": True}
        try:
            from .. import solidid

            return {**solidid.utente(), "disponibile": solidid.disponibile()}
        except Exception:  # noqa: BLE001
            return {"collegato": False, "disponibile": False}

    # ── Codice di sblocco (PIN del telefono) ─────────────────────────────
    def _file_codice(self) -> Path:
        return config_utente("codice.json")

    def haCodice(self) -> bool:
        return bool(leggi_json(self._file_codice(), {}).get("hash"))

    @staticmethod
    def _hash(codice: str, sale: str) -> str:
        import hashlib

        return hashlib.pbkdf2_hmac("sha256", codice.encode(), bytes.fromhex(sale), 200_000).hex()

    def verificaCodice(self, codice: str) -> dict:
        dati = leggi_json(self._file_codice(), {})
        if not dati.get("hash"):
            return {"ok": True}
        attesa = dati.get("bloccato_fino", 0) - time.time()
        if attesa > 0:
            return {"ok": False, "messaggio": T("Troppi tentativi: riprova tra {s} secondi", s=int(attesa) + 1)}
        if self._hash(codice, dati["sale"]) == dati["hash"]:
            dati["errori"] = 0
            scrivi_json(self._file_codice(), dati)
            return {"ok": True}
        dati["errori"] = dati.get("errori", 0) + 1
        if dati["errori"] >= 5:
            dati["bloccato_fino"] = time.time() + 30 * 2 ** min(dati["errori"] - 5, 6)
        scrivi_json(self._file_codice(), dati)
        return {"ok": False, "messaggio": T("Codice sbagliato")}

    def impostaCodice(self, attuale: str, nuovo: str) -> dict:
        import secrets

        if self.haCodice() and not self.verificaCodice(attuale)["ok"]:
            return {"ok": False, "messaggio": T("Il codice attuale non è giusto")}
        if self.haCodice():
            p = self.azioneProtetta("codice", attuale)
            if not p["ok"]:
                return p
        if nuovo == "":
            scrivi_json(self._file_codice(), {})
            return {"ok": True, "messaggio": T("Codice tolto: il telefono si apre senza codice")}
        if not nuovo.isdigit() or not 4 <= len(nuovo) <= 8:
            return {"ok": False, "messaggio": T("Il codice deve avere da 4 a 8 cifre")}
        sale = secrets.token_hex(16)
        f = self._file_codice()
        scrivi_json(f, {"sale": sale, "hash": self._hash(nuovo, sale), "errori": 0, "lunghezza": len(nuovo)})
        os.chmod(f, 0o600)
        return {"ok": True, "messaggio": T("Codice di sblocco impostato")}

    def lunghezzaCodice(self) -> int:
        return int(leggi_json(self._file_codice(), {}).get("lunghezza", 6))

    # ── Blocco a distanza da «Dov'è» ─────────────────────────────────────
    def _cartella_blocco(self) -> Path:
        base = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os() / "blocco"
        base.mkdir(parents=True, exist_ok=True)
        return base

    def richiestaBlocco(self) -> dict:
        """Controllato ogni 2 secondi: «Dov'è» chiede di bloccare il telefono?"""
        base = self._cartella_blocco()
        messaggio = ""
        try:
            messaggio = (base / "messaggio-remoto").read_text(encoding="utf-8").strip()
        except OSError:
            pass
        ora = (base / "blocca-ora").exists()
        if ora:
            (base / "blocca-ora").unlink(missing_ok=True)
        cancella = (base / "cancella-ora").exists()
        return {"blocca": ora, "messaggio": messaggio, "perso": (base / "perso").exists() and bool(messaggio),
                "cancella": cancella}

    # ── Sicurezza come su iPhone ─────────────────────────────────────────
    def verificaSolidId(self, password: str) -> dict:
        """Modalità smarrito: si sblocca solo con la password del Solid ID (il codice non basta)."""
        from . import telefonia

        if telefonia.DEMO:
            return {"ok": password == "prova", "messaggio": "" if password == "prova" else T("Password sbagliata")}
        from .. import solidid

        if solidid.verifica_password(password):
            return {"ok": True}
        return {"ok": False, "messaggio": T("Password del Solid ID sbagliata (o niente connessione a Internet)")}

    def emailSolidId(self) -> str:
        from .. import solidid

        email = solidid.utente().get("email", "")
        return (email[0] + "•••" + email[email.index("@"):]) if "@" in email else ""

    def bloccoAttivazione(self) -> str:
        """Telefono di un altro Solid ID (anche dopo un reset): l'email nascosta del proprietario."""
        from . import telefonia

        if telefonia.DEMO:
            return "p•••@gmail.com" if self.avvio().get("schermata") == "attivazione" else ""
        from .. import solidid

        try:
            return solidid.blocco_attivazione()
        except Exception:  # noqa: BLE001 — senza rete il telefono non resta bloccato per sempre
            return ""

    def sbloccaAttivazione(self, email: str, password: str) -> dict:
        from .. import solidid

        r = solidid.accedi(email, password)
        if not r.get("ok"):
            return r
        if solidid.blocco_attivazione():
            solidid.esci()
            return {"ok": False, "messaggio": T("Questo telefono appartiene a un altro Solid ID")}
        return {"ok": True, "messaggio": T("Telefono sbloccato: bentornato")}

    def disattivaProtezioneFurto(self, codice: str = "") -> dict:
        p = self.azioneProtetta("protezione", codice)
        if not p["ok"]:
            return p
        self.imposta("protezione_furto", False)
        return {"ok": True, "messaggio": T("Protezione in caso di furto spenta")}

    def inizializzaDaImpostazioni(self, codice: str = "") -> dict:
        p = self.azioneProtetta("inizializza", codice)
        return p if not p["ok"] else self.inizializza()

    def inizializza(self) -> dict:
        """Cancella tutti i dati dell'utente (Dov'è › Inizializza a distanza, o dalle Impostazioni)
        e riparte come nuovo. Il blocco di attivazione resta: serve il Solid ID del proprietario."""
        from . import telefonia

        casa = Path.home()
        if telefonia.DEMO or str(casa) in ("/", "/root") or not str(casa).startswith("/home/"):
            return {"ok": False, "messaggio": T("Non disponibile qui")}
        import shutil

        for voce in list(casa.iterdir()):
            try:
                shutil.rmtree(voce) if voce.is_dir() and not voce.is_symlink() else voce.unlink()
            except OSError:
                pass
        os._exit(0)          # il servizio dell'interfaccia riparte da solo, come un telefono nuovo

    def sbloccatoRemoto(self) -> None:
        try:
            from ..solidid.servizio import sbloccato

            sbloccato()
        except Exception:  # noqa: BLE001
            (self._cartella_blocco() / "messaggio-remoto").unlink(missing_ok=True)

    # ── Dov'è (stessa logica dell'app del PC) ────────────────────────────
    def _dove(self):
        if not hasattr(self, "_bd"):
            from ..apps.dove import BackendDove

            self._bd = BackendDove()
        return self._bd

    def doveDispositivi(self) -> dict:
        from . import telefonia

        if telefonia.DEMO:
            return {"ok": True, "dispositivi": [
                {"id": "a", "nome": "Portatile di Pasquale", "tipo": "portatile", "icona": "computer-laptop", "modello": "Lenovo ThinkPad",
                 "questo": False, "stato": "adesso · 76% · in carica", "posizione": True, "lat": 41.8986, "lon": 12.4769, "precisione": 60,
                 "fonte": "wifi", "quandoPosizione": "adesso", "bloccato": False, "trova": True},
                {"id": "b", "nome": "Telefono di Pasquale", "tipo": "telefono", "icona": "phone", "modello": "Huawei P10 Lite",
                 "questo": True, "stato": "Questo telefono · 82%", "posizione": True, "lat": 41.9028, "lon": 12.4964, "precisione": 15,
                 "fonte": "gps", "quandoPosizione": "adesso", "bloccato": False, "trova": True}]}
        r = self._dove().dispositivi()
        for d in r.get("dispositivi", []):
            if d.get("questo"):
                d["stato"] = d["stato"].replace(T("Questo computer"), T("Questo telefono"))
        return r

    def doveComando(self, dispositivo: str, tipo: str, messaggio: str = "") -> dict:
        from . import telefonia

        if telefonia.DEMO:
            return {"ok": True, "id": 1}
        return self._dove().comando(dispositivo, tipo, messaggio)

    def doveStatoComando(self, ident: int) -> str:
        from . import telefonia

        return "eseguito" if telefonia.DEMO else self._dove().statoComando(ident)

    def tessere(self, elenco, stile: str = "chiaro") -> dict:
        return self._dove().tessere(elenco, stile)

    # ── Mappe e navigatore (nucleo/mappe: lo stesso codice del PC) ───────
    def mappe(self, metodo: str, argomenti=None):
        if not hasattr(self, "_mappe_b"):
            from ..apps.mappe import BackendMappe

            self._mappe_b = BackendMappe()
        if str(metodo).startswith("_") or not hasattr(self._mappe_b, metodo):
            return None
        return getattr(self._mappe_b, metodo)(*(argomenti or []))

    def indicazioni(self, lat: float, lon: float) -> None:
        self._dove().indicazioni(lat, lon)

    # ── App di base (strumenti.py) ───────────────────────────────────────
    def calcola(self, espressione: str, radianti: bool = False) -> dict:
        return strumenti.calcola(espressione, radianti)

    def calcStoria(self) -> list:
        return strumenti.storia_calcoli()

    def calcAggiungi(self, espressione: str, risultato: str) -> None:
        strumenti.aggiungi_calcolo(espressione, risultato)

    def calcCancellaStoria(self) -> None:
        strumenti.cancella_storia()

    def calcUnita(self, categoria: str) -> list:
        return strumenti.unita_conversione(categoria)

    def calcConverti(self, categoria: str, da: str, a: str, espressione: str) -> dict:
        return strumenti.converti(categoria, da, a, espressione)

    def note(self, cerca: str = "") -> list:
        return strumenti.note(cerca)

    def leggiNota(self, ident: str) -> dict:
        return strumenti.leggi_nota(ident)

    def salvaNota(self, ident: str, testo: str) -> str:
        return strumenti.salva_nota(ident, testo)

    def fissaNota(self, ident: str, si: bool) -> None:
        strumenti.fissa_nota(ident, si)

    def eliminaNota(self, ident: str) -> None:
        strumenti.elimina_nota(ident)

    def luoghiFile(self) -> list:
        return strumenti.luoghi()

    def elencoFile(self, percorso: str, nascosti: bool = False, ordine: str = "nome") -> dict:
        return strumenti.elenco_file(percorso, nascosti, ordine)

    def fileSfoglia(self) -> dict:
        return strumenti.file_sfoglia()

    def fileRecenti(self, filtro: str = "") -> list:
        return strumenti.file_recenti(filtro)

    def fileCondivisi(self) -> list:
        return strumenti.file_condivisi()

    def fileCerca(self, testo: str) -> list:
        return strumenti.file_cerca(testo)

    def fileConTag(self, ident: str) -> list:
        return strumenti.file_con_tag(ident)

    def fileTag(self, percorso: str, ident: str, si: bool) -> None:
        strumenti.file_imposta_tag(percorso, ident, si)

    def fileDuplica(self, percorso: str) -> dict:
        return strumenti.file_duplica(percorso)

    def fileComprimi(self, percorso: str) -> dict:
        return strumenti.file_comprimi(percorso)

    def fileSposta(self, percorso: str, cartella: str) -> dict:
        return strumenti.file_sposta(percorso, cartella)

    def fileRemoto(self, servizio: str, cartella: str = "") -> dict:
        from . import fotoaccount

        return fotoaccount.sfoglia(servizio, cartella)

    def fileScaricaRemoto(self, servizio: str, relativo: str) -> dict:
        from . import fotoaccount

        return fotoaccount.scarica(servizio, relativo)

    def nuovaCartella(self, dove: str, nome: str) -> dict:
        return strumenti.nuova_cartella(dove, nome)

    def rinominaFile(self, percorso: str, nome: str) -> dict:
        return strumenti.rinomina(percorso, nome)

    def cestinaFile(self, percorso: str) -> dict:
        return strumenti.cestina(percorso)

    def leggiTesto(self, percorso: str) -> str:
        return strumenti.leggi_testo(percorso)

    # ── Foto: account collegati ──────────────────────────────────────────
    def fotoServizi(self) -> list:
        from . import fotoaccount

        return fotoaccount.servizi()

    def fotoCollegaNextcloud(self, indirizzo: str, utente: str, password: str, cartella: str) -> dict:
        from . import fotoaccount

        return fotoaccount.collega_nextcloud(indirizzo, utente, password, cartella)

    def fotoCollegaServer(self, indirizzo: str, utente: str = "", password: str = "") -> dict:
        from . import fotoaccount

        return fotoaccount.collega_server(indirizzo, utente, password)

    def fotoScopriServer(self) -> list:
        from . import fotoaccount

        return fotoaccount.scopri_server()

    def fotoScollega(self, servizio: str) -> dict:
        from . import fotoaccount

        return fotoaccount.scollega(servizio)

    def fotoImposta(self, servizio: str, chiave: str, valore: bool) -> None:
        from . import fotoaccount

        fotoaccount.imposta(servizio, chiave, bool(valore))

    def fotoPreferita(self, percorso: str, si: bool) -> None:
        strumenti.foto_preferita(percorso, bool(si))

    def fotoSincronizza(self) -> None:
        from . import fotoaccount

        fotoaccount.sincronizza()

    def foto(self) -> list:
        return strumenti.foto()

    def nuovaFoto(self) -> str:
        return strumenti.nuova_foto()

    def sfondoFoto(self, percorso: str) -> dict:
        self.imposta("sfondo", percorso)
        return {"ok": True, "messaggio": T("Sfondo cambiato")}

    def musica(self) -> list:
        return strumenti.musica()

    def storeConsigliate(self) -> dict:
        return strumenti.store_consigliate()

    def storeCerca(self, testo: str, solo_telefono: bool = True) -> list:
        return strumenti.store_cerca(testo, bool(solo_telefono))

    # ── Store: raccolte, scheda dell'app e recensioni (come SolidOS App sul PC) ──
    def storeRaccolte(self) -> list:
        from .. import catalogo

        installate = strumenti._installate_flatpak()
        r = catalogo.raccolte(catalogo.RACCOLTE_TELEFONO)
        for x in r:
            for a in x["app"]:
                a["installata"] = a["id"] in installate
        return r

    def storeScheda(self, ident: str) -> dict:
        from .. import catalogo

        d = catalogo.dettagli(ident)
        if d.get("ok"):
            d["installata"] = ident in strumenti._installate_flatpak()
            d["telefono"] = strumenti.adatta_al_telefono(ident)
            d["raccolte"] = catalogo.raccolte_di(ident, catalogo.RACCOLTE_TELEFONO)
        return d

    def storeRecensioni(self, ident: str) -> dict:
        from .. import recensioni

        return {"riepilogo": recensioni.riepilogo(ident), "elenco": recensioni.elenco(ident),
                "account": recensioni.collegato()}

    def storeScriviRecensione(self, ident: str, voto: int, titolo: str, testo: str) -> dict:
        from .. import recensioni

        return recensioni.scrivi(ident, voto, titolo, testo)

    def storeCancellaRecensione(self, ident: str) -> dict:
        from .. import recensioni

        return recensioni.cancella(ident)

    def storeUtile(self, recensione: str) -> dict:
        from .. import recensioni

        return recensioni.utile(recensione)

    def storeInstalla(self, ident: str, nome: str = "", icona: str = "") -> dict:
        from .. import appmie

        def avanzamento(percento: int, fase: str) -> None:
            self.emetti("store-avanzamento", {"id": ident, "percento": percento, "fase": fase})

        r = strumenti.store_installa(ident, avanzamento)
        self._app = None
        if r.get("ok"):
            appmie.aggiungi(ident, nome, icona)   # entra in «Le mie app» del Solid ID
        return r

    # ── Le mie app: quelle prese con lo stesso Solid ID sugli altri dispositivi ──
    def storeMieApp(self) -> dict:
        from .. import appmie
        from . import telefonia

        installate = strumenti._installate_flatpak()
        if telefonia.DEMO:   # solo per le foto della prova
            elenco = [{"app": "org.gnome.Weather", "nome": "Meteo", "dispositivo": "telefono"},
                      {"app": "org.gnome.Maps", "nome": "Mappe", "dispositivo": "pc", "icona": strumenti._icona_flathub("org.gnome.Maps")},
                      {"app": "de.haeckerfelix.Shortwave", "nome": "Shortwave", "dispositivo": "pc",
                       "icona": strumenti._icona_flathub("de.haeckerfelix.Shortwave")}]
            collegato = True
        else:
            elenco, collegato = appmie.elenco(), appmie.collegato()
        for a in elenco:
            a["installata"] = a.get("app") in installate
        return {"collegato": collegato, "elenco": elenco, "automatiche": bool(self.impostazioni().get("app_automatiche", True))}

    def storeScaricaMie(self) -> dict:
        """Scarica da sola le app prese sugli altri dispositivi (se l'impostazione è accesa)."""
        from .. import appmie

        if not self.impostazioni().get("app_automatiche", True) or not appmie.collegato():
            return {"ok": True, "scaricate": 0}
        n = 0
        for a in appmie.da_scaricare(strumenti._installate_flatpak()):
            if self.storeInstalla(a["app"], a.get("nome", ""), a.get("icona", "")).get("ok"):
                n += 1
                self.emetti("store-scaricata", {"id": a["app"], "nome": a.get("nome", "")})
        return {"ok": True, "scaricate": n}

    def storeTogliMia(self, ident: str) -> dict:
        from .. import appmie

        return appmie.togli(ident)

    def storeRimuovi(self, ident: str) -> dict:
        r = strumenti.store_rimuovi(ident)
        self._app = None
        return r

    def vicinaStato(self) -> dict:
        return strumenti.vicina_stato()

    def vicinaScopri(self) -> None:
        strumenti.vicina_scopri()

    def vicinaVisibilita(self, modalita: str) -> None:
        strumenti.vicina_visibilita(modalita)

    def vicinaInvia(self, file, dispositivo: str) -> dict:
        return strumenti.vicina_invia(list(file), dispositivo)

    def vicinaQr(self) -> dict:
        return strumenti.vicina_qr()

    def vicinaFermaQr(self) -> None:
        strumenti.vicina_ferma_qr()

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
