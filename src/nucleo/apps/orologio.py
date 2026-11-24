"""Orologio: ora nel mondo, sveglie, cronometro e timer (dati in nucleo/orologio.py; a suonare
ci pensa il servizio degli avvisi, anche ad app chiusa)."""

from __future__ import annotations

import sys

from .. import orologio
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendOrologio(Backend):
    def sveglie(self) -> list:
        return orologio.sveglie()

    def salvaSveglia(self, s: dict) -> list:
        return orologio.salva_sveglia(dict(s))

    def attivaSveglia(self, ident: str, si: bool) -> list:
        return orologio.attiva_sveglia(str(ident), bool(si))

    def togliSveglia(self, ident: str) -> list:
        return orologio.togli_sveglia(str(ident))

    def prossima(self) -> str:
        return orologio.prossima_sveglia()

    def timer(self) -> dict:
        return orologio.timer()

    def avviaTimer(self, secondi: float, etichetta: str = "") -> dict:
        return orologio.avvia_timer(float(secondi), str(etichetta))

    def pausaTimer(self, si: bool) -> dict:
        return orologio.pausa_timer(bool(si))

    def fermaTimer(self) -> dict:
        return orologio.ferma_timer()

    def mondo(self) -> list:
        return orologio.mondo()

    def citta(self, testo: str) -> list:
        return orologio.citta_disponibili(str(testo))

    def aggiungiCitta(self, c: str) -> list:
        return orologio.aggiungi_citta(str(c))

    def togliCitta(self, c: str) -> list:
        return orologio.togli_citta(str(c))


def main() -> int:
    return esegui_app("orologio", "Orologio/Main.qml", lambda app: {"ponte": crea_ponte(BackendOrologio())})


if __name__ == "__main__":
    sys.exit(main())
