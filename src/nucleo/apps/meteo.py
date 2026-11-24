"""Meteo: le città salvate e la posizione attuale a sinistra; a destra il tempo di adesso,
le prossime 24 ore, i prossimi 10 giorni e i dettagli (percepita, umidità, vento, UV, alba e
tramonto, qualità dell'aria, visibilità, pressione). Dati di Open-Meteo (nucleo/meteo.py)."""

from __future__ import annotations

import sys

from .. import meteo
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendMeteo(Backend):
    def luoghi(self) -> list:
        return meteo.luoghi()

    def qui(self) -> dict:
        return meteo.qui()

    def cerca(self, testo: str) -> list:
        return meteo.cerca_citta(str(testo))

    def salva(self, luogo: dict) -> list:
        return meteo.salva_luogo(dict(luogo))

    def togli(self, lat: float, lon: float) -> list:
        return meteo.togli_luogo(float(lat), float(lon))

    def previsioni(self, lat: float, lon: float, nome: str) -> dict:
        p = meteo.previsioni(float(lat), float(lon), str(nome))
        if p.get("ok"):
            p["giudizioUv"] = meteo.giudizio_uv(p.get("uv", 0))
        return p


def main() -> int:
    return esegui_app("meteo", "Meteo/Main.qml", lambda app: {"ponte": crea_ponte(BackendMeteo())})


if __name__ == "__main__":
    sys.exit(main())
