"""Recensioni delle app dello Store, salvate nel Solid ID (Supabase).

Le leggono tutti, anche senza accesso; le scrive solo chi ha fatto l'accesso al Solid ID,
una per app (scriverne un'altra la sostituisce). Il nome mostrato lo mette il database dal
profilo. Tabelle e regole: supabase/schema.sql (sezione «Recensioni»).
Stesso file su PC (SolidOS App) e telefono (Store).
"""

from __future__ import annotations

import re
import urllib.parse

from .i18n import T

_ID = re.compile(r"^[A-Za-z0-9._-]{3,200}$")


def _sid():
    from . import solidid

    return solidid


def _q(v: str) -> str:
    return urllib.parse.quote(v, safe="")


def riepilogo(app: str) -> dict:
    """{media, totale, distribuzione: [n5, n4, n3, n2, n1]} — tutto a zero se non ci sono voti."""
    vuoto = {"media": 0, "totale": 0, "distribuzione": [0, 0, 0, 0, 0]}
    if not _ID.match(app or ""):
        return vuoto
    try:
        r = _sid().rest("GET", "voti_app", filtri=f"app=eq.{_q(app)}&select=*", rappresenta=False) or []
    except Exception:  # noqa: BLE001 — senza rete o senza Solid ID: niente voti
        return vuoto
    if not r:
        return vuoto
    v = r[0]
    return {"media": v.get("media") or 0, "totale": v.get("totale") or 0,
            "distribuzione": [v.get(k) or 0 for k in ("v5", "v4", "v3", "v2", "v1")]}


def elenco(app: str, quante: int = 30) -> list:
    """Le recensioni più recenti di un'app: {id, nome, voto, titolo, testo, quando, utili, mia}."""
    if not _ID.match(app or ""):
        return []
    try:
        r = _sid().rest("GET", "recensioni_complete",
                        filtri=f"app=eq.{_q(app)}&select=*&order=modificata.desc&limit={int(quante)}", rappresenta=False) or []
    except Exception:  # noqa: BLE001
        return []
    mesi = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]
    for x in r:
        data = str(x.get("modificata") or "")[:10]
        try:
            a, m, g = data.split("-")
            x["quando"] = f"{int(g)} {mesi[int(m) - 1]} {a}"
        except ValueError:
            x["quando"] = ""
    return r


def piu_amate(quante: int = 12, minimo: int = 2) -> list:
    """App con il voto medio più alto (almeno «minimo» recensioni): [{app, media, totale}]."""
    try:
        r = _sid().rest("GET", "voti_app",
                        filtri=f"totale=gte.{int(minimo)}&select=app,media,totale&order=media.desc,totale.desc&limit={int(quante)}",
                        rappresenta=False) or []
    except Exception:  # noqa: BLE001
        return []
    return r


def scrivi(app: str, voto: int, titolo: str, testo: str) -> dict:
    if not _ID.match(app or ""):
        return {"ok": False, "messaggio": T("App non valida")}
    sid = _sid()
    if not sid.collegato():
        return {"ok": False, "messaggio": T("Per scrivere una recensione accedi al Solid ID")}
    try:
        voto = int(voto)
    except (TypeError, ValueError):
        voto = 0
    if not 1 <= voto <= 5:
        return {"ok": False, "messaggio": T("Tocca le stelle per dare un voto")}
    corpo = {"app": app, "voto": voto, "titolo": (titolo or "").strip()[:80], "testo": (testo or "").strip()[:2000]}
    try:
        sid.rest("POST", "recensioni", corpo, filtri="on_conflict=app,autore",
                 extra={"Prefer": "return=minimal,resolution=merge-duplicates"})
    except sid.ErroreSolidID as e:
        return {"ok": False, "messaggio": str(e)}
    return {"ok": True, "messaggio": T("Recensione pubblicata. Grazie!")}


def cancella(app: str) -> dict:
    sid = _sid()
    if not sid.collegato() or not _ID.match(app or ""):
        return {"ok": False, "messaggio": T("Per togliere la recensione accedi al Solid ID")}
    try:
        # le regole del database lasciano cancellare solo la propria
        sid.rest("DELETE", "recensioni", filtri=f"app=eq.{_q(app)}", rappresenta=False)
    except sid.ErroreSolidID as e:
        return {"ok": False, "messaggio": str(e)}
    return {"ok": True, "messaggio": T("Recensione tolta")}


def utile(recensione: str) -> dict:
    sid = _sid()
    if not sid.collegato():
        return {"ok": False, "messaggio": T("Accedi al Solid ID per segnare le recensioni utili")}
    if not re.fullmatch(r"[0-9a-f-]{36}", recensione or ""):
        return {"ok": False, "messaggio": T("Recensione non valida")}
    try:
        sid.rest("POST", "recensioni_utili", {"recensione": recensione}, rappresenta=False,
                 extra={"Prefer": "return=minimal,resolution=ignore-duplicates"})
    except sid.ErroreSolidID as e:
        return {"ok": False, "messaggio": str(e)}
    return {"ok": True, "messaggio": T("Grazie per la segnalazione")}


def collegato() -> dict:
    """Chi scrive: {collegato, nome}."""
    try:
        sid = _sid()
        if not sid.collegato():
            return {"collegato": False, "nome": ""}
        u = sid.utente() or {}
        return {"collegato": True, "nome": u.get("nome") or u.get("email") or ""}
    except Exception:  # noqa: BLE001
        return {"collegato": False, "nome": ""}
