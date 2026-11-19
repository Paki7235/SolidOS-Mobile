"""Dov'è: trova i tuoi dispositivi (come «Dov'è» di Apple).

Mappa OpenStreetMap con la posizione dei dispositivi del Solid ID, e per ognuno:
Fai suonare, Blocca con un messaggio, Aggiorna posizione, Indicazioni.
Le tessere della mappa si scaricano una volta e restano in ~/.cache/<os>/mappe.
"""

from __future__ import annotations

import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .. import branding, solidid
from ..i18n import T
from ..ponte import Backend, crea_ponte

# Mappa OpenStreetMap (riserva: il server tedesco della comunità). Le regole d'uso chiedono
# un programma riconoscibile con un contatto vero: un indirizzo segnaposto viene bloccato.
SERVER = ["https://tile.openstreetmap.org/{z}/{x}/{y}.png", "https://tile.openstreetmap.de/{z}/{x}/{y}.png"]
CONTATTO = "https://github.com/Paki7235/SolidOS"


def _cartella_mappe() -> Path:
    import os

    c = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os() / "mappe"
    c.mkdir(parents=True, exist_ok=True)
    return c


def _quando(iso: str) -> str:
    from datetime import datetime, timezone

    try:
        t = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return ""
    s = (datetime.now(timezone.utc) - t).total_seconds()
    if s < 120:
        return T("adesso")
    if s < 3600:
        return T("{n} min fa", n=int(s // 60))
    if s < 86400:
        return T("{n} h fa", n=int(s // 3600))
    if s < 7 * 86400:
        return T("{n} giorni fa", n=int(s // 86400))
    return t.astimezone().strftime("%d/%m/%Y")


def _variante(originale: Path, stile: str) -> str:
    """Mappa «morbida» (come le mappe dei telefoni): gli stessi dati di OpenStreetMap con colori
    tenui e strade leggere; la scura per il tema scuro. Si prepara una volta e resta salvata."""
    f = originale.with_name(f"{originale.stem}-{stile}.png")
    if f.exists() and f.stat().st_size > 0:
        return str(f)
    from PyQt6.QtGui import QColor, QImage, QPainter

    img = QImage(str(originale)).convertToFormat(QImage.Format.Format_RGB32)
    if img.isNull():
        return str(originale)
    grigia = img.convertToFormat(QImage.Format.Format_Grayscale8).convertToFormat(QImage.Format.Format_RGB32)
    p = QPainter(img)
    if stile == "morbida-scura":
        grigia.invertPixels()
        p.drawImage(0, 0, grigia)
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Multiply)
        p.fillRect(img.rect(), QColor(178, 186, 210))          # grafite un po' blu
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)
        p.fillRect(img.rect(), QColor(30, 34, 46, 22))
    else:
        p.setOpacity(0.62)
        p.drawImage(0, 0, grigia)                               # colori tenui
        p.setOpacity(1)
        p.fillRect(img.rect(), QColor(250, 249, 245, 46))       # più chiara, meno contrasto
        p.setCompositionMode(QPainter.CompositionMode.CompositionMode_Multiply)
        p.fillRect(img.rect(), QColor(246, 244, 238))           # carta calda
    p.end()
    tmp = f.with_suffix(".tmp.png")
    img.save(str(tmp), "PNG")
    tmp.replace(f)
    return str(f)


def _scarica_tessera(stile: str, z: int, x: int, y: int) -> str:
    if stile in ("morbida-chiara", "morbida-scura"):
        originale = _scarica_tessera("osm", z, x, y)
        return _variante(Path(originale), stile) if originale else ""
    f = _cartella_mappe() / str(z) / str(x) / f"{y}.png"
    if f.exists() and f.stat().st_size > 0:
        return str(f)
    f.parent.mkdir(parents=True, exist_ok=True)
    agente = f"{branding.nome()}-Dove/{branding.get('OS_VERSION', '')} (+{CONTATTO})"
    for server in SERVER:
        req = urllib.request.Request(server.format(z=z, x=x, y=y), headers={"User-Agent": agente})
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                dati = r.read()
                tipo = r.headers.get("Content-Type", "")
                bloccata = bool(r.headers.get("X-Blocked"))
        except OSError:
            continue
        # Tessera «Access blocked» (intestazione X-Blocked): non si salva, si prova l'altro server
        if bloccata or not tipo.startswith("image/") or len(dati) < 120:
            continue
        tmp = f.with_suffix(".tmp")
        tmp.write_bytes(dati)
        tmp.replace(f)
        return str(f)
    return ""


ICONE_TIPO = {
    "telefono": ["phone", "smartphone", "phone-symbolic", "multimedia-player"],
    "tablet": ["tablet", "pda", "computer-tablet", "phone"],
    "portatile": ["computer-laptop", "laptop", "computer"],
    "computer": ["computer", "computer-desktop", "video-display"],
}


def _icona_tipo(tipo: str) -> str:
    """Prima icona del tipo che esiste davvero nel tema (i temi non hanno tutti gli stessi nomi)."""
    from PyQt6.QtGui import QIcon

    candidati = ICONE_TIPO.get(tipo, ICONE_TIPO["computer"])
    return next((n for n in candidati if QIcon.hasThemeIcon(n)), candidati[-1])


class BackendDove(Backend):
    def __init__(self):
        self._pool = ThreadPoolExecutor(max_workers=2)

    # ── Account ──────────────────────────────────────────────────────────
    def utente(self) -> dict:
        return {**solidid.utente(), "disponibile": solidid.disponibile()}

    def accedi(self, email: str, password: str) -> dict:
        return solidid.accedi(email, password)

    def crea(self, nome: str, email: str, password: str) -> dict:
        return solidid.crea(nome, email, password)

    def reinviaConferma(self, email: str) -> dict:
        return solidid.reinvia_conferma(email)

    def passwordDimenticata(self, email: str) -> dict:
        return solidid.password_dimenticata(email)

    def esci(self) -> dict:
        return solidid.esci()

    def apriImpostazioni(self) -> None:
        from ..sistema import avvia

        avvia([branding.comando("impostazioni"), "solidid"])

    # ── Dispositivi ──────────────────────────────────────────────────────
    def dispositivi(self) -> dict:
        try:
            elenco = solidid.dispositivi()
        except solidid.ErroreSolidID as e:
            return {"ok": False, "messaggio": str(e), "dispositivi": []}
        questo = solidid.sessione().get("dispositivo_id", "")
        risultato = []
        for d in elenco:
            ha_pos = d.get("lat") is not None and d.get("lon") is not None
            icona = _icona_tipo(d.get("tipo", "computer"))
            stato = [T("Questo computer") if d["id"] == questo else _quando(d.get("ultimo_visto", ""))]
            if d.get("batteria") is not None:
                stato.append(f"{d['batteria']}%" + (" ⚡" if d.get("in_carica") else ""))
            if not d.get("trova_attivo", True):
                stato.append(T("Dov'è spento"))
            risultato.append({
                "id": d["id"], "nome": d.get("nome") or T("Dispositivo"), "tipo": d.get("tipo", "computer"),
                "icona": icona, "modello": d.get("modello", ""), "questo": d["id"] == questo,
                "stato": " · ".join(x for x in stato if x), "posizione": ha_pos,
                "lat": d.get("lat") or 0, "lon": d.get("lon") or 0, "precisione": d.get("precisione") or 0,
                "fonte": d.get("fonte_posizione") or "",
                "quandoPosizione": _quando(d.get("posizione_quando") or ""),
                "bloccato": bool(d.get("bloccato")), "trova": bool(d.get("trova_attivo", True)),
            })
        return {"ok": True, "dispositivi": risultato}

    def comando(self, dispositivo: str, tipo: str, messaggio: str = "") -> dict:
        try:
            return solidid.invia_comando(dispositivo, tipo, messaggio)
        except solidid.ErroreSolidID as e:
            return {"ok": False, "messaggio": str(e)}

    def statoComando(self, ident: int) -> str:
        try:
            return solidid.stato_comando(int(ident))
        except (solidid.ErroreSolidID, ValueError):
            return ""

    def rimuovi(self, dispositivo: str) -> dict:
        try:
            return solidid.rimuovi_dispositivo(dispositivo)
        except solidid.ErroreSolidID as e:
            return {"ok": False, "messaggio": str(e)}

    def iconaTipo(self, tipo: str) -> str:
        return _icona_tipo(tipo)

    def indicazioni(self, lat: float, lon: float) -> None:
        from ..sistema import avvia

        avvia(["xdg-open", f"https://www.openstreetmap.org/directions?to={lat:.6f}%2C{lon:.6f}#map=16/{lat:.5f}/{lon:.5f}"])

    # ── Mappa ────────────────────────────────────────────────────────────
    def tessere(self, elenco, stile: str = "chiaro") -> dict:
        """[[z, x, y], …] → {"stile/z/x/y": "file:///…"} (scaricate se mancano)."""
        richieste = [(int(t[0]), int(t[1]), int(t[2])) for t in list(elenco)[:48]]
        risultato = {}
        for (z, x, y), percorso in zip(richieste, self._pool.map(lambda t: _scarica_tessera(stile, *t), richieste)):
            if percorso:
                risultato[f"{stile}/{z}/{x}/{y}"] = "file://" + percorso
        return risultato


def main() -> int:
    from ..qmlapp import esegui_app

    return esegui_app("dove", "Dove/Main.qml", lambda app: {"ponte": crea_ponte(BackendDove())})


if __name__ == "__main__":
    sys.exit(main())
