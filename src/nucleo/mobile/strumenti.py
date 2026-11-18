"""Le app di base del telefono: Calcolatrice, Note, File, Foto, Musica, Fotocamera,
Store (Flathub) e Condivisione vicina (servizio comune con il PC).

Tutto in Python standard, con i file nelle cartelle dell'utente. NUCLEO_DEMO=1 crea
dati di esempio (solo per le foto della prova).
"""

from __future__ import annotations

import ast
import json
import math
import mimetypes
import operator
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from .. import branding
from ..i18n import T
from ..sistema import cartella_utente, leggi_json, scrivi_json
from .telefonia import DEMO

IMMAGINI = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}
AUDIO = {".mp3", ".ogg", ".oga", ".opus", ".flac", ".wav", ".m4a", ".aac"}
VIDEO = {".mp4", ".mkv", ".webm", ".mov", ".avi"}
TESTO = {".txt", ".md", ".csv", ".log", ".json", ".py", ".sh"}


def _uri(p: Path) -> str:
    return "file://" + urllib.parse.quote(str(p))


# ── Calcolatrice ─────────────────────────────────────────────────────────────
_OPERATORI = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
              ast.Pow: operator.pow, ast.Mod: operator.mod, ast.USub: operator.neg, ast.UAdd: operator.pos}
_FUNZIONI = {"sqrt": math.sqrt, "sin": lambda x: math.sin(math.radians(x)), "cos": lambda x: math.cos(math.radians(x)),
             "tan": lambda x: math.tan(math.radians(x)), "log": math.log10, "ln": math.log, "abs": abs}
_COSTANTI = {"pi": math.pi, "e": math.e}


def _valuta(nodo):
    if isinstance(nodo, ast.Expression):
        return _valuta(nodo.body)
    if isinstance(nodo, ast.Constant) and isinstance(nodo.value, (int, float)):
        return nodo.value
    if isinstance(nodo, ast.BinOp) and type(nodo.op) in _OPERATORI:
        a, b = _valuta(nodo.left), _valuta(nodo.right)
        if isinstance(nodo.op, ast.Pow) and abs(b) > 1000:
            raise ValueError
        return _OPERATORI[type(nodo.op)](a, b)
    if isinstance(nodo, ast.UnaryOp) and type(nodo.op) in _OPERATORI:
        return _OPERATORI[type(nodo.op)](_valuta(nodo.operand))
    if isinstance(nodo, ast.Call) and isinstance(nodo.func, ast.Name) and nodo.func.id in _FUNZIONI and len(nodo.args) == 1:
        return _FUNZIONI[nodo.func.id](_valuta(nodo.args[0]))
    if isinstance(nodo, ast.Name) and nodo.id in _COSTANTI:
        return _COSTANTI[nodo.id]
    raise ValueError


def formatta_numero(valore) -> str:
    if isinstance(valore, float) and valore.is_integer() and abs(valore) < 1e15:
        valore = int(valore)
    if isinstance(valore, int):
        return f"{valore:,}".replace(",", ".")
    testo = f"{valore:.10g}"
    if "e" in testo:
        return testo.replace(".", ",")
    intero, _, decimali = testo.partition(".")
    return f"{int(intero):,}".replace(",", ".") + ("," + decimali if decimali else "")


def calcola(espressione: str) -> dict:
    testo = (espressione.replace("×", "*").replace("÷", "/").replace("−", "-").replace("^", "**")
             .replace("π", "pi").replace("√", "sqrt").replace(".", "").replace(",", "."))
    if testo.endswith("%"):
        testo = f"({testo[:-1]})/100"
    try:
        return {"ok": True, "valore": formatta_numero(_valuta(ast.parse(testo, mode="eval")))}
    except ZeroDivisionError:
        return {"ok": False, "valore": T("Impossibile dividere per zero")}
    except (ValueError, SyntaxError, TypeError, OverflowError):
        return {"ok": False, "valore": T("Errore")}


# ── Note (stessa cartella delle Note del PC; qui testo semplice) ────────────
def _cartella_note() -> Path:
    c = Path.home() / ".local/share" / branding.id_os() / "note-telefono"
    c.mkdir(parents=True, exist_ok=True)
    return c


def _demo_note() -> None:
    c = _cartella_note()
    if any(c.glob("*.json")):
        return
    adesso = time.time()
    for i, (testo, fissa) in enumerate([
            ("Lista della spesa\n- latte\n- pane\n- caffè\n- mele", True),
            ("Idee per SolidOS Mobile\nWidget del meteo nella schermata di blocco, tema automatico al tramonto.", False),
            ("Numero del meccanico\n06 1234 5678", False)]):
        scrivi_json(c / f"demo{i}.json", {"id": f"demo{i}", "testo": testo, "fissata": fissa, "modificata": adesso - i * 86400})


def _riassunto(n: dict) -> dict:
    righe = [r for r in n.get("testo", "").splitlines() if r.strip()]
    quando = time.localtime(n.get("modificata", 0))
    oggi = time.localtime()
    ora = time.strftime("%H:%M", quando) if quando[:3] == oggi[:3] else time.strftime("%d/%m/%y", quando)
    return {"id": n["id"], "titolo": righe[0][:80] if righe else T("Nuova nota"),
            "anteprima": " ".join(righe[1:3])[:120], "fissata": bool(n.get("fissata")), "quando": ora,
            "modificata": n.get("modificata", 0)}


def note(cerca: str = "") -> list:
    if DEMO:
        _demo_note()
    elenco = []
    for f in _cartella_note().glob("*.json"):
        n = leggi_json(f, {})
        if not n.get("id"):
            continue
        if cerca and cerca.lower() not in n.get("testo", "").lower():
            continue
        elenco.append(_riassunto(n))
    elenco.sort(key=lambda n: (not n["fissata"], -n["modificata"]))
    return elenco


def leggi_nota(ident: str) -> dict:
    return leggi_json(_cartella_note() / f"{Path(ident).name}.json", {"id": ident, "testo": "", "fissata": False})


def salva_nota(ident: str, testo: str) -> str:
    ident = Path(ident).name if ident else uuid.uuid4().hex[:12]
    f = _cartella_note() / f"{ident}.json"
    vecchia = leggi_json(f, {})
    if not testo.strip():
        f.unlink(missing_ok=True)
        return ""
    scrivi_json(f, {"id": ident, "testo": testo, "fissata": vecchia.get("fissata", False), "modificata": time.time()})
    return ident


def fissa_nota(ident: str, si: bool) -> None:
    f = _cartella_note() / f"{Path(ident).name}.json"
    n = leggi_json(f, {})
    if n:
        n["fissata"] = bool(si)
        scrivi_json(f, n)


def elimina_nota(ident: str) -> None:
    (_cartella_note() / f"{Path(ident).name}.json").unlink(missing_ok=True)


# ── File ─────────────────────────────────────────────────────────────────────
def _tipo(p: Path) -> str:
    if p.is_dir():
        return "cartella"
    s = p.suffix.lower()
    if s in IMMAGINI:
        return "immagine"
    if s in AUDIO:
        return "audio"
    if s in VIDEO:
        return "video"
    if s in TESTO:
        return "testo"
    if s == ".pdf":
        return "pdf"
    return "file"


ICONE_TIPO = {"cartella": "folder", "immagine": "image-x-generic", "audio": "audio-x-generic", "video": "video-x-generic",
              "testo": "text-x-generic", "pdf": "application-pdf", "file": "text-x-generic"}


def _dimensione(byte: int) -> str:
    for unita in ("B", "KB", "MB", "GB"):
        if byte < 1024 or unita == "GB":
            return f"{byte:.0f} {unita}" if unita == "B" else f"{byte:.1f} {unita}".replace(".", ",")
        byte /= 1024
    return ""


def _demo_file() -> None:
    casa = Path.home()
    for nome in ("Documenti", "Immagini", "Musica", "Scaricati", "Video"):
        (casa / nome).mkdir(exist_ok=True)
    esempi = {"Documenti/Lettera.txt": "Caro amico,\nti scrivo dal mio nuovo telefono.\n",
              "Documenti/Spese.csv": "voce;euro\naffitto;500\n", "Scaricati/manuale.pdf": "%PDF-1.4\n"}
    for nome, testo in esempi.items():
        if not (casa / nome).exists():
            (casa / nome).write_text(testo, encoding="utf-8")


def luoghi() -> list:
    if DEMO:
        _demo_file()
    casa = Path.home()
    voci = [("Documenti", "DOCUMENTS", "folder-documents"), ("Immagini", "PICTURES", "folder-pictures"),
            ("Musica", "MUSIC", "folder-music"), ("Video", "VIDEOS", "folder-videos"),
            ("Scaricati", "DOWNLOAD", "folder-download")]
    risultato = [{"nome": T("Telefono"), "percorso": str(casa), "icona": "user-home"}]
    for nome, tipo, icona in voci:
        p = cartella_utente(tipo, nome)
        if p.is_dir():
            risultato.append({"nome": T(nome), "percorso": str(p), "icona": icona})
    sd = [m for m in Path("/media").glob("*/*") if m.is_dir()] + [m for m in Path("/run/media").glob("*/*") if m.is_dir()]
    for m in sd:
        risultato.append({"nome": m.name, "percorso": str(m), "icona": "media-flash"})
    risultato.append({"nome": T("Cestino"), "percorso": str(_cestino() / "files"), "icona": "user-trash"})
    return risultato


def elenco_file(percorso: str, nascosti: bool = False) -> dict:
    p = Path(percorso or Path.home()).expanduser()
    if not p.is_dir():
        p = Path.home()
    voci = []
    try:
        figli = list(p.iterdir())
    except OSError:
        figli = []
    for f in figli:
        if f.name.startswith(".") and not nascosti:
            continue
        try:
            st = f.stat()
        except OSError:
            continue
        tipo = _tipo(f)
        voci.append({"nome": f.name, "percorso": str(f), "tipo": tipo, "icona": ICONE_TIPO[tipo],
                     "uri": _uri(f) if tipo == "immagine" else "",
                     "info": (T("{n} elementi", n=sum(1 for _ in f.iterdir())) if tipo == "cartella" and os.access(f, os.R_OK)
                              else _dimensione(st.st_size)) + " · " + time.strftime("%d/%m/%y", time.localtime(st.st_mtime))})
    voci.sort(key=lambda v: (v["tipo"] != "cartella", v["nome"].lower()))
    casa = Path.home()
    titolo = T("Telefono") if p == casa else p.name
    return {"percorso": str(p), "titolo": titolo, "su": str(p.parent) if p != Path("/") and p != casa else "", "voci": voci}


def nuova_cartella(dove: str, nome: str) -> dict:
    nome = nome.strip().replace("/", "-")
    if not nome:
        return {"ok": False, "messaggio": T("Scrivi un nome")}
    try:
        (Path(dove) / nome).mkdir()
        return {"ok": True}
    except FileExistsError:
        return {"ok": False, "messaggio": T("Esiste già")}
    except OSError as e:
        return {"ok": False, "messaggio": str(e)}


def rinomina(percorso: str, nome: str) -> dict:
    nome = nome.strip().replace("/", "-")
    p = Path(percorso)
    nuovo = p.with_name(nome)
    if not nome or nuovo.exists():
        return {"ok": False, "messaggio": T("Nome non valido o già usato")}
    try:
        p.rename(nuovo)
        return {"ok": True}
    except OSError as e:
        return {"ok": False, "messaggio": str(e)}


def _cestino() -> Path:
    c = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "Trash"
    (c / "files").mkdir(parents=True, exist_ok=True)
    (c / "info").mkdir(parents=True, exist_ok=True)
    return c


def cestina(percorso: str) -> dict:
    """Sposta nel Cestino (standard freedesktop, lo stesso del PC)."""
    p = Path(percorso)
    c = _cestino()
    if c in p.parents:
        try:
            shutil.rmtree(p) if p.is_dir() else p.unlink()
            (c / "info" / (p.name + ".trashinfo")).unlink(missing_ok=True)
            return {"ok": True, "messaggio": T("Eliminato")}
        except OSError as e:
            return {"ok": False, "messaggio": str(e)}
    nome, n = p.name, 1
    while (c / "files" / nome).exists():
        n += 1
        nome = f"{p.stem} ({n}){p.suffix}"
    try:
        (c / "info" / f"{nome}.trashinfo").write_text(
            f"[Trash Info]\nPath={urllib.parse.quote(str(p))}\nDeletionDate={time.strftime('%Y-%m-%dT%H:%M:%S')}\n")
        shutil.move(str(p), str(c / "files" / nome))
        return {"ok": True, "messaggio": T("Spostato nel Cestino")}
    except OSError as e:
        return {"ok": False, "messaggio": str(e)}


def leggi_testo(percorso: str) -> str:
    try:
        with open(percorso, encoding="utf-8", errors="replace") as f:
            return f.read(200_000)
    except OSError:
        return ""


# ── Foto ─────────────────────────────────────────────────────────────────────
def cartella_foto() -> Path:
    c = cartella_utente("PICTURES", "Immagini") / "Fotocamera"
    c.mkdir(parents=True, exist_ok=True)
    return c


def _png(percorso: Path, larghezza: int, altezza: int, c1: tuple, c2: tuple) -> None:
    """Immagine PNG a sfumatura (dati di esempio, senza librerie)."""
    import struct
    import zlib

    righe = bytearray()
    for y in range(altezza):
        righe.append(0)
        for x in range(larghezza):
            t = (x / larghezza + y / altezza) / 2
            righe += bytes(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))

    def blocco(tipo: bytes, dati: bytes) -> bytes:
        return struct.pack(">I", len(dati)) + tipo + dati + struct.pack(">I", zlib.crc32(tipo + dati) & 0xFFFFFFFF)

    percorso.write_bytes(b"\x89PNG\r\n\x1a\n" + blocco(b"IHDR", struct.pack(">IIBBBBB", larghezza, altezza, 8, 2, 0, 0, 0))
                         + blocco(b"IDAT", zlib.compress(bytes(righe), 6)) + blocco(b"IEND", b""))


def _demo_foto() -> None:
    c = cartella_foto()
    if any(c.iterdir()):
        return
    colori = [((255, 140, 90), (120, 60, 200)), ((40, 120, 255), (20, 220, 200)), ((250, 210, 80), (240, 90, 80)),
              ((30, 40, 90), (110, 80, 220)), ((60, 200, 120), (20, 90, 140)), ((240, 120, 180), (250, 220, 150)),
              ((90, 90, 110), (200, 200, 220)), ((10, 120, 90), (200, 240, 120)), ((120, 30, 60), (250, 150, 60))]
    for i, (a, b) in enumerate(colori):
        f = c / f"IMG_202611{10 + i}_1200{i}.png"
        _png(f, 240, 240, a, b)
        os.utime(f, (time.time() - i * 86400, time.time() - i * 86400))


def foto() -> list:
    if DEMO:
        _demo_foto()
    radici = {cartella_utente("PICTURES", "Immagini"), Path.home() / "DCIM", cartella_utente("DOWNLOAD", "Scaricati")}
    trovate = []
    for r in radici:
        if not r.is_dir():
            continue
        for f in r.rglob("*"):
            if f.suffix.lower() in IMMAGINI and not any(x.startswith(".") for x in f.parts):
                try:
                    trovate.append((f.stat().st_mtime, f))
                except OSError:
                    pass
    scaricati = cartella_utente("DOWNLOAD", "Scaricati")
    elenco = []
    for t, f in trovate[:2000]:
        album = "scaricati" if scaricati in f.parents else ("schermate" if "screenshot" in f.name.lower() or "schermata" in f.name.lower() else "fotocamera")
        elenco.append({"percorso": str(f), "uri": _uri(f), "nome": f.name, "quando": t, "fonte": "telefono", "album": album})
    # Le foto degli account collegati (Nextcloud…), con il simbolino del servizio
    from . import fotoaccount

    elenco += [dict(x, album="account") for x in fotoaccount.foto()]
    if DEMO:   # foto di prova: alcune «arrivano» dagli account collegati
        for i, x in enumerate(elenco):
            if i in (2, 5):
                x["fonte"] = "google"
            elif i in (6, 8):
                x["fonte"] = "onedrive"
    elenco.sort(key=lambda x: -x["quando"])
    oggi = time.strftime("%Y-%m-%d")
    ieri = time.strftime("%Y-%m-%d", time.localtime(time.time() - 86400))
    mesi = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre",
            "ottobre", "novembre", "dicembre"]
    for x in elenco:
        lt = time.localtime(x["quando"])
        g = time.strftime("%Y-%m-%d", lt)
        x["giorno"] = T("Oggi") if g == oggi else (T("Ieri") if g == ieri else f"{lt.tm_mday} {T(mesi[lt.tm_mon - 1])}" + (f" {lt.tm_year}" if lt.tm_year != time.localtime().tm_year else ""))
        x["data"] = time.strftime("%d/%m/%Y %H:%M", lt)
    return elenco


def nuova_foto() -> str:
    return str(cartella_foto() / time.strftime("IMG_%Y%m%d_%H%M%S.jpg"))


# ── Musica ───────────────────────────────────────────────────────────────────
def musica() -> list:
    radice = cartella_utente("MUSIC", "Musica")
    brani = []
    if radice.is_dir():
        for f in sorted(radice.rglob("*")):
            if f.suffix.lower() in AUDIO:
                nome = f.stem.replace("_", " ")
                artista, _, titolo = nome.partition(" - ")
                if not titolo:
                    artista, titolo = (f.parent.name if f.parent != radice else T("Artista sconosciuto")), nome
                brani.append({"percorso": str(f), "uri": _uri(f), "titolo": titolo.strip(), "artista": artista.strip()})
    if DEMO and not brani:
        brani = [{"percorso": "", "uri": "", "titolo": t, "artista": a} for t, a in
                 [("Alba sul mare", "Le Onde"), ("Città di notte", "Neon Rosso"), ("Passeggiata", "Trio Verde"),
                  ("Strada di casa", "Le Onde"), ("Vento d'estate", "Marta Blu")]]
    return brani


# ── Store (Flathub, installazione per l'utente: niente password) ────────────
CONSIGLIATE = [
    ("org.mozilla.firefox", "Firefox", "Navigare sul web"),
    ("org.gnome.Maps", "Mappe", "Mappe e indicazioni"),
    ("org.gnome.Weather", "Meteo", "Previsioni del tempo"),
    ("org.gnome.Podcasts", "Podcast", "Ascolta i podcast"),
    ("io.github.alainm23.planify", "Planify", "Promemoria e attività"),
    ("org.gnome.Fractal", "Fractal", "Chat Matrix"),
    ("org.telegram.desktop", "Telegram", "Messaggi"),
    ("org.kde.kasts", "Kasts", "Podcast per il telefono"),
]
_RIMOTO = "https://dl.flathub.org/repo/flathub.flatpakrepo"


def _icona_flathub(ident: str) -> str:
    return f"https://dl.flathub.org/repo/appstream/aarch64/icons/128x128/{ident}.png"


def _installate_flatpak() -> set:
    if DEMO:
        return {"org.gnome.Weather"}
    if not shutil.which("flatpak"):
        return set()
    try:
        r = subprocess.run(["flatpak", "list", "--app", "--columns=application"], capture_output=True, text=True, timeout=20)
        return {x.strip() for x in r.stdout.splitlines() if x.strip()}
    except (OSError, subprocess.SubprocessError):
        return set()


def store_consigliate() -> dict:
    installate = _installate_flatpak()
    return {"disponibile": DEMO or bool(shutil.which("flatpak")),
            "app": [{"id": i, "nome": n, "descrizione": d, "icona": _icona_flathub(i), "installata": i in installate}
                    for i, n, d in CONSIGLIATE]}


def store_cerca(testo: str) -> list:
    testo = testo.strip()
    if not testo:
        return []
    installate = _installate_flatpak()
    if DEMO:
        return [a for a in store_consigliate()["app"] if testo.lower() in (a["nome"] + a["descrizione"]).lower()]
    try:
        richiesta = urllib.request.Request(
            "https://flathub.org/api/v2/search", data=json.dumps({"query": testo}).encode(),
            headers={"Content-Type": "application/json", "User-Agent": f"{branding.nome()}-Mobile/{branding.get('OS_VERSION', '0')}"})
        with urllib.request.urlopen(richiesta, timeout=15) as r:
            dati = json.load(r)
    except (OSError, ValueError):
        return []
    risultati = []
    for h in dati.get("hits", [])[:30]:
        ident = h.get("app_id", "")
        if not ident or "aarch64" not in (h.get("arches") or ["aarch64"]):
            continue
        risultati.append({"id": ident, "nome": h.get("name", ident), "descrizione": h.get("summary", ""),
                          "icona": h.get("icon") or _icona_flathub(ident), "installata": ident in installate})
    return risultati


def store_installa(ident: str) -> dict:
    if DEMO:
        return {"ok": True, "messaggio": T("Installata")}
    if not shutil.which("flatpak"):
        return {"ok": False, "messaggio": T("Flatpak non è installato")}
    if not all(c.isalnum() or c in "._-" for c in ident):
        return {"ok": False, "messaggio": T("App non valida")}
    subprocess.run(["flatpak", "--user", "remote-add", "--if-not-exists", "flathub", _RIMOTO],
                   capture_output=True, timeout=120)
    r = subprocess.run(["flatpak", "--user", "install", "-y", "--noninteractive", "flathub", ident],
                       capture_output=True, text=True, timeout=3600)
    return {"ok": r.returncode == 0,
            "messaggio": T("Installata") if r.returncode == 0 else (r.stderr.strip().splitlines() or [T("Non riuscito")])[-1]}


def store_rimuovi(ident: str) -> dict:
    if DEMO:
        return {"ok": True, "messaggio": T("Rimossa")}
    if not all(c.isalnum() or c in "._-" for c in ident):
        return {"ok": False, "messaggio": T("App non valida")}
    r = subprocess.run(["flatpak", "uninstall", "-y", "--noninteractive", ident], capture_output=True, text=True, timeout=600)
    return {"ok": r.returncode == 0, "messaggio": T("Rimossa") if r.returncode == 0 else T("Non riuscito")}


# ── Condivisione vicina (lo stesso servizio del PC: LocalSend, Quick Share, QR) ─
def _vicina(metodo: str, *argomenti, timeout: float = 10):
    from ..dbusutil import chiama

    nome = branding.nome_dbus("Condivisione1")
    return chiama(nome, branding.percorso_dbus("Condivisione1"), nome, metodo, *argomenti, timeout=timeout)


def _avvia_vicina() -> None:
    if _vicina("StatoBackend", timeout=2) is not None:
        return
    subprocess.Popen([sys.executable, "-m", "nucleo.condivisione"], stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def vicina_stato() -> dict:
    if DEMO:
        return {"attivo": True, "visibilita": "tutti10", "cartella": str(Path.home() / "Scaricati"),
                "dispositivi": [{"id": "ls:1", "nome": "Portatile di Pasquale", "tipo": "computer", "backend": "localsend"},
                                {"id": "qs:2", "nome": "Pixel di Marta", "tipo": "telefono", "backend": "quickshare"}]}
    _avvia_vicina()
    dispositivi = _vicina("Dispositivi", timeout=3)
    visibilita = None
    try:
        import dbus

        nome = branding.nome_dbus("Condivisione1")
        o = dbus.SessionBus().get_object(nome, branding.percorso_dbus("Condivisione1"))
        prop = dbus.Interface(o, "org.freedesktop.DBus.Properties")
        visibilita = str(prop.Get(nome, "Visibilita"))
        cartella = str(prop.Get(nome, "CartellaRicevuti"))
    except Exception:  # noqa: BLE001
        cartella = str(cartella_utente("DOWNLOAD", "Scaricati"))
    return {"attivo": dispositivi is not None, "visibilita": visibilita or "nessuno", "cartella": cartella,
            "dispositivi": json.loads(dispositivi) if dispositivi else []}


def vicina_scopri() -> None:
    if not DEMO:
        _avvia_vicina()
        _vicina("Scopri", 30)


def vicina_visibilita(modalita: str) -> None:
    if not DEMO:
        _vicina("ImpostaVisibilita", modalita)


def vicina_invia(file: list, dispositivo: str) -> dict:
    if DEMO:
        return {"ok": True, "messaggio": T("Inviato")}
    r = _vicina("Invia", [str(f) for f in file], dispositivo, timeout=30)
    return {"ok": r is not None, "messaggio": T("Invio in corso…") if r is not None else T("Servizio non disponibile")}


def vicina_qr() -> dict:
    """Ricevi da qualsiasi telefono: codice QR con un indirizzo da aprire nel browser."""
    if DEMO:
        return {"ok": True, "url": "http://192.168.1.20:53318/abc123", "svg": ""}
    _avvia_vicina()
    r = _vicina("RiceviConQr", False, timeout=15)
    try:
        dati = json.loads(r) if r else {}
    except ValueError:
        dati = {}
    return {"ok": bool(dati), **dati}


def vicina_ferma_qr() -> None:
    if not DEMO:
        _vicina("FermaQr")


def tipo_mime(percorso: str) -> str:
    return mimetypes.guess_type(percorso)[0] or ""
