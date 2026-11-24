"""Agenda di SolidOS (PC e telefono): Calendario e Promemoria.

Dati in ~/.local/share/<os>/agenda/ (calendari, eventi, liste e promemoria, in JSON).
- Eventi: titolo, inizio e fine (o tutto il giorno), luogo, note, ripetizione (ogni giorno,
  settimana, mese, anno), avviso qualche minuto prima, calendario (con il suo colore).
- Promemoria: liste colorate, scadenza (giorno o giorno e ora), bandiera, completati.
- File .ics (il formato standard dei calendari): importa ed esporta.
Gli avvisi li dà il servizio della sessione (nucleo/avvisi.py) con avvisi_dovuti().
"""

from __future__ import annotations

import json
import os
import re
import threading
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path

from . import branding
from .i18n import T

_blocco = threading.Lock()
COLORI = ["#3B82F6", "#EF4444", "#22C55E", "#F59E0B", "#A855F7", "#EC4899", "#14B8A6", "#64748B"]
RIPETI = {"": "Mai", "giorno": "Ogni giorno", "settimana": "Ogni settimana", "mese": "Ogni mese", "anno": "Ogni anno"}
AVVISI = {-1: "Nessun avviso", 0: "All'ora dell'evento", 5: "5 minuti prima", 15: "15 minuti prima", 30: "30 minuti prima",
          60: "1 ora prima", 1440: "1 giorno prima"}


def _cartella() -> Path:
    c = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / branding.id_os() / "agenda"
    c.mkdir(parents=True, exist_ok=True)
    return c


def _leggi(nome: str, predefinito):
    try:
        return json.loads((_cartella() / nome).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return predefinito


def _scrivi(nome: str, dati) -> None:
    f = _cartella() / nome
    tmp = f.with_name(f.name + f".{os.getpid()}.tmp")
    tmp.write_text(json.dumps(dati, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(f)


def _dt(testo: str) -> datetime:
    """«2026-11-23T10:30» o «2026-11-23» → datetime."""
    return datetime.fromisoformat(testo[:16]) if "T" in testo else datetime.fromisoformat(testo[:10])


# ── Calendari ────────────────────────────────────────────────────────────────
def calendari() -> list[dict]:
    c = _leggi("calendari.json", None)
    if not c:
        c = [{"id": "personale", "nome": T("Personale"), "colore": "#3B82F6", "visibile": True},
             {"id": "lavoro", "nome": T("Lavoro"), "colore": "#F59E0B", "visibile": True},
             {"id": "famiglia", "nome": T("Famiglia"), "colore": "#22C55E", "visibile": True}]
        _scrivi("calendari.json", c)
    return c


def salva_calendario(cal: dict) -> list[dict]:
    with _blocco:
        elenco = calendari()
        voce = {"id": cal.get("id") or uuid.uuid4().hex[:8], "nome": str(cal.get("nome") or T("Calendario"))[:40],
                "colore": cal.get("colore") if cal.get("colore") in COLORI else COLORI[len(elenco) % len(COLORI)],
                "visibile": bool(cal.get("visibile", True))}
        elenco = [x for x in elenco if x["id"] != voce["id"]] + [voce]
        _scrivi("calendari.json", elenco)
    return elenco


def mostra_calendario(ident: str, si: bool) -> list[dict]:
    with _blocco:
        elenco = calendari()
        for c in elenco:
            if c["id"] == ident:
                c["visibile"] = bool(si)
        _scrivi("calendari.json", elenco)
    return elenco


# ── Eventi ───────────────────────────────────────────────────────────────────
def _eventi() -> list[dict]:
    return _leggi("eventi.json", [])


def salva_evento(e: dict) -> dict:
    e = dict(e)
    titolo = str(e.get("titolo") or "").strip()
    if not titolo:
        return {"ok": False, "messaggio": T("Scrivi il titolo dell'evento")}
    try:
        inizio, fine = _dt(str(e["inizio"])), _dt(str(e.get("fine") or e["inizio"]))
    except (KeyError, ValueError):
        return {"ok": False, "messaggio": T("Data o ora non valida")}
    tutto = bool(e.get("tuttoGiorno"))
    if fine < inizio:
        fine = inizio + (timedelta(days=0) if tutto else timedelta(hours=1))
    voce = {"id": e.get("id") or uuid.uuid4().hex[:10], "titolo": titolo[:120], "calendario": e.get("calendario") or "personale",
            "inizio": inizio.strftime("%Y-%m-%d") if tutto else inizio.strftime("%Y-%m-%dT%H:%M"),
            "fine": fine.strftime("%Y-%m-%d") if tutto else fine.strftime("%Y-%m-%dT%H:%M"),
            "tuttoGiorno": tutto, "luogo": str(e.get("luogo") or "")[:200], "note": str(e.get("note") or "")[:4000],
            "ripeti": e.get("ripeti") if e.get("ripeti") in RIPETI else "",
            "avviso": int(e.get("avviso", 15)) if int(e.get("avviso", 15)) in AVVISI else 15}
    with _blocco:
        elenco = [x for x in _eventi() if x["id"] != voce["id"]] + [voce]
        _scrivi("eventi.json", elenco)
    return {"ok": True, "id": voce["id"], "messaggio": T("Evento salvato")}


def elimina_evento(ident: str) -> None:
    with _blocco:
        _scrivi("eventi.json", [x for x in _eventi() if x["id"] != ident])


def _avanza(d: datetime, ripeti: str, n: int) -> datetime:
    if ripeti == "giorno":
        return d + timedelta(days=n)
    if ripeti == "settimana":
        return d + timedelta(weeks=n)
    if ripeti == "mese":
        m = d.month - 1 + n
        anno, mese = d.year + m // 12, m % 12 + 1
        giorno = min(d.day, [31, 29 if anno % 4 == 0 and (anno % 100 or anno % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][mese - 1])
        return d.replace(year=anno, month=mese, day=giorno)
    if ripeti == "anno":
        try:
            return d.replace(year=d.year + n)
        except ValueError:   # 29 febbraio
            return d.replace(year=d.year + n, day=28)
    return d


def eventi_tra(da: str, a: str) -> list[dict]:
    """Le occorrenze degli eventi (anche ripetuti) tra due giorni «AAAA-MM-GG» compresi, in ordine."""
    inizio_vista, fine_vista = datetime.fromisoformat(da), datetime.fromisoformat(a) + timedelta(days=1)
    colori = {c["id"]: c for c in calendari()}
    risultato = []
    for e in _eventi():
        cal = colori.get(e["calendario"]) or {"colore": "#64748B", "visibile": True, "nome": ""}
        if not cal.get("visibile", True):
            continue
        s, f = _dt(e["inizio"]), _dt(e["fine"])
        if e["tuttoGiorno"]:
            f = f + timedelta(days=1)
        durata = f - s
        n = 0
        # salto veloce per gli eventi ripetuti nati molto prima
        while n < 5000:
            occ = _avanza(s, e["ripeti"], n) if e["ripeti"] else s
            if occ >= fine_vista:
                break
            if occ + durata > inizio_vista:
                risultato.append({**e, "inizio": occ.strftime("%Y-%m-%dT%H:%M"), "fine": (occ + durata).strftime("%Y-%m-%dT%H:%M"),
                                  "giorno": occ.strftime("%Y-%m-%d"), "colore": cal["colore"], "nomeCalendario": cal.get("nome", ""),
                                  "ora": "" if e["tuttoGiorno"] else occ.strftime("%H:%M"),
                                  "oraFine": "" if e["tuttoGiorno"] else (occ + durata).strftime("%H:%M")})
            if not e["ripeti"]:
                break
            n += 1
    risultato.sort(key=lambda x: (x["inizio"], not x["tuttoGiorno"]))
    return risultato


# ── Promemoria ───────────────────────────────────────────────────────────────
def liste() -> list[dict]:
    l = _leggi("liste.json", None)
    if not l:
        l = [{"id": "promemoria", "nome": T("Promemoria"), "colore": "#3B82F6"},
             {"id": "spesa", "nome": T("Spesa"), "colore": "#22C55E"}]
        _scrivi("liste.json", l)
    voci = _leggi("promemoria.json", [])
    for x in l:
        x["quanti"] = sum(1 for p in voci if p.get("lista") == x["id"] and not p.get("fatto"))
    return l


def salva_lista(lista: dict) -> list[dict]:
    with _blocco:
        elenco = [{k: v for k, v in x.items() if k != "quanti"} for x in liste()]
        voce = {"id": lista.get("id") or uuid.uuid4().hex[:8], "nome": str(lista.get("nome") or T("Lista"))[:40],
                "colore": lista.get("colore") if lista.get("colore") in COLORI else COLORI[len(elenco) % len(COLORI)]}
        elenco = [x for x in elenco if x["id"] != voce["id"]] + [voce]
        _scrivi("liste.json", elenco)
    return liste()


def elimina_lista(ident: str) -> list[dict]:
    with _blocco:
        _scrivi("liste.json", [{k: v for k, v in x.items() if k != "quanti"} for x in liste() if x["id"] != ident])
        _scrivi("promemoria.json", [p for p in _leggi("promemoria.json", []) if p.get("lista") != ident])
    return liste()


def promemoria(filtro: str = "tutti") -> list[dict]:
    """filtro: oggi | programmati | tutti | bandiera | completati | <id della lista>."""
    oggi = date.today().isoformat()
    colori = {x["id"]: x["colore"] for x in liste()}
    voci = _leggi("promemoria.json", [])
    if filtro == "completati":
        voci = [p for p in voci if p.get("fatto")]
    else:
        if filtro == "oggi":
            voci = [p for p in voci if p.get("scadenza") and p["scadenza"][:10] <= oggi]
        elif filtro == "programmati":
            voci = [p for p in voci if p.get("scadenza")]
        elif filtro == "bandiera":
            voci = [p for p in voci if p.get("bandiera")]
        elif filtro != "tutti":
            voci = [p for p in voci if p.get("lista") == filtro]
        voci = [p for p in voci if not p.get("fatto") or (p.get("quandoFatto", 0) > _adesso() - 4)]   # i fatti restano visibili qualche secondo
    for p in voci:
        p["colore"] = colori.get(p.get("lista"), "#64748B")
        p["scaduto"] = bool(p.get("scadenza")) and not p.get("fatto") and (
            p["scadenza"] < datetime.now().strftime("%Y-%m-%dT%H:%M") if "T" in p["scadenza"] else p["scadenza"] < oggi)
        p["quando"] = testo_scadenza(p.get("scadenza", ""))
    voci.sort(key=lambda p: (bool(p.get("fatto")), p.get("scadenza") or "9999", p.get("creato", 0)))
    return voci


def _adesso() -> float:
    import time

    return time.time()


def testo_scadenza(s: str) -> str:
    if not s:
        return ""
    d = _dt(s)
    oggi = date.today()
    if d.date() == oggi:
        giorno = T("Oggi")
    elif d.date() == oggi + timedelta(days=1):
        giorno = T("Domani")
    elif d.date() == oggi - timedelta(days=1):
        giorno = T("Ieri")
    else:
        giorno = d.strftime("%d/%m/%Y")
    return giorno + (" " + d.strftime("%H:%M") if "T" in s else "")


def salva_promemoria(p: dict) -> dict:
    p = dict(p)
    titolo = str(p.get("titolo") or "").strip()
    if not titolo:
        return {"ok": False}
    scadenza = str(p.get("scadenza") or "")
    if scadenza:
        try:
            _dt(scadenza)
        except ValueError:
            scadenza = ""
    with _blocco:
        voci = _leggi("promemoria.json", [])
        vecchio = next((x for x in voci if x["id"] == p.get("id")), {})
        voce = {"id": p.get("id") or uuid.uuid4().hex[:10], "titolo": titolo[:200], "note": str(p.get("note") or "")[:2000],
                "lista": p.get("lista") or vecchio.get("lista") or "promemoria", "scadenza": scadenza,
                "bandiera": bool(p.get("bandiera", vecchio.get("bandiera", False))), "fatto": bool(vecchio.get("fatto", False)),
                "quandoFatto": vecchio.get("quandoFatto", 0), "creato": vecchio.get("creato") or _adesso()}
        voci = [x for x in voci if x["id"] != voce["id"]] + [voce]
        _scrivi("promemoria.json", voci)
    return {"ok": True, "id": voce["id"]}


def segna_fatto(ident: str, si: bool) -> None:
    with _blocco:
        voci = _leggi("promemoria.json", [])
        for p in voci:
            if p["id"] == ident:
                p["fatto"] = bool(si)
                p["quandoFatto"] = _adesso() if si else 0
        _scrivi("promemoria.json", voci)


def elimina_promemoria(ident: str) -> None:
    with _blocco:
        _scrivi("promemoria.json", [p for p in _leggi("promemoria.json", []) if p["id"] != ident])


def conteggi() -> dict:
    oggi = date.today().isoformat()
    voci = [p for p in _leggi("promemoria.json", []) if not p.get("fatto")]
    return {"oggi": sum(1 for p in voci if p.get("scadenza") and p["scadenza"][:10] <= oggi),
            "programmati": sum(1 for p in voci if p.get("scadenza")), "tutti": len(voci),
            "bandiera": sum(1 for p in voci if p.get("bandiera")),
            "completati": sum(1 for p in _leggi("promemoria.json", []) if p.get("fatto"))}


# ── Avvisi (per nucleo/avvisi.py) ────────────────────────────────────────────
def avvisi_dovuti(adesso: datetime):
    """[(chiave, titolo, testo)] da avvisare in questo minuto: eventi e promemoria con l'ora."""
    minuto = adesso.replace(second=0, microsecond=0)
    oggi = minuto.strftime("%Y-%m-%d")
    domani = (minuto + timedelta(days=2)).strftime("%Y-%m-%d")
    for e in eventi_tra(oggi, domani):
        if e.get("avviso", -1) < 0 or e["tuttoGiorno"]:
            continue
        inizio = datetime.fromisoformat(e["inizio"])
        if inizio - timedelta(minutes=e["avviso"]) == minuto:
            testo = (T("Adesso") if e["avviso"] == 0 else T("Alle {ora}", ora=e["ora"])) + (" · " + e["luogo"] if e.get("luogo") else "")
            yield f"evento:{e['id']}:{e['inizio']}", e["titolo"], testo
    for p in _leggi("promemoria.json", []):
        s = p.get("scadenza") or ""
        if not p.get("fatto") and "T" in s and s[:16] == minuto.strftime("%Y-%m-%dT%H:%M"):
            yield f"promemoria:{p['id']}:{s}", p["titolo"], T("Promemoria")


# ── File .ics ────────────────────────────────────────────────────────────────
def _ics_data(valore: str) -> tuple[str, bool]:
    v = valore.strip()
    if re.fullmatch(r"\d{8}", v):
        return f"{v[:4]}-{v[4:6]}-{v[6:8]}", True
    m = re.match(r"(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})", v)
    if not m:
        raise ValueError(v)
    d = datetime(*(int(x) for x in m.groups()))
    if v.endswith("Z"):   # ora universale → ora locale
        d = d.replace(tzinfo=__import__("datetime").timezone.utc).astimezone().replace(tzinfo=None)
    return d.strftime("%Y-%m-%dT%H:%M"), False


def importa_ics(percorso: str, calendario: str = "personale") -> dict:
    try:
        testo = Path(percorso.removeprefix("file://")).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {"ok": False, "messaggio": T("Impossibile leggere il file")}
    testo = re.sub(r"\r?\n[ \t]", "", testo)
    nuovi = 0
    for blocco in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", testo, re.S):
        campi = {}
        for riga in blocco.splitlines():
            if ":" in riga:
                chiave, valore = riga.split(":", 1)
                campi[chiave.split(";")[0].upper()] = valore.replace("\\n", "\n").replace("\\,", ",").replace("\\;", ";")
        try:
            inizio, tutto = _ics_data(campi["DTSTART"])
            fine = _ics_data(campi.get("DTEND", campi["DTSTART"]))[0]
        except (KeyError, ValueError):
            continue
        if tutto:   # nei .ics la fine di un evento di tutto il giorno è il giorno dopo
            fine = (date.fromisoformat(fine[:10]) - timedelta(days=1)).isoformat()
        freq = re.search(r"FREQ=(\w+)", campi.get("RRULE", ""))
        ripeti = {"DAILY": "giorno", "WEEKLY": "settimana", "MONTHLY": "mese", "YEARLY": "anno"}.get(freq.group(1) if freq else "", "")
        r = salva_evento({"titolo": campi.get("SUMMARY", T("Evento")), "inizio": inizio, "fine": fine, "tuttoGiorno": tutto,
                          "luogo": campi.get("LOCATION", ""), "note": campi.get("DESCRIPTION", ""), "ripeti": ripeti,
                          "calendario": calendario, "avviso": 15})
        nuovi += 1 if r.get("ok") else 0
    return {"ok": True, "messaggio": T("{n} eventi importati", n=nuovi)}


def esporta_ics() -> dict:
    from .sistema import cartella_utente

    righe = ["BEGIN:VCALENDAR", "VERSION:2.0", f"PRODID:-//{branding.nome()}//Calendario//IT"]
    for e in _eventi():
        def ics(v: str, tutto: bool) -> str:
            return v[:10].replace("-", "") if tutto else v.replace("-", "").replace(":", "") + "00"
        fine = e["fine"]
        if e["tuttoGiorno"]:
            fine = (date.fromisoformat(fine[:10]) + timedelta(days=1)).isoformat()
        righe += ["BEGIN:VEVENT", f"UID:{e['id']}@{branding.id_os()}", f"SUMMARY:{e['titolo']}",
                  ("DTSTART;VALUE=DATE:" if e["tuttoGiorno"] else "DTSTART:") + ics(e["inizio"], e["tuttoGiorno"]),
                  ("DTEND;VALUE=DATE:" if e["tuttoGiorno"] else "DTEND:") + ics(fine, e["tuttoGiorno"])]
        if e.get("luogo"):
            righe.append("LOCATION:" + e["luogo"].replace(",", "\\,"))
        if e.get("note"):
            righe.append("DESCRIPTION:" + e["note"].replace("\n", "\\n").replace(",", "\\,"))
        if e.get("ripeti"):
            righe.append("RRULE:FREQ=" + {"giorno": "DAILY", "settimana": "WEEKLY", "mese": "MONTHLY", "anno": "YEARLY"}[e["ripeti"]])
        righe.append("END:VEVENT")
    righe.append("END:VCALENDAR")
    cartella = cartella_utente("DOCUMENTS", "Documenti")
    cartella.mkdir(parents=True, exist_ok=True)
    f = cartella / "calendario.ics"
    f.write_text("\r\n".join(righe) + "\r\n", encoding="utf-8")
    return {"ok": True, "messaggio": T("Calendario salvato in {f}", f=f"{cartella.name}/calendario.ics")}
