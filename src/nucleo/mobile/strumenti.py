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
import re
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
from ..sistema import cartella_utente, config_utente, leggi_json, scrivi_json
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
_ANGOLO = {"radianti": False}   # Scientifica: «Rad» acceso = angoli in radianti


def _trig(f):
    return lambda x: f(x if _ANGOLO["radianti"] else math.radians(x))


def _fattoriale(x):
    if x < 0 or x > 170 or x != int(x):
        raise ValueError
    return math.factorial(int(x))


_FUNZIONI = {"sqrt": math.sqrt, "sin": _trig(math.sin), "cos": _trig(math.cos), "tan": _trig(math.tan),
             "log": math.log10, "ln": math.log, "abs": abs, "fact": _fattoriale}
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
    if isinstance(valore, float) and abs(valore - round(valore)) < 1e-12 and abs(valore) < 1e15:
        valore = int(round(valore))
    if isinstance(valore, int):
        return f"{valore:,}".replace(",", ".")
    testo = f"{valore:.10g}"
    if "e" in testo:
        return testo.replace(".", ",")
    intero, _, decimali = testo.partition(".")
    segno = "-" if intero.startswith("-") else ""
    return segno + f"{abs(int(intero)):,}".replace(",", ".") + ("," + decimali if decimali else "")


def _fattoriali(testo: str) -> str:
    """«5!» e «(2+3)!» → fact(5), fact((2+3))."""
    while "!" in testo:
        i = testo.index("!")
        j = i - 1
        if j >= 0 and testo[j] == ")":
            livello = 0
            while j >= 0:
                livello += testo[j] == ")"
                livello -= testo[j] == "("
                if livello == 0:
                    break
                j -= 1
        else:
            while j >= 0 and (testo[j].isdigit() or testo[j] == "."):
                j -= 1
            j += 1
        if j < 0 or j >= i:
            raise ValueError
        testo = testo[:j] + "fact(" + testo[j:i] + ")" + testo[i + 1:]
    return testo


def calcola(espressione: str, radianti: bool = False) -> dict:
    testo = (espressione.replace("×", "*").replace("÷", "/").replace("−", "-").replace("^", "**")
             .replace("π", "pi").replace("√", "sqrt").replace(".", "").replace(",", "."))
    # «89,90 − 15%» toglie il 15% di 89,90 (come le calcolatrici); «1250 × 12%» moltiplica per 0,12
    m = re.fullmatch(r"(.+?)([+-])(\d+(?:\.\d+)?)%", testo)
    if m:
        testo = f"({m.group(1)}){m.group(2)}({m.group(1)})*{m.group(3)}/100"
    testo = re.sub(r"(\d+(?:\.\d+)?)%", r"(\1/100)", testo)
    if testo.endswith("%"):
        testo = f"({testo[:-1]})/100"
    _ANGOLO["radianti"] = bool(radianti)
    try:
        testo = _fattoriali(testo)
        return {"ok": True, "valore": formatta_numero(_valuta(ast.parse(testo, mode="eval")))}
    except ZeroDivisionError:
        return {"ok": False, "valore": T("Impossibile dividere per zero")}
    except (ValueError, SyntaxError, TypeError, OverflowError):
        return {"ok": False, "valore": T("Errore")}


def _file_storia() -> Path:
    return config_utente("calcolatrice.json")


def storia_calcoli() -> list:
    """Gli ultimi calcoli, raggruppati per giorno: [{giorno, calcoli: [{espressione, risultato}]}]."""
    gruppi, oggi = [], time.strftime("%Y-%m-%d")
    ieri = time.strftime("%Y-%m-%d", time.localtime(time.time() - 86400))
    for c in leggi_json(_file_storia(), []):
        g = time.strftime("%Y-%m-%d", time.localtime(c.get("quando", 0)))
        nome = T("Oggi") if g == oggi else (T("Ieri") if g == ieri else time.strftime("%d/%m/%Y", time.localtime(c.get("quando", 0))))
        if not gruppi or gruppi[-1]["giorno"] != nome:
            gruppi.append({"giorno": nome, "calcoli": []})
        gruppi[-1]["calcoli"].append({"espressione": c.get("espressione", ""), "risultato": c.get("risultato", "")})
    return gruppi


def aggiungi_calcolo(espressione: str, risultato: str) -> None:
    elenco = leggi_json(_file_storia(), [])
    elenco.insert(0, {"espressione": espressione, "risultato": risultato, "quando": time.time()})
    scrivi_json(_file_storia(), elenco[:200])


def cancella_storia() -> None:
    scrivi_json(_file_storia(), [])


# ── Converti: valute (cambi della BCE) e misure ─────────────────────────────
UNITA = {
    "lunghezza": {"mm": 0.001, "cm": 0.01, "m": 1, "km": 1000, "in": 0.0254, "ft": 0.3048, "yd": 0.9144, "mi": 1609.344},
    "peso": {"mg": 0.000001, "g": 0.001, "kg": 1, "t": 1000, "oz": 0.028349523125, "lb": 0.45359237},
    "volume": {"ml": 0.001, "cl": 0.01, "l": 1, "m³": 1000, "gal": 3.785411784, "tazza": 0.2365882365},
    "velocita": {"km/h": 1, "m/s": 3.6, "mph": 1.609344, "nodi": 1.852},
    "area": {"m²": 1, "km²": 1e6, "ha": 10000, "ft²": 0.09290304, "acri": 4046.8564224},
    "temperatura": {"°C": None, "°F": None, "K": None},
}
NOMI_VALUTE = {"EUR": "Euro", "USD": "Dollaro USA", "GBP": "Sterlina", "CHF": "Franco svizzero", "JPY": "Yen",
               "CNY": "Yuan", "CAD": "Dollaro canadese", "AUD": "Dollaro australiano", "SEK": "Corona svedese",
               "NOK": "Corona norvegese", "DKK": "Corona danese", "PLN": "Zloty", "CZK": "Corona ceca",
               "HUF": "Fiorino", "RON": "Leu", "TRY": "Lira turca", "BRL": "Real", "INR": "Rupia indiana",
               "MXN": "Peso messicano", "KRW": "Won"}


def _cambi() -> dict:
    """Cambi dell'euro della Banca Centrale Europea (aggiornati ogni giorno lavorativo).
    Si tengono in memoria: senza rete si usano gli ultimi scaricati."""
    cache = Path.home() / ".cache" / "solidos" / "cambi.json"
    dati = leggi_json(cache, {})
    if DEMO and not dati:
        dati = {"data": time.strftime("%Y-%m-%d"), "scaricati": time.time(),
                "cambi": {"USD": 1.083, "GBP": 0.856, "CHF": 0.951, "JPY": 162.4, "CNY": 7.82}}
    if time.time() - dati.get("scaricati", 0) > 6 * 3600 and not DEMO:
        try:
            with urllib.request.urlopen("https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml", timeout=8) as r:
                xml = r.read().decode()
            cambi = {m.group(1): float(m.group(2)) for m in re.finditer(r"currency='(\w+)' rate='([\d.]+)'", xml)}
            giorno = re.search(r"time='([\d-]+)'", xml)
            if cambi:
                dati = {"data": giorno.group(1) if giorno else "", "scaricati": time.time(), "cambi": cambi}
                cache.parent.mkdir(parents=True, exist_ok=True)
                scrivi_json(cache, dati)
        except (OSError, ValueError):
            pass
    return dati


def unita_conversione(categoria: str) -> list:
    if categoria == "valuta":
        c = _cambi().get("cambi", {})
        codici = ["EUR"] + [k for k in NOMI_VALUTE if k in c] + sorted(k for k in c if k not in NOMI_VALUTE)
        return [{"id": k, "nome": NOMI_VALUTE.get(k, k)} for k in codici]
    return [{"id": k, "nome": k} for k in UNITA.get(categoria, {})]


def converti(categoria: str, da: str, a: str, espressione: str) -> dict:
    v = calcola(espressione or "0")
    if not v["ok"]:
        return {"ok": False, "valore": "", "nota": ""}
    numero = float(v["valore"].replace(".", "").replace(",", "."))
    nota = ""
    if categoria == "valuta":
        dati = _cambi()
        c = {"EUR": 1.0, **dati.get("cambi", {})}
        if da not in c or a not in c:
            return {"ok": False, "valore": "", "nota": T("Cambi non disponibili: collegati a Internet una volta")}
        risultato = numero / c[da] * c[a]
        if dati.get("data"):
            g = dati["data"].split("-")
            nota = T("Cambio della Banca Centrale Europea del {d}", d=f"{g[2]}/{g[1]}/{g[0]}" if len(g) == 3 else dati["data"])
    elif categoria == "temperatura":
        c = {"°C": numero, "°F": (numero - 32) * 5 / 9, "K": numero - 273.15}[da]
        risultato = {"°C": c, "°F": c * 9 / 5 + 32, "K": c + 273.15}[a]
    else:
        u = UNITA.get(categoria, {})
        if da not in u or a not in u:
            return {"ok": False, "valore": "", "nota": ""}
        risultato = numero * u[da] / u[a]
    if categoria == "valuta":
        risultato = round(risultato, 2)
    return {"ok": True, "valore": formatta_numero(risultato), "nota": nota}


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


def elenco_file(percorso: str, nascosti: bool = False, ordine: str = "nome") -> dict:
    p = Path(percorso or Path.home()).expanduser()
    if not p.is_dir():
        p = Path.home()
    try:
        figli = list(p.iterdir())
    except OSError:
        figli = []
    tag = _tag_file()
    voci = [v for v in (_voce(f, tag) for f in figli if nascosti or not f.name.startswith(".")) if v]
    if ordine == "data":
        voci.sort(key=lambda v: -v["mtime"])
    elif ordine == "dimensione":
        voci.sort(key=lambda v: -v["byte"])
    else:
        voci.sort(key=lambda v: (v["tipo"] != "cartella", v["nome"].lower()))
    casa = Path.home()
    titolo = T("Su questo telefono") if p == casa else (T("Cestino") if p == _cestino() / "files" else p.name)
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


# ── Meteo (Open-Meteo: gratuito, senza account né chiave) ──────────────────
_CODICI_METEO = {0: ("Sereno", "sole"), 1: ("Poco nuvoloso", "sole"), 2: ("Parzialmente nuvoloso", "nuvola"), 3: ("Nuvoloso", "nuvola"),
                 45: ("Nebbia", "nuvola"), 48: ("Nebbia", "nuvola"), 51: ("Pioviggine", "pioggia"), 53: ("Pioviggine", "pioggia"),
                 55: ("Pioviggine", "pioggia"), 61: ("Pioggia", "pioggia"), 63: ("Pioggia", "pioggia"), 65: ("Pioggia forte", "pioggia"),
                 71: ("Neve", "neve"), 73: ("Neve", "neve"), 75: ("Neve forte", "neve"), 80: ("Rovesci", "pioggia"),
                 81: ("Rovesci", "pioggia"), 82: ("Rovesci forti", "pioggia"), 95: ("Temporale", "temporale"),
                 96: ("Temporale", "temporale"), 99: ("Temporale", "temporale")}


def _json_url(url: str, timeout: float = 8):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "SolidOS-Meteo"}), timeout=timeout) as r:
        return json.loads(r.read().decode())


def meteo(citta: str = "") -> dict:
    """Tempo di adesso e delle prossime ore. Città scelta in Impostazioni o posizione del telefono."""
    if DEMO:
        return {"ok": True, "citta": citta or "Napoli", "gradi": 18, "max": 21, "min": 12, "descrizione": "Soleggiato", "icona": "sole",
                "ore": [{"ora": h, "gradi": g, "icona": i} for h, g, i in (("Ora", 18, "sole"), ("15", 19, "sole"), ("16", 19, "nuvola"), ("17", 17, "nuvola"), ("18", 15, "nuvola"))]}
    cache = Path.home() / ".cache" / "solidos" / "meteo.json"
    dati = leggi_json(cache, {})
    if dati.get("citta_chiesta") == citta and time.time() - dati.get("quando", 0) < 1800:
        return dati["meteo"]
    try:
        if citta:
            g = _json_url("https://geocoding-api.open-meteo.com/v1/search?count=1&language=it&name=" + urllib.parse.quote(citta))
            luogo = (g.get("results") or [None])[0]
            if not luogo:
                return {"ok": False, "messaggio": T("Città non trovata")}
            lat, lon, nome = luogo["latitude"], luogo["longitude"], luogo["name"]
        else:
            try:
                from ..solidid import posizione

                p = posizione.trova() or {}
            except Exception:  # noqa: BLE001
                p = {}
            if not p.get("lat"):
                return {"ok": False, "messaggio": T("Tocca per scegliere la città")}
            lat, lon, nome = p["lat"], p["lon"], p.get("luogo") or T("Qui")
        m = _json_url(f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,weather_code"
                      "&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&forecast_days=2&timezone=auto")
    except (OSError, ValueError, KeyError):
        return dati.get("meteo") or {"ok": False, "messaggio": T("Meteo non disponibile senza rete")}
    codice = m["current"]["weather_code"]
    descrizione, icona = _CODICI_METEO.get(codice, ("", "nuvola"))
    adesso = m["current"]["time"][:13]
    ore = []
    tempi = m["hourly"]["time"]
    inizio = next((i for i, t in enumerate(tempi) if t[:13] >= adesso), 0)
    for i in range(inizio, min(inizio + 5, len(tempi))):
        ore.append({"ora": T("Ora") if i == inizio else tempi[i][11:13], "gradi": round(m["hourly"]["temperature_2m"][i]),
                    "icona": _CODICI_METEO.get(m["hourly"]["weather_code"][i], ("", "nuvola"))[1]})
    risultato = {"ok": True, "citta": nome, "gradi": round(m["current"]["temperature_2m"]), "descrizione": T(descrizione), "icona": icona,
                 "max": round(m["daily"]["temperature_2m_max"][0]), "min": round(m["daily"]["temperature_2m_min"][0]), "ore": ore}
    cache.parent.mkdir(parents=True, exist_ok=True)
    scrivi_json(cache, {"citta_chiesta": citta, "quando": time.time(), "meteo": risultato})
    return risultato


# ── File (come l'app File dell'iPhone): Sfoglia, Recenti, Condivisi, tag ─────
TAG = [{"id": "rosso", "nome": "Importante", "colore": "#E5484D"}, {"id": "blu", "nome": "Lavoro", "colore": "#4C7DFF"},
       {"id": "verde", "nome": "Famiglia", "colore": "#30A46C"}, {"id": "giallo", "nome": "Da fare", "colore": "#F59E0B"}]
_CARTELLE_UTENTE = (("DOCUMENTS", "Documenti"), ("DOWNLOAD", "Scaricati"), ("PICTURES", "Immagini"), ("MUSIC", "Musica"),
                    ("VIDEOS", "Video"), ("DESKTOP", "Scrivania"))
_MESI = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]


def _quando(t: float) -> str:
    lt, oggi = time.localtime(t), time.localtime()
    if lt[:3] == oggi[:3]:
        return time.strftime("%H:%M", lt)
    return f"{lt.tm_mday} {_MESI[lt.tm_mon - 1]}" + (f" {lt.tm_year}" if lt.tm_year != oggi.tm_year else "")


def _tag_file() -> dict:
    return leggi_json(config_utente("file-tag.json"), {})


def _voce(f: Path, tag: dict | None = None) -> dict | None:
    try:
        st = f.stat()
    except OSError:
        return None
    tipo = _tipo(f)
    tag = _tag_file() if tag is None else tag
    if tipo == "cartella":
        try:
            info = T("{n} elementi", n=sum(1 for x in f.iterdir() if not x.name.startswith(".")))
        except OSError:
            info = ""
    else:
        info = _dimensione(st.st_size)
    return {"nome": f.name, "percorso": str(f), "tipo": tipo, "icona": ICONE_TIPO[tipo], "est": f.suffix.lower().lstrip("."),
            "uri": _uri(f) if tipo == "immagine" else "", "quando": _quando(st.st_mtime), "mtime": st.st_mtime,
            "byte": st.st_size if tipo != "cartella" else 0, "info": info, "tag": tag.get(str(f), [])}


def _demo_file_ricchi() -> None:
    casa = Path.home()
    _demo_file()
    doc = casa / "Documenti"
    for nome, giorni in (("Contratto affitto.pdf", 7), ("Preventivo.docx", 9), ("Bilancio 2026.xlsx", 10),
                         ("Presentazione.pptx", 18)):
        f = doc / nome
        if not f.exists():
            f.write_bytes(b"0" * (2000 + len(nome) * 4000))
            os.utime(f, (time.time() - giorni * 86400, time.time() - giorni * 86400))
    for cartella in ("Ricevute", "Musica"):
        (doc / cartella).mkdir(exist_ok=True)
    (doc / "Ricevute" / "scontrino.txt").write_text("Spesa 23,40 €\n")
    scrivi_json(config_utente("file-tag.json"), {str(doc / "Contratto affitto.pdf"): ["rosso"], str(doc / "Preventivo.docx"): ["blu"]})


def file_sfoglia() -> dict:
    """Posizioni (telefono, microSD, server di casa, Nextcloud, PC), preferiti e tag."""
    if DEMO:
        _demo_file_ricchi()
    casa = Path.home()
    try:
        libero = shutil.disk_usage(casa).free
        spazio = T("{n} liberi", n=_dimensione(libero).replace(",0 ", " "))
    except OSError:
        spazio = ""
    posizioni = [{"id": "telefono", "nome": T("Su questo telefono"), "info": spazio, "colore": "#4C7DFF", "icona": "linea-smartphone",
                  "percorso": str(casa)}]
    for m in [m for m in Path("/media").glob("*/*") if m.is_dir()] + [m for m in Path("/run/media").glob("*/*") if m.is_dir()]:
        posizioni.append({"id": "sd", "nome": m.name, "info": T("Scheda di memoria"), "colore": "#71717A", "icona": "linea-chiavetta", "percorso": str(m)})
    from . import fotoaccount

    for a in fotoaccount.servizi():
        if a["id"] in ("casa", "nextcloud") and a["stato"] == "collegato":
            acc = a.get("account", {})
            posizioni.append({"id": a["id"], "nome": a["nome"], "remoto": a["id"], "colore": a["colore"],
                              "icona": "linea-casa" if a["id"] == "casa" else "linea-nuvola",
                              "info": (acc.get("indirizzo") or "").replace("http://", "").replace("https://", "")})
    if DEMO and not any(p["id"] == "casa" for p in posizioni):
        posizioni.append({"id": "casa", "nome": T("Server di casa"), "remoto": "casa", "colore": "#30A46C", "icona": "linea-casa", "info": "NAS · 192.168.1.40"})
    for d in vicina_stato().get("dispositivi", []):
        if d.get("tipo") == "computer":
            posizioni.append({"id": "pc", "nome": d.get("nome", T("PC")), "info": T("Vicina · acceso"), "colore": "#8B5CF6",
                              "icona": "linea-portatile", "vicina": d.get("id", "")})
    posizioni.append({"id": "cestino", "nome": T("Cestino"), "info": "", "colore": "#71717A", "icona": "user-trash-symbolic",
                      "percorso": str(_cestino() / "files")})
    preferiti = []
    for tipo, nome, icona in (("DOCUMENTS", "Documenti", "linea-documento"), ("DOWNLOAD", "Scaricati", "linea-scarica"), ("PICTURES", "Immagini", "linea-foto"),
                              ("MUSIC", "Musica", "linea-musica"), ("VIDEOS", "Video", "linea-video")):
        p = cartella_utente(tipo, nome)
        if p.is_dir():
            preferiti.append({"nome": T(nome), "percorso": str(p), "icona": icona})
    conti = {}
    for etichette in _tag_file().values():
        for t in etichette:
            conti[t] = conti.get(t, 0) + 1
    return {"posizioni": posizioni, "preferiti": preferiti, "tag": [dict(t, nome=T(t["nome"]), n=conti.get(t["id"], 0)) for t in TAG]}


def _tutti_i_file(limite: int = 4000):
    """I file delle cartelle dell'utente (fino a 4 livelli), senza nascosti."""
    visti = 0
    for tipo, nome in _CARTELLE_UTENTE:
        radice = cartella_utente(tipo, nome)
        if not radice.is_dir():
            continue
        for cartella, sotto, file in os.walk(radice):
            sotto[:] = [d for d in sotto if not d.startswith(".")]
            if len(Path(cartella).relative_to(radice).parts) > 4:
                sotto[:] = []
            for f in file:
                if not f.startswith("."):
                    yield Path(cartella) / f
                    visti += 1
                    if visti >= limite:
                        return


def file_recenti(filtro: str = "") -> list:
    """I file modificati di recente (Tutti, Documenti, Immagini, Scaricati)."""
    if DEMO:
        _demo_file_ricchi()
    tag = _tag_file()
    scaricati = cartella_utente("DOWNLOAD", "Scaricati")
    voci = []
    for f in _tutti_i_file():
        t = _tipo(f)
        if filtro == "immagini" and t != "immagine":
            continue
        if filtro == "documenti" and t not in ("pdf", "testo", "file"):
            continue
        if filtro == "scaricati" and scaricati not in f.parents:
            continue
        v = _voce(f, tag)
        if v:
            voci.append(v)
    voci.sort(key=lambda v: -v["mtime"])
    return voci[:60]


def file_condivisi() -> list:
    """I file ricevuti con Vicina (dal PC o da altri telefoni)."""
    cartella = Path(vicina_stato().get("cartella") or cartella_utente("DOWNLOAD", "Scaricati"))
    if not cartella.is_dir():
        return []
    tag = _tag_file()
    voci = [v for v in (_voce(f, tag) for f in cartella.iterdir() if not f.name.startswith(".")) if v]
    voci.sort(key=lambda v: -v["mtime"])
    return voci


def file_cerca(testo: str) -> list:
    testo = testo.strip().lower()
    if len(testo) < 2:
        return []
    tag = _tag_file()
    return [v for v in (_voce(f, tag) for f in _tutti_i_file() if testo in f.name.lower()) if v][:80]


def file_con_tag(ident: str) -> list:
    tag = _tag_file()
    return [v for v in (_voce(Path(p), tag) for p, t in tag.items() if ident in t and Path(p).exists()) if v]


def file_imposta_tag(percorso: str, ident: str, si: bool) -> None:
    tag = _tag_file()
    etichette = [t for t in tag.get(percorso, []) if t != ident] + ([ident] if si else [])
    if etichette:
        tag[percorso] = etichette
    else:
        tag.pop(percorso, None)
    scrivi_json(config_utente("file-tag.json"), tag)


def file_duplica(percorso: str) -> dict:
    p = Path(percorso)
    n, nuovo = 1, p
    while nuovo.exists():
        n += 1
        nuovo = p.with_name(f"{p.stem} ({n}){p.suffix}")
    try:
        shutil.copytree(p, nuovo) if p.is_dir() else shutil.copy2(p, nuovo)
        return {"ok": True, "messaggio": T("Duplicato")}
    except OSError as e:
        return {"ok": False, "messaggio": str(e)}


def file_comprimi(percorso: str) -> dict:
    p = Path(percorso)
    dest = p.with_suffix(".zip") if p.is_file() else p.parent / (p.name + ".zip")
    n = 1
    while dest.exists():
        n += 1
        dest = dest.with_name(f"{p.stem} ({n}).zip")
    try:
        shutil.make_archive(str(dest.with_suffix("")), "zip", root_dir=p.parent, base_dir=p.name)
        return {"ok": True, "messaggio": T("Creato {n}", n=dest.name)}
    except OSError as e:
        return {"ok": False, "messaggio": str(e)}


def file_sposta(percorso: str, cartella: str) -> dict:
    p, dest = Path(percorso), Path(cartella) / Path(percorso).name
    if dest.exists():
        return {"ok": False, "messaggio": T("Lì c'è già un file con questo nome")}
    try:
        shutil.move(str(p), str(dest))
        return {"ok": True, "messaggio": T("Spostato in {c}", c=Path(cartella).name)}
    except OSError as e:
        return {"ok": False, "messaggio": str(e)}


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
    import colorsys

    # Quattro giorni di foto di prova (8 oggi, 8 ieri alle 18:42, 4 e 4 nei giorni prima)
    giorni = [(0, 8, None), (1, 8, (18, 42)), (4, 4, (11, 5)), (5, 4, (16, 20))]
    n = 0
    for indietro, quante, ora in giorni:
        base = time.localtime(time.time() - indietro * 86400)
        for k in range(quante):
            h = (n * 0.137 + 0.08) % 1
            a = tuple(int(v * 255) for v in colorsys.hsv_to_rgb(h, 0.65, 0.85))
            b = tuple(int(v * 255) for v in colorsys.hsv_to_rgb((h + 0.18) % 1, 0.7, 0.75))
            f = c / f"IMG_{time.strftime('%Y%m%d', base)}_{n:04d}.png"
            _png(f, 240, 240, a, b)
            if ora:
                t = time.mktime(base[:3] + (ora[0], ora[1] - k, 0) + base[6:])
            else:
                t = time.time() - 600 - k * 900
            os.utime(f, (t, t))
            n += 1


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
        elenco.sort(key=lambda x: -x["quando"])
        for i, x in enumerate(elenco):
            if i in (2, 5, 14):
                x["fonte"] = "google"
            elif i in (8, 11):
                x["fonte"], x["dove"] = "onedrive", "Immagini/2026"
            elif i == 17:
                x["fonte"] = "nextcloud"
            if 8 <= i < 16:
                x["luogo"] = "Napoli"
    elenco.sort(key=lambda x: -x["quando"])
    preferite = set(leggi_json(config_utente("foto-preferite.json"), []))
    for x in elenco:
        x["preferita"] = x["percorso"] in preferite
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


def foto_preferita(percorso: str, si: bool) -> None:
    f = config_utente("foto-preferite.json")
    elenco = [p for p in leggi_json(f, []) if p != percorso]
    if si:
        elenco.append(percorso)
    scrivi_json(f, elenco[-5000:])


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
# Consigliate per il telefono: tutte segnate da Flathub come adatte al telefono
CONSIGLIATE = [
    ("org.gnome.Epiphany", "Web", "Navigare sul web"),
    ("org.gnome.Maps", "Mappe", "Mappe e indicazioni"),
    ("org.gnome.Weather", "Meteo", "Previsioni del tempo"),
    ("org.gnome.Podcasts", "Podcast", "Ascolta i podcast"),
    ("io.github.mrvladus.List", "Errands", "Promemoria e attività"),
    ("org.gnome.Fractal", "Fractal", "Chat Matrix"),
    ("dev.geopjr.Tuba", "Tuba", "Mastodon e social"),
    ("io.bassi.Amberol", "Amberol", "Musica"),
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


def store_cerca(testo: str, solo_telefono: bool = True) -> list:
    """Cerca su Flathub. Sul telefono di solito solo le app adatte al telefono (Flathub le segna
    «mobile friendly»: si adattano allo schermo piccolo e al tocco); le altre, se si chiedono,
    portano l'etichetta «Per computer»."""
    testo = testo.strip()
    if not testo:
        return []
    installate = _installate_flatpak()
    if DEMO:
        return [a for a in store_consigliate()["app"] if testo.lower() in (a["nome"] + a["descrizione"]).lower()]
    filtri = [{"filterType": "isMobileFriendly", "value": "true"}] if solo_telefono else []
    try:
        richiesta = urllib.request.Request(
            "https://flathub.org/api/v2/search", data=json.dumps({"query": testo, "filters": filtri}).encode(),
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
                          "icona": h.get("icon") or _icona_flathub(ident), "installata": ident in installate,
                          "telefono": bool(h.get("isMobileFriendly"))})
    return risultati


def adatta_al_telefono(ident: str) -> bool | None:
    """Flathub dice se l'app è adatta al telefono? (None se non si sa, es. senza rete)."""
    try:
        richiesta = urllib.request.Request(
            "https://flathub.org/api/v2/search", data=json.dumps({"query": ident}).encode(),
            headers={"Content-Type": "application/json", "User-Agent": f"{branding.nome()}-Mobile/{branding.get('OS_VERSION', '0')}"})
        with urllib.request.urlopen(richiesta, timeout=10) as r:
            hit = next((h for h in json.load(r).get("hits", []) if h.get("app_id") == ident), None)
    except (OSError, ValueError):
        return None
    return bool(hit.get("isMobileFriendly")) if hit else None


def store_installa(ident: str, avanzamento=None) -> dict:
    """Installa da Flathub; avanzamento(percento, fase) riceve la percentuale per la barra."""
    from .. import appmie

    if DEMO:   # nella prova: uno scaricamento finto di 3 secondi
        for p in range(0, 101, 5):
            if avanzamento:
                avanzamento(p, T("Scaricamento") if p < 100 else T("Installazione"))
            time.sleep(0.15)
        return {"ok": True, "messaggio": T("Installata")}
    if not shutil.which("flatpak"):
        return {"ok": False, "messaggio": T("Flatpak non è installato")}
    if not all(c.isalnum() or c in "._-" for c in ident):
        return {"ok": False, "messaggio": T("App non valida")}
    subprocess.run(["flatpak", "--user", "remote-add", "--if-not-exists", "flathub", _RIMOTO],
                   capture_output=True, timeout=120)
    codice, uscita = appmie.flatpak_installa(ident, avanzamento)
    if codice == 0:
        return {"ok": True, "messaggio": T("Installata")}
    righe = [r.strip() for r in uscita.replace("\r", "\n").splitlines() if r.strip()]
    errore = next((r for r in reversed(righe) if "error" in r.lower() or "errore" in r.lower()), righe[-1] if righe else "")
    if "no remote refs" in errore.lower() or "nothing matches" in errore.lower():
        errore = T("Questa app non c'è per il processore del telefono")
    return {"ok": False, "messaggio": errore[-160:] or T("Non riuscito")}


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
