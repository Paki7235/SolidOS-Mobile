"""Lettura del branding generato in build (/usr/share/nucleo/branding.env)."""

from __future__ import annotations

import os
import shlex
from functools import lru_cache
from pathlib import Path

PERCORSI = [
    Path(os.environ.get("NUCLEO_BRANDING", "/usr/share/nucleo/branding.env")),
    Path(__file__).resolve().parents[2] / "build" / "albero" / "branding.env",
]

PREDEFINITI = {
    "OS_NAME": "SolidOS",
    "OS_ID": "solidos",
    "OS_VERSION": "0.1",
    "LINGUA": "it",
    "COLORE_ACCENTO": "#3B82F6",
    "COLORE_ACCENTO_SCURO": "#1D4ED8",
    "COLORE_SFONDO_SCURO": "#0B1220",
    "COLORE_SUPERFICIE_SCURA": "#141C2E",
    "COLORE_SFONDO_CHIARO": "#F5F7FB",
    "COLORE_TESTO_SCURO": "#0F172A",
    "COLORE_TESTO_CHIARO": "#E8EEF8",
    "FONT_UI": "Inter",
    "FONT_UI_DIMENSIONE": "10",
}


@lru_cache(maxsize=1)
def valori() -> dict[str, str]:
    """Restituisce tutte le variabili del branding."""
    dati = dict(PREDEFINITI)
    for percorso in PERCORSI:
        if percorso.is_file():
            for riga in percorso.read_text(encoding="utf-8").splitlines():
                riga = riga.strip()
                if not riga or riga.startswith("#") or "=" not in riga:
                    continue
                chiave, valore = riga.split("=", 1)
                try:
                    parti = shlex.split(valore)
                    dati[chiave] = parti[0] if parti else ""
                except ValueError:
                    dati[chiave] = valore
            break
    return dati


def get(chiave: str, predefinito: str = "") -> str:
    return valori().get(chiave, predefinito)


def nome() -> str:
    return get("OS_NAME")


def id_os() -> str:
    return get("OS_ID")


def nome_dbus(servizio: str) -> str:
    """Nome D-Bus derivato dall'identificatore, es. org.solidos.Shell."""
    return f"org.{id_os()}.{servizio}"


def percorso_dbus(servizio: str) -> str:
    return f"/org/{id_os()}/{servizio}"


def comando(app: str) -> str:
    """Nome del comando di un'app, es. solidos-impostazioni."""
    return f"{id_os()}-{app}"


def tema() -> dict[str, str]:
    """Colori e font per l'interfaccia QML (oggetto «Tema»)."""
    v = valori()
    return {
        "accento": v["COLORE_ACCENTO"],
        "accentoScuro": v["COLORE_ACCENTO_SCURO"],
        "sfondo": v["COLORE_SFONDO_SCURO"],
        "superficie": v["COLORE_SUPERFICIE_SCURA"],
        "sfondoChiaro": v["COLORE_SFONDO_CHIARO"],
        "testo": v["COLORE_TESTO_CHIARO"],
        "testoScuro": v["COLORE_TESTO_SCURO"],
        "font": v["FONT_UI"],
        "fontDimensione": int(v.get("FONT_UI_DIMENSIONE", "10") or 10),
        "nomeSistema": v["OS_NAME"],
        "idSistema": v["OS_ID"],
        "versione": v.get("OS_VERSION", ""),
    }
