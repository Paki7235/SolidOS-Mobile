"""Impostazioni del telefono: Wi-Fi, Bluetooth, rete mobile e SIM, suoni, schermo,
batteria, Solid ID e informazioni sul telefono.

Strumenti standard di Linux: nmcli (Wi-Fi e dati mobili), bluetoothctl, mmcli (SIM),
wpctl (volume), brightnessctl (luminosità), powerprofilesctl (risparmio energetico).
NUCLEO_DEMO=1 mostra dati di esempio (solo per le foto della prova).
"""

from __future__ import annotations

import os
import platform
import re
import shutil
import subprocess
from pathlib import Path

from .. import branding
from ..i18n import T
from .telefonia import DEMO, _mmcli, _modem, stato_modem


def _esegui(cmd: list[str], timeout: float = 20) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError) as e:
        return subprocess.CompletedProcess(cmd, 1, "", str(e))


# ── Wi-Fi ────────────────────────────────────────────────────────────────────
def wifi(scansiona: bool = False) -> dict:
    if DEMO:
        return {"acceso": True, "reti": [
            {"ssid": "Casa", "segnale": 86, "protetta": True, "connessa": True},
            {"ssid": "Vodafone-A1B2", "segnale": 61, "protetta": True, "connessa": False},
            {"ssid": "TIM-Ospiti", "segnale": 44, "protetta": False, "connessa": False},
            {"ssid": "Biblioteca", "segnale": 22, "protetta": True, "connessa": False}]}
    from ..hw import rete

    acceso = rete.wifi_attivo()
    return {"acceso": acceso, "reti": rete.reti_wifi(scansiona) if acceso else []}


def imposta_wifi(acceso: bool) -> None:
    if not DEMO:
        from ..hw import rete

        rete.imposta_wifi(bool(acceso))


def connetti_wifi(ssid: str, password: str) -> dict:
    if DEMO:
        return {"ok": True, "messaggio": T("Connesso a {r}", r=ssid)}
    from ..hw import rete

    r = rete.connetti_wifi(ssid, password)
    return {"ok": r["ok"], "messaggio": T("Connesso a {r}", r=ssid) if r["ok"] else r["messaggio"]}


def dimentica_wifi(ssid: str) -> dict:
    if not DEMO:
        _esegui(["nmcli", "connection", "delete", "id", ssid])
    return {"ok": True, "messaggio": T("Rete dimenticata")}


# ── Bluetooth ────────────────────────────────────────────────────────────────
def bluetooth() -> dict:
    if DEMO:
        return {"disponibile": True, "acceso": True, "dispositivi": [
            {"indirizzo": "AA:BB:CC:00:11:22", "nome": "Cuffie Pasquale", "connesso": True, "tipo": "audio-headphones"},
            {"indirizzo": "AA:BB:CC:00:33:44", "nome": "Auto", "connesso": False, "tipo": "audio-car"},
            {"indirizzo": "AA:BB:CC:00:55:66", "nome": "Portatile di Pasquale", "connesso": False, "tipo": "computer"}]}
    from ..hw import bluetooth as bt

    if not bt.disponibile():
        return {"disponibile": False, "acceso": False, "dispositivi": []}
    return {"disponibile": True, "acceso": bt.attivo(), "dispositivi": bt.dispositivi() if bt.attivo() else []}


def imposta_bluetooth(acceso: bool) -> None:
    if not DEMO:
        from ..hw import bluetooth as bt

        bt.imposta(bool(acceso))


def cerca_bluetooth() -> list:
    if DEMO:
        return [{"indirizzo": "AA:BB:CC:77:88:99", "nome": "Altoparlante cucina", "connesso": False, "tipo": "audio-speakers"}]
    from ..hw import bluetooth as bt

    noti = {d["indirizzo"] for d in bt.dispositivi()}
    return [d for d in bt.cerca(8) if d["indirizzo"] not in noti]


def azione_bluetooth(indirizzo: str, azione: str) -> dict:
    if DEMO:
        return {"ok": True, "messaggio": T("Fatto")}
    from ..hw import bluetooth as bt

    funzioni = {"associa": bt.associa, "connetti": lambda a: bt.connetti(a, True),
                "disconnetti": lambda a: bt.connetti(a, False), "rimuovi": bt.rimuovi}
    if azione not in funzioni or not re.fullmatch(r"[0-9A-Fa-f:]{17}", indirizzo):
        return {"ok": False, "messaggio": T("Azione non valida")}
    ok = funzioni[azione](indirizzo)
    testi = {"associa": T("Associato"), "connetti": T("Connesso"), "disconnetti": T("Disconnesso"), "rimuovi": T("Rimosso")}
    return {"ok": ok, "messaggio": testi[azione] if ok else T("Non riuscito: avvicina il dispositivo e riprova")}


# ── Rete mobile e SIM ────────────────────────────────────────────────────────
def _dati_attivi() -> bool:
    uscita = _esegui(["nmcli", "-t", "-f", "TYPE,STATE", "device"]).stdout
    return any(r.startswith("gsm:connected") for r in uscita.splitlines())


def rete_mobile(preferenze: dict) -> dict:
    m = stato_modem()
    if DEMO:
        dati = preferenze.get("dati_mobili", True)
        imei = "35 123456 789012 3"
    else:
        dati = _dati_attivi()
        mod = _modem()
        imei = _mmcli("-m", mod).get("modem", {}).get("3gpp", {}).get("imei", "") if mod else ""
    return {**m, "dati": dati, "roaming": bool(preferenze.get("roaming", False)), "imei": imei,
            "simDati": preferenze.get("sim_dati", "1")}


def imposta_dati(si: bool) -> dict:
    if DEMO:
        return {"ok": True}
    if si:
        _esegui(["nmcli", "radio", "wwan", "on"])
        r = _esegui(["nmcli", "-t", "-f", "NAME,TYPE", "connection"])
        gsm = [x.split(":")[0] for x in r.stdout.splitlines() if x.endswith(":gsm")]
        if gsm:
            ok = _esegui(["nmcli", "connection", "up", gsm[0]], timeout=60).returncode == 0
        else:
            # Prima volta: profilo automatico (l'APN lo sceglie ModemManager dal database degli operatori)
            ok = _esegui(["nmcli", "connection", "add", "type", "gsm", "ifname", "*", "con-name", "Dati mobili",
                          "apn", ""], timeout=30).returncode == 0
            ok = ok and _esegui(["nmcli", "connection", "up", "Dati mobili"], timeout=60).returncode == 0
        return {"ok": ok, "messaggio": "" if ok else T("Dati mobili non attivati: controlla la SIM e il segnale")}
    _esegui(["nmcli", "radio", "wwan", "off"])
    return {"ok": True}


def sblocca_sim(pin: str) -> dict:
    if not re.fullmatch(r"\d{4,8}", pin or ""):
        return {"ok": False, "messaggio": T("Il PIN ha da 4 a 8 cifre")}
    if DEMO:
        return {"ok": True, "messaggio": T("SIM sbloccata")}
    mod = _modem()
    sim = _mmcli("-m", mod).get("modem", {}).get("generic", {}).get("sim", "") if mod else ""
    if not sim or sim == "--":
        return {"ok": False, "messaggio": T("Nessuna SIM")}
    r = _esegui(["mmcli", "-i", sim, f"--pin={pin}"])
    return {"ok": r.returncode == 0, "messaggio": T("SIM sbloccata") if r.returncode == 0 else T("PIN sbagliato: attenzione, dopo 3 tentativi serve il PUK")}


# ── Suoni ────────────────────────────────────────────────────────────────────
def volume() -> int:
    if DEMO:
        return 60
    from ..hw import audio

    try:
        return int(audio.volume().get("volume", 50))
    except Exception:  # noqa: BLE001
        return 50


def imposta_volume(valore: int) -> None:
    if not DEMO:
        from ..hw import audio

        audio.imposta_volume(int(valore))


# ── Batteria ─────────────────────────────────────────────────────────────────
def batteria(preferenze: dict) -> dict:
    if DEMO:
        return {"presente": True, "livello": 82, "carica": False, "salute": 94, "stato": T("In uso"),
                "risparmio": bool(preferenze.get("risparmio", False))}
    for b in sorted(Path("/sys/class/power_supply").glob("BAT*")) + sorted(Path("/sys/class/power_supply").glob("*battery*")):
        try:
            livello = int((b / "capacity").read_text().strip())
        except (OSError, ValueError):
            continue
        stato = (b / "status").read_text().strip() if (b / "status").exists() else ""
        salute = 0
        for piena, progetto in (("energy_full", "energy_full_design"), ("charge_full", "charge_full_design")):
            try:
                salute = round(int((b / piena).read_text()) * 100 / int((b / progetto).read_text()))
                break
            except (OSError, ValueError, ZeroDivisionError):
                continue
        testi = {"Charging": T("In carica"), "Full": T("Carica completa"), "Discharging": T("In uso"), "Not charging": T("Non in carica")}
        return {"presente": True, "livello": livello, "carica": stato in ("Charging", "Full"), "salute": min(salute, 100),
                "stato": testi.get(stato, stato), "risparmio": bool(preferenze.get("risparmio", False))}
    return {"presente": False, "livello": 100, "carica": True, "salute": 0, "stato": T("Alimentato dalla rete"),
            "risparmio": bool(preferenze.get("risparmio", False))}


def imposta_risparmio(si: bool) -> None:
    if not DEMO and shutil.which("powerprofilesctl"):
        _esegui(["powerprofilesctl", "set", "power-saver" if si else "balanced"])


# ── Informazioni sul telefono ────────────────────────────────────────────────
def _leggi(p: str) -> str:
    try:
        return Path(p).read_text(encoding="utf-8", errors="replace").strip("\x00\n ")
    except OSError:
        return ""


def info() -> dict:
    modello = _leggi("/sys/firmware/devicetree/base/model") or " ".join(
        x for x in (_leggi("/sys/class/dmi/id/sys_vendor"), _leggi("/sys/class/dmi/id/product_name")) if x)
    if DEMO:
        modello = "Huawei P10 Lite"
    ram_kb = 0
    try:
        for riga in Path("/proc/meminfo").read_text().splitlines():
            if riga.startswith("MemTotal:"):
                ram_kb = int(riga.split()[1])
    except (OSError, ValueError):
        pass
    try:
        disco = shutil.disk_usage(str(Path.home()))
        spazio = T("{l} GB liberi su {t} GB", l=round(disco.free / 1e9, 1), t=round(disco.total / 1e9))
    except OSError:
        spazio = ""
    m = stato_modem()
    return {"nome": platform.node() or branding.nome(), "modello": modello or platform.machine(),
            "sistema": f"{branding.nome()} Mobile {branding.get('OS_VERSION', '')}",
            "kernel": platform.release(), "architettura": platform.machine(),
            "ram": f"{round(ram_kb / 1048576, 1)} GB" if ram_kb else "", "spazio": spazio,
            "numero": m.get("numero", ""), "operatore": m.get("operatore", "")}
