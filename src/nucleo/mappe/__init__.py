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
    return {"nome": nome, "dettaglio": dettaglio or r.get("display_name", ""), "indirizzo": r.get("display_name", ""),
            "lat": float(r["lat"]), "lon": float(r["lon"]), "tipo": r.get("type", "")}


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


def percorso(da: dict, a: dict, mezzo: str = "auto") -> dict:
    """Il percorso da «da» ad «a» ({lat, lon}): forma, manovre con le indicazioni, tempi."""
    corpo = {"locations": [{"lat": da["lat"], "lon": da["lon"]}, {"lat": a["lat"], "lon": a["lon"]}],
             "costing": MEZZI.get(mezzo, "auto"),
             "directions_options": {"language": "it-IT", "units": "kilometers"}}
    try:
        r = _json(f"{VALHALLA}?json={urllib.parse.quote(json.dumps(corpo))}", timeout=30)
    except urllib.error.HTTPError as e:   # 400: non c'è un percorso (mare, troppo lontano…)
        try:
            messaggio = json.loads(e.read()).get("error", "")
        except (OSError, ValueError):
            messaggio = ""
        return {"ok": False, "messaggio": T("Nessun percorso trovato") + (f" ({messaggio})" if messaggio else "")}
    except (OSError, ValueError):
        return {"ok": False, "messaggio": T("Impossibile calcolare il percorso: controlla la connessione")}
    viaggio = r.get("trip") or {}
    tratto = (viaggio.get("legs") or [{}])[0]
    forma = _polilinea(tratto.get("shape", ""))
    manovre = []
    for m in tratto.get("maneuvers", []):
        manovre.append({"tipo": m.get("type", 0), "testo": m.get("instruction", ""),
                        "annuncio": m.get("verbal_pre_transition_instruction") or m.get("instruction", ""),
                        "metri": float(m.get("length", 0)) * 1000, "secondi": float(m.get("time", 0)),
                        "inizio": int(m.get("begin_shape_index", 0)), "fine": int(m.get("end_shape_index", 0)),
                        "via": ", ".join(m.get("street_names") or [])})
    s = viaggio.get("summary") or {}
    metri, secondi = float(s.get("length", 0)) * 1000, float(s.get("time", 0))
    return {"ok": True, "forma": forma, "manovre": manovre, "metri": metri, "secondi": secondi,
            "distanza": testo_distanza(metri), "tempo": testo_tempo(secondi), "mezzo": mezzo,
            "arrivo": time.strftime("%H:%M", time.localtime(time.time() + secondi))}


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
