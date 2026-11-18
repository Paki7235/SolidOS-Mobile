"""Account collegati all'app Foto: le foto dei propri servizi accanto a quelle del telefono.

Ogni foto porta la sua «fonte» (telefono, nextcloud, onedrive, dropbox, google): l'app Foto
mostra un simbolino del servizio sulla miniatura. Le foto di un account si scaricano in una
cache (~/.cache/solidos/foto/<servizio>/) e si aggiornano in background quando si apre Foto
(solo con il Wi-Fi, se scelto).

Servizi:
- Nextcloud (e ogni server WebDAV): indirizzo, utente e una «password per le app» creata in
  Nextcloud › Impostazioni › Sicurezza. Funziona senza registrazioni.
- OneDrive, Dropbox, Google Foto: chiedono che SolidOS sia registrato come app sui loro siti
  (gratis, con l'account di chi distribuisce SolidOS). Finché l'identificativo non c'è in
  branding.env (FOTO_ONEDRIVE_ID, FOTO_DROPBOX_ID, FOTO_GOOGLE_ID) restano «da attivare».
  Google, dal 31/03/2025, lascia solo SCEGLIERE foto e album con il suo selettore: niente
  sincronizzazione di tutta la libreria.
- Amazon Foto: nessun accesso ufficiale per le app esterne.
"""

from __future__ import annotations

import base64
import hashlib
import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

from .. import branding
from ..i18n import T
from ..sistema import config_utente, leggi_json, scrivi_json

ESTENSIONI = (".jpg", ".jpeg", ".png", ".webp", ".heic", ".gif")
SERVIZI = {
    "nextcloud": {"nome": "Nextcloud", "colore": "#0082C9", "lettera": "N", "descrizione": T("Il tuo cloud personale")},
    "onedrive": {"nome": "OneDrive", "colore": "#0078D4", "lettera": "O", "descrizione": T("Cartella Immagini"), "chiave": "FOTO_ONEDRIVE_ID"},
    "dropbox": {"nome": "Dropbox", "colore": "#0061FE", "lettera": "D", "descrizione": T("Cartella Foto"), "chiave": "FOTO_DROPBOX_ID"},
    "google": {"nome": "Google Foto", "colore": "#4285F4", "lettera": "G", "descrizione": T("Scegli foto e album"), "chiave": "FOTO_GOOGLE_ID"},
    "amazon": {"nome": "Amazon Foto", "colore": "#232F3E", "lettera": "A", "descrizione": T("Non disponibile: Amazon non lo permette")},
}
_blocco = threading.Lock()


def _file() -> Path:
    return config_utente("foto-account.json")


def _cache(servizio: str) -> Path:
    c = Path.home() / ".cache" / "solidos" / "foto" / servizio
    c.mkdir(parents=True, exist_ok=True)
    return c


def _demo() -> bool:
    from . import telefonia

    return telefonia.DEMO


def account() -> list:
    """Gli account collegati (senza password)."""
    return [{k: v for k, v in a.items() if k != "password"} for a in leggi_json(_file(), [])]


def servizi() -> list:
    """Tutti i servizi, con lo stato: collegato | collegabile | da_attivare | impossibile."""
    collegati = {a["servizio"]: a for a in account()}
    if _demo():
        collegati.setdefault("google", {"servizio": "google", "utente": "pasquale@…", "foto": 412, "album": 3})
        collegati.setdefault("onedrive", {"servizio": "onedrive", "cartella": "Immagini", "auto": True, "wifi": True, "scarica": False})
    elenco = []
    for chiave, s in SERVIZI.items():
        a = collegati.get(chiave)
        if a:
            stato = "collegato"
        elif chiave == "amazon":
            stato = "impossibile"
        elif chiave == "nextcloud" or branding.get(s.get("chiave", ""), ""):
            stato = "collegabile"
        else:
            stato = "da_attivare"
        elenco.append({"id": chiave, **{k: v for k, v in s.items() if k != "chiave"}, "stato": stato, "account": a or {}})
    return elenco


def _richiesta_dav(url: str, utente: str, password: str, metodo: str = "GET", corpo: bytes | None = None,
                   intestazioni: dict | None = None, timeout: int = 30):
    h = {"Authorization": "Basic " + base64.b64encode(f"{utente}:{password}".encode()).decode(),
         "User-Agent": f"{branding.nome()}-Foto"}
    h.update(intestazioni or {})
    return urllib.request.urlopen(urllib.request.Request(url, data=corpo, method=metodo, headers=h), timeout=timeout)


def _base_nextcloud(indirizzo: str, utente: str) -> str:
    indirizzo = indirizzo.strip().rstrip("/")
    if not indirizzo.startswith(("https://", "http://")):
        indirizzo = "https://" + indirizzo
    return f"{indirizzo}/remote.php/dav/files/{urllib.parse.quote(utente)}"


def _elenca(base: str, cartella: str, utente: str, password: str, profondita: int = 3) -> list:
    """File di immagine nella cartella (e sottocartelle, fino a «profondita» livelli)."""
    corpo = (b'<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:getlastmodified/>'
             b'<d:getcontentlength/><d:resourcetype/></d:prop></d:propfind>')
    url = base + "/" + urllib.parse.quote(cartella.strip("/")) + "/"
    with _richiesta_dav(url, utente, password, "PROPFIND", corpo, {"Depth": "1", "Content-Type": "application/xml"}) as r:
        albero = ET.fromstring(r.read())
    ns = {"d": "DAV:"}
    trovati = []
    radice = urllib.parse.urlparse(url).path
    for risp in albero.findall("d:response", ns):
        href = urllib.parse.unquote(risp.findtext("d:href", "", ns))
        if href.rstrip("/") == urllib.parse.unquote(radice).rstrip("/"):
            continue
        cartella_figlia = risp.find(".//d:resourcetype/d:collection", ns) is not None
        relativo = href.split("/remote.php/dav/files/", 1)[-1].split("/", 1)[-1]
        if cartella_figlia:
            if profondita > 0:
                trovati += _elenca(base, relativo, utente, password, profondita - 1)
        elif href.lower().endswith(ESTENSIONI):
            quando = risp.findtext(".//d:getlastmodified", "", ns)
            try:
                t = time.mktime(time.strptime(quando, "%a, %d %b %Y %H:%M:%S GMT")) - time.timezone
            except ValueError:
                t = 0
            trovati.append({"relativo": relativo, "quando": t})
    return trovati


def collega_nextcloud(indirizzo: str, utente: str, password: str, cartella: str = "Photos") -> dict:
    utente, password, cartella = utente.strip(), password.strip(), (cartella or "Photos").strip()
    if not indirizzo.strip() or not utente or not password:
        return {"ok": False, "messaggio": T("Scrivi indirizzo, utente e password per le app")}
    base = _base_nextcloud(indirizzo, utente)
    try:
        _elenca(base, cartella, utente, password, profondita=0)
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            return {"ok": False, "messaggio": T("Utente o password non validi (usa una «password per le app»)")}
        if e.code == 404:
            return {"ok": False, "messaggio": T("Cartella non trovata:") + " " + cartella}
        return {"ok": False, "messaggio": T("Il server ha risposto con un errore") + f" ({e.code})"}
    except (OSError, ET.ParseError):
        return {"ok": False, "messaggio": T("Server non raggiungibile: controlla l'indirizzo")}
    with _blocco:
        elenco = [a for a in leggi_json(_file(), []) if a.get("servizio") != "nextcloud"]
        elenco.append({"servizio": "nextcloud", "indirizzo": indirizzo.strip(), "utente": utente, "password": password,
                       "cartella": cartella, "auto": True, "wifi": True, "scarica": True})
        scrivi_json(_file(), elenco)
        try:
            _file().chmod(0o600)   # dentro c'è la password per le app
        except OSError:
            pass
    threading.Thread(target=sincronizza, daemon=True).start()
    return {"ok": True, "messaggio": T("Nextcloud collegato: le foto arrivano tra poco")}


def scollega(servizio: str) -> dict:
    with _blocco:
        scrivi_json(_file(), [a for a in leggi_json(_file(), []) if a.get("servizio") != servizio])
    for f in _cache(servizio).glob("*"):
        try:
            f.unlink()
        except OSError:
            pass
    return {"ok": True, "messaggio": T("Account scollegato: le sue foto non sono più sul telefono")}


def imposta(servizio: str, chiave: str, valore: bool) -> None:
    if chiave not in ("auto", "wifi", "scarica"):
        return
    with _blocco:
        elenco = leggi_json(_file(), [])
        for a in elenco:
            if a.get("servizio") == servizio:
                a[chiave] = bool(valore)
        scrivi_json(_file(), elenco)


def _su_wifi() -> bool:
    try:
        from . import impostazioni

        return bool((impostazioni.wifi() or {}).get("connesso"))
    except Exception:  # noqa: BLE001
        return True


def sincronizza() -> None:
    """Scarica nella cache le foto nuove degli account con la sincronizzazione accesa."""
    if not _blocco.acquire(blocking=False):
        return
    try:
        elenco = leggi_json(_file(), [])
    finally:
        _blocco.release()
    for a in elenco:
        if a.get("servizio") != "nextcloud" or not a.get("auto", True):
            continue
        if a.get("wifi", True) and not _su_wifi():
            continue
        base = _base_nextcloud(a["indirizzo"], a["utente"])
        try:
            remoti = _elenca(base, a.get("cartella", "Photos"), a["utente"], a["password"])
        except (OSError, ET.ParseError):
            continue
        cache = _cache("nextcloud")
        indice = leggi_json(cache / "indice.json", {})
        for f in sorted(remoti, key=lambda x: -x["quando"])[:500]:
            nome = hashlib.sha1(f["relativo"].encode()).hexdigest()[:16] + Path(f["relativo"]).suffix.lower()
            if (cache / nome).is_file():
                continue
            try:
                with _richiesta_dav(base + "/" + urllib.parse.quote(f["relativo"]), a["utente"], a["password"], timeout=120) as r:
                    (cache / nome).write_bytes(r.read())
                indice[nome] = {"quando": f["quando"], "remoto": f["relativo"]}
            except OSError:
                continue
        scrivi_json(cache / "indice.json", indice)


def foto() -> list:
    """Le foto scaricate dagli account, nello stesso formato di quelle del telefono."""
    risultato = []
    for servizio in ("nextcloud",):
        cache = _cache(servizio)
        indice = leggi_json(cache / "indice.json", {})
        for nome, info in indice.items():
            f = cache / nome
            if f.is_file():
                risultato.append({"percorso": str(f), "uri": f.as_uri(), "nome": Path(info.get("remoto", nome)).name,
                                  "quando": info.get("quando", f.stat().st_mtime), "fonte": servizio,
                                  "dove": info.get("remoto", "")})
    return risultato
