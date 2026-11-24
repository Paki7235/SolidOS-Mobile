"""Orologio di SolidOS (PC e telefono): sveglie, timer e ora nel mondo.

Tutto in ~/.config/<os>/orologio.json. A far suonare sveglie e timer, anche ad app chiusa,
ci pensa il servizio degli avvisi della sessione (nucleo/avvisi.py).
"""

from __future__ import annotations

import time
import uuid
from datetime import datetime
from zoneinfo import ZoneInfo

from .i18n import T
from .sistema import config_utente, leggi_json, scrivi_json

GIORNI_BREVI = ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]

# Città per «Ora nel mondo» (nome in italiano → fuso orario)
CITTA = {
    "Roma": "Europe/Rome", "Milano": "Europe/Rome", "Napoli": "Europe/Rome", "Londra": "Europe/London", "Parigi": "Europe/Paris",
    "Berlino": "Europe/Berlin", "Madrid": "Europe/Madrid", "Lisbona": "Europe/Lisbon", "Amsterdam": "Europe/Amsterdam",
    "Bruxelles": "Europe/Brussels", "Zurigo": "Europe/Zurich", "Vienna": "Europe/Vienna", "Praga": "Europe/Prague",
    "Varsavia": "Europe/Warsaw", "Atene": "Europe/Athens", "Istanbul": "Europe/Istanbul", "Mosca": "Europe/Moscow",
    "Kiev": "Europe/Kyiv", "Bucarest": "Europe/Bucharest", "Stoccolma": "Europe/Stockholm", "Oslo": "Europe/Oslo",
    "Copenaghen": "Europe/Copenhagen", "Helsinki": "Europe/Helsinki", "Dublino": "Europe/Dublin", "Reykjavík": "Atlantic/Reykjavik",
    "New York": "America/New_York", "Washington": "America/New_York", "Boston": "America/New_York", "Miami": "America/New_York",
    "Chicago": "America/Chicago", "Denver": "America/Denver", "Los Angeles": "America/Los_Angeles", "San Francisco": "America/Los_Angeles",
    "Seattle": "America/Los_Angeles", "Toronto": "America/Toronto", "Vancouver": "America/Vancouver", "Città del Messico": "America/Mexico_City",
    "San Paolo": "America/Sao_Paulo", "Rio de Janeiro": "America/Sao_Paulo", "Buenos Aires": "America/Argentina/Buenos_Aires",
    "Santiago del Cile": "America/Santiago", "Lima": "America/Lima", "Bogotà": "America/Bogota", "L'Avana": "America/Havana",
    "Honolulu": "Pacific/Honolulu", "Anchorage": "America/Anchorage", "Il Cairo": "Africa/Cairo", "Casablanca": "Africa/Casablanca",
    "Lagos": "Africa/Lagos", "Nairobi": "Africa/Nairobi", "Johannesburg": "Africa/Johannesburg", "Tunisi": "Africa/Tunis",
    "Dubai": "Asia/Dubai", "Doha": "Asia/Qatar", "Riad": "Asia/Riyadh", "Tel Aviv": "Asia/Jerusalem", "Teheran": "Asia/Tehran",
    "Karachi": "Asia/Karachi", "Nuova Delhi": "Asia/Kolkata", "Mumbai": "Asia/Kolkata", "Dacca": "Asia/Dhaka", "Bangkok": "Asia/Bangkok",
    "Giacarta": "Asia/Jakarta", "Singapore": "Asia/Singapore", "Kuala Lumpur": "Asia/Kuala_Lumpur", "Manila": "Asia/Manila",
    "Hong Kong": "Asia/Hong_Kong", "Pechino": "Asia/Shanghai", "Shanghai": "Asia/Shanghai", "Taipei": "Asia/Taipei",
    "Seul": "Asia/Seoul", "Tokyo": "Asia/Tokyo", "Sydney": "Australia/Sydney", "Melbourne": "Australia/Melbourne",
    "Perth": "Australia/Perth", "Auckland": "Pacific/Auckland",
}


def _file():
    return config_utente("orologio.json")


def _leggi() -> dict:
    d = leggi_json(_file(), {})
    d.setdefault("sveglie", [])
    d.setdefault("mondo", ["New York", "Londra", "Tokyo"])
    d.setdefault("timer", {})
    return d


def _scrivi(d: dict) -> None:
    scrivi_json(_file(), d)


def testo_giorni(giorni: list[int]) -> str:
    giorni = sorted(set(int(g) for g in giorni))
    if not giorni:
        return T("Una volta")
    if giorni == list(range(7)):
        return T("Ogni giorno")
    if giorni == list(range(5)):
        return T("Giorni feriali")
    if giorni == [5, 6]:
        return T("Fine settimana")
    return ", ".join(T(GIORNI_BREVI[g]) for g in giorni)


# ── Sveglie ──────────────────────────────────────────────────────────────────
def sveglie() -> list[dict]:
    elenco = sorted(_leggi()["sveglie"], key=lambda s: s["ora"])
    for s in elenco:
        s["ripeti"] = testo_giorni(s.get("giorni", []))
    return elenco


def salva_sveglia(s: dict) -> list[dict]:
    d = _leggi()
    s = dict(s)
    ora = str(s.get("ora", "07:00"))
    try:
        h, m = (int(x) for x in ora.split(":"))
        assert 0 <= h < 24 and 0 <= m < 60
    except (ValueError, AssertionError):
        return sveglie()
    voce = {"id": s.get("id") or uuid.uuid4().hex[:8], "ora": f"{h:02d}:{m:02d}", "etichetta": str(s.get("etichetta", ""))[:60],
            "giorni": sorted(set(int(g) for g in s.get("giorni", []) if 0 <= int(g) < 7)), "attiva": bool(s.get("attiva", True)),
            "posticipa": bool(s.get("posticipa", True))}
    d["sveglie"] = [x for x in d["sveglie"] if x["id"] != voce["id"]] + [voce]
    _scrivi(d)
    return sveglie()


def attiva_sveglia(ident: str, si: bool) -> list[dict]:
    d = _leggi()
    for s in d["sveglie"]:
        if s["id"] == ident:
            s["attiva"] = bool(si)
    _scrivi(d)
    return sveglie()


def togli_sveglia(ident: str) -> list[dict]:
    d = _leggi()
    d["sveglie"] = [s for s in d["sveglie"] if s["id"] != ident]
    _scrivi(d)
    return sveglie()


def prossima_sveglia() -> str:
    """«Sveglia tra 7 h 20 min» (per l'intestazione), vuoto se nessuna è attiva."""
    adesso = datetime.now()
    minimo = None
    for s in _leggi()["sveglie"]:
        if not s.get("attiva"):
            continue
        h, m = (int(x) for x in s["ora"].split(":"))
        for avanti in range(0, 8):
            giorno = (adesso.weekday() + avanti) % 7
            if s.get("giorni") and giorno not in s["giorni"]:
                continue
            quando = adesso.replace(hour=h, minute=m, second=0, microsecond=0).timestamp() + avanti * 86400
            if quando > adesso.timestamp():
                minimo = quando if minimo is None else min(minimo, quando)
                break
    if minimo is None:
        return ""
    minuti = int((minimo - adesso.timestamp()) // 60)
    return T("Prossima sveglia tra {h} h {m} min", h=minuti // 60, m=minuti % 60)


# ── Timer (il conto alla rovescia vive nel file: suona anche ad app chiusa) ──
def timer() -> dict:
    t = _leggi()["timer"]
    if not t:
        return {"attivo": False}
    if t.get("pausa") is not None:
        resto = t["pausa"]
    else:
        resto = max(0.0, t["fine"] - time.time())
    return {"attivo": True, "inPausa": t.get("pausa") is not None, "resto": resto, "durata": t["durata"], "etichetta": t.get("etichetta", "")}


def avvia_timer(secondi: float, etichetta: str = "") -> dict:
    d = _leggi()
    secondi = max(1, min(24 * 3600, float(secondi)))
    d["timer"] = {"fine": time.time() + secondi, "durata": secondi, "etichetta": str(etichetta)[:60], "pausa": None}
    _scrivi(d)
    return timer()


def pausa_timer(si: bool) -> dict:
    d = _leggi()
    t = d["timer"]
    if t:
        if si and t.get("pausa") is None:
            t["pausa"] = max(0.0, t["fine"] - time.time())
        elif not si and t.get("pausa") is not None:
            t["fine"] = time.time() + t["pausa"]
            t["pausa"] = None
        _scrivi(d)
    return timer()


def ferma_timer() -> dict:
    d = _leggi()
    d["timer"] = {}
    _scrivi(d)
    return timer()


# ── Ora nel mondo ────────────────────────────────────────────────────────────
def citta_disponibili(testo: str = "") -> list[str]:
    testo = testo.strip().lower()
    return [c for c in sorted(CITTA) if not testo or testo in c.lower()][:30]


def mondo() -> list[dict]:
    qui = datetime.now().astimezone()
    risultato = []
    for c in _leggi()["mondo"]:
        if c not in CITTA:
            continue
        ora = datetime.now(ZoneInfo(CITTA[c]))
        differenza = (ora.utcoffset() - qui.utcoffset()).total_seconds() / 3600
        giorno = ""
        if ora.date() > qui.date():
            giorno = T("Domani")
        elif ora.date() < qui.date():
            giorno = T("Ieri")
        else:
            giorno = T("Oggi")
        if differenza == 0:
            diff = T("stessa ora")
        else:
            h = int(abs(differenza)) if differenza == int(differenza) else abs(differenza)
            diff = (f"+{h}" if differenza > 0 else f"−{h}") + " h"
        risultato.append({"citta": c, "ora": ora.strftime("%H:%M"), "giorno": giorno, "differenza": diff,
                          "notte": ora.hour >= 20 or ora.hour < 7})
    return risultato


def aggiungi_citta(c: str) -> list[dict]:
    d = _leggi()
    if c in CITTA and c not in d["mondo"]:
        d["mondo"].append(c)
        _scrivi(d)
    return mondo()


def togli_citta(c: str) -> list[dict]:
    d = _leggi()
    d["mondo"] = [x for x in d["mondo"] if x != c]
    _scrivi(d)
    return mondo()
