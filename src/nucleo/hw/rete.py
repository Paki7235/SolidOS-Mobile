"""Rete tramite NetworkManager (nmcli)."""

from __future__ import annotations

import re

from ..sistema import esegui, uscita


def _campi(riga: str) -> list[str]:
    """Divide una riga «terse» di nmcli rispettando i due punti con escape (\\:)."""
    return [p.replace("\\:", ":") for p in re.split(r"(?<!\\):", riga)]


def wifi_attivo() -> bool:
    return uscita(["nmcli", "radio", "wifi"]).strip() == "enabled"


def imposta_wifi(attivo: bool) -> bool:
    ok = esegui(["nmcli", "radio", "wifi", "on" if attivo else "off"]).returncode == 0
    if ok and attivo:
        # dopo l'accensione la scheda impiega qualche secondo: si aspetta che sia pronta
        # e si cercano subito le reti (altrimenti l'elenco risulta vuoto «senza motivo»)
        import time

        fine = time.monotonic() + 12
        while time.monotonic() < fine:
            stati = [_campi(r) for r in uscita(["nmcli", "-t", "-f", "TYPE,STATE", "device"], timeout=5).splitlines()]
            if any(c[0] == "wifi" and len(c) > 1 and c[1] not in ("unavailable", "unmanaged") for c in stati):
                break
            time.sleep(0.5)
        esegui(["nmcli", "device", "wifi", "rescan"], timeout=10)
        fine = time.monotonic() + 8
        while time.monotonic() < fine and not reti_wifi():
            time.sleep(1)
    return ok


def reti_wifi(scansiona: bool = False) -> list[dict]:
    cmd = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
    if scansiona:
        cmd += ["--rescan", "yes"]
    viste: dict[str, dict] = {}
    for riga in uscita(cmd, timeout=30).splitlines():
        c = _campi(riga)
        if len(c) < 4 or not c[1]:
            continue
        rete = {"ssid": c[1], "segnale": int(c[2] or 0), "protetta": c[3] not in ("", "--"),
                "connessa": c[0] == "*"}
        if c[1] not in viste or rete["segnale"] > viste[c[1]]["segnale"]:
            viste[c[1]] = rete
    return sorted(viste.values(), key=lambda r: (not r["connessa"], -r["segnale"]))


def connetti_wifi(ssid: str, password: str = "") -> dict:
    cmd = ["nmcli", "--wait", "40", "device", "wifi", "connect", ssid]
    if password:
        cmd += ["password", password]
    r = esegui(cmd, timeout=50)
    testo = (r.stderr or r.stdout).strip()
    if r.returncode != 0:
        basso = testo.lower()
        if "secrets were required" in basso or "password" in basso or "802-1x" in basso:
            testo = "Password sbagliata: riprova"
        elif "no network with ssid" in basso:
            testo = "Rete non trovata: avvicinati al router e riprova"
        elif "timeout" in basso:
            testo = "Il router non risponde: riprova tra poco"
    return {"ok": r.returncode == 0, "messaggio": testo}


def disconnetti_wifi() -> bool:
    for disp in dispositivi():
        if disp["tipo"] == "wifi" and disp["stato"] == "connected":
            return esegui(["nmcli", "device", "disconnect", disp["nome"]]).returncode == 0
    return False


def dispositivi() -> list[dict]:
    risultato = []
    for riga in uscita(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]).splitlines():
        c = _campi(riga)
        if len(c) >= 4:
            risultato.append({"nome": c[0], "tipo": c[1], "stato": c[2], "connessione": c[3]})
    return risultato


def connessioni(tipo: str | None = None) -> list[dict]:
    risultato = []
    for riga in uscita(["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]).splitlines():
        c = _campi(riga)
        if len(c) >= 4 and (tipo is None or tipo in c[2]):
            risultato.append({"nome": c[0], "uuid": c[1], "tipo": c[2], "attiva": c[3] == "yes"})
    return risultato


def attiva_connessione(nome_o_uuid: str, attiva: bool = True) -> bool:
    azione = "up" if attiva else "down"
    return esegui(["nmcli", "connection", azione, nome_o_uuid], timeout=45).returncode == 0


def vpn() -> list[dict]:
    return [c for c in connessioni() if c["tipo"] in ("vpn", "wireguard")]


def importa_vpn(file: str) -> dict:
    tipo = "wireguard" if file.endswith(".conf") else "openvpn"
    r = esegui(["nmcli", "connection", "import", "type", tipo, "file", file])
    return {"ok": r.returncode == 0, "messaggio": (r.stderr or r.stdout).strip()}


def hotspot(attivo: bool, ssid: str = "", password: str = "") -> dict:
    if not attivo:
        ok = esegui(["nmcli", "connection", "down", "Hotspot"]).returncode == 0
        return {"ok": ok}
    cmd = ["nmcli", "device", "wifi", "hotspot", "con-name", "Hotspot"]
    if ssid:
        cmd += ["ssid", ssid]
    if password:
        cmd += ["password", password]
    r = esegui(cmd, timeout=30)
    return {"ok": r.returncode == 0, "messaggio": (r.stderr or r.stdout).strip(), **dati_hotspot()}


def dati_hotspot() -> dict:
    testo = uscita(["nmcli", "-s", "-t", "-f", "802-11-wireless.ssid,802-11-wireless-security.psk",
                    "connection", "show", "Hotspot"])
    dati = {}
    for riga in testo.splitlines():
        if ":" in riga:
            chiave, valore = riga.split(":", 1)
            dati["ssid" if "ssid" in chiave else "password"] = valore
    return dati


def supporta_hotspot() -> bool:
    return "AP" in uscita(["iw", "list"])


def proxy() -> dict:
    return {"http": uscita(["sh", "-c", "echo ${http_proxy:-}"]).strip()}


def indirizzo_lan() -> str:
    """Primo indirizzo IPv4 privato dell'host (per Condivisione Vicina via QR)."""
    for riga in uscita(["ip", "-4", "-o", "addr", "show", "scope", "global"]).splitlines():
        parti = riga.split()
        if "inet" in parti:
            ip = parti[parti.index("inet") + 1].split("/")[0]
            if ip.startswith(("10.", "192.168.")) or re.match(r"172\.(1[6-9]|2\d|3[01])\.", ip):
                return ip
    return ""


def stato_breve() -> dict:
    disp = dispositivi()
    connesso = next((d for d in disp if d["stato"] == "connected" and d["tipo"] in ("wifi", "ethernet")), None)
    return {
        "wifi": wifi_attivo(),
        "connesso": connesso is not None,
        "tipo": connesso["tipo"] if connesso else "",
        "nome": connesso["connessione"] if connesso else "",
    }
