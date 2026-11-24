"""Contatti (come sul telefono): elenco con ricerca e lettere, scheda grande con
le azioni (email, sito, mappa), modifica, preferiti, «La mia scheda», importa ed esporta vCard.
Stesso archivio dei Contatti del telefono (nucleo/rubrica.py)."""

from __future__ import annotations

import sys
import urllib.parse

from .. import rubrica
from ..ponte import Backend, crea_ponte
from ..qmlapp import esegui_app
from ..sistema import avvia


class BackendContatti(Backend):
    def contatti(self) -> list:
        return rubrica.contatti()

    def miaScheda(self) -> dict:
        return rubrica.mia_scheda()

    def salva(self, dati: dict) -> dict:
        return rubrica.salva_scheda(dict(dati))

    def elimina(self, ident: str) -> None:
        rubrica.elimina_contatto(str(ident))

    def preferito(self, ident: str, si: bool) -> None:
        rubrica.preferito(str(ident), bool(si))

    def importa(self, percorso: str) -> dict:
        return rubrica.importa_vcard(str(percorso))

    def esporta(self) -> dict:
        return rubrica.esporta_vcard()

    def apri(self, tipo: str, valore: str) -> None:
        """Email, sito o indirizzo sulla mappa con le app predefinite."""
        valore = str(valore).strip()
        if not valore:
            return
        if tipo == "email":
            url = "mailto:" + valore
        elif tipo == "sito":
            url = valore if "://" in valore else "https://" + valore
        elif tipo == "indirizzo":
            url = "https://www.openstreetmap.org/search?query=" + urllib.parse.quote(valore)
        elif tipo == "numero":
            url = "tel:" + rubrica.normalizza(valore)
        else:
            return
        avvia(["xdg-open", url])


def main() -> int:
    file_da_aprire = next((a for a in sys.argv[1:] if a.lower().endswith(".vcf")), "")

    def contesto(app):
        b = BackendContatti()
        if file_da_aprire:   # doppio clic su un .vcf: si importa subito
            b.importa(file_da_aprire)
        return {"ponte": crea_ponte(b)}

    return esegui_app("contatti", "Contatti/Main.qml", contesto)


if __name__ == "__main__":
    sys.exit(main())
