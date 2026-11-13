"""Bluetooth tramite bluetoothctl (BlueZ)."""

from __future__ import annotations

import re

from ..sistema import esegui, esiste, uscita


def disponibile() -> bool:
    from pathlib import Path

    if not any(Path("/sys/class/bluetooth").glob("hci*")):
        return False            # nessun adattatore: risposta immediata
    return esiste("bluetoothctl") and "Controller" in uscita(["bluetoothctl", "list"], timeout=3)


def attivo() -> bool:
    from pathlib import Path

    if not any(Path("/sys/class/bluetooth").glob("hci*")):
        return False
    return "Powered: yes" in uscita(["bluetoothctl", "show"], timeout=3)


def imposta(acceso: bool) -> bool:
    if acceso:
        esegui(["rfkill", "unblock", "bluetooth"])
    return esegui(["bluetoothctl", "power", "on" if acceso else "off"], timeout=10).returncode == 0


def dispositivi() -> list[dict]:
    associati = {m for m, _ in _elenco(["bluetoothctl", "devices", "Paired"])}
    connessi = {m for m, _ in _elenco(["bluetoothctl", "devices", "Connected"])}
    return [{"indirizzo": m, "nome": n, "associato": m in associati, "connesso": m in connessi}
            for m, n in _elenco(["bluetoothctl", "devices"])]


def _elenco(cmd: list[str]) -> list[tuple[str, str]]:
    risultato = []
    for riga in uscita(cmd, timeout=8).splitlines():
        m = re.match(r"Device ([0-9A-F:]{17}) (.*)", riga.strip())
        if m:
            risultato.append((m.group(1), m.group(2)))
    return risultato


def cerca(secondi: int = 8) -> list[dict]:
    esegui(["bluetoothctl", "--timeout", str(secondi), "scan", "on"], timeout=secondi + 5)
    return dispositivi()


def associa(indirizzo: str) -> bool:
    esegui(["bluetoothctl", "trust", indirizzo], timeout=10)
    if esegui(["bluetoothctl", "pair", indirizzo], timeout=40).returncode != 0:
        return False
    return esegui(["bluetoothctl", "connect", indirizzo], timeout=20).returncode == 0


def connetti(indirizzo: str, connesso: bool = True) -> bool:
    azione = "connect" if connesso else "disconnect"
    return esegui(["bluetoothctl", azione, indirizzo], timeout=20).returncode == 0


def rimuovi(indirizzo: str) -> bool:
    return esegui(["bluetoothctl", "remove", indirizzo], timeout=10).returncode == 0
