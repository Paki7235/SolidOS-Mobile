"""Le mappe di SolidOS: disegnate qui, dai dati grezzi di OpenStreetMap.

I dati (strade, acqua, parchi, edifici, nomi) arrivano da OpenFreeMap come tessere
vettoriali, gratis e senza chiavi; il disegno — colori, spessori, nomi — è nostro, chiaro o
scuro come il sistema. Ogni tessera disegnata resta in ~/.cache/<os>/mappe/<tema>/.
Sopra lo zoom 14 si ingrandisce la tessera del 14 (i dati arrivano fino lì), sempre nitida
perché è disegnata e non stirata.

Dati © OpenStreetMap (ODbL), tessere OpenFreeMap / OpenMapTiles: l'app lo scrive sulla mappa.
"""

from __future__ import annotations

import json
import os
import threading
import time
import urllib.request
from pathlib import Path

from .. import branding
from . import mvt

TILEJSON = "https://tiles.openfreemap.org/planet"
ZOOM_DATI = 14
LATO = 256          # lato logico della tessera (come la mappa a schermo)
DENSITA = 2         # disegnata al doppio: nitida anche sugli schermi densi
_blocco = threading.Lock()
_indirizzo = {"url": "", "quando": 0.0}

TEMI = {
    "chiaro": {
        "fondo": "#F2EFE9", "acqua": "#A9CBEA", "acqua_linea": "#8DB9E3", "verde": "#D3E8C6", "bosco": "#C2DFB2",
        "sabbia": "#F3E9CF", "abitato": "#ECE7DF", "industria": "#E8E2E6", "edificio": "#DED7CD", "edificio_bordo": "#D0C8BD",
        "strada": "#FFFFFF", "strada_bordo": "#D6D0C6", "principale": "#FCE29C", "principale_bordo": "#E2C06A",
        "autostrada": "#F8B67A", "autostrada_bordo": "#D98C4C", "sentiero": "#B8AE9E", "ferrovia": "#A7A29A",
        "confine": "#B6A9C8", "testo": "#3B3F46", "testo_alone": "#F7F5F1", "testo_acqua": "#3E6E9E",
        "poi": "#7B6F63",
    },
    "scuro": {
        "fondo": "#1C2028", "acqua": "#1F3550", "acqua_linea": "#2A4566", "verde": "#1F3127", "bosco": "#1B2C22",
        "sabbia": "#2B2A24", "abitato": "#232831", "industria": "#262833", "edificio": "#2D333D", "edificio_bordo": "#363D49",
        "strada": "#3A4252", "strada_bordo": "#2A303C", "principale": "#5B5240", "principale_bordo": "#3F392E",
        "autostrada": "#7A5636", "autostrada_bordo": "#56402B", "sentiero": "#4A5160", "ferrovia": "#4C5260",
        "confine": "#5C5470", "testo": "#E3E7EE", "testo_alone": "#1C2028", "testo_acqua": "#8FB6DE",
        "poi": "#AEB4BE",
    },
}

# Spessore delle strade (pixel logici) per classe, alla zoom 14; cresce con lo zoom
SPESSORI = {"motorway": 3.2, "trunk": 3.0, "primary": 2.6, "secondary": 2.2, "tertiary": 1.8, "minor": 1.3,
            "service": 0.8, "track": 0.6, "path": 0.6, "rail": 0.8, "transit": 0.6}


def _cache() -> Path:
    c = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os() / "mappe-solidos"
    c.mkdir(parents=True, exist_ok=True)
    return c


def _url_tessere() -> str:
    """L'indirizzo attuale delle tessere (OpenFreeMap lo cambia a ogni aggiornamento dei dati)."""
    with _blocco:
        if _indirizzo["url"] and time.time() - _indirizzo["quando"] < 6 * 3600:
            return _indirizzo["url"]
        salvato = _cache() / "tilejson.json"
        try:
            req = urllib.request.Request(TILEJSON, headers={"User-Agent": f"{branding.nome()}-Mappe"})
            with urllib.request.urlopen(req, timeout=15) as r:
                dati = json.load(r)
            salvato.write_text(json.dumps(dati))
        except (OSError, ValueError):
            try:
                dati = json.loads(salvato.read_text())
            except (OSError, ValueError):
                return ""
        _indirizzo["url"] = (dati.get("tiles") or [""])[0]
        _indirizzo["quando"] = time.time()
        return _indirizzo["url"]


_memoria: dict = {}          # ultime tessere di dati già lette (z, x, y) → strati
_ordine: list = []


def _con_riquadri(strati: dict) -> dict:
    """Aggiunge a ogni oggetto il suo riquadro: così si disegna solo ciò che cade nella tessera."""
    for st in strati.values():
        for o in st["oggetti"]:
            xs = [pt[0] for parte in o["geom"] for pt in parte]
            ys = [pt[1] for parte in o["geom"] for pt in parte]
            o["box"] = (min(xs), min(ys), max(xs), max(ys)) if xs else (0, 0, 0, 0)
    return strati


def _dati(z: int, x: int, y: int) -> dict | None:
    chiave = (z, x, y)
    with _blocco:
        if chiave in _memoria:
            return _memoria[chiave]
    strati = _dati_da_disco(z, x, y)
    if strati is not None:
        strati = _con_riquadri(strati)
        with _blocco:
            _memoria[chiave] = strati
            _ordine.append(chiave)
            while len(_ordine) > 12:
                _memoria.pop(_ordine.pop(0), None)
    return strati


def _dati_da_disco(z: int, x: int, y: int) -> dict | None:
    f = _cache() / "dati" / str(z) / str(x) / f"{y}.pbf"
    if not f.is_file():
        url = _url_tessere()
        if not url:
            return None
        f.parent.mkdir(parents=True, exist_ok=True)
        try:
            req = urllib.request.Request(url.format(z=z, x=x, y=y), headers={"User-Agent": f"{branding.nome()}-Mappe"})
            with urllib.request.urlopen(req, timeout=20) as r:
                grezzi = r.read()
        except OSError:
            return None
        tmp = f.with_name(f"{f.name}.{os.getpid()}.{threading.get_ident()}.tmp")
        tmp.write_bytes(grezzi)
        tmp.replace(f)
    try:
        return mvt.leggi(f.read_bytes())
    except (OSError, ValueError, IndexError):
        f.unlink(missing_ok=True)
        return None


def _nome(attr: dict) -> str:
    return str(attr.get("name:it") or attr.get("name") or attr.get("name_int") or "")


def tessera(z: int, x: int, y: int, tema: str = "chiaro") -> str:
    """Percorso del PNG della tessera z/x/y disegnata (vuoto se i dati non arrivano)."""
    tema = tema if tema in TEMI else "chiaro"
    if not (0 <= z <= 20 and 0 <= x < 2 ** z and 0 <= y < 2 ** z):
        return ""
    f = _cache() / tema / str(z) / str(x) / f"{y}.png"
    if f.is_file() and f.stat().st_size > 0:
        return str(f)
    zd = min(z, ZOOM_DATI)
    dz = z - zd
    px, py = x >> dz, y >> dz
    strati = _dati(zd, px, py)
    if strati is None:
        return ""
    img = _disegna(strati, z, dz, x - (px << dz), y - (py << dz), TEMI[tema])
    f.parent.mkdir(parents=True, exist_ok=True)
    # nome provvisorio diverso per ogni richiesta: due richieste della stessa tessera non si pestano
    tmp = f.with_name(f"{f.stem}.{os.getpid()}.{threading.get_ident()}.tmp.png")
    img.save(str(tmp), "PNG")
    tmp.replace(f)
    return str(f)


def _disegna(strati: dict, z: int, dz: int, sx: int, sy: int, c: dict):
    from PyQt6.QtCore import QPointF, QRectF, Qt
    from PyQt6.QtGui import QColor, QFont, QFontMetricsF, QImage, QPainter, QPainterPath, QPen

    img = QImage(LATO * DENSITA, LATO * DENSITA, QImage.Format.Format_RGB32)
    img.setDevicePixelRatio(DENSITA)
    img.fill(QColor(c["fondo"]))
    p = QPainter(img)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    ingrandimento = 2 ** dz
    crescita = 1.0 + max(0, z - 13) * 0.55   # strade più larghe da vicino

    def trasforma(extent):
        s = LATO * ingrandimento / extent
        return s, -sx * LATO, -sy * LATO

    def dentro(o, extent):
        """L'oggetto tocca questa tessera? (con un margine per i nomi e le linee spesse)"""
        if not ingrandimento > 1:
            return True
        passo = extent / ingrandimento
        m = passo * 0.25
        x0, y0 = sx * passo - m, sy * passo - m
        b = o.get("box")
        return not b or not (b[2] < x0 or b[0] > x0 + passo + 2 * m or b[3] < y0 or b[1] > y0 + passo + 2 * m)

    def percorso(geom, extent, chiudi):
        s, ox, oy = trasforma(extent)
        cammino = QPainterPath()
        for parte in geom:
            if not parte:
                continue
            cammino.moveTo(parte[0][0] * s + ox, parte[0][1] * s + oy)
            for (gx, gy) in parte[1:]:
                cammino.lineTo(gx * s + ox, gy * s + oy)
            if chiudi:
                cammino.closeSubpath()
        return cammino

    def riempi(nome_strato, colore_per):
        st = strati.get(nome_strato)
        if not st:
            return
        p.setPen(Qt.PenStyle.NoPen)
        for o in st["oggetti"]:
            if o["tipo"] != 3 or not dentro(o, st["extent"]):
                continue
            colore = colore_per(o["attr"])
            if colore:
                p.setBrush(QColor(colore))
                cammino = percorso(o["geom"], st["extent"], True)
                cammino.setFillRule(Qt.FillRule.OddEvenFill)
                p.drawPath(cammino)

    def copertura(a):
        k = a.get("class", "")
        if k in ("wood", "forest"):
            return c["bosco"]
        if k in ("grass", "farmland", "wetland", "scrub"):
            return c["verde"]
        if k in ("sand", "beach"):
            return c["sabbia"]
        return None

    def uso(a):
        k = a.get("class", "")
        if k in ("residential", "suburb", "neighbourhood", "quarter"):
            return c["abitato"]
        if k in ("industrial", "commercial", "retail", "railway"):
            return c["industria"]
        if k in ("park", "cemetery", "pitch", "stadium", "playground", "garden"):
            return c["verde"]
        return None

    riempi("landuse", uso)
    riempi("landcover", copertura)
    riempi("park", lambda a: c["verde"])
    riempi("water", lambda a: c["acqua"])

    # fiumi e canali
    st = strati.get("waterway")
    if st:
        p.setBrush(Qt.BrushStyle.NoBrush)
        for o in st["oggetti"]:
            if not dentro(o, st["extent"]):
                continue
            largo = 2.0 if o["attr"].get("class") == "river" else 0.9
            p.setPen(QPen(QColor(c["acqua_linea"]), largo * crescita, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
            p.drawPath(percorso(o["geom"], st["extent"], False))

    if z >= 15:
        st = strati.get("building")
        if st:
            p.setBrush(QColor(c["edificio"]))
            p.setPen(QPen(QColor(c["edificio_bordo"]), 0.6))
            for o in st["oggetti"]:
                if o["tipo"] == 3 and dentro(o, st["extent"]):
                    p.drawPath(percorso(o["geom"], st["extent"], True))

    # strade: prima i bordi, poi il riempimento, dalle piccole alle grandi
    st = strati.get("transportation")
    ordine = ["path", "track", "service", "minor", "tertiary", "secondary", "primary", "trunk", "motorway"]
    if st:
        strade = [o for o in st["oggetti"] if o["tipo"] == 2 and dentro(o, st["extent"])]
        strade.sort(key=lambda o: ordine.index(o["attr"].get("class")) if o["attr"].get("class") in ordine else -1)
        p.setBrush(Qt.BrushStyle.NoBrush)
        for fase in ("bordo", "dentro"):
            for o in strade:
                a = o["attr"]
                k = a.get("class", "")
                if k in ("rail", "transit"):
                    if fase == "dentro":
                        p.setPen(QPen(QColor(c["ferrovia"]), SPESSORI["rail"] * crescita, Qt.PenStyle.DashLine))
                        p.drawPath(percorso(o["geom"], st["extent"], False))
                    continue
                if k not in SPESSORI or (k in ("path", "track") and z < 14) or (k == "service" and z < 15):
                    continue
                largo = SPESSORI[k] * crescita * (1.6 if z >= 16 else 1)
                if k in ("motorway", "trunk"):
                    colore, bordo = c["autostrada"], c["autostrada_bordo"]
                elif k in ("primary", "secondary"):
                    colore, bordo = c["principale"], c["principale_bordo"]
                elif k in ("path", "track"):
                    if fase == "dentro":
                        p.setPen(QPen(QColor(c["sentiero"]), largo, Qt.PenStyle.DotLine, Qt.PenCapStyle.RoundCap))
                        p.drawPath(percorso(o["geom"], st["extent"], False))
                    continue
                else:
                    colore, bordo = c["strada"], c["strada_bordo"]
                if a.get("brunnel") == "tunnel":
                    colore = bordo
                penna = QPen(QColor(bordo if fase == "bordo" else colore), largo + (1.6 if fase == "bordo" else 0),
                             Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin)
                p.setPen(penna)
                p.drawPath(percorso(o["geom"], st["extent"], False))

    # confini amministrativi (regioni e stati)
    st = strati.get("boundary")
    if st:
        for o in st["oggetti"]:
            if o["attr"].get("admin_level", 99) <= 4 and not o["attr"].get("maritime"):
                p.setPen(QPen(QColor(c["confine"]), 1.2, Qt.PenStyle.DashDotLine))
                p.drawPath(percorso(o["geom"], st["extent"], False))

    # ── Nomi ──
    occupati: list = []

    def scrivi(testo, punto, extent, dimensione, colore, peso=QFont.Weight.Normal, corsivo=False):
        if not testo:
            return False
        s, ox, oy = trasforma(extent)
        x0, y0 = punto[0] * s + ox, punto[1] * s + oy
        font = QFont(branding.get("FONT_UI", "Inter") or "Inter")
        font.setPixelSize(int(dimensione))
        font.setWeight(peso)
        font.setItalic(corsivo)
        m = QFontMetricsF(font)
        larghezza, altezza = m.horizontalAdvance(testo), m.height()
        r = QRectF(x0 - larghezza / 2, y0 - altezza / 2, larghezza, altezza)
        # dentro la tessera (niente nomi tagliati a metà) e senza sovrapporsi
        if r.left() < 2 or r.top() < 2 or r.right() > LATO - 2 or r.bottom() > LATO - 2:
            return False
        if any(r.intersects(o) for o in occupati):
            return False
        occupati.append(r.adjusted(-4, -2, 4, 2))
        cammino = QPainterPath()
        cammino.addText(QPointF(r.left(), r.top() + m.ascent()), font, testo)
        p.setPen(QPen(QColor(c["testo_alone"]), 3, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawPath(cammino)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QColor(colore))
        p.drawPath(cammino)
        return True

    def centro(geom):
        punti = [pt for parte in geom for pt in parte]
        if not punti:
            return None
        if len(geom[0]) == 1:
            return geom[0][0]
        return punti[len(punti) // 2]

    st = strati.get("place")
    if st:
        dimensioni = {"city": 15, "town": 13, "village": 11.5, "suburb": 11.5, "hamlet": 10.5,
                      "neighbourhood": 10.5, "quarter": 11}
        posti = sorted(st["oggetti"], key=lambda o: o["attr"].get("rank", 99))
        for o in posti:
            k = o["attr"].get("class", "")
            if k not in dimensioni or (k in ("neighbourhood", "hamlet") and z < 15):
                continue
            pt = centro(o["geom"])
            if pt:
                scrivi(_nome(o["attr"]), pt, st["extent"], dimensioni[k] + (1 if z >= 15 else 0), c["testo"],
                       QFont.Weight.DemiBold if k in ("city", "town") else QFont.Weight.Medium)

    # nomi delle strade lungo la strada (il tratto dritto più lungo, sempre leggibile)
    if z >= 15:
        st = strati.get("transportation_name")
        if st:
            import math as _m

            from PyQt6.QtGui import QTransform

            s_, ox_, oy_ = trasforma(st["extent"])
            font = QFont(branding.get("FONT_UI", "Inter") or "Inter")
            font.setPixelSize(9 if z < 17 else 10)
            font.setWeight(QFont.Weight.Medium)
            mf = QFontMetricsF(font)
            importanti = ("motorway", "trunk", "primary", "secondary", "tertiary", "minor", "service")
            for o in sorted(st["oggetti"], key=lambda o: importanti.index(o["attr"].get("class")) if o["attr"].get("class") in importanti else 99):
                if o["attr"].get("class") not in importanti or not dentro(o, st["extent"]):
                    continue
                nome = _nome(o["attr"])
                if not nome:
                    continue
                largo = mf.horizontalAdvance(nome)
                migliore = None
                for parte in o["geom"]:
                    for (x1, y1), (x2, y2) in zip(parte, parte[1:]):
                        ax, ay, bx, by = x1 * s_ + ox_, y1 * s_ + oy_, x2 * s_ + ox_, y2 * s_ + oy_
                        lung = _m.hypot(bx - ax, by - ay)
                        if lung > largo + 8 and (migliore is None or lung > migliore[0]):
                            migliore = (lung, ax, ay, bx, by)
                if not migliore:
                    continue
                _l, ax, ay, bx, by = migliore
                mx, my = (ax + bx) / 2, (ay + by) / 2
                angolo = _m.degrees(_m.atan2(by - ay, bx - ax))
                if angolo > 90:
                    angolo -= 180
                elif angolo < -90:
                    angolo += 180
                raggio = largo / 2 + 4
                riquadro = QRectF(mx - raggio, my - raggio * 0.5 - 5, 2 * raggio, raggio + 10) if abs(angolo) > 30 \
                    else QRectF(mx - raggio, my - 7, 2 * raggio, 14)
                if riquadro.left() < 0 or riquadro.top() < 0 or riquadro.right() > LATO or riquadro.bottom() > LATO:
                    continue
                if any(riquadro.intersects(x) for x in occupati):
                    continue
                occupati.append(riquadro)
                cammino = QPainterPath()
                cammino.addText(QPointF(-largo / 2, mf.ascent() / 2 - 1), font, nome)
                cammino = QTransform().translate(mx, my).rotate(angolo).map(cammino)
                p.setPen(QPen(QColor(c["testo_alone"]), 2.6, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap, Qt.PenJoinStyle.RoundJoin))
                p.setBrush(Qt.BrushStyle.NoBrush)
                p.drawPath(cammino)
                p.setPen(Qt.PenStyle.NoPen)
                p.setBrush(QColor(c["testo"]))
                p.drawPath(cammino)
    st = strati.get("water_name")
    if st:
        for o in st["oggetti"]:
            pt = centro(o["geom"])
            if pt:
                scrivi(_nome(o["attr"]), pt, st["extent"], 11, c["testo_acqua"], QFont.Weight.Medium, True)
    # luoghi: un pallino colorato per tipo e il nome accanto
    if z >= 16:
        st = strati.get("poi")
        if st:
            colori_poi = {"food": "#F97316", "restaurant": "#F97316", "fast_food": "#F97316", "cafe": "#B45309",
                          "bar": "#B45309", "shop": "#8B5CF6", "grocery": "#8B5CF6", "hospital": "#EF4444",
                          "pharmacy": "#16A34A", "fuel": "#0EA5E9", "parking": "#3B82F6", "lodging": "#EC4899",
                          "museum": "#A16207", "attraction": "#A16207", "school": "#64748B", "bank": "#0F766E",
                          "bus": "#2563EB", "railway": "#2563EB", "place_of_worship": "#78716C", "park": "#16A34A"}
            s_, ox_, oy_ = trasforma(st["extent"])
            for o in sorted(st["oggetti"], key=lambda o: o["attr"].get("rank", 99)):
                if o["attr"].get("rank", 99) > (25 if z >= 17 else 10) or not dentro(o, st["extent"]):
                    continue
                pt = centro(o["geom"])
                nome = _nome(o["attr"])
                if not pt or not nome or (o["attr"].get("class") in ("bus", "railway") and z < 17):
                    continue
                x0, y0 = pt[0] * s_ + ox_, pt[1] * s_ + oy_
                if not (6 < x0 < LATO - 6 and 6 < y0 < LATO - 6):
                    continue
                colore = colori_poi.get(o["attr"].get("class", ""), c["poi"])
                # il pallino solo se il nome trova posto accanto (niente puntini senza nome)
                if scrivi(nome, (pt[0] + (6 + len(nome) * 2.6) / s_, pt[1]), st["extent"], 9, colore):
                    occupati.append(QRectF(x0 - 5, y0 - 5, 10, 10))
                    p.setPen(QPen(QColor("#FFFFFF"), 1.2))
                    p.setBrush(QColor(colore))
                    p.drawEllipse(QPointF(x0, y0), 4.2, 4.2)
    p.end()
    return img
