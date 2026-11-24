"""Videochiamate di SolidOS tra persone con un Solid ID (PC e telefoni).

- Audio e video vanno diretti tra i dispositivi con WebRTC (cifrati da un capo all'altro,
  DTLS-SRTP), nel motore web del sistema (pagina chiamata.html).
- Per trovarsi si usa Solid ID: la tabella chiamate_segnali su Supabase (offerta, risposta,
  indirizzi di rete, fine), che ognuno vede solo per sé, ricevuta in tempo reale.
- Una chiamata suona su tutti i dispositivi di chi la riceve; risponde il primo. Si possono
  chiamare anche i propri altri dispositivi (stesso Solid ID).
- Il servizio degli avvisi ascolta le chiamate anche ad app chiusa e apre la schermata
  della chiamata in arrivo.
"""

from __future__ import annotations

import asyncio
import json
import time
import uuid

from .. import branding
from ..i18n import T
from ..sistema import config_utente, leggi_json, scrivi_json

SQUILLO_MAX = 45          # secondi prima di «nessuna risposta»


def _solidid():
    from .. import solidid

    return solidid


def ice() -> list[dict]:
    """Server per attraversare i router (STUN); un TURN si può mettere nel branding."""
    server = [{"urls": ["stun:stun.cloudflare.com:3478", "stun:stun.l.google.com:19302"]}]
    turn = branding.get("TURN_URL", "")
    if turn:
        server.append({"urls": [u.strip() for u in turn.split(",") if u.strip()],
                       "username": branding.get("TURN_UTENTE", ""), "credential": branding.get("TURN_PASSWORD", "")})
    return server


def dispositivo() -> str:
    s = _solidid()
    return s.sessione().get("dispositivo_id") or s.codice_dispositivo()[:40]


def configurazione() -> dict:
    """Quello che serve alla pagina della chiamata (o perché non si può chiamare)."""
    s = _solidid()
    if not s.disponibile():
        return {"ok": False, "motivo": T("Le videochiamate usano Solid ID, che non è configurato in questo sistema")}
    if not s.collegato():
        return {"ok": False, "motivo": T("Per fare e ricevere videochiamate accedi con il tuo Solid ID in Impostazioni")}
    try:
        token = s.token()
    except s.ErroreSolidID as e:
        return {"ok": False, "motivo": str(e)}
    u = s.sessione().get("utente", {})
    return {"ok": True, "url": s.url_base(), "chiave": s.chiave(), "token": token, "io": u.get("id", ""),
            "nome": u.get("nome") or u.get("email", "").split("@")[0], "email": u.get("email", ""),
            "dispositivo": dispositivo(), "ice": ice(), "squillo": SQUILLO_MAX}


def persona(email: str) -> dict:
    """Chi ha questo Solid ID? {"ok", "id", "nome"}."""
    email = email.strip()
    if "@" not in email:
        return {"ok": False, "messaggio": T("Scrivi l'email del Solid ID da chiamare")}
    try:
        r = _solidid()._richiesta("POST", "/rest/v1/rpc/persona_da_email", {"e": email}, _solidid().token())
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "messaggio": str(e)}
    if not r:
        return {"ok": False, "messaggio": T("Nessun Solid ID con questa email: solo chi usa SolidOS si può chiamare")}
    return {"ok": True, "id": r[0]["id"], "nome": r[0]["nome"], "email": email.lower()}


# ── recenti e preferiti ─────────────────────────────────────────────────────
def _file():
    return config_utente("videochiamate.json")


def _dati() -> dict:
    d = leggi_json(_file(), {})
    d.setdefault("recenti", [])
    d.setdefault("preferiti", [])
    return d


def recenti() -> list[dict]:
    out = []
    for r in _dati()["recenti"][:100]:
        r = dict(r)
        r["quando"] = _quando(r.get("ora", 0))
        r["durataTesto"] = _durata(r.get("durata", 0))
        out.append(r)
    return out


def aggiungi_recente(voce: dict) -> None:
    d = _dati()
    voce = {"chiamata": voce.get("chiamata") or uuid.uuid4().hex, "id": voce.get("id", ""), "nome": voce.get("nome", ""),
            "email": voce.get("email", ""), "verso": voce.get("verso", "uscita"),          # uscita | entrata | persa
            "video": bool(voce.get("video", True)), "durata": int(voce.get("durata", 0)), "ora": voce.get("ora") or time.time()}
    d["recenti"] = [voce] + [r for r in d["recenti"] if r.get("chiamata") != voce["chiamata"]]
    d["recenti"] = d["recenti"][:200]
    scrivi_json(_file(), d)


def cancella_recenti() -> None:
    d = _dati()
    d["recenti"] = []
    scrivi_json(_file(), d)


def preferiti() -> list[dict]:
    return _dati()["preferiti"]


def preferito(p: dict, si: bool) -> list[dict]:
    d = _dati()
    d["preferiti"] = [x for x in d["preferiti"] if x.get("id") != p.get("id")]
    if si:
        d["preferiti"].append({"id": p["id"], "nome": p.get("nome", ""), "email": p.get("email", "")})
    scrivi_json(_file(), d)
    return d["preferiti"]


def contatti_con_email() -> list[dict]:
    try:
        try:
            from ..mobile import telefonia as rubrica       # telefono
        except ImportError:
            from .. import rubrica                          # PC
        out = []
        for c in rubrica.contatti():
            e = c.get("email")
            if isinstance(e, list):
                e = e[0] if e else ""
            if e:
                out.append({"nome": c.get("nome") or e, "email": e})
        return sorted(out, key=lambda x: x["nome"].lower())
    except Exception:  # noqa: BLE001
        return []


def _quando(t: float) -> str:
    from datetime import datetime

    d = datetime.fromtimestamp(t)
    oggi = datetime.now().date()
    if d.date() == oggi:
        return d.strftime("%H:%M")
    if (oggi - d.date()).days == 1:
        return T("Ieri")
    return d.strftime("%d/%m/%y")


def _durata(s: int) -> str:
    if s <= 0:
        return ""
    if s < 3600:
        return f"{s // 60}:{s % 60:02d}"
    return f"{s // 3600}:{s % 3600 // 60:02d}:{s % 60:02d}"


# ── ascolto delle chiamate in arrivo (per il servizio degli avvisi) ──────────
async def ascolta(in_arrivo) -> None:
    """Chiama in_arrivo(record) per ogni offerta nuova arrivata a questo account da un altro
    dispositivo. Si ricollega da solo; non fa niente senza Solid ID."""
    import aiohttp

    s = _solidid()
    while True:
        if not (s.disponibile() and s.collegato()):
            await asyncio.sleep(60)
            continue
        try:
            conf = await asyncio.to_thread(configurazione)
            if not conf.get("ok"):
                await asyncio.sleep(120)
                continue
            indirizzo = conf["url"].replace("https://", "wss://") + f"/realtime/v1/websocket?apikey={conf['chiave']}&vsn=1.0.0"
            argomento = f"realtime:chiamate-{conf['dispositivo']}"
            async with aiohttp.ClientSession() as http, http.ws_connect(indirizzo, heartbeat=None, timeout=20) as ws:
                rif = 1
                await ws.send_json({"topic": argomento, "event": "phx_join", "ref": str(rif), "join_ref": "1",
                                    "payload": {"config": {"broadcast": {"self": False}, "presence": {"key": ""},
                                                           "postgres_changes": [{"event": "INSERT", "schema": "public",
                                                                                 "table": "chiamate_segnali", "filter": f"a=eq.{conf['io']}"}]},
                                                "access_token": conf["token"]}})
                battito = time.monotonic() + 25
                while True:
                    try:
                        msg = await ws.receive(timeout=5)
                    except asyncio.TimeoutError:
                        msg = None
                    if msg is not None:
                        if msg.type in (aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.ERROR, aiohttp.WSMsgType.CLOSE):
                            break
                        if msg.type == aiohttp.WSMsgType.TEXT:
                            dati = json.loads(msg.data)
                            if dati.get("event") == "postgres_changes":
                                r = ((dati.get("payload") or {}).get("data") or {}).get("record") or {}
                                if r.get("tipo") == "offerta" and r.get("dispositivo") != conf["dispositivo"]:
                                    in_arrivo(r)
                    if time.monotonic() >= battito:
                        rif += 1
                        await ws.send_json({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": str(rif)})
                        rif += 1
                        await ws.send_json({"topic": argomento, "event": "access_token", "ref": str(rif),
                                            "payload": {"access_token": await asyncio.to_thread(s.token)}})
                        battito = time.monotonic() + 25
        except Exception:  # noqa: BLE001 — rete assente o token scaduto: si riprova
            pass
        await asyncio.sleep(15)
