"""Posizione di questo computer per «Dov'è».

Un PC non ha il GPS: si usano le reti Wi-Fi vicine (servizio aperto BeaconDB,
precisione di qualche decina di metri) e, se non ci sono, l'indirizzo internet
(precisione di città). Si invia solo se «Dov'è» è attivo.
"""

from __future__ import annotations

import json
import subprocess
import urllib.request

from .. import branding

BEACONDB = "https://api.beacondb.net/v1/geolocate"


def _reti_wifi() -> list[dict]:
    try:
        uscita = subprocess.run(["nmcli", "-t", "-f", "BSSID,SIGNAL", "device", "wifi", "list", "--rescan", "auto"],
                                capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    reti = []
    for riga in uscita.splitlines():
        # BSSID con «\:» al posto dei due punti (formato -t di nmcli)
        parti = riga.replace("\\:", "-").split(":")
        if len(parti) < 2 or not parti[1].isdigit():
            continue
        mac = parti[0].replace("-", ":").lower()
        segnale = int(parti[1])
        reti.append({"macAddress": mac, "signalStrength": int(segnale / 2 - 100)})   # % → dBm circa
    return reti[:30]


def trova() -> dict | None:
    """{lat, lon, precisione (metri), fonte: wifi|ip} oppure None."""
    reti = _reti_wifi()
    corpo = {"considerIp": True}
    if len(reti) >= 2:
        corpo["wifiAccessPoints"] = reti
    req = urllib.request.Request(BEACONDB, data=json.dumps(corpo).encode(), method="POST",
                                 headers={"Content-Type": "application/json",
                                          "User-Agent": f"{branding.nome()}-Dove/{branding.get('OS_VERSION', '')}"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            dati = json.loads(r.read())
    except (OSError, ValueError):
        return None
    pos = dati.get("location") or {}
    if "lat" not in pos or "lng" not in pos:
        return None
    precisione = float(dati.get("accuracy") or 0) or None
    fonte = "wifi" if len(reti) >= 2 and (precisione or 99999) < 2000 else "ip"
    return {"lat": float(pos["lat"]), "lon": float(pos["lng"]), "precisione": precisione, "fonte": fonte}
