"""Traduzioni.

Il testo sorgente è l'italiano (lingua predefinita). Per le altre lingue si
usano cataloghi JSON in /usr/share/nucleo/i18n/<lingua>.json nella forma
{"testo italiano": "traduzione"}. Un testo senza traduzione resta in italiano.
"""

from __future__ import annotations

import json
import locale
import os
from functools import lru_cache
from pathlib import Path

CARTELLA = Path(os.environ.get("NUCLEO_I18N", "/usr/share/nucleo/i18n"))


def lingua_corrente() -> str:
    for var in ("LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"):
        valore = os.environ.get(var, "")
        if valore and valore not in ("C", "POSIX", "C.UTF-8"):
            return valore.split(":")[0].split("_")[0].split(".")[0]
    try:
        loc = locale.getlocale()[0]
        if loc:
            return loc.split("_")[0]
    except ValueError:
        pass
    return "it"


@lru_cache(maxsize=4)
def catalogo(lingua: str) -> dict[str, str]:
    if lingua == "it":
        return {}
    file = CARTELLA / f"{lingua}.json"
    if not file.is_file():
        return {}
    try:
        return json.loads(file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def T(testo: str, **valori) -> str:
    """Traduce un testo e sostituisce i segnaposto {nome}."""
    tradotto = catalogo(lingua_corrente()).get(testo, testo)
    if valori:
        try:
            return tradotto.format(**valori)
        except (KeyError, IndexError):
            return tradotto
    return tradotto
