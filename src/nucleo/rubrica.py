"""Rubrica comune a PC e telefono (app Contatti).

Stesso archivio e stesse funzioni dei Contatti di SolidOS Mobile:
~/.local/share/<os>/telefono/contatti.json e mia-scheda.json, schede con nome, azienda,
tre numeri, due email, indirizzo, compleanno, sito, social e note, preferiti, importazione
ed esportazione vCard (.vcf: il formato standard dei contatti di telefoni e programmi di posta).
"""

from __future__ import annotations

import json
import os
import re
import threading
import uuid
from pathlib import Path

from . import branding
from .i18n import T

_blocco = threading.Lock()


# ── Archivio locale ──────────────────────────────────────────────────────────
def _cartella() -> Path:
    base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / branding.id_os() / "telefono"
    base.mkdir(parents=True, exist_ok=True)
    return base


def _leggi(nome: str, predefinito):
    try:
        return json.loads((_cartella() / nome).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return predefinito


def _scrivi(nome: str, dati) -> None:
    f = _cartella() / nome
    tmp = f.with_suffix(".tmp")
    tmp.write_text(json.dumps(dati, ensure_ascii=False), encoding="utf-8")
    tmp.replace(f)


def normalizza(numero: str) -> str:
    """Numero confrontabile: solo cifre e «+»; i numeri italiani senza prefisso ricevono +39."""
    n = re.sub(r"[^\d+*#]", "", numero or "")
    if n.startswith("00"):
        n = "+" + n[2:]
    if n and not n.startswith("+") and len(n) >= 9 and n[0] in "03":
        n = "+39" + n
    return n


def _uguali(a: str, b: str) -> bool:
    a, b = normalizza(a), normalizza(b)
    return bool(a) and (a == b or a[-9:] == b[-9:])


# ── ModemManager ─────────────────────────────────────────────────────────────
def contatti() -> list[dict]:
    elenco = _leggi("contatti.json", [])
    return sorted(elenco, key=lambda c: c.get("nome", "").lower())


def salva_contatto(nome: str, numero: str, ident: str = "", email: str = "", note: str = "") -> dict:
    nome, numero, email = nome.strip(), numero.strip(), email.strip()
    if not nome or not normalizza(numero):
        return {"ok": False, "messaggio": T("Scrivi nome e numero")}
    with _blocco:
        elenco = _leggi("contatti.json", [])
        voce = next((c for c in elenco if c["id"] == ident), None)
        if voce:
            voce.update(nome=nome, numero=numero, email=email, note=note.strip())
        else:
            voce = {"id": uuid.uuid4().hex[:10], "nome": nome, "numero": numero, "email": email,
                    "note": note.strip(), "preferito": False}
            elenco.append(voce)
        _scrivi("contatti.json", elenco)
    return {"ok": True, "messaggio": T("Contatto salvato"), "id": voce["id"]}


# Campi della scheda. «nome» è nome e cognome insieme.
CAMPI = ("nome", "azienda", "numero", "numero2", "numero3", "email", "email2", "indirizzo",
         "compleanno", "sito", "social", "note")


def _pulisci(dati: dict) -> dict:
    return {k: str(dati.get(k) or "").strip() for k in CAMPI}


def mia_scheda() -> dict:
    """La scheda del proprietario del telefono (id «io»): il nome viene dal Solid ID se manca."""
    scheda = _leggi("mia-scheda.json", {})
    if not scheda.get("nome"):
        try:
            from . import solidid

            u = solidid.utente() or {}
            scheda["nome"] = u.get("nome", "")
            scheda.setdefault("email", u.get("email", ""))
        except Exception:  # noqa: BLE001
            pass
    return {**{k: "" for k in CAMPI}, **scheda, "id": "io", "preferito": False}


def salva_scheda(dati: dict) -> dict:
    """Salva un contatto con tutti i campi (o «La mia scheda», id «io»)."""
    dati = dict(dati or {})
    ident = str(dati.get("id") or "")
    campi = _pulisci(dati)
    if ident == "io":
        if not campi["nome"]:
            return {"ok": False, "messaggio": T("Scrivi il tuo nome")}
        with _blocco:
            _scrivi("mia-scheda.json", campi)
        return {"ok": True, "messaggio": T("La tua scheda è salvata"), "id": "io"}
    if not campi["nome"] or not any(normalizza(campi[k]) for k in ("numero", "numero2", "numero3")):
        return {"ok": False, "messaggio": T("Scrivi il nome e almeno un numero")}
    if not normalizza(campi["numero"]):   # il primo numero scritto diventa il principale
        for k in ("numero2", "numero3"):
            if normalizza(campi[k]):
                campi["numero"], campi[k] = campi[k], ""
                break
    with _blocco:
        elenco = _leggi("contatti.json", [])
        voce = next((c for c in elenco if c["id"] == ident), None)
        if voce:
            voce.update(campi)
        else:
            voce = {"id": uuid.uuid4().hex[:10], **campi, "preferito": False}
            elenco.append(voce)
        _scrivi("contatti.json", elenco)
    return {"ok": True, "messaggio": T("Contatto salvato"), "id": voce["id"]}


# ── vCard (.vcf): il formato standard dei contatti ──
def _valore_vcard(riga: str) -> str:
    valore = riga.split(":", 1)[1] if ":" in riga else ""
    return valore.replace("\\,", ",").replace("\\;", ";").replace("\\n", " ").strip()


def importa_vcard(percorso: str) -> dict:
    """Importa tutti i contatti di un file .vcf (anche con molti contatti dentro)."""
    try:
        testo = Path(percorso.removeprefix("file://")).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {"ok": False, "messaggio": T("Impossibile leggere il file")}
    # righe spezzate (continuano con uno spazio all'inizio) riunite
    testo = re.sub(r"\r?\n[ \t]", "", testo)
    nuovi = 0
    with _blocco:
        elenco = _leggi("contatti.json", [])
        for blocco in re.findall(r"BEGIN:VCARD(.*?)END:VCARD", testo, re.S | re.I):
            nome = numero = email = ""
            for riga in blocco.splitlines():
                chiave = riga.split(":", 1)[0].upper()
                if chiave.startswith("FN"):
                    nome = _valore_vcard(riga)
                elif chiave.startswith("N") and not nome and not chiave.startswith("NOTE") and not chiave.startswith("NICK"):
                    parti = _valore_vcard(riga).split(";")
                    nome = " ".join(x for x in (parti[1] if len(parti) > 1 else "", parti[0]) if x)
                elif chiave.startswith("TEL") and not numero:
                    numero = _valore_vcard(riga).removeprefix("tel:")
                elif chiave.startswith("EMAIL") and not email:
                    email = _valore_vcard(riga)
            if not nome or not normalizza(numero) or any(_uguali(c["numero"], numero) for c in elenco):
                continue
            elenco.append({"id": uuid.uuid4().hex[:10], "nome": nome, "numero": numero, "email": email,
                           "note": "", "preferito": False})
            nuovi += 1
        _scrivi("contatti.json", elenco)
    return {"ok": True, "messaggio": T("{n} contatti importati", n=nuovi) if nuovi != 1 else T("1 contatto importato")}


def cerca_vcard() -> list[dict]:
    """File .vcf in Scaricati, Documenti e nella cartella personale (per «Importa»)."""
    from .sistema import cartella_utente

    trovati = []
    for cartella in (cartella_utente("DOWNLOAD", "Scaricati"), cartella_utente("DOCUMENTS", "Documenti"), Path.home()):
        try:
            for f in sorted(Path(cartella).glob("*.vcf")):
                trovati.append({"percorso": str(f), "nome": f.name, "cartella": Path(cartella).name})
        except OSError:
            continue
    return trovati[:30]


def esporta_vcard() -> dict:
    from .sistema import cartella_utente

    cartella = cartella_utente("DOCUMENTS", "Documenti")
    cartella.mkdir(parents=True, exist_ok=True)
    f = cartella / "contatti.vcf"
    righe = []
    for c in contatti():
        sicuro = lambda x: (x or "").replace(",", "\\,").replace(";", "\\;")
        righe += ["BEGIN:VCARD", "VERSION:3.0", f"FN:{sicuro(c['nome'])}", f"N:;{sicuro(c['nome'])};;;",
                  f"TEL;TYPE=CELL:{c['numero']}"]
        for chiave, riga in (("numero2", "TEL;TYPE=HOME:"), ("numero3", "TEL;TYPE=WORK:"), ("email", "EMAIL:"),
                             ("email2", "EMAIL;TYPE=WORK:"), ("azienda", "ORG:"), ("indirizzo", "ADR;TYPE=HOME:;;"),
                             ("sito", "URL:"), ("note", "NOTE:")):
            if c.get(chiave):
                righe.append(riga + sicuro(c[chiave]))
        righe.append("END:VCARD")
    f.write_text("\r\n".join(righe) + "\r\n", encoding="utf-8")
    return {"ok": True, "messaggio": T("Contatti salvati in {f}", f=f"{cartella.name}/contatti.vcf")}


def preferito(ident: str, si: bool) -> None:
    with _blocco:
        elenco = _leggi("contatti.json", [])
        for c in elenco:
            if c["id"] == ident:
                c["preferito"] = bool(si)
        _scrivi("contatti.json", elenco)


def elimina_contatto(ident: str) -> None:
    with _blocco:
        elenco = [c for c in _leggi("contatti.json", []) if c["id"] != ident]
        _scrivi("contatti.json", elenco)


def nome_di(numero: str) -> str:
    return next((c["nome"] for c in contatti() if _uguali(c["numero"], numero)), "")
