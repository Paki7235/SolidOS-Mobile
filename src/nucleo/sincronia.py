"""Sincronia dei dati tra i dispositivi dello stesso Solid ID (come iCloud).

Contatti, calendari ed eventi, liste e promemoria, note: ogni voce (con il suo «id») è una riga
della tabella «sincronia» del Solid ID, visibile solo al proprietario. A ogni giro:
1. si scaricano le voci cambiate altrove dall'ultimo giro e si scrivono qui;
2. si caricano le voci cambiate qui (confrontando l'impronta con quella dell'ultimo giro) e
   quelle tolte qui (diventano «eliminato»).
Se la stessa voce cambia su due dispositivi tra un giro e l'altro vince l'ultima arrivata.
Le password restano fuori: la cassaforte è cifrata e si unisce solo aperta (prossimo passo).
Lo stesso file c'è su PC e telefono; il telefono salva le note in un formato più semplice
(solo testo) e le converte da e verso quello del PC.
"""
from __future__ import annotations

import hashlib
import html
import json
import os
import re
import time
from pathlib import Path

from . import branding
from .sistema import config_utente, leggi_json, scrivi_json

TABELLA = "sincronia"


def _dati() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / branding.id_os()


def _impronta(x) -> str:
    return hashlib.sha1(json.dumps(x, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


# ── Raccolte: un file con un elenco di voci ─────────────────────────────────
class Elenco:
    def __init__(self, nome: str, file: Path):
        self.nome, self.file = nome, file

    def leggi(self) -> dict:
        try:
            voci = json.loads(self.file.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}
        return {str(v["id"]): v for v in voci if isinstance(v, dict) and v.get("id")} if isinstance(voci, list) else {}

    def scrivi(self, voci: dict) -> None:
        # l'ordine di prima resta, le nuove in fondo
        try:
            vecchie = json.loads(self.file.read_text(encoding="utf-8"))
            ordine = [str(v.get("id")) for v in vecchie if isinstance(v, dict)]
        except (OSError, ValueError):
            ordine = []
        chiavi = [k for k in ordine if k in voci] + [k for k in voci if k not in ordine]
        self.file.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.file.with_suffix(".tmp")
        tmp.write_text(json.dumps([voci[k] for k in chiavi], ensure_ascii=False, indent=1), encoding="utf-8")
        tmp.replace(self.file)

    def locale(self, v: dict) -> dict:      # formato comune → formato di qui
        return v

    def comune(self, v: dict) -> dict:      # formato di qui → formato comune
        return v


# ── Raccolte: una cartella con un file per voce (le note) ───────────────────
class Cartella(Elenco):
    def leggi(self) -> dict:
        out = {}
        for f in self.file.glob("*.json") if self.file.is_dir() else []:
            try:
                v = json.loads(f.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if isinstance(v, dict):
                out[str(v.get("id") or f.stem)] = {**v, "id": str(v.get("id") or f.stem)}
        return out

    def scrivi(self, voci: dict) -> None:
        self.file.mkdir(parents=True, exist_ok=True)
        presenti = {f.stem for f in self.file.glob("*.json")}
        for k, v in voci.items():
            nome = Path(k).name
            tmp = self.file / f".{nome}.tmp"
            tmp.write_text(json.dumps(v, ensure_ascii=False), encoding="utf-8")
            tmp.replace(self.file / f"{nome}.json")
        for k in presenti - {Path(x).name for x in voci}:
            (self.file / f"{k}.json").unlink(missing_ok=True)


def _testo(h: str) -> str:
    corpo = re.sub(r"(?is)<head.*?</head>", "", h or "")
    corpo = re.sub(r"(?i)<br\s*/?>|</p>|</h\d>|</li>|</div>", "\n", corpo)
    return html.unescape(re.sub(r"<[^>]+>", "", corpo)).replace(" ", "\n").strip()


class NoteTelefono(Cartella):
    """Il telefono scrive le note come testo semplice: si convertono da e verso l'HTML del PC."""

    def locale(self, v: dict) -> dict:
        return {"id": v["id"], "testo": _testo(v.get("html", "")), "fissata": bool(v.get("fissata")),
                "eliminata": bool(v.get("eliminata")), "modificata": v.get("modificata", time.time())}

    def comune(self, v: dict) -> dict:
        righe = (v.get("testo") or "").split("\n")
        corpo = "".join(f"<p>{html.escape(r) or '<br>'}</p>" for r in righe)
        return {"id": v["id"], "html": corpo, "fissata": bool(v.get("fissata")), "eliminata": bool(v.get("eliminata")),
                "modificata": v.get("modificata", time.time()), "cartella": v.get("cartella", "")}


def raccolte(telefono: bool | None = None) -> list[Elenco]:
    if telefono is None:
        telefono = os.environ.get("NUCLEO_TELEFONO") == "1"
    d = _dati()
    note = NoteTelefono("note", d / "note-telefono") if telefono else Cartella("note", d / "note")
    return [Elenco("contatti", d / "telefono" / "contatti.json"),
            Elenco("calendari", d / "agenda" / "calendari.json"),
            Elenco("eventi", d / "agenda" / "eventi.json"),
            Elenco("liste", d / "agenda" / "liste.json"),
            Elenco("promemoria", d / "agenda" / "promemoria.json"),
            note]


# ── Il giro di sincronia ────────────────────────────────────────────────────
def _stato_file() -> Path:
    return config_utente("sincronia.json")


def sincronizza(telefono: bool | None = None) -> dict:
    from . import solidid

    if not solidid.collegato():
        return {"ok": False, "messaggio": "Solid ID non collegato"}
    stato = leggi_json(_stato_file(), {})
    impronte: dict = stato.setdefault("impronte", {})
    dispositivo = solidid.sessione().get("dispositivo_id", "") or ""
    elenco = raccolte(telefono)
    per_nome = {r.nome: r for r in elenco}
    scaricate = caricate = 0

    # 1. Scarica quello che è cambiato altrove
    filtri = "select=raccolta,voce,dati,eliminato,modificato,dispositivo&order=modificato"
    if stato.get("ultimo"):
        from urllib.parse import quote

        filtri += f"&modificato=gt.{quote(stato['ultimo'])}"
    righe = solidid.rest("GET", TABELLA, filtri=filtri) or []
    cambiate: dict[str, dict] = {}
    for r in righe:
        racc = per_nome.get(r.get("raccolta"))
        if not racc:
            continue
        voci = cambiate.setdefault(racc.nome, racc.leggi())
        v = str(r["voce"])
        if r.get("eliminato"):
            voci.pop(v, None)
            impronte.setdefault(racc.nome, {}).pop(v, None)
        elif isinstance(r.get("dati"), dict):
            voci[v] = racc.locale({**r["dati"], "id": v})
        stato["ultimo"] = r.get("modificato") or stato.get("ultimo")
        scaricate += 1
    for nome, voci in cambiate.items():
        per_nome[nome].scrivi(voci)
        # l'impronta è quella di come la voce è scritta qui: così non torna indietro uguale
        rilette = per_nome[nome].leggi()
        for v in voci:
            if v in rilette:
                impronte.setdefault(nome, {})[v] = _impronta(per_nome[nome].comune(rilette[v]))

    # 2. Carica quello che è cambiato qui
    da_mandare = []
    for racc in elenco:
        voci = racc.leggi()
        note = impronte.setdefault(racc.nome, {})
        for v, dati in voci.items():
            comune = racc.comune(dati)
            h = _impronta(comune)
            if note.get(v) != h:
                da_mandare.append({"raccolta": racc.nome, "voce": v, "dati": comune, "eliminato": False, "dispositivo": dispositivo})
                note[v] = h
        for v in [x for x in note if x not in voci]:
            da_mandare.append({"raccolta": racc.nome, "voce": v, "dati": None, "eliminato": True, "dispositivo": dispositivo})
            note.pop(v, None)
    for i in range(0, len(da_mandare), 200):
        solidid.rest("POST", TABELLA, da_mandare[i:i + 200], filtri="on_conflict=proprietario,raccolta,voce",
                     rappresenta=False, extra={"Prefer": "resolution=merge-duplicates,return=minimal"})
        caricate += len(da_mandare[i:i + 200])
    stato["quando"] = time.time()
    scrivi_json(_stato_file(), stato)
    return {"ok": True, "scaricate": scaricate, "caricate": caricate}


def ultima() -> float:
    return float(leggi_json(_stato_file(), {}).get("quando", 0))
