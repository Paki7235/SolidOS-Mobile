"""Videochiamate: chiamate audio e video tra persone con un Solid ID (vedi nucleo/chiamate).

Uso: videochiamate                      → elenco (preferiti, recenti, contatti) e chiamate
     videochiamate --in-arrivo <dati>   → schermata della chiamata in arrivo (la apre il
                                          servizio degli avvisi)
     videochiamate --chiama <email>     → chiama subito (da Contatti, per esempio)
"""

from __future__ import annotations

import base64
import json
import os
import signal
import sys
import time
from pathlib import Path

from .. import chiamate, suoni
from ..i18n import T
from ..ponte import Backend, crea_ponte

TESTI = ["Chiamata…", "Squilla…", "Connessione…", "Connessione instabile…", "Collegamento non riuscito", "Non disponibile",
         "Occupato", "Nessuna risposta", "Chiamata persa", "Hai risposto su un altro dispositivo", "Videochiamata SolidOS",
         "Chiamata audio SolidOS", "Chiamata non riuscita", "Videocamera non disponibile: chiamata solo audio",
         "Videocamera non disponibile", "Stai condividendo lo schermo", "{n} ha spento il microfono", "Spegni il microfono",
         "Accendi il microfono", "Spegni la videocamera", "Accendi la videocamera"]


def file_occupato() -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "solidos-in-chiamata"


class BackendVideochiamate(Backend):
    def __init__(self, in_arrivo: dict | None = None, chiama: str = "") -> None:
        self._in_arrivo = in_arrivo
        self._chiama = chiama
        self._suono = None

    def avvio(self) -> dict:
        r = {"inArrivo": self._in_arrivo, "chiama": self._chiama}
        self._in_arrivo, self._chiama = None, ""
        return r

    def configurazione(self) -> dict:
        return chiamate.configurazione()

    def token(self) -> str:
        try:
            from .. import solidid

            return solidid.token()
        except Exception:  # noqa: BLE001
            return ""

    def traduzioni(self) -> dict:
        return {t: T(t) for t in TESTI}

    def persona(self, email: str) -> dict:
        return chiamate.persona(str(email))

    def recenti(self) -> list:
        return chiamate.recenti()

    def cancellaRecenti(self) -> None:
        chiamate.cancella_recenti()

    def preferiti(self) -> list:
        return chiamate.preferiti()

    def preferito(self, p: dict, si: bool) -> list:
        return chiamate.preferito(dict(p), bool(si))

    def contatti(self) -> list:
        return chiamate.contatti_con_email()

    def registra(self, voce: dict) -> None:
        chiamate.aggiungi_recente(dict(voce))

    # ── suoni e stato «occupato» ──
    def squillo(self, attivo: bool, uscita: bool = False) -> None:
        if self._suono:
            try:
                os.killpg(self._suono.pid, signal.SIGTERM)
            except (OSError, ProcessLookupError):
                pass
            self._suono = None
        if attivo:
            self._suono = suoni.suona(volte=12 if uscita else 25, file=suoni.attesa() if uscita else suoni.squillo())

    def inChiamata(self, si: bool) -> None:
        f = file_occupato()
        if si:
            f.write_text(str(time.time()))
        else:
            f.unlink(missing_ok=True)

    def avvisoPersa(self, nome: str) -> None:
        from ..sistema import notifica

        notifica(T("Chiamata persa"), nome, "call-missed")

    def pagina(self) -> str:
        from ..qmlapp import CARTELLA_QML

        pc = CARTELLA_QML / "Videochiamate" / "chiamata.html"
        return (pc if pc.exists() else CARTELLA_QML / "Mobile" / "chiamata-video.html").as_uri()   # PC o telefono


def main() -> int:
    from ..qmlapp import carica, crea_app, prepara_ambiente

    in_arrivo, chiama = None, ""
    argomenti = sys.argv[1:]
    if "--in-arrivo" in argomenti:
        try:
            in_arrivo = json.loads(base64.urlsafe_b64decode(argomenti[argomenti.index("--in-arrivo") + 1]))
        except (IndexError, ValueError):
            return 1
    if "--chiama" in argomenti:
        chiama = argomenti[argomenti.index("--chiama") + 1] if len(argomenti) > argomenti.index("--chiama") + 1 else ""
    prepara_ambiente()
    if os.environ.get("QT_QUICK_BACKEND") == "software":
        os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu")
    try:
        from PyQt6.QtCore import Qt
        from PyQt6.QtGui import QGuiApplication
        from PyQt6.QtWebEngineQuick import QtWebEngineQuick

        QGuiApplication.setAttribute(Qt.ApplicationAttribute.AA_ShareOpenGLContexts)
        QtWebEngineQuick.initialize()
    except ImportError:
        pass
    app = crea_app("videochiamate")
    backend = BackendVideochiamate(in_arrivo, chiama)
    motore = carica(app, "Videochiamate/Main.qml", {"ponte": crea_ponte(backend)})
    try:
        return app.exec()
    finally:
        backend.squillo(False)
        backend.inChiamata(False)
        del motore


if __name__ == "__main__":
    sys.exit(main())
