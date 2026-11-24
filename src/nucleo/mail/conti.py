"""Account di posta: elenco (senza password) in ~/.config/<os>/mail/account.json; le password in
segreti.bin, cifrate con AES-256-GCM con una chiave casuale leggibile solo dall'utente (come fa
un portachiavi aperto all'accesso: la posta deve arrivare anche senza chiedere ogni volta la
password).

Configurazione automatica: prima la tabella dei fornitori più usati in Italia e nel mondo, poi
il servizio di configurazione aperto di Thunderbird (gli si manda solo il dominio), poi i nomi
tipici (imap.<dominio>, smtp.<dominio>).
"""

from __future__ import annotations

import json
import os
import secrets
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.request import Request, urlopen

from ..i18n import T
from ..sistema import config_utente, leggi_json, scrivi_json

_AAD = b"solidos-mail-segreti-1"

# dominio → (imap, porta, smtp, porta, sicurezza smtp, nota)
FORNITORI = {
    "gmail.com": ("imap.gmail.com", 993, "smtp.gmail.com", 465, "ssl", "gmail"),
    "googlemail.com": ("imap.gmail.com", 993, "smtp.gmail.com", 465, "ssl", "gmail"),
    "icloud.com": ("imap.mail.me.com", 993, "smtp.mail.me.com", 587, "starttls", "app"),
    "me.com": ("imap.mail.me.com", 993, "smtp.mail.me.com", 587, "starttls", "app"),
    "mac.com": ("imap.mail.me.com", 993, "smtp.mail.me.com", 587, "starttls", "app"),
    "yahoo.com": ("imap.mail.yahoo.com", 993, "smtp.mail.yahoo.com", 465, "ssl", "app"),
    "yahoo.it": ("imap.mail.yahoo.com", 993, "smtp.mail.yahoo.com", 465, "ssl", "app"),
    "libero.it": ("imapmail.libero.it", 993, "smtpmail.libero.it", 465, "ssl", ""),
    "inwind.it": ("imapmail.libero.it", 993, "smtpmail.libero.it", 465, "ssl", ""),
    "iol.it": ("imapmail.libero.it", 993, "smtpmail.libero.it", 465, "ssl", ""),
    "blu.it": ("imapmail.libero.it", 993, "smtpmail.libero.it", 465, "ssl", ""),
    "virgilio.it": ("in.virgilio.it", 993, "out.virgilio.it", 465, "ssl", ""),
    "alice.it": ("in.alice.it", 993, "out.alice.it", 465, "ssl", ""),
    "tim.it": ("imap.tim.it", 993, "smtp.tim.it", 465, "ssl", ""),
    "tiscali.it": ("imap.tiscali.it", 993, "smtp.tiscali.it", 465, "ssl", ""),
    "fastwebnet.it": ("imap.fastwebnet.it", 993, "smtp.fastwebnet.it", 587, "starttls", ""),
    "aruba.it": ("imaps.aruba.it", 993, "smtps.aruba.it", 465, "ssl", ""),
    "pec.it": ("imaps.pec.aruba.it", 993, "smtps.pec.aruba.it", 465, "ssl", ""),
    "legalmail.it": ("mbox.cert.legalmail.it", 993, "sendm.cert.legalmail.it", 465, "ssl", ""),
    "gmx.com": ("imap.gmx.com", 993, "mail.gmx.com", 465, "ssl", ""),
    "gmx.it": ("imap.gmx.com", 993, "mail.gmx.com", 465, "ssl", ""),
    "zoho.com": ("imap.zoho.eu", 993, "smtp.zoho.eu", 465, "ssl", ""),
    "outlook.com": ("outlook.office365.com", 993, "smtp-mail.outlook.com", 587, "starttls", "microsoft"),
    "hotmail.com": ("outlook.office365.com", 993, "smtp-mail.outlook.com", 587, "starttls", "microsoft"),
    "hotmail.it": ("outlook.office365.com", 993, "smtp-mail.outlook.com", 587, "starttls", "microsoft"),
    "live.com": ("outlook.office365.com", 993, "smtp-mail.outlook.com", 587, "starttls", "microsoft"),
    "live.it": ("outlook.office365.com", 993, "smtp-mail.outlook.com", 587, "starttls", "microsoft"),
    "msn.com": ("outlook.office365.com", 993, "smtp-mail.outlook.com", 587, "starttls", "microsoft"),
}

NOTE = {
    "gmail": "Con l'accesso in due passaggi attivo serve una «password per le app»: la crei nel tuo account Google, in Sicurezza.",
    "app": "Serve una «password per le app», che crei nelle impostazioni di sicurezza del tuo account.",
    "microsoft": "Microsoft per Outlook e Hotmail accetta solo il proprio accesso: se la password viene rifiutata, crea una «password per le app» nel tuo account Microsoft.",
}


def _cartella() -> Path:
    c = config_utente("mail", "x").parent
    c.mkdir(parents=True, exist_ok=True)
    os.chmod(c, 0o700)
    return c


# ── segreti ──────────────────────────────────────────────────────────────────
def _aes():
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    return AESGCM


def _scrivi_privato(percorso: Path, dati: bytes) -> None:
    tmp = percorso.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(dati)
    tmp.replace(percorso)


def _chiave() -> bytes:
    f = _cartella() / "chiave"
    if not f.exists():
        _scrivi_privato(f, secrets.token_bytes(32))
    return f.read_bytes()


def _segreti() -> dict:
    f = _cartella() / "segreti.bin"
    if not f.exists():
        return {}
    blob = f.read_bytes()
    try:
        return json.loads(_aes()(_chiave()).decrypt(blob[:12], blob[12:], _AAD))
    except Exception:  # noqa: BLE001
        return {}


def _salva_segreti(d: dict) -> None:
    nonce = secrets.token_bytes(12)
    _scrivi_privato(_cartella() / "segreti.bin", nonce + _aes()(_chiave()).encrypt(nonce, json.dumps(d).encode(), _AAD))


def password(ident: str) -> str:
    return _segreti().get(ident, "")


# ── account ──────────────────────────────────────────────────────────────────
COLORI = ["#3B82F6", "#EF4444", "#22C55E", "#F59E0B", "#8B5CF6", "#EC4899", "#14B8A6"]


def elenco() -> list[dict]:
    return leggi_json(_cartella() / "account.json", [])


def conto(ident: str) -> dict | None:
    return next((a for a in elenco() if a["id"] == ident), None)


def salva(a: dict, pw: str | None = None) -> dict:
    tutti = elenco()
    vecchio = next((x for x in tutti if x["id"] == a.get("id")), {})
    voce = {**vecchio, **{k: v for k, v in a.items() if k != "password"}}
    voce.setdefault("id", uuid.uuid4().hex[:8])
    voce.setdefault("colore", COLORI[len(tutti) % len(COLORI)])
    voce.setdefault("firma", "")
    tutti = [x for x in tutti if x["id"] != voce["id"]] + [voce]
    scrivi_json(_cartella() / "account.json", tutti)
    if pw is not None:
        s = _segreti()
        s[voce["id"]] = pw
        _salva_segreti(s)
    return voce


def togli(ident: str) -> None:
    scrivi_json(_cartella() / "account.json", [x for x in elenco() if x["id"] != ident])
    s = _segreti()
    s.pop(ident, None)
    _salva_segreti(s)


# ── configurazione automatica ────────────────────────────────────────────────
def configurazione(email: str) -> dict:
    email = email.strip().lower()
    dominio = email.rpartition("@")[2]
    if dominio in FORNITORI:
        i, ip, s, sp, sic, nota = FORNITORI[dominio]
        return {"imap": i, "portaImap": ip, "smtp": s, "portaSmtp": sp, "sicurezzaSmtp": sic, "utente": email,
                "nota": T(NOTE[nota]) if nota else "", "trovata": True}
    for url in (f"https://autoconfig.thunderbird.net/v1.1/{dominio}", f"https://autoconfig.{dominio}/mail/config-v1.1.xml"):
        try:
            with urlopen(Request(url, headers={"User-Agent": "SolidOS-Mail"}), timeout=8) as r:
                c = _leggi_autoconfig(r.read(), email)
            if c:
                return c
        except Exception:  # noqa: BLE001
            continue
    return {"imap": f"imap.{dominio}", "portaImap": 993, "smtp": f"smtp.{dominio}", "portaSmtp": 465, "sicurezzaSmtp": "ssl",
            "utente": email, "nota": "", "trovata": False}


def _leggi_autoconfig(xml: bytes, email: str) -> dict | None:
    radice = ET.fromstring(xml)
    locale, _, dominio = email.partition("@")

    def sost(t: str) -> str:
        return (t or "").replace("%EMAILADDRESS%", email).replace("%EMAILLOCALPART%", locale).replace("%EMAILDOMAIN%", dominio)

    imap = next((s for s in radice.iter("incomingServer") if s.get("type") == "imap"), None)
    smtp = next((s for s in radice.iter("outgoingServer") if s.get("type") == "smtp"), None)
    if imap is None or smtp is None:
        return None
    if (imap.findtext("socketType") or "").upper() != "SSL":
        return None              # solo connessioni cifrate
    sic = (smtp.findtext("socketType") or "").upper()
    if sic not in ("SSL", "STARTTLS"):
        return None
    return {"imap": sost(imap.findtext("hostname")), "portaImap": int(imap.findtext("port") or 993),
            "smtp": sost(smtp.findtext("hostname")), "portaSmtp": int(smtp.findtext("port") or 465),
            "sicurezzaSmtp": "ssl" if sic == "SSL" else "starttls", "utente": sost(imap.findtext("username")) or email,
            "nota": "", "trovata": True}
