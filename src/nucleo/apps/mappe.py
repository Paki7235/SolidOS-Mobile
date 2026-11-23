"""Mappe: le mappe di SolidOS (disegnate da noi dai dati di OpenStreetMap), la ricerca dei
luoghi, i percorsi in auto, bici o a piedi e il navigatore con le indicazioni a voce.

Sul PC la posizione arriva dalle reti Wi-Fi vicine (qualche decina di metri); sul telefono
dal GPS. «Prova il percorso» fa scorrere la guida lungo il percorso, anche da fermi.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from .. import mappe
from ..mappe import disegno
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import config_utente, leggi_json, scrivi_json


def _gps() -> dict | None:
    """Posizione dal GPS del modem (i telefoni con ModemManager); None se non c'è."""
    import json as _json

    if not shutil.which("mmcli"):
        return None
    try:
        subprocess.run(["mmcli", "-m", "any", "--location-enable-gps-raw"], capture_output=True, timeout=8)
        uscita = subprocess.run(["mmcli", "-m", "any", "--location-get", "-J"], capture_output=True, text=True,
                                timeout=8).stdout
        gps = (_json.loads(uscita or "{}").get("modem", {}).get("location", {}) or {}).get("gps", {}) or {}
        lat, lon = float(gps.get("latitude", "--")), float(gps.get("longitude", "--"))
    except (OSError, ValueError, subprocess.TimeoutExpired, AttributeError):
        return None
    return {"lat": lat, "lon": lon, "precisione": 10, "fonte": "gps"}


class BackendMappe(Backend):
    def __init__(self):
        self._pool = ThreadPoolExecutor(max_workers=4)
        self._percorso: dict = {}

    # ── Carta ───────────────────────────────────────────────────────────────
    def tessere(self, richieste: list, tema: str) -> dict:
        def una(t):
            z, x, y = (int(v) for v in t)
            try:
                f = disegno.tessera(z, x, y, tema)
            except Exception:  # noqa: BLE001 — una tessera sbagliata non deve fermare le altre
                f = ""
            return f"{tema}/{z}/{x}/{y}", ("file://" + f) if f else ""

        # anche le tessere non riuscite (vuote): la carta le richiede quando ci si sposta
        return dict(self._pool.map(una, richieste))

    # ── Dove sono ───────────────────────────────────────────────────────────
    def posizione(self) -> dict:
        """Dal GPS se c'è (telefono: ModemManager), altrimenti dalle reti Wi-Fi vicine."""
        p = _gps()
        if p:
            return p
        try:
            from ..solidid.posizione import trova

            p = trova()
        except Exception:  # noqa: BLE001
            p = None
        return p or {}

    def indirizzo(self, lat: float, lon: float) -> dict:
        return mappe.indirizzo(float(lat), float(lon))

    # ── Ricerca, preferiti e recenti ────────────────────────────────────────
    def cerca(self, testo: str, lat=None, lon=None) -> list:
        return mappe.cerca(str(testo), float(lat) if lat not in (None, "") else None,
                           float(lon) if lon not in (None, "") else None)

    def salvati(self) -> dict:
        return leggi_json(config_utente("mappe.json"), {"preferiti": [], "recenti": []})

    def ricorda(self, luogo: dict) -> None:
        c = self.salvati()
        luogo = {k: luogo.get(k) for k in ("nome", "dettaglio", "lat", "lon")}
        c["recenti"] = [luogo] + [r for r in c.get("recenti", []) if (r.get("lat"), r.get("lon")) != (luogo["lat"], luogo["lon"])][:11]
        scrivi_json(config_utente("mappe.json"), c)

    def preferito(self, luogo: dict, etichetta: str = "") -> dict:
        """Salva un luogo tra i preferiti («Casa», «Lavoro» o col suo nome); di nuovo lo toglie."""
        c = self.salvati()
        chiave = (luogo.get("lat"), luogo.get("lon"))
        gia = [p for p in c.get("preferiti", []) if (p.get("lat"), p.get("lon")) == chiave]
        if gia and not etichetta:
            c["preferiti"] = [p for p in c["preferiti"] if (p.get("lat"), p.get("lon")) != chiave]
        else:
            if etichetta:   # un solo «Casa» e un solo «Lavoro»
                c["preferiti"] = [p for p in c.get("preferiti", []) if p.get("etichetta") != etichetta]
            c["preferiti"] = c.get("preferiti", []) + [{**{k: luogo.get(k) for k in ("nome", "dettaglio", "lat", "lon")},
                                                        "etichetta": etichetta}]
        scrivi_json(config_utente("mappe.json"), c)
        return c

    # ── Percorso e guida ────────────────────────────────────────────────────
    def percorso(self, da: dict, a: dict, mezzo: str) -> dict:
        p = mappe.percorso(dict(da), dict(a), str(mezzo))
        self._percorso = p if p.get("ok") else {}
        return p

    def guida(self, lat: float, lon: float, indice: int = 0) -> dict:
        if not self._percorso:
            return {"ok": False}
        return mappe.guida(self._percorso, float(lat), float(lon), int(indice))

    def parla(self, testo: str) -> None:
        """Indicazioni a voce (se c'è la sintesi vocale del sistema)."""
        if shutil.which("spd-say"):
            subprocess.Popen(["spd-say", "-l", "it", "-r", "-10", str(testo)], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)

    def testoDistanza(self, metri: float) -> str:
        return mappe.testo_distanza(float(metri))


def main() -> int:
    return esegui_app("mappe", "Mappe/Main.qml", lambda app: {"ponte": crea_ponte(BackendMappe())})


if __name__ == "__main__":
    sys.exit(main())
