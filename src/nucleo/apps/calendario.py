"""Calendario: mese, settimana e giorno; calendari con i colori; eventi con ripetizione,
avviso, luogo e note; importa ed esporta i file .ics. Dati in nucleo/agenda.py (gli avvisi
li dà il servizio della sessione, anche ad app chiusa)."""

from __future__ import annotations

import sys

from .. import agenda
from ..i18n import T
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app


class BackendCalendario(Backend):
    def calendari(self) -> list:
        return agenda.calendari()

    def salvaCalendario(self, c: dict) -> list:
        return agenda.salva_calendario(dict(c))

    def mostraCalendario(self, ident: str, si: bool) -> list:
        return agenda.mostra_calendario(str(ident), bool(si))

    def eventi(self, da: str, a: str) -> list:
        return agenda.eventi_tra(str(da), str(a))

    def salvaEvento(self, e: dict) -> dict:
        return agenda.salva_evento(dict(e))

    def eliminaEvento(self, ident: str) -> None:
        agenda.elimina_evento(str(ident))

    def promemoriaOggi(self) -> list:
        return agenda.promemoria("oggi")

    def opzioni(self) -> dict:
        return {"ripeti": [{"id": k, "nome": T(v)} for k, v in agenda.RIPETI.items()],
                "avvisi": [{"id": k, "nome": T(v)} for k, v in agenda.AVVISI.items()], "colori": agenda.COLORI}

    def importa(self, percorso: str, calendario: str = "personale") -> dict:
        return agenda.importa_ics(str(percorso), str(calendario))

    def esporta(self) -> dict:
        return agenda.esporta_ics()


def main() -> int:
    file_ics = next((a for a in sys.argv[1:] if a.lower().endswith(".ics")), "")

    def contesto(app):
        b = BackendCalendario()
        if file_ics:
            b.importa(file_ics)
        return {"ponte": crea_ponte(b)}

    return esegui_app("calendario", "Calendario/Main.qml", contesto)


if __name__ == "__main__":
    sys.exit(main())
