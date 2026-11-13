"""Servizio «Dov'è» di questo computer (gira in background solo se l'accesso al
Solid ID è fatto e «Dov'è» è attivo).

- ogni 10 minuti: ultimo collegamento, batteria e posizione;
- comandi dagli altri dispositivi, ricevuti subito (tempo reale di Supabase) e,
  come riserva, controllati ogni minuto: Fai suonare, Ferma, Blocca con messaggio, Posizione.
"""

from __future__ import annotations

import asyncio
import json
import math
import os
import shutil
import struct
import subprocess
import time
import wave
from pathlib import Path

from .. import branding
from ..i18n import T
from . import (ErroreSolidID, aggiorna_stato, chiave, collegato, registra_dispositivo, rest, sessione,
               sessione_live, token, url_base)
from .posizione import trova

INTERVALLO_STATO = 600
INTERVALLO_COMANDI = 60
DURATA_SUONO = 120


def _cache() -> Path:
    c = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os()
    c.mkdir(parents=True, exist_ok=True)
    return c


def file_messaggio_blocco() -> Path:
    return _cache() / "blocco" / "messaggio-remoto"


def _suono() -> Path:
    """Un richiamo forte e riconoscibile (due toni che salgono), generato una volta."""
    f = _cache() / "dove-suono.wav"
    if f.exists():
        return f
    frequenza = 44100
    campioni = bytearray()
    for nota in (1318.5, 1760.0, 2093.0, 0, 1318.5, 1760.0, 2093.0, 0, 0):
        for i in range(int(frequenza * 0.16)):
            inviluppo = min(1.0, i / 400, (frequenza * 0.16 - i) / 400)
            v = 0 if nota == 0 else math.sin(2 * math.pi * nota * i / frequenza) * 0.9 * inviluppo
            campioni += struct.pack("<h", int(v * 32767))
    with wave.open(str(f), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(frequenza)
        w.writeframes(bytes(campioni))
    return f


class Servizio:
    def __init__(self):
        self.dispositivo = ""
        self.suona_fino = 0.0
        self.suono_task: asyncio.Task | None = None
        self.eseguiti: set[int] = set()

    async def esegui(self, funzione, *argomenti):
        return await asyncio.get_running_loop().run_in_executor(None, funzione, *argomenti)

    # ── Stato e posizione ────────────────────────────────────────────────
    async def aggiorna(self):
        posizione = await self.esegui(trova)
        try:
            await self.esegui(lambda: aggiorna_stato(posizione))
        except ErroreSolidID:
            pass

    async def ciclo_stato(self):
        while True:
            await self.aggiorna()
            await asyncio.sleep(INTERVALLO_STATO)

    # ── Comandi ──────────────────────────────────────────────────────────
    def _segna(self, ident: int, stato: str):
        corpo = {"stato": stato}
        if stato in ("eseguito", "errore"):
            corpo["eseguito"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        try:
            rest("PATCH", "comandi", corpo, f"id=eq.{int(ident)}", rappresenta=False)
        except ErroreSolidID:
            pass

    async def comando(self, c: dict):
        ident = int(c.get("id", 0))
        if not ident or ident in self.eseguiti or c.get("stato") != "inviato":
            return
        # Comandi vecchi (dispositivo spento a lungo): «suona» non ha più senso dopo 10 minuti
        self.eseguiti.add(ident)
        await self.esegui(self._segna, ident, "ricevuto")
        tipo = c.get("tipo")
        try:
            if tipo == "suona":
                await self.suona()
            elif tipo == "ferma":
                self.suona_fino = 0
            elif tipo == "blocca":
                await self.blocca(c.get("messaggio") or "")
            elif tipo == "posizione":
                await self.aggiorna()
            await self.esegui(self._segna, ident, "eseguito")
        except Exception:  # noqa: BLE001 — il servizio non deve cadere per un comando
            await self.esegui(self._segna, ident, "errore")

    async def ciclo_comandi(self):
        while True:
            try:
                attesi = await self.esegui(lambda: rest(
                    "GET", "comandi", filtri=f"select=*&dispositivo=eq.{self.dispositivo}&stato=eq.inviato&order=id"))
                for c in attesi or []:
                    vecchio = time.time() - _secondi(c.get("creato", "")) > 600
                    if vecchio and c.get("tipo") == "suona":
                        self.eseguiti.add(int(c["id"]))
                        await self.esegui(self._segna, c["id"], "errore")
                        continue
                    await self.comando(c)
            except ErroreSolidID:
                pass
            await asyncio.sleep(INTERVALLO_COMANDI)

    async def tempo_reale(self):
        """Comandi ricevuti appena inviati (canale Realtime di Supabase)."""
        import aiohttp

        indirizzo = url_base().replace("https://", "wss://") + f"/realtime/v1/websocket?apikey={chiave()}&vsn=1.0.0"
        argomento = f"realtime:dove-{self.dispositivo}"
        while True:
            try:
                async with aiohttp.ClientSession() as http, http.ws_connect(indirizzo, heartbeat=None, timeout=20) as ws:
                    rif = 1
                    await ws.send_json({"topic": argomento, "event": "phx_join", "ref": str(rif), "join_ref": "1",
                                        "payload": {"config": {"broadcast": {"self": False}, "presence": {"key": ""},
                                                               "postgres_changes": [{"event": "INSERT", "schema": "public",
                                                                                     "table": "comandi",
                                                                                     "filter": f"dispositivo=eq.{self.dispositivo}"}]},
                                                    "access_token": await self.esegui(token)}})
                    prossimo_battito = time.monotonic() + 25
                    while True:
                        try:
                            msg = await ws.receive(timeout=5)
                        except asyncio.TimeoutError:
                            msg = None
                        if msg is not None:
                            if msg.type in (aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.ERROR, aiohttp.WSMsgType.CLOSE):
                                break
                            if msg.type == aiohttp.WSMsgType.TEXT:
                                dati = json.loads(msg.data)
                                if dati.get("event") == "postgres_changes":
                                    record = ((dati.get("payload") or {}).get("data") or {}).get("record") or {}
                                    if record:
                                        asyncio.create_task(self.comando(record))
                        if time.monotonic() >= prossimo_battito:
                            rif += 1
                            await ws.send_json({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": str(rif)})
                            # Il token dura un'ora: lo si rinnova sul canale
                            rif += 1
                            await ws.send_json({"topic": argomento, "event": "access_token", "ref": str(rif),
                                                "payload": {"access_token": await self.esegui(token)}})
                            prossimo_battito = time.monotonic() + 25
            except (OSError, asyncio.TimeoutError, ErroreSolidID, ValueError, Exception):  # noqa: BLE001
                pass
            await asyncio.sleep(15)

    # ── Azioni ───────────────────────────────────────────────────────────
    async def suona(self):
        self.suona_fino = time.time() + DURATA_SUONO
        if self.suono_task and not self.suono_task.done():
            return
        self.suono_task = asyncio.create_task(self._suona())

    async def _suona(self):
        suono = await self.esegui(_suono)
        volume_prima = await self.esegui(_volume)
        await self.esegui(lambda: subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"], check=False, timeout=5))
        await self.esegui(lambda: subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "1.0"], check=False, timeout=5))
        avviso = await asyncio.create_subprocess_exec(
            "notify-send", "--wait", "--urgency=critical", f"--app-name={T('Dov’è')}", "--icon=find-location",
            "--action=ferma=" + T("Ferma il suono"), T("Questo dispositivo è cercato"),
            T("Qualcuno sta usando «Dov'è» per trovarlo. Premi «Ferma il suono»."),
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        try:
            lettore = shutil.which("pw-play") or shutil.which("paplay") or "aplay"
            while time.time() < self.suona_fino:
                if avviso.returncode is not None or (avviso.stdout and avviso.stdout.at_eof()):
                    break
                p = await asyncio.create_subprocess_exec(lettore, str(suono), stdout=asyncio.subprocess.DEVNULL,
                                                         stderr=asyncio.subprocess.DEVNULL)
                await p.wait()
                await asyncio.sleep(0.3)
        finally:
            if avviso.returncode is None:
                avviso.terminate()
            if volume_prima is not None:
                await self.esegui(lambda: subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", str(volume_prima)],
                                                         check=False, timeout=5))

    async def blocca(self, messaggio: str):
        f = file_messaggio_blocco()
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(messaggio.strip()[:200] or T("Questo dispositivo è stato bloccato dal proprietario."), encoding="utf-8")
        await self.esegui(lambda: aggiorna_stato(None, bloccato=True, messaggio_blocco=messaggio[:200] or None))
        await self.esegui(lambda: subprocess.run([branding.comando("blocca")], check=False, timeout=30))

    async def avvia(self) -> int:
        if sessione_live() or not collegato() or not sessione().get("trova", True):
            return 0
        try:
            self.dispositivo = sessione().get("dispositivo_id") or await self.esegui(registra_dispositivo)
        except ErroreSolidID:
            self.dispositivo = ""
        if not self.dispositivo:
            return 1   # nessuna rete o accesso scaduto: systemd riprova più tardi
        await asyncio.gather(self.ciclo_stato(), self.ciclo_comandi(), self.tempo_reale())
        return 0


def _volume() -> float | None:
    try:
        uscita = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True, timeout=5).stdout
        return float(uscita.split()[1])
    except (OSError, IndexError, ValueError, subprocess.SubprocessError):
        return None


def _secondi(iso: str) -> float:
    from datetime import datetime

    try:
        return datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return time.time()


def sbloccato() -> None:
    """Chiamato dopo lo sblocco: toglie il messaggio e lo segna nel Solid ID."""
    f = file_messaggio_blocco()
    if f.exists():
        f.unlink(missing_ok=True)
        try:
            aggiorna_stato(None, bloccato=False, messaggio_blocco=None)
        except (ErroreSolidID, KeyError):
            pass


def main() -> int:
    return asyncio.run(Servizio().avvia())
