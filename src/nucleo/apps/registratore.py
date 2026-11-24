"""Registratore vocale: registra con pausa e il livello dal vivo, poi riascolta, rinomina,
condivide (apre la cartella) ed elimina. Dati in nucleo/registratore.py."""

from __future__ import annotations

from .. import registratore
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia


class BackendRegistratore(Backend):
    def avvia(self) -> dict:
        return registratore.avvia()

    def pausa(self, si: bool) -> dict:
        return registratore.pausa(bool(si))

    def stato(self) -> dict:
        return registratore.stato()

    def ferma(self, tieni: bool = True) -> dict:
        return registratore.ferma(bool(tieni))

    def elenco(self) -> list:
        return registratore.elenco()

    def rinomina(self, ident: str, nome: str) -> dict:
        return registratore.rinomina(str(ident), str(nome))

    def elimina(self, ident: str) -> bool:
        return registratore.elimina(str(ident))

    def apriCartella(self) -> None:
        avvia(["xdg-open", str(registratore.cartella())])


def main() -> int:
    try:
        return esegui_app("registratore", "Registratore/Main.qml", lambda app: {"ponte": crea_ponte(BackendRegistratore())})
    finally:
        registratore.ferma(True)     # chiudendo la finestra durante una registrazione, la si salva


if __name__ == "__main__":
    raise SystemExit(main())
