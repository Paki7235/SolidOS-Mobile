"""Compatibilità con Quick Share / Nearby Share di Android (rete locale).

Implementazione del protocollo documentato dai progetti open source NearDrop
(macOS) e RQuickShare (Linux):
- scoperta mDNS del servizio «_FC9F5ED42C8A._tcp»;
- annuncio BLE (UUID 0xFE2C) per far comparire il PC sui telefoni vicini;
- connessione TCP con frame protobuf preceduti dalla lunghezza;
- handshake UKEY2 (P-256, SHA-512) e canale cifrato AES-256-CBC + HMAC-SHA256;
- protocollo di condivisione (Introduction / Response / Payload).
Il telefono deve avere Quick Share visibile («Tutti») per ricevere dal PC.
"""

import asyncio
import base64
import hashlib
import hmac
import logging
import mimetypes
import os
import random
import secrets
import socket
import string
import struct

from cryptography.hazmat.primitives import hashes, padding
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

from ...i18n import T
from .. import PORTA_QUICKSHARE
from ..modelli import Dispositivo, FileInArrivo, Trasferimento
from ..sicurezza import nome_sicuro, percorso_libero
from .base import Backend
from .protobuf import codifica, decodifica, intero_con_segno, primo, sotto

log = logging.getLogger("condivisione.quickshare")
TIPO_SERVIZIO = "_FC9F5ED42C8A._tcp.local."

# OfflineFrame.V1Frame.FrameType
CONNECTION_REQUEST, CONNECTION_RESPONSE, PAYLOAD_TRANSFER, KEEP_ALIVE, DISCONNECTION = 1, 2, 3, 5, 6
# sharing.V1Frame.FrameType
INTRODUCTION, RESPONSE, PAIRED_KEY_ENCRYPTION, PAIRED_KEY_RESULT, CANCEL = 1, 2, 3, 4, 6
# PayloadHeader.PayloadType
BYTES, FILE = 1, 2
# Ukey2Message.Type
CLIENT_INIT, SERVER_INIT, CLIENT_FINISH = 2, 3, 4
P256_SHA512 = 100
D2D_SALT = hashlib.sha256(b"D2D").digest()
SMSG_SALT = hashlib.sha256(b"SecureMessage").digest()


# ── Utilità di cifratura ──────────────────────────────────────────────────────
def hkdf(chiave: bytes, sale: bytes, info: bytes, lunghezza: int = 32) -> bytes:
    return HKDF(algorithm=hashes.SHA256(), length=lunghezza, salt=sale, info=info).derive(chiave)


def _intero_java(b: bytes) -> bytes:
    """Coordinate come BigInteger Java: zero iniziale se il bit alto è 1."""
    return b"\x00" + b if b[0] & 0x80 else b


def codice_pin(chiave: bytes) -> str:
    h, m = 0, 1
    for byte in chiave:
        b = byte - 256 if byte > 127 else byte
        h = (h + b * m) % 9973
        m = (m * 31) % 9973
    return f"{abs(h):04d}"


def info_endpoint(nome: str, tipo_dispositivo: int = 3) -> bytes:
    """EndpointInfo: tipo (3 = laptop) nei bit 1-3, 16 byte casuali, nome."""
    nome_b = nome.encode("utf-8")[:255]
    return bytes([(tipo_dispositivo & 7) << 1]) + secrets.token_bytes(16) + bytes([len(nome_b)]) + nome_b


def nome_da_info(info: bytes) -> tuple[str, int]:
    if len(info) < 18:
        return "", 0
    tipo = (info[0] >> 1) & 7
    lunghezza = info[17]
    return info[18:18 + lunghezza].decode("utf-8", "replace"), tipo


# ── Canale di trasporto ───────────────────────────────────────────────────────
class Canale:
    """Frame con lunghezza (4 byte big-endian) e, dopo UKEY2, cifratura D2D."""

    def __init__(self, lettore: asyncio.StreamReader, scrittore: asyncio.StreamWriter):
        self.lettore, self.scrittore = lettore, scrittore
        self.cifrato = False
        self.seq_invio = 0
        self.seq_ricezione = 0
        self.chiave_dec = self.hmac_dec = self.chiave_enc = self.hmac_enc = b""

    async def leggi_grezzo(self) -> bytes:
        lunghezza = struct.unpack(">I", await self.lettore.readexactly(4))[0]
        if lunghezza > 8 * 1024 * 1024:
            raise ValueError("frame troppo grande")
        return await self.lettore.readexactly(lunghezza)

    async def scrivi_grezzo(self, dati: bytes):
        self.scrittore.write(struct.pack(">I", len(dati)) + dati)
        await self.scrittore.drain()

    def imposta_chiavi(self, chiave_dec, hmac_dec, chiave_enc, hmac_enc):
        self.chiave_dec, self.hmac_dec, self.chiave_enc, self.hmac_enc = chiave_dec, hmac_dec, chiave_enc, hmac_enc
        self.cifrato = True

    async def leggi(self) -> dict:
        """Restituisce l'OfflineFrame decodificato."""
        dati = await self.leggi_grezzo()
        if not self.cifrato:
            return decodifica(dati)
        sm = decodifica(dati)
        corpo_testa, firma = primo(sm, 1, b""), primo(sm, 2, b"")
        if not hmac.compare_digest(hmac.new(self.hmac_dec, corpo_testa, hashlib.sha256).digest(), firma):
            raise ValueError("firma del messaggio non valida")
        hb = decodifica(corpo_testa)
        testa = sotto(hb, 1)
        iv = primo(testa, 5, b"")
        decifratore = Cipher(algorithms.AES(self.chiave_dec), modes.CBC(iv)).decryptor()
        chiaro = decifratore.update(primo(hb, 2, b"")) + decifratore.finalize()
        sp = padding.PKCS7(128).unpadder()
        chiaro = sp.update(chiaro) + sp.finalize()
        d2d = decodifica(chiaro)
        self.seq_ricezione += 1
        if primo(d2d, 2, 0) != self.seq_ricezione:
            raise ValueError("numero di sequenza inatteso")
        return decodifica(primo(d2d, 1, b""))

    async def scrivi(self, frame: dict):
        dati = codifica(frame)
        if not self.cifrato:
            await self.scrivi_grezzo(dati)
            return
        self.seq_invio += 1
        d2d = codifica({1: dati, 2: self.seq_invio})
        p = padding.PKCS7(128).padder()
        d2d = p.update(d2d) + p.finalize()
        iv = secrets.token_bytes(16)
        cifratore = Cipher(algorithms.AES(self.chiave_enc), modes.CBC(iv)).encryptor()
        corpo = cifratore.update(d2d) + cifratore.finalize()
        testa = {1: 1, 2: 2, 5: iv, 6: codifica({1: 13, 2: 1})}   # HMAC_SHA256, AES_256_CBC, GcmMetadata(D2D,1)
        corpo_testa = codifica({1: testa, 2: corpo})
        firma = hmac.new(self.hmac_enc, corpo_testa, hashlib.sha256).digest()
        await self.scrivi_grezzo(codifica({1: corpo_testa, 2: firma}))

    def chiudi(self):
        try:
            self.scrittore.close()
        except Exception:  # noqa: BLE001
            pass


# ── UKEY2 ─────────────────────────────────────────────────────────────────────
def _chiave_pubblica(privata) -> bytes:
    numeri = privata.public_key().public_numbers()
    x, y = numeri.x.to_bytes(32, "big"), numeri.y.to_bytes(32, "big")
    return codifica({1: 1, 2: {1: _intero_java(x), 2: _intero_java(y)}})   # GenericPublicKey(EC_P256)


def _carica_pubblica(dati: bytes):
    gpk = decodifica(dati)
    ec_k = sotto(gpk, 2)
    x = int.from_bytes(primo(ec_k, 1, b"")[-32:], "big")
    y = int.from_bytes(primo(ec_k, 2, b"")[-32:], "big")
    return ec.EllipticCurvePublicNumbers(x, y, ec.SECP256R1()).public_key()


def _deriva(privata, pubblica_peer, msg_client_init: bytes, msg_server_init: bytes):
    condiviso = privata.exchange(ec.ECDH(), pubblica_peer)
    dhs = hashlib.sha256(condiviso).digest()
    info = msg_client_init + msg_server_init
    auth = hkdf(dhs, b"UKEY2 v1 auth", info)
    nxt = hkdf(dhs, b"UKEY2 v1 next", info)
    d2d_client = hkdf(nxt, D2D_SALT, b"client")
    d2d_server = hkdf(nxt, D2D_SALT, b"server")
    return {
        "pin": codice_pin(auth),
        "client_enc": hkdf(d2d_client, SMSG_SALT, b"ENC:2"), "client_hmac": hkdf(d2d_client, SMSG_SALT, b"SIG:1"),
        "server_enc": hkdf(d2d_server, SMSG_SALT, b"ENC:2"), "server_hmac": hkdf(d2d_server, SMSG_SALT, b"SIG:1"),
    }


async def ukey2_server(canale: Canale) -> str:
    msg_client_init = await canale.leggi_grezzo()
    m = decodifica(msg_client_init)
    if primo(m, 1) != CLIENT_INIT:
        raise ValueError("atteso CLIENT_INIT")
    ci = decodifica(primo(m, 2, b""))
    impegni = [decodifica(c) for c in ci.get(3, [])]
    impegno = next((primo(c, 2) for c in impegni if primo(c, 1) == P256_SHA512), None)
    if impegno is None:
        raise ValueError("cifrario P256_SHA512 non offerto")
    privata = ec.generate_private_key(ec.SECP256R1())
    msg_server_init = codifica({1: SERVER_INIT, 2: codifica({1: 1, 2: secrets.token_bytes(32), 3: P256_SHA512,
                                                             4: _chiave_pubblica(privata)})})
    await canale.scrivi_grezzo(msg_server_init)
    msg_finish = await canale.leggi_grezzo()
    if hashlib.sha512(msg_finish).digest() != impegno:
        raise ValueError("impegno UKEY2 non corrispondente")
    finito = decodifica(primo(decodifica(msg_finish), 2, b""))
    chiavi = _deriva(privata, _carica_pubblica(primo(finito, 1, b"")), msg_client_init, msg_server_init)
    canale._chiavi_pendenti = (chiavi["client_enc"], chiavi["client_hmac"], chiavi["server_enc"], chiavi["server_hmac"])
    return chiavi["pin"]


async def ukey2_client(canale: Canale) -> str:
    privata = ec.generate_private_key(ec.SECP256R1())
    msg_finish = codifica({1: CLIENT_FINISH, 2: codifica({1: _chiave_pubblica(privata)})})
    impegno = hashlib.sha512(msg_finish).digest()
    msg_client_init = codifica({1: CLIENT_INIT, 2: codifica({
        1: 1, 2: secrets.token_bytes(32), 3: [{1: P256_SHA512, 2: impegno}], 4: "AES_256_CBC-HMAC_SHA256"})})
    await canale.scrivi_grezzo(msg_client_init)
    msg_server_init = await canale.leggi_grezzo()
    m = decodifica(msg_server_init)
    if primo(m, 1) != SERVER_INIT:
        raise ValueError("atteso SERVER_INIT")
    si = decodifica(primo(m, 2, b""))
    await canale.scrivi_grezzo(msg_finish)
    chiavi = _deriva(privata, _carica_pubblica(primo(si, 4, b"")), msg_client_init, msg_server_init)
    canale._chiavi_pendenti = (chiavi["server_enc"], chiavi["server_hmac"], chiavi["client_enc"], chiavi["client_hmac"])
    return chiavi["pin"]


# ── Frame di alto livello ─────────────────────────────────────────────────────
def frame_offline(tipo: int, **campi) -> dict:
    v1 = {1: tipo}
    v1.update(campi)
    return {1: 1, 2: v1}


def risposta_connessione() -> dict:
    return frame_offline(CONNECTION_RESPONSE, **{3: {1: 0, 3: 1, 4: {1: 100}}})   # ACCEPT, OsInfo LINUX


async def invia_byte_payload(canale: Canale, dati: bytes):
    """Un frame di condivisione viaggia come payload BYTES in due blocchi (dati + fine)."""
    ident = random.randint(1, 2 ** 62)
    intestazione = {1: ident, 2: BYTES, 3: len(dati)}
    await canale.scrivi(frame_offline(PAYLOAD_TRANSFER, **{4: {1: 1, 2: intestazione, 3: {1: 0, 2: 0, 3: dati}}}))
    await canale.scrivi(frame_offline(PAYLOAD_TRANSFER, **{4: {1: 1, 2: intestazione, 3: {1: 1, 2: len(dati)}}}))


def frame_condivisione(tipo: int, **campi) -> bytes:
    v1 = {1: tipo}
    v1.update(campi)
    return codifica({1: 1, 2: v1})


class Sessione:
    """Gestisce i frame in arrivo: riassembla i payload BYTES e scrive i payload FILE."""

    def __init__(self, canale: Canale):
        self.canale = canale
        self.byte: dict[int, bytearray] = {}
        self.coda_condivisione: asyncio.Queue = asyncio.Queue()
        self.file_aperti: dict[int, object] = {}
        self.file_completati: set[int] = set()
        self.al_dato = None          # callback(id_payload, quantità)

    async def ciclo(self):
        while True:
            frame = await self.canale.leggi()
            v1 = sotto(frame, 2)
            tipo = primo(v1, 1)
            if tipo == KEEP_ALIVE:
                await self.canale.scrivi(frame_offline(KEEP_ALIVE, **{6: {1: True}}))
            elif tipo == DISCONNECTION:
                await self.coda_condivisione.put(None)
                return
            elif tipo == PAYLOAD_TRANSFER:
                await self._payload(sotto(v1, 4))

    async def _payload(self, pt: dict):
        intestazione, blocco = sotto(pt, 2), sotto(pt, 3)
        ident = intero_con_segno(primo(intestazione, 1, 0))
        tipo = primo(intestazione, 2, 0)
        corpo = primo(blocco, 3, b"")
        ultimo = primo(blocco, 1, 0) & 1
        if tipo == BYTES:
            self.byte.setdefault(ident, bytearray()).extend(corpo)
            if ultimo:
                await self.coda_condivisione.put(bytes(self.byte.pop(ident)))
        elif tipo == FILE:
            f = self.file_aperti.get(ident)
            if f is None:
                return                                   # payload non annunciato o non accettato
            if corpo:
                f.write(corpo)
                if self.al_dato:
                    await self.al_dato(ident, len(corpo))
            if ultimo:
                f.close()
                self.file_aperti.pop(ident, None)
                self.file_completati.add(ident)

    async def prossimo_frame_condivisione(self, timeout=120) -> dict | None:
        elemento = await asyncio.wait_for(self.coda_condivisione.get(), timeout)
        if elemento is None:
            return None
        return sotto(decodifica(elemento), 2)


# ── Backend ───────────────────────────────────────────────────────────────────
class BackendQuickShare(Backend):
    nome = "quickshare"

    def __init__(self, gestore):
        super().__init__(gestore)
        self.id_endpoint = "".join(random.choices(string.ascii_uppercase + string.digits, k=4))
        self.server = None
        self.zeroconf = None
        self.registrazione = None
        self.browser = None
        self.ble = None

    def disponibile(self):
        try:
            import zeroconf  # noqa: F401
        except ImportError:
            return False, T("Componente mDNS mancante (python3-zeroconf)")
        return True, T("Pronto: telefono e computer devono essere sulla stessa rete Wi-Fi")

    def _nome_servizio(self) -> str:
        grezzo = bytes([0x23]) + self.id_endpoint.encode() + bytes([0xFC, 0x9F, 0x5E, 0x00, 0x00])
        return base64.urlsafe_b64encode(grezzo).decode().rstrip("=")

    async def avvia(self):
        from zeroconf.asyncio import AsyncServiceBrowser, AsyncZeroconf

        self.server = await asyncio.start_server(self._connessione, "0.0.0.0", PORTA_QUICKSHARE)
        self.zeroconf = AsyncZeroconf()
        self.browser = AsyncServiceBrowser(self.zeroconf.zeroconf, TIPO_SERVIZIO, handlers=[self._servizio_cambiato])

    async def ferma(self):
        await self.visibilita("nessuno")
        if self.browser:
            await self.browser.async_cancel()
        if self.zeroconf:
            await self.zeroconf.async_close()
        if self.server:
            self.server.close()

    async def visibilita(self, modalita):
        from zeroconf import ServiceInfo

        if self.registrazione:
            await self.zeroconf.async_unregister_service(self.registrazione)
            self.registrazione = None
        if self.ble:
            await self.ble.ferma()
            self.ble = None
        if modalita == "nessuno":
            return
        indirizzi = [socket.inet_aton(ip) for ip in _indirizzi_locali()]
        info = info_endpoint(self.gestore.nome_dispositivo)
        self.registrazione = ServiceInfo(
            TIPO_SERVIZIO, f"{self._nome_servizio()}.{TIPO_SERVIZIO}", addresses=indirizzi, port=PORTA_QUICKSHARE,
            properties={"n": base64.urlsafe_b64encode(info).decode().rstrip("=")}, server=f"{socket.gethostname()}.local.")
        await self.zeroconf.async_register_service(self.registrazione)
        if modalita in ("tutti10", "tutti"):
            from .ble import AnnuncioBLE

            self.ble = AnnuncioBLE.quick_share()
            await self.ble.avvia()

    async def scopri(self, secondi=15):
        pass   # lo ServiceBrowser è sempre attivo

    def _servizio_cambiato(self, zeroconf, service_type, name, state_change):
        from zeroconf import ServiceStateChange

        if state_change is ServiceStateChange.Removed:
            self.gestore.dispositivo_perso(f"quickshare:{name}")
            return
        asyncio.ensure_future(self._risolvi(service_type, name))

    async def _risolvi(self, tipo, nome):
        from zeroconf.asyncio import AsyncServiceInfo

        if self.registrazione and nome == self.registrazione.name:
            return
        info = AsyncServiceInfo(tipo, nome)
        if not await info.async_request(self.zeroconf.zeroconf, 3000):
            return
        testo = (info.properties or {}).get(b"n")
        if not testo:
            return
        try:
            grezzo = base64.urlsafe_b64decode(testo + b"=" * (-len(testo) % 4))
        except ValueError:
            return
        nome_disp, tipo_disp = nome_da_info(grezzo)
        indirizzi = info.parsed_addresses()
        if not nome_disp or not indirizzi:
            return
        self.gestore.dispositivo_trovato(Dispositivo(
            id=f"quickshare:{nome}", nome=nome_disp, tipo={1: "telefono", 2: "tablet", 3: "computer"}.get(tipo_disp, "telefono"),
            backend="quickshare", indirizzo=indirizzi[0], porta=info.port))

    # ── Ricezione ───────────────────────────────────────────────────────────
    async def _connessione(self, lettore, scrittore):
        canale = Canale(lettore, scrittore)
        notifica = [0]
        t = None
        try:
            richiesta = await canale.leggi()
            cr = sotto(sotto(richiesta, 2), 2)
            nome_mittente, _ = nome_da_info(primo(cr, 6, b""))
            nome_mittente = nome_mittente or primo(cr, 2, b"").decode("utf-8", "replace") or T("Telefono Android")
            id_mittente = f"quickshare:{primo(cr, 1, b'').decode('utf-8', 'replace')}:{nome_mittente}"
            pin = await ukey2_server(canale)
            await canale.leggi()                                # ConnectionResponse del telefono
            await canale.scrivi(risposta_connessione())
            canale.imposta_chiavi(*canale._chiavi_pendenti)
            sessione = Sessione(canale)
            ciclo = asyncio.ensure_future(sessione.ciclo())

            # Scambio delle chiavi abbinate (non usate: modalità «Tutti»)
            await invia_byte_payload(canale, frame_condivisione(PAIRED_KEY_ENCRYPTION, **{4: {1: secrets.token_bytes(72), 2: secrets.token_bytes(6)}}))
            intro = None
            while intro is None:
                f = await sessione.prossimo_frame_condivisione()
                if f is None:
                    raise ConnectionError("disconnesso")
                tipo = primo(f, 1)
                if tipo == PAIRED_KEY_ENCRYPTION:
                    await invia_byte_payload(canale, frame_condivisione(PAIRED_KEY_RESULT, **{5: {1: 3}}))   # UNABLE
                elif tipo == INTRODUCTION:
                    intro = sotto(f, 2)
                elif tipo == CANCEL:
                    raise ConnectionError("annullato dal telefono")

            metadati = [decodifica(m) for m in intro.get(1, [])]
            testi = intro.get(2, [])
            if not metadati:
                # Solo testo/link: non supportato in questa versione
                await invia_byte_payload(canale, frame_condivisione(RESPONSE, **{3: {1: 4}}))
                if testi:
                    await self.gestore.notifiche.mostra(T("Contenuto non supportato"),
                                                        T("Per ora si possono ricevere solo file, non testi o link."))
                return
            file = [FileInArrivo(nome=nome_sicuro(primo(m, 1, b"file").decode("utf-8", "replace")),
                                 dimensione=int(primo(m, 4, 0)), mime=primo(m, 5, b"").decode("utf-8", "replace"))
                    for m in metadati]
            t = Trasferimento(direzione="ricevi", backend="quickshare", dispositivo=nome_mittente, file=file, codice=pin)
            if not await self.gestore.chiedi_conferma(t, id_mittente):
                await invia_byte_payload(canale, frame_condivisione(RESPONSE, **{3: {1: 2}}))   # REJECT
                return
            # Prepara i file di destinazione prima di accettare
            for m, f in zip(metadati, file):
                percorso = percorso_libero(self.gestore.cartella, f.nome)
                ident = intero_con_segno(primo(m, 3, 0))
                sessione.file_aperti[ident] = open(percorso, "wb")
                t.percorsi.append(str(percorso))
            t.stato = "in corso"

            async def al_dato(_ident, quantita):
                t.trasferiti += quantita
                await self.gestore.avanzamento(t, notifica)
                if t.annullato:
                    raise ConnectionError(T("Annullato"))

            sessione.al_dato = al_dato
            await invia_byte_payload(canale, frame_condivisione(RESPONSE, **{3: {1: 1}}))      # ACCEPT
            attesi = set(sessione.file_aperti)
            while not attesi <= sessione.file_completati:
                if ciclo.done():
                    ciclo.result()
                    break
                await asyncio.sleep(0.2)
            if not attesi <= sessione.file_completati:
                raise ConnectionError(T("Trasferimento interrotto"))
            await self.gestore.completato(t, notifica)
            await canale.scrivi(frame_offline(DISCONNECTION, **{7: {}}))
        except (asyncio.IncompleteReadError, ConnectionError, ValueError, asyncio.TimeoutError) as e:
            log.info("connessione Quick Share terminata: %s", e)
            if t and t.stato in ("in corso", "accettato"):
                for p in t.percorsi:
                    try:
                        if os.path.getsize(p) == 0:
                            os.unlink(p)
                    except OSError:
                        pass
                await self.gestore.completato(t, notifica, str(e) or T("Trasferimento interrotto"))
        finally:
            canale.chiudi()

    # ── Invio ───────────────────────────────────────────────────────────────
    async def invia(self, dispositivo: Dispositivo, t: Trasferimento):
        lettore, scrittore = await asyncio.wait_for(asyncio.open_connection(dispositivo.indirizzo, dispositivo.porta), 10)
        canale = Canale(lettore, scrittore)
        notifica = [0]
        try:
            info = info_endpoint(self.gestore.nome_dispositivo)
            await canale.scrivi(frame_offline(CONNECTION_REQUEST, **{2: {
                1: self.id_endpoint, 2: self.gestore.nome_dispositivo, 5: [5], 6: info,
                8: 5000, 9: 30000}}))
            t.codice = await ukey2_client(canale)
            await canale.scrivi(risposta_connessione())
            await canale.leggi()                                # ConnectionResponse del telefono
            canale.imposta_chiavi(*canale._chiavi_pendenti)
            sessione = Sessione(canale)
            ciclo = asyncio.ensure_future(sessione.ciclo())
            await self.gestore.notifiche.mostra(T("Invio a {d}", d=dispositivo.nome),
                                                T("Conferma sul telefono. Codice di verifica: {c}", c=t.codice))

            await invia_byte_payload(canale, frame_condivisione(PAIRED_KEY_ENCRYPTION, **{4: {1: secrets.token_bytes(72), 2: secrets.token_bytes(6)}}))
            ricevuti_chiave = False
            while not ricevuti_chiave:
                f = await sessione.prossimo_frame_condivisione(60)
                if f is None:
                    raise ConnectionError(T("Il telefono ha chiuso la connessione"))
                if primo(f, 1) == PAIRED_KEY_ENCRYPTION:
                    await invia_byte_payload(canale, frame_condivisione(PAIRED_KEY_RESULT, **{5: {1: 3}}))
                elif primo(f, 1) == PAIRED_KEY_RESULT:
                    ricevuti_chiave = True

            payload = {}
            metadati = []
            for p in t.file:
                ident = random.randint(1, 2 ** 62)
                payload[ident] = p
                mime = mimetypes.guess_type(p.name)[0] or "application/octet-stream"
                tipo = 1 if mime.startswith("image/") else 2 if mime.startswith("video/") else 4 if mime.startswith("audio/") else 0
                metadati.append({1: p.name, 2: tipo, 3: ident, 4: p.stat().st_size, 5: mime, 6: random.randint(1, 2 ** 62)})
            await invia_byte_payload(canale, frame_condivisione(INTRODUCTION, **{2: {1: metadati}}))

            risposta = None
            while risposta is None:
                f = await sessione.prossimo_frame_condivisione(180)
                if f is None:
                    raise ConnectionError(T("Il telefono ha chiuso la connessione"))
                if primo(f, 1) == RESPONSE:
                    risposta = primo(sotto(f, 3), 1, 0)
                elif primo(f, 1) == CANCEL:
                    risposta = 2
            if risposta != 1:
                t.stato = "rifiutato"
                return
            t.stato = "in corso"
            for ident, p in payload.items():
                totale, inviati = p.stat().st_size, 0
                intestazione = {1: ident, 2: FILE, 3: totale, 5: p.name}
                with open(p, "rb") as f:
                    while blocco := f.read(512 * 1024):
                        if t.annullato:
                            await invia_byte_payload(canale, frame_condivisione(CANCEL))
                            raise ConnectionError(T("Annullato"))
                        await canale.scrivi(frame_offline(PAYLOAD_TRANSFER, **{4: {1: 1, 2: intestazione, 3: {1: 0, 2: inviati, 3: blocco}}}))
                        inviati += len(blocco)
                        t.trasferiti += len(blocco)
                        await self.gestore.avanzamento(t, notifica)
                await canale.scrivi(frame_offline(PAYLOAD_TRANSFER, **{4: {1: 1, 2: intestazione, 3: {1: 1, 2: inviati}}}))
            await asyncio.sleep(1)
            await canale.scrivi(frame_offline(DISCONNECTION, **{7: {}}))
            ciclo.cancel()
            await self.gestore.notifiche.chiudi(notifica[0])
        finally:
            canale.chiudi()


def _indirizzi_locali() -> list[str]:
    from ...hw import rete

    ip = rete.indirizzo_lan()
    return [ip] if ip else ["127.0.0.1"]
