"""App Password: accessi ai siti con nome utente, password, codice di verifica e note; Wi-Fi
salvate con il codice QR da far inquadrare; controllo della sicurezza; generatore; importa ed
esporta in CSV. Tutto in nucleo/password.py (cassaforte cifrata)."""

from __future__ import annotations

import time
from urllib.parse import unquote, urlparse

from .. import password as pw
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia, cartella_utente
from ..i18n import T

BLOCCO_DOPO = 5 * 60          # secondi senza usare l'app
CANCELLA_APPUNTI_DOPO = 90


class BackendPassword(Backend):
    def __init__(self) -> None:
        self.c = pw.Cassaforte()

    def _aperta(self) -> bool:
        if self.c.aperta() and time.time() - self.c.ultimo_uso > BLOCCO_DOPO:
            self.c.chiudi()
        if self.c.aperta():
            self.c.tocca()
            return True
        return False

    # ── apertura ──
    def stato(self) -> dict:
        return {"aperta": self._aperta(), "servePassword": self.c.serve_password()}

    def apri(self, password: str = "", vecchia: str = "") -> dict:
        return self.c.apri(str(password), str(vecchia))

    def blocca(self) -> None:
        self.c.chiudi()

    # ── voci ──
    def elenco(self, filtro: str, testo: str) -> list:
        return self.c.elenco(str(filtro), str(testo)) if self._aperta() else []

    def conteggi(self) -> dict:
        if not self._aperta():
            return {}
        d = self.c.conteggi()
        d["wifi"] = len(pw.reti_wifi())
        return d

    def dettagli(self, ident: str) -> dict:
        return self.c.dettagli(str(ident)) if self._aperta() else {}

    def salva(self, v: dict) -> dict:
        if not self._aperta():
            return {"ok": False, "bloccata": True}
        return self.c.salva_voce(dict(v))

    def elimina(self, ident: str, per_sempre: bool = False) -> None:
        if self._aperta():
            self.c.elimina(str(ident), bool(per_sempre))

    def ripristina(self, ident: str) -> None:
        if self._aperta():
            self.c.ripristina(str(ident))

    def codice(self, ident: str) -> dict:
        if not self._aperta():
            return {}
        v = self.c.voce(str(ident))
        return pw.codice_otp(v["codice"]) if v and v.get("codice") else {}

    def provaCodice(self, testo: str) -> dict:
        return pw.codice_otp(str(testo))

    def genera(self, tipo: str = "robusta", lunghezza: int = 20) -> str:
        return pw.genera(str(tipo), int(lunghezza))

    def forza(self, p: str) -> dict:
        return pw.forza(str(p))

    def controllaTrapelate(self) -> dict:
        if not self._aperta():
            return {"ok": False}
        return self.c.controlla_trapelate()

    # ── appunti: si cancellano da soli ──
    def copia(self, testo: str) -> None:
        from PyQt6.QtCore import QTimer
        from PyQt6.QtGui import QGuiApplication

        appunti = QGuiApplication.clipboard()
        appunti.setText(str(testo))
        QTimer.singleShot(CANCELLA_APPUNTI_DOPO * 1000, lambda t=str(testo): appunti.text() == t and appunti.clear())

    def copiaVoce(self, ident: str, campo: str) -> bool:
        if not self._aperta():
            return False
        v = self.c.voce(str(ident))
        if not v:
            return False
        if campo == "codice":
            valore = pw.codice_otp(v.get("codice", "")).get("codice", "")
        else:
            valore = v.get(str(campo), "")
        if valore:
            self.copia(valore)
        return bool(valore)

    # ── Wi-Fi ──
    def reti(self) -> list:
        return pw.reti_wifi() if self._aperta() else []

    def rete(self, nome: str) -> dict:
        if not self._aperta():
            return {"ok": False}
        r = pw.password_wifi(str(nome))
        if r.get("ok"):
            try:
                r["immagineQr"] = pw.qr_svg(r["qr"])
            except Exception:  # noqa: BLE001 — senza la libreria del QR si vede solo la password
                r["immagineQr"] = ""
        return r

    # ── file ──
    def importa(self, indirizzo: str) -> dict:
        if not self._aperta():
            return {"ok": False}
        percorso = unquote(urlparse(str(indirizzo)).path) if "://" in str(indirizzo) else str(indirizzo)
        return self.c.importa_csv(percorso)

    def esporta(self) -> dict:
        if not self._aperta():
            return {"ok": False}
        cartella = cartella_utente("DOCUMENTS", "Documenti")
        cartella.mkdir(parents=True, exist_ok=True)
        return self.c.esporta_csv(str(cartella / (T("Password") + ".csv")))

    def apriSito(self, sito: str) -> None:
        sito = str(sito).strip()
        if sito:
            avvia(["xdg-open", sito if "://" in sito else "https://" + sito])


def main() -> int:
    return esegui_app("password", "Password/Main.qml", lambda app: {"ponte": crea_ponte(BackendPassword())})


if __name__ == "__main__":
    raise SystemExit(main())
