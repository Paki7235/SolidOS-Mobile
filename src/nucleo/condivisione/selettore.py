"""Finestra «Condividi»: scegli un dispositivo vicino oppure usa il codice QR.

Uso: <OS_ID>-condividi [FILE…]    (senza file: modalità «ricevi con QR»)
"""

import json
import sys
from pathlib import Path

from .. import branding
from ..dbusutil import chiama, inizializza
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


def _servizio(metodo, *argomenti, timeout=10):
    nome = branding.nome_dbus("Condivisione1")
    return chiama(nome, branding.percorso_dbus("Condivisione1"), nome, metodo, *argomenti, timeout=timeout)


class BackendSelettore(Backend):
    def file(self) -> list:
        return [str(Path(a.removeprefix("file://")).resolve()) for a in sys.argv[1:] if not a.startswith("-")]

    def attivo(self) -> bool:
        return _servizio("StatoBackend", timeout=3) is not None

    def scopri(self) -> None:
        _servizio("Scopri", 30)

    def dispositivi(self) -> list:
        testo = _servizio("Dispositivi", timeout=3)
        return json.loads(str(testo)) if testo else []

    def invia(self, dispositivo: str) -> str:
        return str(_servizio("Invia", self.file(), dispositivo) or "")

    def qr(self, hotspot: bool = False) -> dict:
        if self.file():
            testo = _servizio("InviaConQr", self.file(), timeout=40)
        else:
            testo = _servizio("RiceviConQr", bool(hotspot), timeout=40)
        return json.loads(str(testo)) if testo else {"errore": "servizio non attivo"}

    def fermaQr(self) -> None:
        _servizio("FermaQr")

    def visibilita(self) -> str:
        nome = branding.nome_dbus("Condivisione1")
        valore = chiama(nome, branding.percorso_dbus("Condivisione1"), "org.freedesktop.DBus.Properties", "Get",
                        nome, "Visibilita", timeout=3)
        return str(valore) if valore is not None else "nessuno"

    def impostaVisibilita(self, modalita: str) -> None:
        _servizio("ImpostaVisibilita", modalita, timeout=3)

    def diagnosi(self) -> list:
        """Stato di ogni sistema (Quick Share, LocalSend, QR) e del Bluetooth, con il motivo."""
        testo = _servizio("StatoBackend", timeout=5)
        stato = json.loads(str(testo)) if testo else {}
        nomi = {"quickshare": "Quick Share (Android)", "localsend": "LocalSend", "qr": "Codice QR"}
        voci = [{"nome": nomi.get(k, k), "ok": bool(v[0]), "motivo": str(v[1])} for k, v in stato.items()]
        try:
            from ..hw import bluetooth

            bt = bluetooth.attivo() if bluetooth.disponibile() else None
        except Exception:  # noqa: BLE001
            bt = None
        voci.append({"nome": "Bluetooth", "ok": bool(bt),
                     "motivo": "Acceso" if bt else ("Spento: accendilo dal centro di controllo" if bt is False else "Nessun adattatore Bluetooth trovato")})
        if not stato:
            voci.insert(0, {"nome": "Servizio", "ok": False, "motivo": "Il servizio Condivisione Vicina non risponde"})
        return voci


def main() -> int:
    inizializza()
    return esegui_app("condividi", "Condividi/Main.qml", lambda app: {"ponte": crea_ponte(BackendSelettore())})


if __name__ == "__main__":
    sys.exit(main())
