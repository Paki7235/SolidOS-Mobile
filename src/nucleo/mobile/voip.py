"""Chiamate via Internet (VoIP, SIP) con il telefono SIP di SolidOS (sip.py).

Serve un account SIP: lo danno gli operatori VoIP (numero di telefono vero, si chiamano i
fissi e i cellulari) e molti centralini di casa o d'ufficio. Si scrivono utente, password e
dominio in Impostazioni › Chiamate via Internet; il telefono si registra e le chiamate
passano da Internet (Wi-Fi o dati), anche senza SIM.

Il telefono SIP (sip.py) è scritto in SolidOS: nessun programma esterno da installare.
L'audio passa da PipeWire o ALSA (callaudiod sceglie altoparlante o auricolare).
"""

from __future__ import annotations

from pathlib import Path

from ..i18n import T
from ..sistema import config_utente, leggi_json, scrivi_json


def _file() -> Path:
    return config_utente("voip.json")


def account() -> dict:
    """L'account SIP salvato (la password non esce mai da qui verso l'interfaccia)."""
    a = leggi_json(_file(), {})
    return {"utente": a.get("utente", ""), "dominio": a.get("dominio", ""), "server": a.get("server", ""),
            "nome": a.get("nome", ""), "attivo": bool(a.get("attivo")), "haPassword": bool(a.get("password"))}


class Linea:
    """La linea VoIP del telefono: il telefono SIP di SolidOS (nucleo/mobile/sip.py)."""

    def __init__(self):
        self.tel = None

    @property
    def registrato(self) -> bool:
        return bool(self.tel and self.tel.registrato)

    @property
    def errore(self) -> str:
        return self.tel.errore if self.tel else ""

    @property
    def chiamata(self) -> dict:
        return self.tel.chiamata if self.tel else {}

    @chiamata.setter
    def chiamata(self, valore: dict) -> None:
        if self.tel:
            self.tel.chiamata = valore

    @property
    def attiva(self) -> bool:
        return bool(self.tel and self.tel.attivo)

    def avvia(self) -> None:
        from .sip import TelefonoSIP

        a = leggi_json(_file(), {})
        self.ferma()
        if not a.get("attivo") or not a.get("utente") or not a.get("dominio"):
            return
        self.tel = TelefonoSIP(a["utente"], a.get("password", ""), a["dominio"], a.get("server", ""), a.get("nome", ""))
        self.tel.avvia()

    def ferma(self) -> None:
        if self.tel:
            self.tel.ferma()
        self.tel = None

    def chiama(self, numero: str) -> dict:
        if not self.tel:
            return {"ok": False, "messaggio": T("Chiamate via Internet spente: attivale in Impostazioni")}
        r = self.tel.chiama(numero)
        if not r.get("ok"):
            r["messaggio"] = T(r.get("messaggio", ""))
        return r

    def rispondi(self) -> None:
        if self.tel:
            self.tel.rispondi()

    def riaggancia(self) -> None:
        if self.tel:
            self.tel.riaggancia()

    def tono(self, cifra: str) -> None:
        if self.tel:
            self.tel.tono(cifra)

    def muto(self, si: bool) -> None:
        if self.tel:
            self.tel.muto(si)

    def stato(self) -> dict:
        return {"disponibile": True, "attivo": self.attiva, "registrato": self.registrato, "errore": T(self.errore) if self.errore else ""}


_istanza: Linea | None = None


def linea() -> Linea:
    global _istanza
    if _istanza is None:
        _istanza = Linea()
    return _istanza


def salva(utente: str, password: str, dominio: str, server: str = "", nome: str = "", attivo: bool = True) -> dict:
    utente, dominio = utente.strip(), dominio.strip().removeprefix("sip:")
    if attivo and (not utente or not dominio):
        return {"ok": False, "messaggio": T("Scrivi utente e dominio dell'account SIP")}
    vecchio = leggi_json(_file(), {})
    dati = {"utente": utente, "dominio": dominio, "server": server.strip(), "nome": nome.strip(), "attivo": bool(attivo),
            "password": password if password else vecchio.get("password", "")}
    scrivi_json(_file(), dati)
    try:
        _file().chmod(0o600)
    except OSError:
        pass
    b = linea()
    if attivo:
        b.avvia()
        return {"ok": True, "messaggio": T("Account salvato: mi collego…")}
    b.ferma()
    return {"ok": True, "messaggio": T("Chiamate via Internet spente")}
