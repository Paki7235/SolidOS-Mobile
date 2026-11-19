"""Telefono SIP di SolidOS: chiamate via Internet senza programmi esterni.

Un piccolo «user agent» SIP (RFC 3261) scritto qui, per non dipendere da baresip o linphone:
- si registra all'account (UDP, autenticazione digest MD5/SHA-256, rinnovo, tenuta in vita
  per i router di casa);
- chiama (INVITE, anche con l'autenticazione), riceve chiamate, risponde, riaggancia
  (CANCEL/BYE), manda i toni (RFC 4733);
- l'audio è G.711 (PCMU/PCMA, quello che tutti gli operatori accettano) su RTP: il microfono
  arriva da PipeWire (pw-cat) o ALSA (arecord) e la voce dall'altra parte va all'altoparlante.

Dietro il router di casa: «rport» nelle Via, Contact con l'indirizzo pubblico che il server
ci restituisce, RTP simmetrico (si risponde da dove arriva la voce).
"""

from __future__ import annotations

import array
import hashlib
import os
import random
import re
import shutil
import socket
import struct
import subprocess
import threading
import time

AGENTE = "SolidOS-Telefono/1.0"


def _caso(n: int = 10) -> str:
    return "".join(random.choice("abcdefghijklmnopqrstuvwxyz0123456789") for _ in range(n))


# ── G.711 ────────────────────────────────────────────────────────────────────
def _ulaw(campione: int) -> int:
    segno = 0x80 if campione < 0 else 0
    campione = min(abs(campione), 32635) + 0x84
    esponente = 7
    while esponente > 0 and not campione & (0x4000 >> (7 - esponente)):
        esponente -= 1
    mantissa = (campione >> (esponente + 3)) & 0x0F
    return ~(segno | (esponente << 4) | mantissa) & 0xFF


def _ulaw_inverso(b: int) -> int:
    b = ~b & 0xFF
    esponente, mantissa = (b >> 4) & 7, b & 0x0F
    valore = (((mantissa << 3) + 0x84) << esponente) - 0x84
    return -valore if b & 0x80 else valore


def _alaw(campione: int) -> int:
    segno = 0x80 if campione >= 0 else 0
    campione = min(abs(campione), 32767) >> 3
    if campione < 32:
        valore = campione >> 1
    else:
        esponente = campione.bit_length() - 5
        valore = (esponente << 4) | ((campione >> esponente) & 0x0F)
    return (valore | segno) ^ 0x55


def _alaw_inverso(b: int) -> int:
    b ^= 0x55
    esponente, mantissa = (b >> 4) & 7, b & 0x0F
    valore = (mantissa << 4) + 8 if esponente == 0 else ((mantissa << 4) + 0x108) << (esponente - 1)
    return valore if b & 0x80 else -valore


_COD = {0: bytes(_ulaw(s - 65536 if s > 32767 else s) for s in range(65536)),
        8: bytes(_alaw(s - 65536 if s > 32767 else s) for s in range(65536))}
_DEC = {0: [struct.pack("<h", _ulaw_inverso(b)) for b in range(256)],
        8: [struct.pack("<h", max(-32768, min(32767, _alaw_inverso(b)))) for b in range(256)]}


def codifica(pcm: bytes, tipo: int) -> bytes:
    campioni = array.array("h")
    campioni.frombytes(pcm[: len(pcm) // 2 * 2])
    tabella = _COD[tipo]
    return bytes(tabella[c & 0xFFFF] for c in campioni)


def decodifica(dati: bytes, tipo: int) -> bytes:
    tabella = _DEC[tipo]
    return b"".join(tabella[b] for b in dati)


# ── Messaggi SIP ─────────────────────────────────────────────────────────────
_BREVI = {"v": "via", "f": "from", "t": "to", "i": "call-id", "m": "contact", "l": "content-length", "c": "content-type"}


class Messaggio:
    def __init__(self, testo: str):
        testa, _, self.corpo = testo.partition("\r\n\r\n")
        righe = testa.split("\r\n")
        self.prima = righe[0]
        self.intestazioni: list[tuple[str, str]] = []
        for r in righe[1:]:
            if ":" in r:
                k, v = r.split(":", 1)
                k = k.strip().lower()
                self.intestazioni.append((_BREVI.get(k, k), v.strip()))
        p = self.prima.split(" ", 2)
        self.risposta = p[0].startswith("SIP/")
        self.codice = int(p[1]) if self.risposta and len(p) > 1 and p[1].isdigit() else 0
        self.metodo = "" if self.risposta else p[0]
        self.uri = "" if self.risposta else (p[1] if len(p) > 1 else "")

    def h(self, nome: str) -> str:
        return next((v for k, v in self.intestazioni if k == nome), "")

    def tutte(self, nome: str) -> list[str]:
        return [v for k, v in self.intestazioni if k == nome]

    @property
    def cseq(self) -> tuple[int, str]:
        n, _, m = self.h("cseq").partition(" ")
        return int(n or 0), m.strip()


def _tag(valore: str) -> str:
    m = re.search(r";\s*tag=([^;>\s]+)", valore)
    return m.group(1) if m else ""


def _uri_di(valore: str) -> str:
    m = re.search(r"<([^>]+)>", valore)
    return m.group(1) if m else valore.split(";")[0].strip()


def numero_di(valore: str) -> str:
    m = re.search(r"sips?:([^@;>]+)", valore or "")
    return m.group(1) if m else (valore or "")


def _digest(sfida: str, metodo: str, uri: str, utente: str, password: str) -> str:
    p = dict(re.findall(r'(\w+)="?([^",]*)"?', sfida))
    alg = p.get("algorithm", "MD5").upper()
    h = (lambda x: hashlib.sha256(x.encode()).hexdigest()) if alg.startswith("SHA-256") else (lambda x: hashlib.md5(x.encode()).hexdigest())
    ha1 = h(f"{utente}:{p.get('realm', '')}:{password}")
    ha2 = h(f"{metodo}:{uri}")
    campi = [f'username="{utente}"', f'realm="{p.get("realm", "")}"', f'nonce="{p.get("nonce", "")}"', f'uri="{uri}"']
    if "auth" in p.get("qop", "").split(","):
        nc, cnonce = "00000001", _caso(12)
        risposta = h(f"{ha1}:{p.get('nonce', '')}:{nc}:{cnonce}:auth:{ha2}")
        campi += ["qop=auth", f"nc={nc}", f'cnonce="{cnonce}"']
    else:
        risposta = h(f"{ha1}:{p.get('nonce', '')}:{ha2}")
    campi.append(f'response="{risposta}"')
    if "opaque" in p:
        campi.append(f'opaque="{p["opaque"]}"')
    campi.append(f"algorithm={alg}")
    return "Digest " + ", ".join(campi)


# ── Audio e RTP ──────────────────────────────────────────────────────────────
def _comandi_audio() -> tuple[list[str] | None, list[str] | None]:
    if os.environ.get("SOLIDOS_SIP_AUDIO") == "nessuno":
        return None, None
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if shutil.which("pw-cat") and os.path.exists(os.path.join(runtime, "pipewire-0")):
        base = ["--format", "s16", "--rate", "8000", "--channels", "1", "--latency", "40ms", "-"]
        return ["pw-cat", "--record", *base], ["pw-cat", "--playback", *base]
    if shutil.which("arecord"):
        base = ["-q", "-f", "S16_LE", "-r", "8000", "-c", "1", "-t", "raw"]
        return ["arecord", *base], ["aplay", *base]
    return None, None


class Media:
    """Voce della chiamata: RTP G.711 da e verso il microfono e l'altoparlante."""

    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("0.0.0.0", 0))
        self.porta = self.sock.getsockname()[1]
        self.remoto: tuple[str, int] | None = None
        self.tipo = 0
        self.dtmf = 101
        self.attivo = False
        self.muto = False
        self.ssrc = random.getrandbits(32)
        self.seq = random.getrandbits(16)
        self.ts = random.getrandbits(32)
        self._toni: list[str] = []
        self._cattura = self._ascolto = None

    def avvia(self, remoto: tuple[str, int], tipo: int, dtmf: int) -> None:
        if self.attivo:
            self.remoto, self.tipo = remoto, tipo
            return
        self.remoto, self.tipo, self.dtmf, self.attivo = remoto, tipo, dtmf, True
        cattura, ascolto = _comandi_audio()
        try:
            if cattura:
                self._cattura = subprocess.Popen(cattura, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            if ascolto:
                self._ascolto = subprocess.Popen(ascolto, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except OSError:
            pass
        threading.Thread(target=self._manda, daemon=True).start()
        threading.Thread(target=self._ricevi, daemon=True).start()

    def _pacchetto(self, tipo: int, carico: bytes, marcatore: bool = False, passo: int = 160) -> bytes:
        self.seq = (self.seq + 1) & 0xFFFF
        intestazione = struct.pack("!BBHII", 0x80, (0x80 if marcatore else 0) | tipo, self.seq, self.ts, self.ssrc)
        self.ts = (self.ts + passo) & 0xFFFFFFFF
        return intestazione + carico

    def _manda(self) -> None:
        prossimo = time.monotonic()
        while self.attivo:
            if self._toni and self.remoto:
                self._manda_tono(self._toni.pop(0))
                prossimo = time.monotonic()
                continue
            if self._cattura and self._cattura.stdout:
                pcm = self._cattura.stdout.read(320)
                if not pcm:
                    pcm = bytes(320)
            else:
                prossimo += 0.02
                time.sleep(max(0, prossimo - time.monotonic()))
                pcm = bytes(320)
            if self.muto:
                pcm = bytes(320)
            if self.remoto:
                try:
                    self.sock.sendto(self._pacchetto(self.tipo, codifica(pcm, self.tipo)), self.remoto)
                except OSError:
                    pass

    def _manda_tono(self, cifra: str) -> None:
        evento = "0123456789*#".index(cifra)
        inizio = self.ts
        for i in range(8):
            fine = i >= 5
            durata = min(i + 1, 5) * 160
            carico = struct.pack("!BBH", evento, (0x80 if fine else 0) | 10, durata)
            self.seq = (self.seq + 1) & 0xFFFF
            pacchetto = struct.pack("!BBHII", 0x80, (0x80 if i == 0 else 0) | self.dtmf, self.seq, inizio, self.ssrc) + carico
            try:
                self.sock.sendto(pacchetto, self.remoto)
            except OSError:
                pass
            time.sleep(0.02)
        self.ts = (inizio + 8 * 160) & 0xFFFFFFFF

    def _ricevi(self) -> None:
        self.sock.settimeout(0.5)
        while self.attivo:
            try:
                dati, mittente = self.sock.recvfrom(2048)
            except socket.timeout:
                continue
            except OSError:
                break
            if len(dati) < 12 or dati[0] >> 6 != 2:
                continue
            self.remoto = mittente          # RTP simmetrico: si risponde da dove arriva la voce
            tipo = dati[1] & 0x7F
            if tipo not in (0, 8):
                continue
            inizio = 12 + 4 * (dati[0] & 0x0F)
            if self._ascolto and self._ascolto.stdin:
                try:
                    self._ascolto.stdin.write(decodifica(dati[inizio:], tipo))
                    self._ascolto.stdin.flush()
                except OSError:
                    pass

    def tono(self, cifra: str) -> None:
        if cifra in "0123456789*#":
            self._toni.append(cifra)

    def ferma(self) -> None:
        self.attivo = False
        for p in (self._cattura, self._ascolto):
            if p:
                try:
                    p.kill()
                except OSError:
                    pass
        try:
            self.sock.close()
        except OSError:
            pass


def _sdp(ip: str, porta: int) -> str:
    sessione = str(int(time.time()))
    return ("v=0\r\n" f"o=- {sessione} {sessione} IN IP4 {ip}\r\n" "s=SolidOS\r\n" f"c=IN IP4 {ip}\r\n" "t=0 0\r\n"
            f"m=audio {porta} RTP/AVP 0 8 101\r\n" "a=rtpmap:0 PCMU/8000\r\n" "a=rtpmap:8 PCMA/8000\r\n"
            "a=rtpmap:101 telephone-event/8000\r\n" "a=fmtp:101 0-15\r\n" "a=ptime:20\r\n" "a=sendrecv\r\n")


def _leggi_sdp(corpo: str) -> tuple[tuple[str, int] | None, int, int]:
    ip = re.search(r"^c=IN IP4 (\S+)", corpo, re.M)
    m = re.search(r"^m=audio (\d+) \S+ ([\d ]+)", corpo, re.M)
    if not ip or not m:
        return None, 0, 101
    formati = [int(x) for x in m.group(2).split()]
    tipo = next((f for f in formati if f in (0, 8)), 0)
    dtmf = re.search(r"a=rtpmap:(\d+) telephone-event", corpo)
    return (ip.group(1), int(m.group(1))), tipo, int(dtmf.group(1)) if dtmf else 101


# ── Telefono SIP ─────────────────────────────────────────────────────────────
class TelefonoSIP:
    def __init__(self, utente: str, password: str, dominio: str, server: str = "", nome: str = ""):
        self.utente, self.password, self.dominio, self.nome = utente, password, dominio, nome
        destinazione = (server or dominio).removeprefix("sip:").split(";")[0]
        host, _, porta = destinazione.partition(":")
        self.server = (host, int(porta or 5060))
        self.registrato = False
        self.errore = ""
        self.chiamata: dict = {}
        self.attivo = False
        self._sock: socket.socket | None = None
        self._ip = "0.0.0.0"
        self._porta = 0
        self._pubblico: tuple[str, int] | None = None
        self._call_id_reg = _caso(16) + "@solidos"
        self._tag_reg = _caso(8)
        self._cseq = random.randint(1, 1000)
        self._dialogo: dict = {}
        self._media: Media | None = None
        self._blocco = threading.RLock()

    # ── Rete ─────────────────────────────────────────────────────────────
    def _indirizzo_server(self) -> tuple[str, int]:
        return socket.getaddrinfo(self.server[0], self.server[1], socket.AF_INET, socket.SOCK_DGRAM)[0][4][:2]

    def avvia(self) -> None:
        self.attivo = True
        try:
            self._remoto = self._indirizzo_server()
        except OSError:
            self.errore = "Server SIP non trovato: controlla il dominio e la rete"
            return
        self._sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._sock.bind(("0.0.0.0", 0))
        prova = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            prova.connect(self._remoto)
            self._ip = prova.getsockname()[0]
        finally:
            prova.close()
        self._porta = self._sock.getsockname()[1]
        threading.Thread(target=self._ricevi, daemon=True).start()
        threading.Thread(target=self._mantieni, daemon=True).start()

    def ferma(self) -> None:
        self.attivo = False
        if self.registrato:
            self._registra(scadenza=0)
        self.registrato = False
        if self._media:
            self._media.ferma()
        if self._sock:
            try:
                self._sock.close()
            except OSError:
                pass

    def _manda(self, testo: str, a: tuple[str, int] | None = None) -> None:
        if self._sock:
            try:
                self._sock.sendto(testo.encode(), a or self._remoto)
            except OSError:
                pass

    def _contatto(self) -> str:
        ip, porta = self._pubblico or (self._ip, self._porta)
        return f"<sip:{self.utente}@{ip}:{porta}>"

    def _via(self, ramo: str | None = None) -> str:
        return f"SIP/2.0/UDP {self._ip}:{self._porta};branch=z9hG4bK{ramo or _caso(12)};rport"

    def _richiesta(self, metodo: str, uri: str, a: str, call_id: str, tag: str, cseq: int, extra: list[str] | None = None,
                   corpo: str = "", ramo: str | None = None, tag_a: str = "") -> str:
        mittente = f'"{self.nome}" ' if self.nome else ""
        righe = [f"{metodo} {uri} SIP/2.0", f"Via: {self._via(ramo)}", "Max-Forwards: 70",
                 f"From: {mittente}<sip:{self.utente}@{self.dominio}>;tag={tag}", f"To: <{a}>" + (f";tag={tag_a}" if tag_a else ""),
                 f"Call-ID: {call_id}", f"CSeq: {cseq} {metodo}", f"Contact: {self._contatto()}", f"User-Agent: {AGENTE}",
                 "Allow: INVITE, ACK, CANCEL, BYE, OPTIONS", *(extra or [])]
        if corpo:
            righe.append("Content-Type: application/sdp")
        righe.append(f"Content-Length: {len(corpo.encode())}")
        return "\r\n".join(righe) + "\r\n\r\n" + corpo

    def _rispondi_a(self, m: Messaggio, codice: int, motivo: str, corpo: str = "", tag: str = "", a=None) -> None:
        righe = [f"SIP/2.0 {codice} {motivo}"]
        for via in m.tutte("via"):
            righe.append(f"Via: {via}")
        righe.append(f"From: {m.h('from')}")
        to = m.h("to")
        if tag and not _tag(to):
            to += f";tag={tag}"
        righe += [f"To: {to}", f"Call-ID: {m.h('call-id')}", f"CSeq: {m.h('cseq')}", f"Contact: {self._contatto()}",
                  f"User-Agent: {AGENTE}"]
        if corpo:
            righe.append("Content-Type: application/sdp")
        righe.append(f"Content-Length: {len(corpo.encode())}")
        self._manda("\r\n".join(righe) + "\r\n\r\n" + corpo, a)

    # ── Registrazione ────────────────────────────────────────────────────
    def _registra(self, autorizzazione: str = "", scadenza: int = 300) -> None:
        self._cseq += 1
        uri = f"sip:{self.dominio}"
        extra = [f"Expires: {scadenza}"] + ([autorizzazione] if autorizzazione else [])
        self._manda(self._richiesta("REGISTER", uri, f"sip:{self.utente}@{self.dominio}", self._call_id_reg, self._tag_reg, self._cseq, extra))

    def _mantieni(self) -> None:
        prossima, battito = 0.0, 0.0
        while self.attivo:
            adesso = time.time()
            if adesso >= prossima:
                self._registra()
                prossima = adesso + (240 if self.registrato else 30)
            elif adesso >= battito:
                self._manda("\r\n\r\n")      # tiene aperta la porta del router di casa
                battito = adesso + 25
            time.sleep(1)

    # ── Ricezione ────────────────────────────────────────────────────────
    def _ricevi(self) -> None:
        while self.attivo and self._sock:
            try:
                dati, mittente = self._sock.recvfrom(65535)
            except OSError:
                break
            testo = dati.decode(errors="replace")
            if not testo.strip():
                continue
            try:
                m = Messaggio(testo)
                with self._blocco:
                    (self._risposta if m.risposta else self._richiesta_in_arrivo)(m, mittente)
            except Exception:  # noqa: BLE001 — un messaggio storto non ferma il telefono
                continue

    def _risposta(self, m: Messaggio, mittente) -> None:
        n, metodo = m.cseq
        if metodo == "REGISTER":
            if m.codice in (401, 407) and "Authorization" not in getattr(self, "_ultimo_reg", ""):
                sfida = m.h("www-authenticate") or m.h("proxy-authenticate")
                intestazione = "Authorization" if m.codice == 401 else "Proxy-Authorization"
                self._ultimo_reg = "Authorization"
                self._registra(f"{intestazione}: " + _digest(sfida, "REGISTER", f"sip:{self.dominio}", self.utente, self.password))
            elif m.codice == 200:
                self._ultimo_reg = ""
                via = m.h("via")
                ricevuto = re.search(r"received=([\d.]+)", via)
                porta = re.search(r"rport=(\d+)", via)
                pubblico = (ricevuto.group(1) if ricevuto else self._ip, int(porta.group(1)) if porta else self._porta)
                cambiato = pubblico != (self._pubblico or (self._ip, self._porta))
                self._pubblico = pubblico
                if cambiato:                 # il Contact deve avere l'indirizzo che vede il server
                    self._registra()
                self.registrato, self.errore = True, ""
            elif m.codice >= 300:
                self._ultimo_reg = ""
                self.registrato = False
                self.errore = "Accesso non riuscito: controlla utente, password e dominio" if m.codice in (401, 403, 407) \
                    else f"Il server ha risposto {m.codice}"
            return
        d = self._dialogo
        if not d or m.h("call-id") != d.get("call_id"):
            return
        if metodo == "INVITE":
            if m.codice >= 200:
                self._ack(m)
            if m.codice in (401, 407) and not d.get("autenticato"):
                d["autenticato"] = True
                sfida = m.h("www-authenticate") or m.h("proxy-authenticate")
                intestazione = "Authorization" if m.codice == 401 else "Proxy-Authorization"
                self._invita(f"{intestazione}: " + _digest(sfida, "INVITE", d["uri"], self.utente, self.password))
            elif m.codice in (180, 183):
                self.chiamata["stato"] = "ringing-out"
                if m.corpo:
                    self._media_da(m.corpo)
            elif 200 <= m.codice < 300:
                d["tag_a"] = _tag(m.h("to"))
                d["contatto"] = _uri_di(m.h("contact")) or d["uri"]
                d["confermato"] = True
                self.chiamata["stato"] = "active"
                if m.corpo:
                    self._media_da(m.corpo)
            elif m.codice >= 300:
                self._fine("rifiutata" if m.codice in (486, 600, 603) else f"{m.codice}")
        elif metodo == "BYE" and m.codice >= 200:
            self._fine("")

    def _richiesta_in_arrivo(self, m: Messaggio, mittente) -> None:
        if m.metodo == "OPTIONS":
            self._rispondi_a(m, 200, "OK", a=mittente)
        elif m.metodo == "INVITE":
            if self._dialogo and m.h("call-id") != self._dialogo.get("call_id"):
                self._rispondi_a(m, 486, "Busy Here", tag=_caso(8), a=mittente)
                return
            if self._dialogo:                 # re-INVITE (cambio di indirizzo, attesa…)
                if m.corpo:
                    self._media_da(m.corpo)
                self._rispondi_a(m, 200, "OK", _sdp(self._pubblico[0] if self._pubblico else self._ip, self._media.porta),
                                 tag=self._dialogo["tag"], a=mittente)
                return
            tag = _caso(8)
            self._media = Media()
            self._dialogo = {"call_id": m.h("call-id"), "tag": tag, "invito": m, "da": mittente, "entrata": True,
                             "tag_a": _tag(m.h("from")), "contatto": _uri_di(m.h("contact")), "uri": _uri_di(m.h("from"))}
            remoto, tipo, dtmf = _leggi_sdp(m.corpo)
            self._dialogo["sdp"] = (remoto, tipo, dtmf)
            self._rispondi_a(m, 100, "Trying", a=mittente)
            self._rispondi_a(m, 180, "Ringing", tag=tag, a=mittente)
            self.chiamata = {"stato": "ringing-in", "numero": numero_di(m.h("from"))}
        elif m.metodo == "ACK":
            pass
        elif m.metodo == "CANCEL":
            self._rispondi_a(m, 200, "OK", a=mittente)
            d = self._dialogo
            if d and d.get("entrata") and m.h("call-id") == d.get("call_id"):
                self._rispondi_a(d["invito"], 487, "Request Terminated", tag=d["tag"], a=d["da"])
                self._fine("persa")
        elif m.metodo == "BYE":
            self._rispondi_a(m, 200, "OK", a=mittente)
            if self._dialogo and m.h("call-id") == self._dialogo.get("call_id"):
                self._fine("")
        else:
            self._rispondi_a(m, 405, "Method Not Allowed", a=mittente)

    # ── Chiamate ─────────────────────────────────────────────────────────
    def _media_da(self, corpo: str) -> None:
        remoto, tipo, dtmf = _leggi_sdp(corpo)
        if remoto and self._media:
            self._media.avvia(remoto, tipo, dtmf)

    def _invita(self, autorizzazione: str = "") -> None:
        d = self._dialogo
        self._cseq += 1
        d["cseq"], d["ramo"] = self._cseq, _caso(12)
        ip = self._pubblico[0] if self._pubblico else self._ip
        extra = [autorizzazione] if autorizzazione else []
        self._manda(self._richiesta("INVITE", d["uri"], d["uri"], d["call_id"], d["tag"], d["cseq"], extra,
                                    _sdp(ip, self._media.porta), ramo=d["ramo"]))

    def _ack(self, m: Messaggio) -> None:
        d = self._dialogo
        n, _ = m.cseq
        uri = _uri_di(m.h("contact")) if m.codice < 300 and m.h("contact") else d["uri"]
        ramo = None if m.codice < 300 else d.get("ramo")      # 2xx: nuova transazione; errori: stessa
        righe = [f"ACK {uri} SIP/2.0", f"Via: {self._via(ramo)}", "Max-Forwards: 70",
                 f"From: <sip:{self.utente}@{self.dominio}>;tag={d['tag']}", f"To: {m.h('to')}", f"Call-ID: {d['call_id']}",
                 f"CSeq: {n} ACK", f"User-Agent: {AGENTE}", "Content-Length: 0"]
        self._manda("\r\n".join(righe) + "\r\n\r\n")

    def chiama(self, numero: str) -> dict:
        if not self.registrato:
            return {"ok": False, "messaggio": self.errore or "Chiamate via Internet non collegate: controlla la rete"}
        with self._blocco:
            if self._dialogo:
                return {"ok": False, "messaggio": "C'è già una chiamata in corso"}
            numero = numero.strip()
            if numero.startswith("sip:"):
                uri = numero
            elif "@" in numero:
                uri = "sip:" + numero
            else:
                uri = f"sip:{re.sub(r'[^0-9+*#]', '', numero)}@{self.dominio}"
            self._media = Media()
            self._dialogo = {"call_id": _caso(16) + "@solidos", "tag": _caso(8), "uri": uri, "entrata": False}
            self.chiamata = {"stato": "dialing", "numero": numero}
            self._invita()
        return {"ok": True}

    def rispondi(self) -> None:
        with self._blocco:
            d = self._dialogo
            if not d or not d.get("entrata") or d.get("confermato"):
                return
            d["confermato"] = True
            remoto, tipo, dtmf = d.get("sdp", (None, 0, 101))
            ip = self._pubblico[0] if self._pubblico else self._ip
            self._rispondi_a(d["invito"], 200, "OK", _sdp(ip, self._media.porta), tag=d["tag"], a=d["da"])
            if remoto:
                self._media.avvia(remoto, tipo, dtmf)
            self.chiamata["stato"] = "active"

    def riaggancia(self) -> None:
        with self._blocco:
            d = self._dialogo
            if not d:
                return
            if d.get("entrata") and not d.get("confermato"):
                self._rispondi_a(d["invito"], 486, "Busy Here", tag=d["tag"], a=d["da"])
            elif not d.get("entrata") and not d.get("confermato"):
                righe = [f"CANCEL {d['uri']} SIP/2.0", f"Via: {self._via(d.get('ramo'))}", "Max-Forwards: 70",
                         f"From: <sip:{self.utente}@{self.dominio}>;tag={d['tag']}", f"To: <{d['uri']}>", f"Call-ID: {d['call_id']}",
                         f"CSeq: {d.get('cseq', 1)} CANCEL", f"User-Agent: {AGENTE}", "Content-Length: 0"]
                self._manda("\r\n".join(righe) + "\r\n\r\n")
            else:
                self._cseq += 1
                if d.get("entrata"):
                    a, tag_a = _uri_di(d["invito"].h("from")), _tag(d["invito"].h("from"))
                else:
                    a, tag_a = d["uri"], d.get("tag_a", "")
                testo = self._richiesta("BYE", d.get("contatto") or a, a, d["call_id"], d["tag"], self._cseq, tag_a=tag_a)
                self._manda(testo, d.get("da") if d.get("entrata") else None)
            self._fine("")

    def tono(self, cifra: str) -> None:
        if self._media:
            self._media.tono(cifra)

    def muto(self, si: bool) -> None:
        if self._media:
            self._media.muto = bool(si)

    def _fine(self, motivo: str) -> None:
        if self._media:
            self._media.ferma()
        self._media = None
        self._dialogo = {}
        if self.chiamata:
            self.chiamata["stato"] = "terminated"
            self.chiamata["motivo"] = motivo
