"""Chiamate via Internet (VoIP, SIP) con baresip.

Serve un account SIP: lo danno gli operatori VoIP (numero di telefono vero, si chiamano i
fissi e i cellulari) e molti centralini di casa o d'ufficio. Si scrivono utente, password e
dominio in Impostazioni › Chiamate via Internet; il telefono si registra e le chiamate
passano da Internet (Wi-Fi o dati), anche senza SIM.

baresip gira in sottofondo e si comanda dal modulo «ctrl_tcp» (solo da questo telefono,
127.0.0.1): comandi e avvisi sono JSON in «netstring» (lunghezza:testo,).
L'audio passa da PipeWire (callaudiod sceglie altoparlante o auricolare).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import socket
import subprocess
import threading
import time
from pathlib import Path

from ..i18n import T
from ..sistema import config_utente, leggi_json, scrivi_json

PORTA = 4444
MODULI = Path("/usr/lib/baresip/modules")


def _file() -> Path:
    return config_utente("voip.json")


def account() -> dict:
    """L'account SIP salvato (la password non esce mai da qui verso l'interfaccia)."""
    a = leggi_json(_file(), {})
    return {"utente": a.get("utente", ""), "dominio": a.get("dominio", ""), "server": a.get("server", ""),
            "nome": a.get("nome", ""), "attivo": bool(a.get("attivo")), "haPassword": bool(a.get("password"))}


def disponibile() -> bool:
    return bool(shutil.which("baresip"))


def _uri(numero: str, dominio: str) -> str:
    numero = numero.strip()
    if numero.startswith("sip:"):
        return numero
    if "@" in numero:
        return "sip:" + numero
    pulito = re.sub(r"[^\d+*#]", "", numero)
    return f"sip:{pulito}@{dominio}"


def numero_da_uri(uri: str) -> str:
    m = re.search(r"sip:([^@;>]+)", uri or "")
    return m.group(1) if m else (uri or "")


class Baresip:
    """Un processo baresip e la sua connessione di controllo."""

    def __init__(self):
        self.proc: subprocess.Popen | None = None
        self.sock: socket.socket | None = None
        self.registrato = False
        self.errore = ""
        self.chiamata: dict = {}         # {stato, numero, id}
        self._blocco = threading.Lock()

    # ── Avvio ────────────────────────────────────────────────────────────
    def _scrivi_configurazione(self, a: dict) -> Path:
        cartella = config_utente("baresip")
        cartella.mkdir(parents=True, exist_ok=True)
        moduli = ["g711.so", "g722.so", "opus.so", "auconv.so", "auresamp.so", "stun.so", "turn.so", "ice.so"]
        # PipeWire se è acceso (e il modulo c'è), altrimenti ALSA direttamente
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
        audio = "pipewire" if (MODULI / "pipewire.so").exists() and (runtime / "pipewire-0").exists() else "alsa"
        moduli.append(f"{audio}.so")
        config = [
            f"module_path\t\t{MODULI}",
            "sip_listen\t\t0.0.0.0:0",
            f"audio_player\t\t{audio},default",
            f"audio_source\t\t{audio},default",
            f"audio_alert\t\t{audio},default",
            "audio_level\t\tno",
            "call_max_calls\t\t2",
            *[f"module\t\t\t{m}" for m in moduli],
            "module_app\t\taccount.so",
            "module_app\t\tmenu.so",
            "module_app\t\tctrl_tcp.so",
            f"ctrl_tcp_listen\t\t127.0.0.1:{PORTA}",
        ]
        (cartella / "config").write_text("\n".join(config) + "\n")
        riga = f"<sip:{a['utente']}@{a['dominio']}>;auth_pass={a.get('password', '')};regint=300"
        if a.get("server"):
            server = a["server"] if a["server"].startswith("sip:") else "sip:" + a["server"]
            riga += f';outbound="{server}"'
        if a.get("nome"):
            riga = f'"{a["nome"]}" ' + riga
        conti = cartella / "accounts"
        conti.write_text(riga + "\n")
        os.chmod(conti, 0o600)       # dentro c'è la password
        return cartella

    def avvia(self) -> None:
        a = leggi_json(_file(), {})
        if not a.get("attivo") or not a.get("utente") or not disponibile():
            return
        self.ferma()
        cartella = self._scrivi_configurazione(a)
        self.registrato, self.errore = False, ""
        self.proc = subprocess.Popen(["baresip", "-f", str(cartella)], stdin=subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        threading.Thread(target=self._ascolta, daemon=True).start()

    def ferma(self) -> None:
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        self.proc = None
        self.registrato = False

    # ── Controllo (netstring JSON) ───────────────────────────────────────
    def _ascolta(self) -> None:
        for _ in range(50):          # baresip impiega un attimo ad aprire la porta
            if not self.proc or self.proc.poll() is not None:
                self.errore = T("baresip si è fermato: controlla l'account")
                return
            try:
                self.sock = socket.create_connection(("127.0.0.1", PORTA), timeout=2)
                break
            except OSError:
                time.sleep(0.2)
        else:
            self.errore = T("baresip non risponde")
            return
        self.sock.settimeout(None)
        dati = b""
        while self.sock:
            try:
                pezzo = self.sock.recv(4096)
            except OSError:
                break
            if not pezzo:
                break
            dati += pezzo
            while True:
                m = re.match(rb"(\d+):", dati)
                if not m:
                    break
                n, inizio = int(m.group(1)), m.end()
                if len(dati) < inizio + n + 1:
                    break
                corpo, dati = dati[inizio:inizio + n], dati[inizio + n + 1:]
                try:
                    self._evento(json.loads(corpo))
                except ValueError:
                    pass

    def _evento(self, e: dict) -> None:
        if not e.get("event"):
            return
        tipo, param = e.get("type", ""), e.get("param", "")
        with self._blocco:
            if tipo == "REGISTER_OK":
                self.registrato, self.errore = True, ""
            elif tipo == "REGISTER_FAIL":
                self.registrato = False
                self.errore = T("Accesso non riuscito: controlla utente, password e dominio") + (f" ({param})" if param else "")
            elif tipo == "CALL_INCOMING":
                self.chiamata = {"stato": "ringing-in", "numero": numero_da_uri(e.get("peeruri", param)), "id": e.get("id", "")}
            elif tipo in ("CALL_RINGING", "CALL_PROGRESS", "CALL_OUTGOING"):
                if self.chiamata:
                    self.chiamata["stato"] = "ringing-out"
            elif tipo in ("CALL_ESTABLISHED", "CALL_ANSWERED"):
                if self.chiamata:
                    self.chiamata["stato"] = "active"
            elif tipo == "CALL_CLOSED":
                if self.chiamata:
                    self.chiamata["stato"] = "terminated"
                    self.chiamata["motivo"] = param

    def comando(self, nome: str, parametri: str = "") -> bool:
        if not self.sock:
            return False
        corpo = json.dumps({"command": nome, "params": parametri, "token": str(time.time())}).encode()
        try:
            self.sock.sendall(str(len(corpo)).encode() + b":" + corpo + b",")
            return True
        except OSError:
            return False

    # ── Chiamate ─────────────────────────────────────────────────────────
    def chiama(self, numero: str) -> dict:
        a = leggi_json(_file(), {})
        if not self.registrato:
            return {"ok": False, "messaggio": self.errore or T("Chiamate via Internet non collegate: controlla la rete")}
        self.chiamata = {"stato": "dialing", "numero": numero, "id": ""}
        if not self.comando("dial", _uri(numero, a.get("dominio", ""))):
            self.chiamata = {}
            return {"ok": False, "messaggio": T("La chiamata non è partita")}
        return {"ok": True}

    def rispondi(self) -> None:
        self.comando("accept")

    def riaggancia(self) -> None:
        self.comando("hangup")
        if self.chiamata:
            self.chiamata["stato"] = "terminated"

    def tono(self, cifra: str) -> None:
        if re.fullmatch(r"[0-9*#]", cifra or ""):
            self.comando("sndcode", cifra)

    def stato(self) -> dict:
        return {"disponibile": disponibile(), "attivo": bool(self.proc and self.proc.poll() is None),
                "registrato": self.registrato, "errore": self.errore}


_istanza: Baresip | None = None


def baresip() -> Baresip:
    global _istanza
    if _istanza is None:
        _istanza = Baresip()
    return _istanza


def salva(utente: str, password: str, dominio: str, server: str = "", nome: str = "", attivo: bool = True) -> dict:
    utente, dominio = utente.strip(), dominio.strip().removeprefix("sip:")
    if attivo and (not utente or not dominio):
        return {"ok": False, "messaggio": T("Scrivi utente e dominio dell'account SIP")}
    vecchio = leggi_json(_file(), {})
    dati = {"utente": utente, "dominio": dominio, "server": server.strip(), "nome": nome.strip(), "attivo": bool(attivo),
            "password": password if password else vecchio.get("password", "")}
    scrivi_json(_file(), dati)
    try:
        _file().chmod(0o600)
    except OSError:
        pass
    b = baresip()
    if attivo:
        if not disponibile():
            return {"ok": False, "messaggio": T("Manca baresip: arriva con il prossimo aggiornamento del telefono")}
        b.avvia()
        return {"ok": True, "messaggio": T("Account salvato: mi collego…")}
    b.ferma()
    return {"ok": True, "messaggio": T("Chiamate via Internet spente")}
