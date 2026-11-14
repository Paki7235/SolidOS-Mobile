"""Condivisione via codice QR: funziona con qualsiasi telefono, senza app.

Il PC avvia un piccolo server web temporaneo, solo in rete locale, protetto da un
codice monouso nel QR. Il telefono inquadra il QR e dal browser può inviare file
al PC o scaricare quelli condivisi. Tutto scade da solo dopo 10 minuti.
Senza una rete Wi-Fi comune il PC può creare un hotspot: un primo QR collega il
telefono alla rete, il secondo apre la pagina.
"""

import asyncio
import ipaddress
import json
import logging
import secrets
import time
from pathlib import Path

from aiohttp import web

from ...hw import rete
from ...i18n import T
from .. import DURATA_QR, PORTA_QR
from ..modelli import FileInArrivo, Trasferimento
from ..sicurezza import nome_sicuro, percorso_libero
from .base import Backend

log = logging.getLogger("condivisione.qr")
PAGINA = Path(__file__).resolve().parent.parent / "web" / "pagina.html"
CARTELLA_QR = Path("/tmp") / f"condivisione-qr-{__import__('os').getuid()}"


def _qr_svg(testo: str, file: Path) -> str:
    import qrcode
    import qrcode.image.svg

    img = qrcode.make(testo, image_factory=qrcode.image.svg.SvgPathFillImage, box_size=12, border=2)
    file.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(file))
    return str(file)


class BackendQR(Backend):
    nome = "qr"

    def __init__(self, gestore):
        super().__init__(gestore)
        self.runner: web.AppRunner | None = None
        self.token = ""
        self.cookie = ""
        self.usato = False
        self.offerti: list[Path] = []
        self.ricevi = True
        self.scadenza = 0.0
        self._timer: asyncio.TimerHandle | None = None
        self._ip = ""

    def disponibile(self):
        return True, T("Sempre disponibile: il telefono usa solo il browser")

    # ── Sessione ────────────────────────────────────────────────────────────
    def sessione(self, file: list, ricevi: bool, hotspot: bool = False) -> dict:
        info = {}
        if hotspot:
            r = rete.hotspot(True)
            if not r.get("ok"):
                return {"errore": T("Impossibile creare l'hotspot: {m}", m=r.get("messaggio", ""))}
            ip = "10.42.0.1"
            info["ssid"] = r.get("ssid", "")
            info["password"] = r.get("password", "")
            info["qrWifi"] = _qr_svg(f'WIFI:T:WPA;S:{info["ssid"]};P:{info["password"]};;', CARTELLA_QR / "wifi.svg")
        else:
            ip = rete.indirizzo_lan()
            if not ip:
                return {"errore": T("Nessuna rete locale: collega il PC al Wi-Fi oppure usa l'hotspot")}
        self.token = secrets.token_urlsafe(18)
        self.cookie = ""
        self.usato = False
        self.offerti = [Path(f.removeprefix("file://")) for f in file if Path(f.removeprefix("file://")).is_file()]
        self.ricevi = ricevi or not self.offerti
        self.scadenza = time.time() + DURATA_QR
        url = f"http://{ip}:{PORTA_QR}/t/{self.token}"
        info.update({"url": url, "qr": _qr_svg(url, CARTELLA_QR / f"{self.token[:8]}.svg"),
                     "scadenza": int(self.scadenza), "ip": ip})
        asyncio.ensure_future(self._avvia_server(ip))
        return info

    async def _avvia_server(self, ip: str):
        if self.runner and self._ip == ip:
            self._programma_scadenza()
            return
        await self.chiudi_sessione(mantieni_dati=True)
        app = web.Application(middlewares=[self._controllo], client_max_size=1024 ** 4)
        app.router.add_get("/t/{token}", self._ingresso)
        app.router.add_get("/", self._pagina)
        app.router.add_get("/stato", self._stato)
        app.router.add_get("/scarica/{indice}", self._scarica)
        app.router.add_post("/richiesta", self._richiesta)
        app.router.add_post("/carica/{ident}", self._carica)
        self.runner = web.AppRunner(app, access_log=None)
        await self.runner.setup()
        await web.TCPSite(self.runner, ip, PORTA_QR).start()
        self._ip = ip
        self._programma_scadenza()
        log.info("server QR su %s:%s", ip, PORTA_QR)

    def _programma_scadenza(self):
        if self._timer:
            self._timer.cancel()
        self._timer = asyncio.get_running_loop().call_later(
            max(1, self.scadenza - time.time()), lambda: asyncio.ensure_future(self.chiudi_sessione()))

    async def chiudi_sessione(self, mantieni_dati: bool = False):
        if self._timer:
            self._timer.cancel()
            self._timer = None
        if self.runner:
            await self.runner.cleanup()
            self.runner = None
        self._ip = ""
        if not mantieni_dati:
            self.token = ""
            self.cookie = ""

    # ── Sicurezza ───────────────────────────────────────────────────────────
    @web.middleware
    async def _controllo(self, richiesta: web.Request, gestore):
        try:
            remoto = ipaddress.ip_address(richiesta.remote or "")
        except ValueError:
            raise web.HTTPForbidden()
        if not (remoto.is_private or remoto.is_link_local):
            raise web.HTTPForbidden(text="Solo rete locale")
        if time.time() > self.scadenza:
            return web.Response(text=T("Il codice è scaduto. Genera un nuovo QR sul computer."), status=410,
                                content_type="text/plain", charset="utf-8")
        if richiesta.path.startswith("/t/"):
            return await gestore(richiesta)
        if not self.cookie or richiesta.cookies.get("sessione") != self.cookie:
            return web.Response(text=T("Accesso non autorizzato: inquadra il codice QR mostrato sul computer."),
                                status=403, content_type="text/plain", charset="utf-8")
        return await gestore(richiesta)

    async def _ingresso(self, richiesta):
        if not self.token or richiesta.match_info["token"] != self.token or self.usato:
            return web.Response(text=T("Codice già usato o non valido. Genera un nuovo QR sul computer."),
                                status=403, content_type="text/plain", charset="utf-8")
        self.usato = True                   # monouso: vale per un solo telefono
        self.cookie = secrets.token_urlsafe(24)
        risposta = web.HTTPFound("/")
        risposta.set_cookie("sessione", self.cookie, httponly=True, samesite="Strict", max_age=DURATA_QR)
        raise risposta

    # ── Pagine ──────────────────────────────────────────────────────────────
    async def _pagina(self, richiesta):
        from ... import branding

        html = PAGINA.read_text(encoding="utf-8").replace("{{NOME}}", branding.nome()).replace(
            "{{DISPOSITIVO}}", self.gestore.nome_dispositivo)
        return web.Response(text=html, content_type="text/html", charset="utf-8")

    async def _stato(self, richiesta):
        return web.json_response({
            "ricevi": self.ricevi, "scadenza": int(self.scadenza - time.time()),
            "file": [{"indice": i, "nome": p.name, "dimensione": p.stat().st_size} for i, p in enumerate(self.offerti)],
        })

    async def _scarica(self, richiesta):
        try:
            p = self.offerti[int(richiesta.match_info["indice"])]
        except (ValueError, IndexError):
            raise web.HTTPNotFound()
        t = Trasferimento(direzione="invia", backend="qr", dispositivo=T("telefono (QR)"), file=[p],
                          totale=p.stat().st_size, stato="completato")
        self.gestore.registra(t)
        return web.FileResponse(p, headers={"Content-Disposition": f'attachment; filename="{nome_sicuro(p.name)}"'})

    async def _richiesta(self, richiesta):
        dati = await richiesta.json()
        file = [FileInArrivo(nome=nome_sicuro(str(f.get("nome", "file"))), dimensione=int(f.get("dimensione", 0)))
                for f in dati.get("file", [])][:500]
        if not file:
            return web.json_response({"ok": False})
        agente = richiesta.headers.get("User-Agent", "")
        dispositivo = "iPhone" if "iPhone" in agente else ("iPad" if "iPad" in agente else
                      ("Android" if "Android" in agente else T("Telefono")))
        t = Trasferimento(direzione="ricevi", backend="qr", dispositivo=dispositivo, file=file)
        ok = await self.gestore.chiedi_conferma(t, "", utente_avviato=True)
        return web.json_response({"ok": ok, "id": t.id if ok else ""})

    async def _carica(self, richiesta):
        t = self.gestore.trasferimenti.get(richiesta.match_info["ident"])
        if not t or t.stato not in ("accettato", "in corso"):
            raise web.HTTPForbidden()
        attesi = {f.nome: f.dimensione for f in t.file}
        t.stato = "in corso"
        notifica = [0]
        lettore = await richiesta.multipart()
        while True:
            parte = await lettore.next()
            if parte is None:
                break
            nome = nome_sicuro(parte.filename or "file")
            if nome not in attesi:
                continue                                      # solo i file approvati
            destinazione = percorso_libero(self.gestore.cartella, nome)
            scritti = 0
            with open(destinazione, "wb") as uscita:
                while True:
                    blocco = await parte.read_chunk(256 * 1024)
                    if not blocco:
                        break
                    scritti += len(blocco)
                    if scritti > attesi[nome] + 1024 or t.annullato:
                        uscita.close()
                        destinazione.unlink(missing_ok=True)
                        await self.gestore.completato(t, notifica, T("Trasferimento interrotto"))
                        raise web.HTTPBadRequest()
                    uscita.write(blocco)
                    t.trasferiti += len(blocco)
                    await self.gestore.avanzamento(t, notifica)
            t.percorsi.append(str(destinazione))
        await self.gestore.completato(t, notifica)
        return web.json_response({"ok": True, "salvati": len(t.percorsi)})
