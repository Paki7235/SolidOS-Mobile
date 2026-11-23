"""Mappe e navigatore di SolidOS, comuni a PC e telefono.

- mappe disegnate da noi (nucleo.mappe.disegno) dai dati aperti di OpenStreetMap;
- ricerca dei luoghi e indirizzi (Nominatim, OpenStreetMap), anche al contrario (dove sono?);
- percorsi in auto, bici o a piedi con le indicazioni in italiano (Valhalla, server della
  comunità OpenStreetMap), tempi e distanze;
- guida passo passo: data la posizione, la prossima manovra, quanto manca, se si è usciti
  dal percorso (allora si ricalcola).
"""

from __future__ import annotations

import json
import math
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

from .. import branding
from ..i18n import T

NOMINATIM = "https://nominatim.openstreetmap.org"
VALHALLA = "https://valhalla1.openstreetmap.de/route"
MEZZI = {"auto": "auto", "bici": "bicycle", "piedi": "pedestrian"}
_ultima_ricerca = {"t": 0.0}
_blocco = threading.Lock()


def _agente() -> dict:
    return {"User-Agent": f"{branding.nome()}-Mappe/{branding.get('OS_VERSION', '0')}", "Accept-Language": "it"}


def _json(url: str, timeout: float = 20):
    with urllib.request.urlopen(urllib.request.Request(url, headers=_agente()), timeout=timeout) as r:
        return json.load(r)


def _pausa_nominatim() -> None:
    """Le regole di Nominatim chiedono al massimo una ricerca al secondo."""
    with _blocco:
        attesa = 1.05 - (time.time() - _ultima_ricerca["t"])
        if attesa > 0:
            time.sleep(attesa)
        _ultima_ricerca["t"] = time.time()


def _luogo(r: dict) -> dict:
    a = r.get("address") or {}
    nome = r.get("name") or a.get("road") or (r.get("display_name") or "").split(",")[0]
    via = " ".join(x for x in (a.get("road", ""), a.get("house_number", "")) if x)
    citta = a.get("city") or a.get("town") or a.get("village") or a.get("municipality") or ""
    dettaglio = ", ".join(x for x in (via if via != nome else "", citta, a.get("county", "") if not citta else "") if x)
    osm = (r.get("osm_type") or "")[:1].upper() + str(r.get("osm_id") or "")
    return {"nome": nome, "dettaglio": dettaglio or r.get("display_name", ""), "indirizzo": r.get("display_name", ""),
            "lat": float(r["lat"]), "lon": float(r["lon"]), "tipo": r.get("type", ""), "osm": osm if len(osm) > 1 else ""}


def cerca(testo: str, lat: float | None = None, lon: float | None = None) -> list[dict]:
    """Luoghi e indirizzi; se si sa dove si è, prima quelli vicini."""
    testo = testo.strip()
    if len(testo) < 2:
        return []
    q = {"q": testo, "format": "jsonv2", "limit": "8", "addressdetails": "1", "accept-language": "it"}
    if lat is not None and lon is not None:
        d = 0.6
        q["viewbox"] = f"{lon - d},{lat + d},{lon + d},{lat - d}"
    _pausa_nominatim()
    try:
        risultati = _json(f"{NOMINATIM}/search?{urllib.parse.urlencode(q)}")
    except (OSError, ValueError):
        return []
    luoghi = [_luogo(r) for r in risultati if "lat" in r]
    if lat is not None and lon is not None:
        for l in luoghi:
            l["distanza"] = distanza(lat, lon, l["lat"], l["lon"])
    return luoghi


def indirizzo(lat: float, lon: float) -> dict:
    """Il luogo in un punto (per «Sei qui» o per un punto scelto sulla mappa)."""
    _pausa_nominatim()
    q = {"lat": f"{lat:.6f}", "lon": f"{lon:.6f}", "format": "jsonv2", "addressdetails": "1", "zoom": "18",
         "accept-language": "it"}
    try:
        r = _json(f"{NOMINATIM}/reverse?{urllib.parse.urlencode(q)}")
    except (OSError, ValueError):
        return {"nome": T("Punto sulla mappa"), "dettaglio": f"{lat:.5f}, {lon:.5f}", "lat": lat, "lon": lon}
    if "lat" not in r:
        return {"nome": T("Punto sulla mappa"), "dettaglio": f"{lat:.5f}, {lon:.5f}", "lat": lat, "lon": lon}
    return _luogo(r)


def distanza(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Metri tra due punti (formula dell'emisenoverso)."""
    r = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _polilinea(codice: str, precisione: int = 6) -> list[list[float]]:
    punti, indice, lat, lon, fattore = [], 0, 0, 0, 10 ** precisione
    while indice < len(codice):
        for coord in (0, 1):
            risultato = spostamento = 0
            while True:
                b = ord(codice[indice]) - 63
                indice += 1
                risultato |= (b & 0x1F) << spostamento
                spostamento += 5
                if b < 0x20:
                    break
            delta = ~(risultato >> 1) if risultato & 1 else risultato >> 1
            if coord == 0:
                lat += delta
            else:
                lon += delta
        punti.append([lat / fattore, lon / fattore])
    return punti


def testo_distanza(metri: float) -> str:
    if metri < 1000:
        return f"{int(round(metri / 10.0) * 10)} m"
    return f"{metri / 1000:.1f} km".replace(".", ",")


def testo_tempo(secondi: float) -> str:
    minuti = int(round(secondi / 60))
    if minuti < 60:
        return f"{max(1, minuti)} min"
    return f"{minuti // 60} h {minuti % 60:02d} min"


def _manovre(tratto: dict, scostamento: int = 0) -> list[dict]:
    out = []
    for m in tratto.get("maneuvers", []):
        out.append({"tipo": m.get("type", 0), "testo": m.get("instruction", ""),
                    "annuncio": m.get("verbal_pre_transition_instruction") or m.get("instruction", ""),
                    "metri": float(m.get("length", 0)) * 1000, "secondi": float(m.get("time", 0)),
                    "inizio": int(m.get("begin_shape_index", 0)) + scostamento,
                    "fine": int(m.get("end_shape_index", 0)) + scostamento,
                    "via": ", ".join(m.get("street_names") or [])})
    return out


def _viaggio(viaggio: dict, mezzo: str) -> dict:
    """Un percorso di Valhalla (anche con tappe: più tratti uniti) nella forma dell'app."""
    forma, manovre = [], []
    for tratto in viaggio.get("legs") or []:
        punti = _polilinea(tratto.get("shape", ""))
        scostamento = len(forma) - 1 if forma else 0
        forma += punti[1:] if forma else punti
        manovre += _manovre(tratto, scostamento)
    s = viaggio.get("summary") or {}
    metri, secondi = float(s.get("length", 0)) * 1000, float(s.get("time", 0))
    return {"ok": True, "forma": forma, "manovre": manovre, "metri": metri, "secondi": secondi,
            "distanza": testo_distanza(metri), "tempo": testo_tempo(secondi), "mezzo": mezzo,
            "pedaggi": bool(s.get("has_toll")), "autostrade": bool(s.get("has_highway")),
            "traghetti": bool(s.get("has_ferry")),
            "arrivo": time.strftime("%H:%M", time.localtime(time.time() + secondi))}


def percorso(da: dict, a: dict, mezzo: str = "auto", opzioni: dict | None = None, tappe: list | None = None) -> dict:
    """Il percorso da «da» ad «a» ({lat, lon}), con le eventuali tappe in mezzo.
    opzioni: {"pedaggi": False, "autostrade": False, "traghetti": False} per evitarli.
    Risponde col percorso migliore e fino a due alternative (in «alternative»)."""
    if mezzo == "mezzi":
        return trasporti(da, a)
    opzioni = opzioni or {}
    punti = [da] + list(tappe or []) + [a]
    corpo = {"locations": [{"lat": float(p["lat"]), "lon": float(p["lon"])} for p in punti],
             "costing": MEZZI.get(mezzo, "auto"),
             "directions_options": {"language": "it-IT", "units": "kilometers"}}
    if len(punti) == 2:
        corpo["alternates"] = 2
    costo = MEZZI.get(mezzo, "auto")
    preferenze = {}
    if opzioni.get("pedaggi") is False:
        preferenze["use_tolls"] = 0.0
    if opzioni.get("autostrade") is False:
        preferenze["use_highways"] = 0.0
    if opzioni.get("traghetti") is False:
        preferenze["use_ferry"] = 0.0
    if preferenze:
        corpo["costing_options"] = {costo: preferenze}
    try:
        req = urllib.request.Request(VALHALLA, data=json.dumps(corpo).encode(),
                                     headers={**_agente(), "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=40) as risposta:
            r = json.load(risposta)
    except urllib.error.HTTPError as e:   # 400: non c'è un percorso (mare, troppo lontano…)
        try:
            messaggio = json.loads(e.read()).get("error", "")
        except (OSError, ValueError):
            messaggio = ""
        return {"ok": False, "messaggio": T("Nessun percorso trovato") + (f" ({messaggio})" if messaggio else "")}
    except (OSError, ValueError):
        return {"ok": False, "messaggio": T("Impossibile calcolare il percorso: controlla la connessione")}
    principale = _viaggio(r.get("trip") or {}, mezzo)
    principale["alternative"] = [_viaggio(x.get("trip") or {}, mezzo) for x in r.get("alternates") or []]
    return principale


# ── Limiti di velocità e nomi delle strade lungo il percorso ────────────────
def _polilinea_codifica(punti: list, precisione: int = 6) -> str:
    out, plat, plon, f = [], 0, 0, 10 ** precisione
    for lat, lon in punti:
        for valore, prec in ((round(lat * f), plat), (round(lon * f), plon)):
            d = valore - prec
            d = ~(d << 1) if d < 0 else d << 1
            while d >= 0x20:
                out.append(chr((0x20 | (d & 0x1F)) + 63))
                d >>= 5
            out.append(chr(d + 63))
        plat, plon = round(lat * f), round(lon * f)
    return "".join(out)


def strade(forma: list, mezzo: str = "auto") -> list[dict]:
    """Per tratti del percorso: [{inizio, fine, limite (km/h o 0), via}] (dati di OpenStreetMap)."""
    if len(forma) < 2:
        return []
    corpo = {"encoded_polyline": _polilinea_codifica(forma), "costing": MEZZI.get(mezzo, "auto"),
             "shape_match": "map_snap",
             "filters": {"attributes": ["edge.speed_limit", "edge.names", "edge.begin_shape_index",
                                        "edge.end_shape_index"], "action": "include"}}
    try:
        req = urllib.request.Request(VALHALLA.replace("/route", "/trace_attributes"), data=json.dumps(corpo).encode(),
                                     headers={**_agente(), "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=40) as risposta:
            archi = json.load(risposta).get("edges") or []
    except (OSError, ValueError):
        return []
    return [{"inizio": e.get("begin_shape_index", 0), "fine": e.get("end_shape_index", 0),
             "limite": int(e.get("speed_limit") or 0) if str(e.get("speed_limit") or "0").isdigit() else 0,
             "via": ", ".join(e.get("names") or [])} for e in archi]


# ── Mezzi pubblici (Transitous: servizio aperto della comunità, Europa e altro) ──
TRANSITOUS = "https://api.transitous.org/api/v1/plan"
NOMI_MEZZI = {"WALK": "A piedi", "BUS": "Autobus", "TRAM": "Tram", "SUBWAY": "Metro", "RAIL": "Treno",
              "REGIONAL_RAIL": "Treno regionale", "HIGHSPEED_RAIL": "Alta velocità", "LONG_DISTANCE": "Treno",
              "SUBURBAN": "Treno suburbano", "FERRY": "Traghetto", "COACH": "Pullman", "FUNICULAR": "Funicolare",
              "CABLE_CAR": "Funivia", "AERIAL_LIFT": "Funivia", "METRO": "Metro"}


def _ora(iso: str) -> str:
    try:
        import calendar

        t = time.strptime(iso[:19], "%Y-%m-%dT%H:%M:%S")   # gli orari arrivano in UTC
        return time.strftime("%H:%M", time.localtime(calendar.timegm(t)))
    except (ValueError, TypeError):
        return ""


def trasporti(da: dict, a: dict) -> dict:
    """Percorsi con i mezzi pubblici: bus, metro, treni, tram, traghetti (orari dalla rete aperta Transitous)."""
    q = {"fromPlace": f"{da['lat']},{da['lon']}", "toPlace": f"{a['lat']},{a['lon']}", "numItineraries": "4"}
    try:
        r = _json(f"{TRANSITOUS}?{urllib.parse.urlencode(q)}", timeout=40)
    except (OSError, ValueError):
        return {"ok": False, "messaggio": T("Impossibile cercare i mezzi pubblici: controlla la connessione")}
    soluzioni = []
    for it in r.get("itineraries") or []:
        tratti, forma = [], []
        for l in it.get("legs") or []:
            g = l.get("legGeometry") or {}
            punti = _polilinea(g.get("points", ""), int(g.get("precision", 6) or 6)) if g.get("points") else []
            forma += punti
            tratti.append({"mezzo": l.get("mode", ""), "nome": T(NOMI_MEZZI.get(l.get("mode", ""), l.get("mode", ""))),
                           "linea": l.get("routeShortName") or l.get("displayName") or "",
                           "direzione": l.get("headsign") or "", "colore": "#" + (l.get("routeColor") or "3B82F6"),
                           "da": (l.get("from") or {}).get("name", ""), "a": (l.get("to") or {}).get("name", ""),
                           "parte": _ora(l.get("startTime", "")), "arriva": _ora(l.get("endTime", "")),
                           "minuti": round(float(l.get("duration", 0)) / 60), "fermate": len(l.get("intermediateStops") or []),
                           "azienda": l.get("agencyName") or ""})
        secondi = float(it.get("duration", 0))
        cambi = sum(1 for t in tratti if t["mezzo"] != "WALK") - 1
        soluzioni.append({"ok": True, "mezzo": "mezzi", "forma": forma, "manovre": [], "tratti": tratti,
                          "secondi": secondi, "metri": 0, "tempo": testo_tempo(secondi), "distanza": "",
                          "parte": _ora(it.get("startTime", "")), "arrivo": _ora(it.get("endTime", "")),
                          "cambi": max(0, cambi)})
    if not soluzioni:
        return {"ok": False, "messaggio": T("Nessun collegamento con i mezzi pubblici trovato")}
    principale = soluzioni[0]
    principale["alternative"] = soluzioni[1:]
    return principale


# ── Luoghi vicini per categoria (OpenStreetMap, servizio Overpass) ──────────
OVERPASS = "https://overpass-api.de/api/interpreter"
CATEGORIE = {
    "ristoranti": ('["amenity"~"^(restaurant|fast_food)$"]', "Ristoranti", "🍴"),
    "bar": ('["amenity"~"^(cafe|bar|pub)$"]', "Bar e caffè", "☕"),
    "benzina": ('["amenity"="fuel"]', "Benzina", "⛽"),
    "ricarica": ('["amenity"="charging_station"]', "Ricarica auto", "⚡"),
    "farmacie": ('["amenity"="pharmacy"]', "Farmacie", "✚"),
    "supermercati": ('["shop"~"^(supermarket|convenience)$"]', "Supermercati", "🛒"),
    "parcheggi": ('["amenity"="parking"]', "Parcheggi", "P"),
    "hotel": ('["tourism"~"^(hotel|guest_house|hostel)$"]', "Hotel", "🛏"),
    "ospedali": ('["amenity"~"^(hospital|clinic)$"]', "Ospedali", "H"),
    "bancomat": ('["amenity"="atm"]', "Bancomat", "€"),
    "musei": ('["tourism"~"^(museum|attraction)$"]', "Da vedere", "★"),
}


def categorie() -> list[dict]:
    return [{"id": k, "nome": T(v[1]), "simbolo": v[2]} for k, v in CATEGORIE.items()]


def vicini(categoria: str, lat: float, lon: float, raggio: int = 1500) -> list[dict]:
    if categoria not in CATEGORIE:
        return []
    filtro = CATEGORIE[categoria][0]
    q = f'[out:json][timeout:20];nwr{filtro}(around:{int(raggio)},{lat:.6f},{lon:.6f});out center tags 60;'
    try:
        req = urllib.request.Request(OVERPASS, data=urllib.parse.urlencode({"data": q}).encode(), headers=_agente())
        with urllib.request.urlopen(req, timeout=40) as risposta:
            elementi = json.load(risposta).get("elements") or []
    except (OSError, ValueError):
        return []
    luoghi = []
    for e in elementi:
        t = e.get("tags") or {}
        la, lo = e.get("lat", (e.get("center") or {}).get("lat")), e.get("lon", (e.get("center") or {}).get("lon"))
        if la is None or lo is None:
            continue
        nome = t.get("name:it") or t.get("name") or t.get("brand") or T(CATEGORIE[categoria][1])
        via = " ".join(x for x in (t.get("addr:street", ""), t.get("addr:housenumber", "")) if x)
        l = {"nome": nome, "dettaglio": via or t.get("addr:city", ""), "lat": float(la), "lon": float(lo),
             "osm": {"node": "N", "way": "W", "relation": "R"}.get(e.get("type"), "") + str(e.get("id", "")),
             "tipo": categoria, "distanza": distanza(lat, lon, float(la), float(lo))}
        l.update(_dettagli_da_tag(t))
        luoghi.append(l)
    luoghi.sort(key=lambda x: x["distanza"])
    return luoghi[:40]


# ── Scheda del luogo: orari, telefono, sito ─────────────────────────────────
GIORNI = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
NOMI_GIORNI = {"Mo": "lun", "Tu": "mar", "We": "mer", "Th": "gio", "Fr": "ven", "Sa": "sab", "Su": "dom"}


def aperto_ora(orari: str, adesso: time.struct_time | None = None) -> bool | None:
    """True/False se l'orario (formato di OpenStreetMap, i casi comuni) dice aperto adesso; None se non si capisce."""
    if not orari:
        return None
    orari = orari.strip()
    if orari == "24/7":
        return True
    adesso = adesso or time.localtime()
    oggi = GIORNI[adesso.tm_wday]
    minuti = adesso.tm_hour * 60 + adesso.tm_min
    risposta = None
    for regola in orari.split(";"):
        regola = regola.strip()
        if not regola:
            continue
        parti = regola.split(" ", 1)
        if len(parti) == 1 and parti[0][:1].isdigit():
            giorni, fasce = GIORNI, parti[0]
        elif len(parti) == 2:
            giorni = []
            for g in parti[0].split(","):
                if "-" in g and g.split("-")[0] in GIORNI and g.split("-")[1] in GIORNI:
                    i, j = GIORNI.index(g.split("-")[0]), GIORNI.index(g.split("-")[1])
                    giorni += GIORNI[i:j + 1] if i <= j else GIORNI[i:] + GIORNI[:j + 1]
                elif g in GIORNI:
                    giorni.append(g)
                elif g == "PH":
                    continue
                else:
                    return None
            fasce = parti[1]
        else:
            return None
        if oggi not in giorni:
            continue
        risposta = False
        if fasce.strip() == "off":
            continue
        for fascia in fasce.split(","):
            try:
                inizio, fine = fascia.strip().split("-")
                h0, m0 = (int(x) for x in inizio.split(":"))
                h1, m1 = (int(x) for x in fine.split(":"))
            except ValueError:
                return None
            a0, a1 = h0 * 60 + m0, h1 * 60 + m1
            if (a0 <= minuti < a1) or (a1 <= a0 and (minuti >= a0 or minuti < a1)):
                risposta = True
    return risposta


def _orari_leggibili(orari: str) -> str:
    testo = orari
    for k, v in NOMI_GIORNI.items():
        testo = testo.replace(k, v)
    return testo.replace("; ", "\n").replace(";", "\n").replace("off", "chiuso").replace("24/7", "sempre aperto")


def _dettagli_da_tag(t: dict) -> dict:
    orari = t.get("opening_hours", "")
    aperto = aperto_ora(orari)
    return {"orari": _orari_leggibili(orari) if orari else "", "aperto": aperto,
            "telefono": t.get("phone") or t.get("contact:phone") or "",
            "sito": t.get("website") or t.get("contact:website") or "",
            "email": t.get("email") or t.get("contact:email") or "",
            "cucina": t.get("cuisine", "").replace(";", ", ").replace("_", " "),
            "accessibile": t.get("wheelchair", ""), "wikipedia": t.get("wikipedia", "")}


def dettagli(luogo: dict) -> dict:
    """Orari (e se è aperto adesso), telefono, sito, indirizzo completo del luogo."""
    osm = str(luogo.get("osm") or "")
    if not osm:
        return dict(luogo)
    _pausa_nominatim()
    q = {"osm_ids": osm, "format": "jsonv2", "extratags": "1", "addressdetails": "1", "accept-language": "it"}
    try:
        r = _json(f"{NOMINATIM}/lookup?{urllib.parse.urlencode(q)}")
    except (OSError, ValueError):
        return dict(luogo)
    if not r:
        return dict(luogo)
    risultato = {**luogo, **{k: v for k, v in _luogo(r[0]).items() if v}}
    risultato.update(_dettagli_da_tag(r[0].get("extratags") or {}))
    risultato["indirizzo"] = r[0].get("display_name", "")
    return risultato


def collegamento(lat: float, lon: float, nome: str = "") -> str:
    """Un indirizzo web per condividere il luogo (si apre su qualsiasi dispositivo)."""
    return f"https://www.openstreetmap.org/?mlat={lat:.6f}&mlon={lon:.6f}#map=17/{lat:.6f}/{lon:.6f}"


# ── Mappe senza rete: scaricare una zona ────────────────────────────────────
def tessere_zona(lat0: float, lon0: float, lat1: float, lon1: float, zoom_max: int = 14) -> list[tuple[int, int, int]]:
    out = []
    for z in range(6, zoom_max + 1):
        n = 2 ** z

        def tx(lo):
            return int((lo + 180) / 360 * n)

        def ty(la):
            r = math.radians(max(-85.0, min(85.0, la)))
            return int((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n)

        for x in range(min(tx(lon0), tx(lon1)), max(tx(lon0), tx(lon1)) + 1):
            for y in range(min(ty(lat0), ty(lat1)), max(ty(lat0), ty(lat1)) + 1):
                out.append((z, x, y))
    return out


def _vicino_al_percorso(forma: list, lat: float, lon: float, da: int = 0) -> tuple[int, float]:
    """Indice del punto del percorso più vicino (cercando poco avanti) e la distanza in metri."""
    migliore, metri = da, float("inf")
    for i in range(max(0, da - 5), min(len(forma), da + 400)):
        d = distanza(lat, lon, forma[i][0], forma[i][1])
        if d < metri:
            migliore, metri = i, d
    return migliore, metri


def guida(p: dict, lat: float, lon: float, indice: int = 0) -> dict:
    """A che punto si è del percorso «p»: prossima manovra, distanza, tempo che manca."""
    forma, manovre = p.get("forma") or [], p.get("manovre") or []
    if not forma or not manovre:
        return {"ok": False}
    i, fuori = _vicino_al_percorso(forma, lat, lon, indice)
    # la prossima manovra è la prima che comincia dopo il punto in cui si è
    prossima = next((m for m in manovre if m["inizio"] > i), manovre[-1])
    k = prossima["inizio"]
    alla_manovra = sum(distanza(*forma[j], *forma[j + 1]) for j in range(i, min(k, len(forma) - 1)))
    alla_manovra += distanza(lat, lon, *forma[i])
    resto_metri = alla_manovra + sum(m["metri"] for m in manovre if m["inizio"] >= k)
    resto_secondi = p.get("secondi", 0) * (resto_metri / p["metri"]) if p.get("metri") else 0
    arrivato = i >= len(forma) - 2 and distanza(lat, lon, *forma[-1]) < 30
    return {"ok": True, "indice": i, "fuori": fuori > 60, "arrivato": arrivato,
            "manovra": prossima, "allaManovra": testo_distanza(alla_manovra), "metriAllaManovra": alla_manovra,
            "resta": testo_distanza(resto_metri), "tempo": testo_tempo(resto_secondi),
            "arrivo": time.strftime("%H:%M", time.localtime(time.time() + resto_secondi))}
