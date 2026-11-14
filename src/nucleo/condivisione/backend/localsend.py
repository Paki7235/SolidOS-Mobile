"""Compatibilità con LocalSend (protocollo v2).

Scoperta: annunci JSON in multicast UDP 224.0.0.167:53317.
Trasferimento: API REST su HTTPS (certificato autofirmato; l'identità del
dispositivo è l'impronta SHA-256 del certificato).
Riferimento: specifica pubblica del protocollo LocalSend v2.
"""

import asyncio
import datetime
import hashlib
import json
import logging
import secrets
import socket
import ssl
import struct
from pathlib import Path

import aiohttp
from aiohttp import web

from ...i18n import T
from ...sistema import config_utente
from .. import PORTA_LOCALSEND
from ..modelli import Dispositivo, FileInArrivo, Trasferimento
from ..sicurezza import nome_sicuro, percorso_libero
from .base import Backend

log = logging.getLogger("condivisione.localsend")
GRUPPO = "224.0.0.167"
API = "/api/localsend/v2"


def _certificato() -> tuple[Path, Path, str]:
    """Crea (una volta) certificato e chiave; restituisce anche l'impronta."""
    cartella = config_utente("localsend", "x").parent
    cert, chiave = cartella / "cert.pem", cartella / "chiave.pem"
    if not cert.exists() or not chiave.exists():
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.x509.oid import NameOID

        k = ec.generate_private_key(ec.SECP256R1())
        nome = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "LocalSend User")])
        adesso = datetime.datetime.now(datetime.timezone.utc)
        c = (x509.CertificateBuilder().subject_name(nome).issuer_name(nome).public_key(k.public_key())
             .serial_number(x509.random_serial_number()).not_valid_before(adesso - datetime.timedelta(days=1))
             .not_valid_after(adesso + datetime.timedelta(days=3650)).sign(k, hashes.SHA256()))
        chiave.write_bytes(k.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                           serialization.NoEncryption()))
        chiave.chmod(0o600)
        cert.write_bytes(c.public_bytes(serialization.Encoding.PEM))
    from cryptography import x509
    from cryptography.hazmat.primitives import serialization

    der = x509.load_pem_x509_certificate(cert.read_bytes()).public_bytes(serialization.Encoding.DER)
    return cert, chiave, hashlib.sha256(der).hexdigest()


class ProtocolloAnnunci(asyncio.DatagramProtocol):
    def __init__(self, backend):
        self.backend = backend

    def datagram_received(self, dati, indirizzo):
        try:
            msg = json.loads(dati.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return
        self.backend.annuncio_ricevuto(msg, indirizzo[0])


class BackendLocalSend(Backend):
    nome = "localsend"

    def __init__(self, gestore):
        super().__init__(gestore)
        self.cert, self.chiave, self.impronta = _certificato()
        self.trasporto = None
        self.runner = None
        self.sessioni: dict[str, dict] = {}
        self._annuncia = False

    def disponibile(self):
        return True, T("Pronto: apri l'app LocalSend sull'altro dispositivo")

    def info(self) -> dict:
        return {"alias": self.gestore.nome_dispositivo, "version": "2.0", "deviceModel": "Linux",
                "deviceType": "desktop", "fingerprint": self.impronta, "port": PORTA_LOCALSEND,
                "protocol": "https", "download": False}

    # ── Avvio ───────────────────────────────────────────────────────────────
    async def avvia(self):
        loop = asyncio.get_running_loop()
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except (AttributeError, OSError):
            pass
        sock.bind(("", PORTA_LOCALSEND))
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
                        struct.pack("4sl", socket.inet_aton(GRUPPO), socket.INADDR_ANY))
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
        self.trasporto, _ = await loop.create_datagram_endpoint(lambda: ProtocolloAnnunci(self), sock=sock)

        app = web.Application(client_max_size=1024 ** 4)
        app.router.add_post(f"{API}/register", self._registra)
        app.router.add_get(f"{API}/info", self._info)
        app.router.add_post(f"{API}/prepare-upload", self._prepara)
        app.router.add_post(f"{API}/upload", self._carica)
        app.router.add_post(f"{API}/cancel", self._annulla)
        contesto = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        contesto.load_cert_chain(self.cert, self.chiave)
        self.runner = web.AppRunner(app, access_log=None)
        await self.runner.setup()
        await web.TCPSite(self.runner, "0.0.0.0", PORTA_LOCALSEND, ssl_context=contesto).start()
        asyncio.ensure_future(self._ciclo_annunci())

    async def ferma(self):
        if self.trasporto:
            self.trasporto.close()
        if self.runner:
            await self.runner.cleanup()

    async def visibilita(self, modalita):
        self._annuncia = modalita != "nessuno"
        if self._annuncia:
            self._invia_annuncio(True)

    async def scopri(self, secondi=15):
        for _ in range(3):
            self._invia_annuncio(True)
            await asyncio.sleep(1.5)

    def _invia_annuncio(self, annuncio: bool):
        if self.trasporto:
            dati = dict(self.info(), announce=annuncio, announcement=annuncio)
            self.trasporto.sendto(json.dumps(dati).encode(), (GRUPPO, PORTA_LOCALSEND))

    async def _ciclo_annunci(self):
        while True:
            await asyncio.sleep(30)
            if self._annuncia:
                self._invia_annuncio(True)

    def annuncio_ricevuto(self, msg: dict, ip: str):
        if msg.get("fingerprint") == self.impronta or not msg.get("alias"):
            return
        tipo = {"mobile": "telefono", "desktop": "computer", "web": "computer"}.get(msg.get("deviceType"), "telefono")
        self.gestore.dispositivo_trovato(Dispositivo(
            id=f"localsend:{msg['fingerprint']}", nome=msg["alias"], tipo=tipo, backend="localsend",
            indirizzo=ip, porta=int(msg.get("port", PORTA_LOCALSEND)),
            extra={"protocollo": msg.get("protocol", "https"), "impronta": msg["fingerprint"]}))
        if msg.get("announce") or msg.get("announcement"):
            # Rispondiamo così l'altro dispositivo ci vede (solo se siamo visibili)
            if self._annuncia:
                asyncio.ensure_future(self._rispondi_registrazione(ip, msg))

    async def _rispondi_registrazione(self, ip, msg):
        url = f'{msg.get("protocol", "https")}://{ip}:{msg.get("port", PORTA_LOCALSEND)}{API}/register'
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=5)) as s:
                await s.post(url, json=self.info(), ssl=False)
        except (aiohttp.ClientError, asyncio.TimeoutError):
            self._invia_annuncio(False)

    # ── Server (ricezione) ──────────────────────────────────────────────────
    async def _registra(self, richiesta):
        try:
            msg = await richiesta.json()
            self.annuncio_ricevuto(dict(msg, announce=False), richiesta.remote)
        except (json.JSONDecodeError, KeyError):
            pass
        return web.json_response(self.info())

    async def _info(self, richiesta):
        return web.json_response(self.info())

    async def _prepara(self, richiesta):
        if self.gestore.visibilita == "nessuno":
            raise web.HTTPForbidden()
        dati = await richiesta.json()
        mittente = dati.get("info", {})
        elenco = dati.get("files", {})
        if not elenco:
            raise web.HTTPBadRequest()
        file = [FileInArrivo(nome=nome_sicuro(f.get("fileName", "file")), dimensione=int(f.get("size", 0)),
                             mime=f.get("fileType", "")) for f in elenco.values()]
        t = Trasferimento(direzione="ricevi", backend="localsend", dispositivo=mittente.get("alias", T("Dispositivo")),
                          file=file)
        ok = await self.gestore.chiedi_conferma(t, f'localsend:{mittente.get("fingerprint", "")}')
        if not ok:
            raise web.HTTPForbidden()
        id_sessione = secrets.token_hex(12)
        gettoni = {fid: secrets.token_hex(12) for fid in elenco}
        self.sessioni[id_sessione] = {"t": t, "file": elenco, "gettoni": gettoni, "notifica": [0],
                                      "ricevuti": 0, "ip": richiesta.remote}
        return web.json_response({"sessionId": id_sessione, "files": gettoni})

    async def _carica(self, richiesta):
        q = richiesta.query
        s = self.sessioni.get(q.get("sessionId", ""))
        fid = q.get("fileId", "")
        if not s or s["gettoni"].get(fid) != q.get("token") or richiesta.remote != s["ip"]:
            raise web.HTTPForbidden()
        t: Trasferimento = s["t"]
        t.stato = "in corso"
        meta = s["file"][fid]
        destinazione = percorso_libero(self.gestore.cartella, nome_sicuro(meta.get("fileName", "file")))
        massimo = int(meta.get("size", 0)) + 1024
        scritti = 0
        with open(destinazione, "wb") as uscita:
            async for blocco in richiesta.content.iter_chunked(256 * 1024):
                scritti += len(blocco)
                if scritti > massimo or t.annullato:
                    uscita.close()
                    destinazione.unlink(missing_ok=True)
                    await self.gestore.completato(t, s["notifica"], T("Trasferimento interrotto"))
                    self.sessioni.pop(q.get("sessionId"), None)
                    raise web.HTTPBadRequest()
                uscita.write(blocco)
                t.trasferiti += len(blocco)
                await self.gestore.avanzamento(t, s["notifica"])
        t.percorsi.append(str(destinazione))
        s["gettoni"].pop(fid, None)
        if not s["gettoni"]:
            await self.gestore.completato(t, s["notifica"])
            self.sessioni.pop(q.get("sessionId"), None)
        return web.Response()

    async def _annulla(self, richiesta):
        s = self.sessioni.pop(richiesta.query.get("sessionId", ""), None)
        if s:
            s["t"].annullato = True
            await self.gestore.completato(s["t"], s["notifica"], T("Annullato dal mittente"))
        return web.Response()

    # ── Client (invio) ──────────────────────────────────────────────────────
    async def invia(self, dispositivo: Dispositivo, t: Trasferimento):
        base = f'{dispositivo.extra.get("protocollo", "https")}://{dispositivo.indirizzo}:{dispositivo.porta}{API}'
        file = {secrets.token_hex(8): p for p in t.file}
        corpo = {"info": self.info(), "files": {
            fid: {"id": fid, "fileName": p.name, "size": p.stat().st_size,
                  "fileType": __import__("mimetypes").guess_type(p.name)[0] or "application/octet-stream"}
            for fid, p in file.items()}}
        timeout = aiohttp.ClientTimeout(total=None, sock_connect=10, sock_read=120)
        async with aiohttp.ClientSession(timeout=timeout) as s:
            async with s.post(f"{base}/prepare-upload", json=corpo, ssl=False,
                              timeout=aiohttp.ClientTimeout(total=120)) as r:
                if r.status in (403, 401):
                    t.stato = "rifiutato"
                    return
                if r.status == 204:
                    return
                r.raise_for_status()
                risposta = await r.json()
            id_sessione = risposta["sessionId"]
            notifica = [0]
            t.stato = "in corso"
            for fid, gettone in risposta.get("files", {}).items():
                percorso = file[fid]

                async def flusso(p=percorso):
                    with open(p, "rb") as f:
                        while blocco := f.read(256 * 1024):
                            if t.annullato:
                                raise asyncio.CancelledError()
                            t.trasferiti += len(blocco)
                            await self.gestore.avanzamento(t, notifica)
                            yield blocco

                try:
                    async with s.post(f"{base}/upload", params={"sessionId": id_sessione, "fileId": fid, "token": gettone},
                                      data=flusso(), ssl=False) as r:
                        r.raise_for_status()
                except asyncio.CancelledError:
                    await s.post(f"{base}/cancel", params={"sessionId": id_sessione}, ssl=False)
                    raise RuntimeError(T("Annullato"))
            await self.gestore.notifiche.chiudi(notifica[0])
