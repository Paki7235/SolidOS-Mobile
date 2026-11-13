"""Solid ID: l'account unico dei dispositivi SolidOS (come l'Apple ID), su Supabase.

Solo librerie standard (urllib): niente dipendenze in più. L'indirizzo del progetto
e la chiave PUBBLICA stanno nel branding (SOLIDID_URL, SOLIDID_CHIAVE); la sicurezza
vera la fanno le regole del database (supabase/schema.sql): ognuno vede solo i suoi dati.

La sessione (token) è in ~/.config/<os>/solidid.json, leggibile solo dall'utente.
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import socket
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from .. import branding
from ..i18n import T

TIMEOUT = 15


class ErroreSolidID(Exception):
    pass


# ── Configurazione e sessione ────────────────────────────────────────────────
def url_base() -> str:
    return branding.get("SOLIDID_URL", "").rstrip("/")


def chiave() -> str:
    return branding.get("SOLIDID_CHIAVE", "")


def disponibile() -> bool:
    return bool(url_base() and chiave())


def _file_sessione() -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / branding.id_os()
    base.mkdir(parents=True, exist_ok=True)
    return base / "solidid.json"


def sessione() -> dict:
    try:
        return json.loads(_file_sessione().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _salva(dati: dict) -> None:
    f = _file_sessione()
    tmp = f.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as h:
        json.dump(dati, h, ensure_ascii=False)
    tmp.replace(f)


def collegato() -> bool:
    return bool(sessione().get("refresh_token"))


# ── HTTP ─────────────────────────────────────────────────────────────────────
def _richiesta(metodo: str, percorso: str, corpo=None, token: str = "", intestazioni: dict | None = None):
    if not disponibile():
        raise ErroreSolidID(T("Solid ID non è configurato in questo sistema"))
    h = {"apikey": chiave(), "Content-Type": "application/json",
         "User-Agent": f"{branding.nome()}/{branding.get('OS_VERSION', '')} SolidID"}
    h["Authorization"] = f"Bearer {token or chiave()}"
    h.update(intestazioni or {})
    dati = json.dumps(corpo).encode() if corpo is not None else None
    req = urllib.request.Request(url_base() + percorso, data=dati, method=metodo, headers=h)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            testo = r.read().decode("utf-8", "replace")
            return json.loads(testo) if testo.strip() else None
    except urllib.error.HTTPError as e:
        try:
            errore = json.loads(e.read().decode("utf-8", "replace"))
        except ValueError:
            errore = {}
        raise ErroreSolidID(_messaggio_errore(e.code, errore)) from None
    except (urllib.error.URLError, TimeoutError, socket.timeout, OSError):
        raise ErroreSolidID(T("Nessuna connessione a internet")) from None


def _messaggio_errore(codice: int, errore: dict) -> str:
    testo = str(errore.get("msg") or errore.get("error_description") or errore.get("message") or errore.get("error") or "")
    basso = testo.lower()
    if "invalid login" in basso or "invalid_grant" in basso:
        return T("Email o password non corrette")
    if "email not confirmed" in basso:
        return T("Email non ancora confermata: apri il link che ti abbiamo mandato")
    if "already registered" in basso or "already been registered" in basso:
        return T("Esiste già un Solid ID con questa email: accedi")
    if "password should be" in basso or "weak" in basso:
        return T("Password troppo debole: almeno 8 caratteri, meglio con numeri e simboli")
    if "rate limit" in basso or codice == 429:
        return T("Troppi tentativi: riprova tra qualche minuto")
    if "invalid" in basso and "email" in basso:
        return T("Indirizzo email non valido")
    if codice in (401, 403):
        return T("Accesso scaduto: accedi di nuovo al Solid ID")
    return testo or T("Errore del servizio ({c})", c=codice)


def _da_risposta_auth(r: dict) -> dict:
    utente = r.get("user") or {}
    dati = {
        "access_token": r["access_token"], "refresh_token": r["refresh_token"],
        "scade": time.time() + int(r.get("expires_in", 3600)) - 60,
        "utente": {"id": utente.get("id", ""), "email": utente.get("email", ""),
                   "nome": (utente.get("user_metadata") or {}).get("nome", "")},
    }
    vecchia = sessione()
    for k in ("dispositivo_id", "trova"):
        if k in vecchia and vecchia.get("utente", {}).get("id") == dati["utente"]["id"]:
            dati[k] = vecchia[k]
    dati.setdefault("trova", True)
    return dati


def token() -> str:
    """Token valido (rinnovato se sta per scadere)."""
    s = sessione()
    if not s.get("refresh_token"):
        raise ErroreSolidID(T("Non hai fatto l'accesso al Solid ID"))
    if time.time() < s.get("scade", 0):
        return s["access_token"]
    r = _richiesta("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": s["refresh_token"]})
    nuova = _da_risposta_auth(r)
    _salva({**s, **nuova})
    return nuova["access_token"]


def rest(metodo: str, tabella: str, corpo=None, filtri: str = "", rappresenta: bool = True, extra: dict | None = None):
    intest = {"Prefer": "return=representation" if rappresenta else "return=minimal"}
    intest.update(extra or {})
    return _richiesta(metodo, f"/rest/v1/{tabella}{('?' + filtri) if filtri else ''}", corpo, token(), intest)


# ── Account ──────────────────────────────────────────────────────────────────
def crea(nome: str, email: str, password: str) -> dict:
    nome, email = nome.strip(), email.strip().lower()
    if not nome or "@" not in email:
        return {"ok": False, "messaggio": T("Scrivi nome ed email")}
    if len(password) < 8:
        return {"ok": False, "messaggio": T("La password deve avere almeno 8 caratteri")}
    try:
        r = _richiesta("POST", "/auth/v1/signup", {"email": email, "password": password, "data": {"nome": nome}})
    except ErroreSolidID as e:
        return {"ok": False, "messaggio": str(e)}
    if r and r.get("access_token"):
        _salva(_da_risposta_auth(r))
        _dopo_accesso()
        return {"ok": True, "collegato": True, "messaggio": T("Solid ID creato: benvenuto, {n}!", n=nome)}
    return {"ok": True, "collegato": False, "conferma": True,
            "messaggio": T("Ti abbiamo mandato un'email a {e}: apri il link per confermare, poi accedi.", e=email)}


def accedi(email: str, password: str) -> dict:
    try:
        r = _richiesta("POST", "/auth/v1/token?grant_type=password",
                       {"email": email.strip().lower(), "password": password})
    except ErroreSolidID as e:
        return {"ok": False, "messaggio": str(e)}
    _salva(_da_risposta_auth(r))
    _dopo_accesso()
    return {"ok": True, "collegato": True, "messaggio": T("Accesso fatto")}


def reinvia_conferma(email: str) -> dict:
    try:
        _richiesta("POST", "/auth/v1/resend", {"type": "signup", "email": email.strip().lower()})
        return {"ok": True, "messaggio": T("Email di conferma inviata di nuovo")}
    except ErroreSolidID as e:
        return {"ok": False, "messaggio": str(e)}


def password_dimenticata(email: str) -> dict:
    try:
        _richiesta("POST", "/auth/v1/recover", {"email": email.strip().lower()})
        return {"ok": True, "messaggio": T("Se l'email è registrata riceverai un link per scegliere una nuova password")}
    except ErroreSolidID as e:
        return {"ok": False, "messaggio": str(e)}


def esci() -> dict:
    s = sessione()
    try:
        if s.get("access_token"):
            _richiesta("POST", "/auth/v1/logout", {}, s["access_token"])
    except ErroreSolidID:
        pass
    _file_sessione().unlink(missing_ok=True)
    _servizio(False)
    return {"ok": True, "messaggio": T("Sei uscito dal Solid ID")}


def utente() -> dict:
    s = sessione()
    u = s.get("utente", {})
    return {"collegato": bool(s.get("refresh_token")), "email": u.get("email", ""), "nome": u.get("nome", ""),
            "trova": bool(s.get("trova", True)), "dispositivo": s.get("dispositivo_id", "")}


def imposta_trova(attivo: bool) -> dict:
    s = sessione()
    if not s:
        return {"ok": False, "messaggio": T("Non hai fatto l'accesso al Solid ID")}
    s["trova"] = bool(attivo)
    _salva(s)
    try:
        if s.get("dispositivo_id"):
            rest("PATCH", "dispositivi", {"trova_attivo": bool(attivo)}, f"id=eq.{s['dispositivo_id']}", rappresenta=False)
    except ErroreSolidID:
        pass
    _servizio(bool(attivo))
    return {"ok": True, "messaggio": T("«Dov'è» attivo su questo computer") if attivo else T("«Dov'è» disattivato su questo computer")}


def _dopo_accesso() -> None:
    try:
        registra_dispositivo()
    except ErroreSolidID:
        pass
    _servizio(bool(sessione().get("trova", True)))


def _servizio(attivo: bool) -> None:
    """Avvia/ferma il servizio che tiene aggiornata la posizione e riceve i comandi."""
    import subprocess

    unita = f"{branding.id_os()}-solidid.service"
    try:
        subprocess.run(["systemctl", "--user", "start" if attivo else "stop", unita],
                       timeout=10, check=False, capture_output=True)
    except (OSError, subprocess.SubprocessError):
        pass


# ── Questo dispositivo ───────────────────────────────────────────────────────
def sessione_live() -> bool:
    try:
        return "boot=live" in Path("/proc/cmdline").read_text()
    except OSError:
        return False


def codice_dispositivo() -> str:
    """Impronta stabile del dispositivo: derivata dalla machine-id, senza rivelarla."""
    try:
        mid = Path("/etc/machine-id").read_text().strip()
    except OSError:
        mid = socket.gethostname()
    return hashlib.sha256(f"{mid}:{branding.id_os()}:dove".encode()).hexdigest()[:40]


def _leggi(p: str) -> str:
    try:
        return Path(p).read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""


def batteria() -> tuple[int | None, bool | None]:
    for b in sorted(Path("/sys/class/power_supply").glob("BAT*")):
        cap = _leggi(str(b / "capacity"))
        stato = _leggi(str(b / "status"))
        if cap.isdigit():
            return int(cap), stato in ("Charging", "Full")
    return None, None


def info_dispositivo() -> dict:
    produttore = _leggi("/sys/class/dmi/id/sys_vendor")
    prodotto = _leggi("/sys/class/dmi/id/product_name")
    if produttore.lower() in ("to be filled by o.e.m.", "system manufacturer", "default string"):
        produttore = ""
    if prodotto.lower() in ("to be filled by o.e.m.", "system product name", "default string"):
        prodotto = ""
    modello = " ".join(x for x in (produttore, prodotto) if x)[:120] or platform.machine()
    try:
        sistema = next((r.split("=", 1)[1].strip('"') for r in Path("/etc/os-release").read_text().splitlines()
                        if r.startswith("PRETTY_NAME=")), branding.nome())
    except OSError:
        sistema = branding.nome()
    portatile = any(Path("/sys/class/power_supply").glob("BAT*"))
    try:
        import subprocess

        nome = subprocess.run(["hostnamectl", "--pretty"], capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, Exception):  # noqa: BLE001
        nome = ""
    if not nome:
        import pwd

        persona = (pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0] or "").split(" ")[0]
        tipo_nome = T("Portatile") if portatile else T("Computer")
        nome = T("{t} di {p}", t=tipo_nome, p=persona) if persona else socket.gethostname()
    cap, carica = batteria()
    return {"nome": nome[:80], "tipo": "portatile" if portatile else "computer", "modello": modello,
            "sistema": sistema[:80], "batteria": cap, "in_carica": carica}


def registra_dispositivo() -> str:
    """Aggiunge (o aggiorna) questo computer tra i dispositivi del Solid ID."""
    if sessione_live():
        return ""
    s = sessione()
    corpo = {"proprietario": s["utente"]["id"], "codice": codice_dispositivo(), **info_dispositivo(),
             "trova_attivo": bool(s.get("trova", True)), "ultimo_visto": _adesso()}
    r = rest("POST", "dispositivi", corpo, "on_conflict=proprietario,codice",
             extra={"Prefer": "resolution=merge-duplicates,return=representation"})
    ident = r[0]["id"] if isinstance(r, list) and r else ""
    if ident:
        s = sessione()
        s["dispositivo_id"] = ident
        _salva(s)
    return ident


def _adesso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def aggiorna_stato(posizione: dict | None = None, **altro) -> None:
    s = sessione()
    ident = s.get("dispositivo_id") or registra_dispositivo()
    if not ident:
        return
    cap, carica = batteria()
    corpo = {"ultimo_visto": _adesso(), "batteria": cap, "in_carica": carica, **altro}
    if posizione:
        corpo.update({"lat": posizione["lat"], "lon": posizione["lon"], "precisione": posizione.get("precisione"),
                      "fonte_posizione": posizione.get("fonte"), "posizione_quando": _adesso()})
    rest("PATCH", "dispositivi", corpo, f"id=eq.{ident}", rappresenta=False)


# ── Dispositivi e comandi (app «Dov'è») ──────────────────────────────────────
def dispositivi() -> list[dict]:
    return rest("GET", "dispositivi", filtri="select=*&order=ultimo_visto.desc") or []


def invia_comando(dispositivo: str, tipo: str, messaggio: str = "") -> dict:
    if tipo not in ("suona", "ferma", "blocca", "posizione"):
        return {"ok": False, "messaggio": T("Comando non valido")}
    corpo = {"dispositivo": dispositivo, "tipo": tipo, "proprietario": sessione()["utente"]["id"]}
    if messaggio:
        corpo["messaggio"] = messaggio[:200]
    r = rest("POST", "comandi", corpo)
    return {"ok": True, "id": r[0]["id"] if r else 0}


def stato_comando(ident: int) -> str:
    r = rest("GET", "comandi", filtri=f"select=stato&id=eq.{int(ident)}")
    return r[0]["stato"] if r else ""


def rimuovi_dispositivo(dispositivo: str) -> dict:
    rest("DELETE", "dispositivi", filtri=f"id=eq.{dispositivo}", rappresenta=False)
    s = sessione()
    if s.get("dispositivo_id") == dispositivo:
        s.pop("dispositivo_id", None)
        _salva(s)
    return {"ok": True, "messaggio": T("Dispositivo rimosso dal Solid ID")}
