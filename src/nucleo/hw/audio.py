"""Audio tramite PipeWire (wpctl) e l'interfaccia compatibile PulseAudio (pactl)."""

from __future__ import annotations

import json
import re

from ..sistema import esegui, uscita

USCITA = "@DEFAULT_AUDIO_SINK@"
INGRESSO = "@DEFAULT_AUDIO_SOURCE@"


def volume(dispositivo: str = USCITA) -> dict:
    testo = uscita(["wpctl", "get-volume", dispositivo], timeout=5)
    m = re.search(r"Volume:\s*([\d.]+)", testo)
    return {"volume": round(float(m.group(1)) * 100) if m else 0, "muto": "MUTED" in testo}


def imposta_volume(percentuale: int, dispositivo: str = USCITA) -> None:
    percentuale = max(0, min(150, int(percentuale)))
    esegui(["wpctl", "set-volume", "-l", "1.5", dispositivo, f"{percentuale}%"], timeout=5)


def cambia_volume(passo: int, dispositivo: str = USCITA) -> dict:
    segno = "+" if passo >= 0 else "-"
    esegui(["wpctl", "set-volume", "-l", "1.0", dispositivo, f"{abs(passo)}%{segno}"], timeout=5)
    return volume(dispositivo)


def imposta_muto(muto: bool | None = None, dispositivo: str = USCITA) -> dict:
    valore = "toggle" if muto is None else ("1" if muto else "0")
    esegui(["wpctl", "set-mute", dispositivo, valore], timeout=5)
    return volume(dispositivo)


def _pactl_json(oggetto: str) -> list[dict]:
    try:
        return json.loads(uscita(["pactl", "-f", "json", "list", oggetto], timeout=5) or "[]")
    except json.JSONDecodeError:
        return []


def dispositivi(tipo: str = "sinks") -> list[dict]:
    """tipo: «sinks» (uscite) o «sources» (ingressi)."""
    predefinito = uscita(["pactl", "get-default-sink" if tipo == "sinks" else "get-default-source"]).strip()
    risultato = []
    for d in _pactl_json(tipo):
        if tipo == "sources" and d.get("monitor_of_sink"):
            continue
        risultato.append({"nome": d.get("name", ""), "descrizione": d.get("description", d.get("name", "")),
                          "predefinito": d.get("name") == predefinito})
    return risultato


def imposta_predefinito(nome: str, tipo: str = "sinks") -> bool:
    cmd = "set-default-sink" if tipo == "sinks" else "set-default-source"
    return esegui(["pactl", cmd, nome]).returncode == 0


def flussi_app() -> list[dict]:
    """Volume per applicazione (sink-input)."""
    risultato = []
    for f in _pactl_json("sink-inputs"):
        prop = f.get("properties", {})
        volumi = f.get("volume", {})
        perc = 100
        for canale in volumi.values():
            try:
                perc = int(str(canale.get("value_percent", "100%")).rstrip("%"))
                break
            except (AttributeError, ValueError):
                pass
        risultato.append({"indice": f.get("index"), "app": prop.get("application.name", "?"),
                          "icona": prop.get("application.icon_name", "audio-x-generic"),
                          "volume": perc, "muto": f.get("mute", False)})
    return risultato


def imposta_volume_app(indice: int, percentuale: int) -> None:
    esegui(["pactl", "set-sink-input-volume", str(indice), f"{int(percentuale)}%"])
