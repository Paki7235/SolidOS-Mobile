"""Promemoria: liste con i colori, «Oggi», «Programmati», «Tutti», «Con bandiera» e «Completati»;
ogni promemoria può avere una scadenza (con l'ora, e allora arriva l'avviso), le note e la bandiera.
Dati in nucleo/agenda.py, condivisi con il Calendario."""

from __future__ import annotations

from .. import agenda
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendPromemoria(Backend):
    def liste(self) -> list:
        return agenda.liste()

    def salvaLista(self, l: dict) -> list:
        return agenda.salva_lista(dict(l))

    def eliminaLista(self, ident: str) -> list:
        return agenda.elimina_lista(str(ident))

    def conteggi(self) -> dict:
        return agenda.conteggi()

    def promemoria(self, filtro: str) -> list:
        return agenda.promemoria(str(filtro))

    def salva(self, p: dict) -> dict:
        return agenda.salva_promemoria(dict(p))

    def fatto(self, ident: str, si: bool) -> None:
        agenda.segna_fatto(str(ident), bool(si))

    def elimina(self, ident: str) -> None:
        agenda.elimina_promemoria(str(ident))

    def colori(self) -> list:
        return agenda.COLORI


def main() -> int:
    return esegui_app("promemoria", "Promemoria/Main.qml", lambda app: {"ponte": crea_ponte(BackendPromemoria())})


if __name__ == "__main__":
    raise SystemExit(main())
