"""(Copia di nucleo/store/catalogo.py di SolidOS per PC, con le raccolte del telefono.)
Catalogo dello Store dal servizio pubblico di Flathub (https://flathub.org/api/v2).

Collezioni (più popolari, di tendenza, nuove), categorie, ricerca e la scheda di ogni app
(descrizione, foto dello schermo, sviluppatore, versione, dimensioni). Si mostrano SOLO le
app che esistono per il processore di questo computer (su ARM, per esempio, non ci sono
Spotify o Steam). Le risposte restano in una piccola cache per qualche ora: lo Store si
apre subito anche con una rete lenta.
"""

from __future__ import annotations

import html
import json
import platform
import re
import time
import urllib.parse
import urllib.request
from hashlib import sha1
from pathlib import Path

from . import branding
from .i18n import T
from .sistema import stato_utente

API = "https://flathub.org/api/v2"
ARCH = {"x86_64": "x86_64", "amd64": "x86_64", "aarch64": "aarch64", "arm64": "aarch64"}.get(
    platform.machine().lower(), platform.machine().lower())
DURATA_CACHE = 6 * 3600

# Categorie principali di Flathub con i nomi in italiano e un'icona del tema
CATEGORIE = [
    ("Office", T("Produttività"), "applications-office"),
    ("Graphics", T("Grafica e foto"), "applications-graphics"),
    ("AudioVideo", T("Musica e video"), "applications-multimedia"),
    ("Game", T("Giochi"), "applications-games"),
    ("Network", T("Internet e comunicazione"), "applications-internet"),
    ("Development", T("Sviluppo"), "applications-development"),
    ("Education", T("Istruzione"), "applications-education"),
    ("Science", T("Scienza"), "applications-science"),
    ("Utility", T("Utilità"), "applications-utilities"),
    ("System", T("Sistema"), "applications-system"),
]


def _cartella_cache() -> Path:
    c = stato_utente("store-cache")
    c.mkdir(parents=True, exist_ok=True)
    return c


def _richiesta(percorso: str, corpo: dict | None = None, cache: bool = True):
    url = API + percorso
    chiave = sha1((url + json.dumps(corpo or {}, sort_keys=True)).encode()).hexdigest()
    file = _cartella_cache() / f"{chiave}.json"
    if cache and file.is_file() and time.time() - file.stat().st_mtime < DURATA_CACHE:
        try:
            return json.loads(file.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            pass
    intestazioni = {"User-Agent": f"{branding.nome()}-App/{branding.get('OS_VERSION', '0')}", "Accept": "application/json"}
    dati = None
    if corpo is not None:
        dati = json.dumps(corpo).encode()
        intestazioni["Content-Type"] = "application/json"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=dati, headers=intestazioni), timeout=20) as r:
            risposta = json.load(r)
    except (OSError, ValueError):
        # Senza rete: meglio una risposta vecchia che niente
        if file.is_file():
            try:
                return json.loads(file.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                return None
        return None
    try:
        file.write_text(json.dumps(risposta), encoding="utf-8")
    except OSError:
        pass
    return risposta


def _app(h: dict) -> dict | None:
    """Una voce del catalogo in forma semplice; None se non esiste per questo processore."""
    archi = h.get("arches") or []
    if archi and ARCH not in archi:
        return None
    ident = h.get("app_id") or h.get("id") or ""
    if not ident:
        return None
    return {"id": ident, "nome": h.get("name") or ident, "descrizione": h.get("summary") or "",
            "icona": h.get("icon") or "", "sviluppatore": h.get("developer_name") or "",
            "verificata": bool(h.get("verification_verified")), "origine": "flatpak",
            "scaricamenti": h.get("installs_last_month") or 0}


def _elenco(risposta, quante: int) -> list[dict]:
    if not risposta:
        return []
    risultati = []
    for h in risposta.get("hits", []):
        a = _app(h)
        if a:
            risultati.append(a)
        if len(risultati) >= quante:
            break
    return risultati


def collezione(nome: str, quante: int = 18) -> list[dict]:
    """popular | trending | recently-updated | recently-added"""
    if nome not in ("popular", "trending", "recently-updated", "recently-added"):
        return []
    return _elenco(_richiesta(f"/collection/{nome}?page=1&per_page=60"), quante)


def categorie() -> list[dict]:
    return [{"id": c, "nome": n, "icona": i} for c, n, i in CATEGORIE]


def categoria(nome: str, quante: int = 60) -> list[dict]:
    if nome not in {c for c, _n, _i in CATEGORIE}:
        return []
    return _elenco(_richiesta(f"/collection/category/{urllib.parse.quote(nome)}?page=1&per_page=100"), quante)


def cerca(testo: str, quante: int = 40) -> list[dict]:
    testo = testo.strip()
    if len(testo) < 2:
        return []
    corpo = {"query": testo, "filters": [{"filterType": "arches", "value": ARCH}]}
    return _elenco(_richiesta("/search", corpo), quante)


def _testo_descrizione(d: str) -> str:
    """La descrizione di Flathub è HTML semplice (<p>, <ul>, <li>, <em>): si tiene così,
    togliendo solo ciò che il testo di Qt non sa mostrare."""
    d = re.sub(r"\s+", " ", d or "").strip()
    d = re.sub(r"</?(code|ol)>", "", d)
    return d


def _misura(byte) -> str:
    try:
        n = float(byte)
    except (TypeError, ValueError):
        return ""
    for unita in ("B", "KB", "MB", "GB"):
        if n < 1024 or unita == "GB":
            return f"{n:.0f} {unita}" if unita in ("B", "KB") else f"{n:.1f} {unita}".replace(".", ",")
        n /= 1024
    return ""


def dettagli(ident: str) -> dict:
    """La scheda completa di un'app (come una pagina dell'App Store)."""
    if not re.fullmatch(r"[A-Za-z0-9._-]+", ident or ""):
        return {"ok": False, "messaggio": T("App non valida")}
    a = _richiesta(f"/appstream/{ident}")
    if not a:
        return {"ok": False, "messaggio": T("Non riesco a leggere la scheda dell'app: controlla la connessione.")}
    s = _richiesta(f"/summary/{ident}") or {}
    archi = s.get("arches") or []
    foto = []
    for sc in a.get("screenshots") or []:
        misure = [m for m in sc.get("sizes") or [] if m.get("src")]
        # la misura più vicina a 1248 px di larghezza: nitida ma non enorme
        misure.sort(key=lambda m: abs(int(m.get("width") or 0) - 1248))
        if misure:
            foto.append({"url": misure[0]["src"], "didascalia": sc.get("caption") or ""})
    versioni = a.get("releases") or []
    ultima = versioni[0] if versioni else {}
    quando = ""
    if ultima.get("timestamp"):
        try:
            quando = time.strftime("%d/%m/%Y", time.localtime(int(ultima["timestamp"])))
        except (TypeError, ValueError):
            quando = ""
    urls = a.get("urls") or {}
    icona = a.get("icon") or ""
    return {
        "ok": True, "id": ident, "nome": a.get("name") or ident, "descrizioneBreve": a.get("summary") or "",
        "descrizione": _testo_descrizione(a.get("description") or ""),
        "sviluppatore": a.get("developer_name") or "", "licenza": a.get("project_license") or "",
        "libera": bool(a.get("is_free_license")), "versione": ultima.get("version") or "", "data": quando,
        "novita": _testo_descrizione(ultima.get("description") or ""),
        "scarica": _misura(s.get("download_size")), "occupa": _misura(s.get("installed_size")),
        "foto": foto[:8], "sito": urls.get("homepage") or "", "icona": icona,
        "disponibile": not archi or ARCH in archi, "origine": "flatpak",
        "categorie": [html.unescape(c) for c in (a.get("categories") or [])][:4],
    }


# ── Raccolte scelte da SolidOS (da sfogliare, come le liste dell'App Store) ────
# id Flathub; quelle che non esistono per questo processore si saltano da sole
RACCOLTE = [
    {"id": "studio", "nome": T("Per lo studio"), "sotto": T("Appunti, flashcard, bibliografia e matematica"),
     "colori": ["#4C7DFF", "#8B5CF6"],
     "app": ["com.github.xournalpp.xournalpp", "net.ankiweb.Anki", "org.zotero.Zotero", "org.libreoffice.LibreOffice",
             "com.logseq.Logseq", "org.geogebra.GeoGebra"]},
    {"id": "ufficio", "nome": T("Ufficio completo"), "sotto": T("Documenti, fogli di calcolo, posta e PDF"),
     "colori": ["#14B8A6", "#2F5FD0"],
     "app": ["org.libreoffice.LibreOffice", "org.mozilla.Thunderbird", "org.onlyoffice.desktopeditors",
             "com.github.jeromerobert.pdfarranger", "org.gnome.Calendar", "org.kde.okular"]},
    {"id": "grafica", "nome": T("Foto e grafica"), "sotto": T("Ritocca, disegna, impagina, modella in 3D"),
     "colori": ["#F59E0B", "#E5484D"],
     "app": ["org.gimp.GIMP", "org.inkscape.Inkscape", "org.kde.krita", "org.blender.Blender",
             "org.darktable.Darktable", "com.github.PintaProject.Pinta"]},
    {"id": "video", "nome": T("Video e musica"), "sotto": T("Montaggio, registrazione e ascolto"),
     "colori": ["#EC4899", "#8B5CF6"],
     "app": ["org.kde.kdenlive", "com.obsproject.Studio", "org.audacityteam.Audacity", "org.videolan.VLC",
             "org.shotcut.Shotcut", "fr.handbrake.ghb"]},
    {"id": "giochi", "nome": T("Giochi gratis"), "sotto": T("Da soli o con gli amici"),
     "colori": ["#30A46C", "#0EA5E9"],
     "app": ["net.supertuxkart.SuperTuxKart", "org.luanti.luanti", "com.play0ad.zeroad", "com.github.Anuken.Mindustry",
             "com.valvesoftware.Steam", "org.libretro.RetroArch"]},
    {"id": "comunicare", "nome": T("Parlare con tutti"), "sotto": T("Messaggi, chiamate e videochiamate"),
     "colori": ["#0EA5E9", "#4C7DFF"],
     "app": ["org.telegram.desktop", "org.signal.Signal", "im.riot.Riot", "com.discordapp.Discord", "us.zoom.Zoom",
             "org.mozilla.firefox"]},
]


def app_breve(ident: str) -> dict | None:
    """Nome, descrizione breve e icona di un'app (dalla sua scheda, in cache)."""
    if not re.fullmatch(r"[A-Za-z0-9._-]+", ident or ""):
        return None
    a = _richiesta(f"/appstream/{ident}")
    if not a:
        return None
    s = _richiesta(f"/summary/{ident}") or {}
    archi = s.get("arches") or []
    if archi and ARCH not in archi:
        return None
    return {"id": ident, "nome": a.get("name") or ident, "descrizione": a.get("summary") or "",
            "icona": a.get("icon") or "", "sviluppatore": a.get("developer_name") or "", "origine": "flatpak"}


def _molte(idents: list[str]) -> list[dict]:
    from concurrent.futures import ThreadPoolExecutor

    with ThreadPoolExecutor(max_workers=8) as pool:
        return [a for a in pool.map(app_breve, idents) if a]


# Sul telefono: app che funzionano bene su uno schermo piccolo
RACCOLTE_TELEFONO = [
    {"id": "giorni", "nome": T("Per tutti i giorni"), "sotto": T("Meteo, promemoria, orologi e mappe"),
     "colori": ["#4C7DFF", "#8B5CF6"],
     "app": ["org.gnome.Weather", "io.github.mrvladus.List", "org.gnome.clocks", "org.gnome.Maps", "org.gnome.Calendar"]},
    {"id": "social", "nome": T("Messaggi e social"), "sotto": T("Chat, gruppi e Mastodon"),
     "colori": ["#0EA5E9", "#4C7DFF"],
     "app": ["org.gnome.Fractal", "dev.geopjr.Tuba", "de.schmidhuberj.Flare", "io.gitlab.news_flash.NewsFlash"]},
    {"id": "ascolto", "nome": T("Musica e podcast"), "sotto": T("Ascolta, scopri, riconosci un brano"),
     "colori": ["#EC4899", "#8B5CF6"],
     "app": ["io.bassi.Amberol", "org.gnome.Podcasts", "org.kde.kasts", "de.haeckerfelix.Shortwave", "io.github.seadve.Mousai"]},
    {"id": "giochi", "nome": T("Giochi da tasca"), "sotto": T("Partite veloci, anche senza rete"),
     "colori": ["#30A46C", "#0EA5E9"],
     "app": ["org.gnome.Chess", "org.gnome.Mahjongg", "org.gnome.Sudoku", "org.gnome.TwentyFortyEight", "org.gnome.Quadrapassel"]},
    {"id": "strumenti", "nome": T("Strumenti utili"), "sotto": T("Codici di accesso, QR e file tra dispositivi"),
     "colori": ["#F59E0B", "#E5484D"],
     "app": ["com.belmoussaoui.Authenticator", "com.belmoussaoui.Decoder", "app.drey.Warp", "org.gnome.Solanum"]},
]


def raccolte(definizioni: list[dict] | None = None) -> list[dict]:
    """Le raccolte con le loro app (quelle che esistono per questo processore)."""
    definizioni = definizioni or RACCOLTE
    tutte = _molte(sorted({i for r in definizioni for i in r["app"]}))
    per_id = {a["id"]: a for a in tutte}
    risultato = []
    for r in definizioni:
        app = [per_id[i] for i in r["app"] if i in per_id]
        if app:
            risultato.append({"id": r["id"], "nome": r["nome"], "sotto": r["sotto"], "colori": r["colori"], "app": app})
    return risultato


def raccolte_di(ident: str, definizioni: list[dict] | None = None) -> list[dict]:
    """In quali raccolte si trova un'app (per la sua scheda)."""
    return [{"id": r["id"], "nome": r["nome"], "colori": r["colori"]} for r in (definizioni or RACCOLTE) if ident in r["app"]]
