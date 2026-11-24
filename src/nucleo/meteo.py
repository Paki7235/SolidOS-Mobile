"""Meteo di SolidOS, comune a PC e telefono.

Dati di Open-Meteo (gratuito, senza chiave, licenza CC BY 4.0): il tempo di adesso, le prossime
24 ore, i prossimi 10 giorni, alba e tramonto, vento, umidità, indice UV e qualità dell'aria.
Le città salvate stanno in ~/.config/<os>/meteo.json; le risposte restano in memoria 20 minuti.
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

from . import branding
from .i18n import T
from .sistema import config_utente, leggi_json, scrivi_json

PREVISIONI = "https://api.open-meteo.com/v1/forecast"
ARIA = "https://air-quality-api.open-meteo.com/v1/air-quality"
CITTA = "https://geocoding-api.open-meteo.com/v1/search"
GIORNI = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]

# codice del tempo (WMO) → descrizione, simbolo di giorno, simbolo di notte
CODICI = {
    0: ("Sereno", "sole", "luna"), 1: ("Quasi sereno", "parz-nuvoloso", "luna"), 2: ("Poco nuvoloso", "parz-nuvoloso", "nuvola"),
    3: ("Nuvoloso", "nuvola", "nuvola"), 45: ("Nebbia", "nebbia", "nebbia"), 48: ("Nebbia con brina", "nebbia", "nebbia"),
    51: ("Pioviggine leggera", "pioggia", "pioggia"), 53: ("Pioviggine", "pioggia", "pioggia"), 55: ("Pioviggine forte", "pioggia", "pioggia"),
    56: ("Pioviggine gelata", "pioggia", "pioggia"), 57: ("Pioviggine gelata", "pioggia", "pioggia"),
    61: ("Pioggia leggera", "pioggia", "pioggia"), 63: ("Pioggia", "pioggia", "pioggia"), 65: ("Pioggia forte", "pioggia", "pioggia"),
    66: ("Pioggia gelata", "pioggia", "pioggia"), 67: ("Pioggia gelata", "pioggia", "pioggia"),
    71: ("Neve leggera", "neve", "neve"), 73: ("Neve", "neve", "neve"), 75: ("Neve forte", "neve", "neve"), 77: ("Nevischio", "neve", "neve"),
    80: ("Rovesci", "pioggia", "pioggia"), 81: ("Rovesci", "pioggia", "pioggia"), 82: ("Rovesci forti", "pioggia", "pioggia"),
    85: ("Rovesci di neve", "neve", "neve"), 86: ("Rovesci di neve", "neve", "neve"),
    95: ("Temporale", "temporale", "temporale"), 96: ("Temporale con grandine", "temporale", "temporale"),
    99: ("Temporale con grandine", "temporale", "temporale"),
}
DIREZIONI = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]


def _json(url: str, timeout: float = 15):
    req = urllib.request.Request(url, headers={"User-Agent": f"{branding.nome()}-Meteo/{branding.get('OS_VERSION', '0')}"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def _codice(c, giorno: bool = True) -> tuple[str, str]:
    d, s_giorno, s_notte = CODICI.get(int(c or 0), ("", "nuvola", "nuvola"))
    return T(d), s_giorno if giorno else s_notte


# ── Città ────────────────────────────────────────────────────────────────────
def cerca_citta(testo: str) -> list[dict]:
    testo = testo.strip()
    if len(testo) < 2:
        return []
    try:
        r = _json(f"{CITTA}?{urllib.parse.urlencode({'name': testo, 'count': 8, 'language': 'it'})}")
    except (OSError, ValueError):
        return []
    return [{"nome": c.get("name", ""), "regione": ", ".join(x for x in (c.get("admin1", ""), c.get("country", "")) if x),
             "lat": c["latitude"], "lon": c["longitude"]} for c in r.get("results") or []]


def _file() -> Path:
    return config_utente("meteo.json")


def luoghi() -> list[dict]:
    return leggi_json(_file(), {}).get("luoghi", [])


def salva_luogo(luogo: dict) -> list[dict]:
    c = leggi_json(_file(), {})
    elenco = [x for x in c.get("luoghi", []) if (round(x["lat"], 3), round(x["lon"], 3)) != (round(luogo["lat"], 3), round(luogo["lon"], 3))]
    elenco.append({k: luogo.get(k) for k in ("nome", "regione", "lat", "lon")})
    c["luoghi"] = elenco
    scrivi_json(_file(), c)
    return elenco


def togli_luogo(lat: float, lon: float) -> list[dict]:
    c = leggi_json(_file(), {})
    c["luoghi"] = [x for x in c.get("luoghi", []) if (round(x["lat"], 3), round(x["lon"], 3)) != (round(lat, 3), round(lon, 3))]
    scrivi_json(_file(), c)
    return c["luoghi"]


def qui() -> dict:
    """La posizione di questo dispositivo (GPS o reti Wi-Fi), con il nome del posto."""
    try:
        from .solidid.posizione import trova

        p = trova() or {}
    except Exception:  # noqa: BLE001
        p = {}
    if "lat" not in p:
        return {}
    nome = T("La mia posizione")
    try:
        r = _json("https://nominatim.openstreetmap.org/reverse?" + urllib.parse.urlencode(
            {"lat": p["lat"], "lon": p["lon"], "format": "jsonv2", "zoom": "10", "accept-language": "it"}))
        a = r.get("address") or {}
        nome = a.get("city") or a.get("town") or a.get("village") or a.get("municipality") or nome
    except (OSError, ValueError):
        pass
    return {"nome": nome, "regione": T("La mia posizione"), "lat": p["lat"], "lon": p["lon"], "qui": True}


# ── Previsioni ───────────────────────────────────────────────────────────────
def _aria(lat: float, lon: float) -> dict:
    try:
        a = _json(f"{ARIA}?{urllib.parse.urlencode({'latitude': lat, 'longitude': lon, 'current': 'european_aqi,pm2_5', 'timezone': 'auto'})}")
    except (OSError, ValueError):
        return {}
    v = (a.get("current") or {}).get("european_aqi")
    if v is None:
        return {}
    for soglia, nome in ((20, "Buona"), (40, "Discreta"), (60, "Moderata"), (80, "Scadente"), (100, "Molto scadente")):
        if v <= soglia:
            return {"indice": round(v), "giudizio": T(nome)}
    return {"indice": round(v), "giudizio": T("Pessima")}


def previsioni(lat: float, lon: float, nome: str = "") -> dict:
    cache = Path.home() / ".cache" / branding.id_os() / "meteo" / f"{lat:.3f}_{lon:.3f}.json"
    try:
        dati = json.loads(cache.read_text())
        if time.time() - dati.get("_quando", 0) < 1200:
            return dati
    except (OSError, ValueError):
        dati = None
    q = {"latitude": lat, "longitude": lon, "timezone": "auto", "forecast_days": 10, "wind_speed_unit": "kmh",
         "current": "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m,"
                    "wind_direction_10m,precipitation,pressure_msl,visibility",
         "hourly": "temperature_2m,weather_code,precipitation_probability,is_day",
         "daily": "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,uv_index_max"}
    try:
        m = _json(f"{PREVISIONI}?{urllib.parse.urlencode(q)}")
    except (OSError, ValueError):
        if dati:
            dati["vecchie"] = True
            return dati
        return {"ok": False, "messaggio": T("Meteo non disponibile: controlla la connessione")}
    c, h, d = m.get("current") or {}, m.get("hourly") or {}, m.get("daily") or {}
    descrizione, simbolo = _codice(c.get("weather_code"), bool(c.get("is_day", 1)))
    # prossime 24 ore, da quella attuale
    adesso = (c.get("time") or "")[:13]
    tempi = h.get("time") or []
    i0 = next((i for i, t in enumerate(tempi) if t[:13] >= adesso), 0)
    ore = []
    for i in range(i0, min(i0 + 25, len(tempi))):
        ore.append({"ora": T("Ora") if i == i0 else tempi[i][11:13],
                    "gradi": round(h["temperature_2m"][i]),
                    "simbolo": _codice(h["weather_code"][i], bool(h["is_day"][i]))[1],
                    "pioggia": h["precipitation_probability"][i] or 0})
    giorni = []
    minimo = min(d.get("temperature_2m_min") or [0])
    massimo = max(d.get("temperature_2m_max") or [1])
    for i, giorno in enumerate(d.get("time") or []):
        t = time.strptime(giorno, "%Y-%m-%d")
        giorni.append({"giorno": T("Oggi") if i == 0 else T(GIORNI[t.tm_wday])[:3],
                       "simbolo": _codice(d["weather_code"][i])[1], "descrizione": _codice(d["weather_code"][i])[0],
                       "min": round(d["temperature_2m_min"][i]), "max": round(d["temperature_2m_max"][i]),
                       "pioggia": d["precipitation_probability_max"][i] or 0})
    oggi = 0
    vento = c.get("wind_direction_10m")
    risultato = {
        "ok": True, "nome": nome, "lat": lat, "lon": lon,
        "gradi": round(c.get("temperature_2m", 0)), "percepita": round(c.get("apparent_temperature", 0)),
        "descrizione": descrizione, "simbolo": simbolo, "giorno": bool(c.get("is_day", 1)),
        "max": round(d["temperature_2m_max"][oggi]) if d.get("temperature_2m_max") else 0,
        "min": round(d["temperature_2m_min"][oggi]) if d.get("temperature_2m_min") else 0,
        "umidita": c.get("relative_humidity_2m", 0), "pressione": round(c.get("pressure_msl", 0)),
        "vento": round(c.get("wind_speed_10m", 0)),
        "direzioneVento": DIREZIONI[int(((vento or 0) + 22.5) // 45) % 8] if vento is not None else "",
        "visibilita": round((c.get("visibility") or 0) / 1000), "precipitazioni": c.get("precipitation", 0),
        "uv": round((d.get("uv_index_max") or [0])[0] or 0),
        "alba": (d.get("sunrise") or [""])[0][11:16], "tramonto": (d.get("sunset") or [""])[0][11:16],
        "ore": ore, "giorni": giorni, "scalaMin": minimo, "scalaMax": massimo,
        "aria": _aria(lat, lon), "aggiornato": time.strftime("%H:%M"), "_quando": time.time(),
    }
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(risultato))
    return risultato


def giudizio_uv(uv: int) -> str:
    return T("Basso") if uv <= 2 else T("Moderato") if uv <= 5 else T("Alto") if uv <= 7 else T("Molto alto") if uv <= 10 else T("Estremo")
