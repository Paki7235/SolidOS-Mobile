"""Registratore vocale: registra dal microfono, con pausa e il livello dal vivo; salva in
~/Musica/Registrazioni (in .m4a se c'è ffmpeg, altrimenti .wav) e tiene per ogni registrazione
la durata e la forma d'onda da disegnare.

Il suono arriva grezzo (48 kHz, mono, 16 bit) da pw-record o, in mancanza, da arecord: Python
lo legge a pezzi, ne calcola il livello e lo scrive nel file .wav; alla fine lo converte.
"""

from __future__ import annotations

import array
import math
import shutil
import subprocess
import threading
import time
import wave
from datetime import datetime
from pathlib import Path

from .i18n import T
from .sistema import cartella_utente, config_utente, esiste, leggi_json, scrivi_json

FREQUENZA = 48000
PEZZO = FREQUENZA // 20          # 50 ms
ESTENSIONI = (".m4a", ".wav", ".ogg", ".opus", ".mp3", ".flac")


def cartella() -> Path:
    c = cartella_utente("MUSIC", "Musica") / T("Registrazioni")
    c.mkdir(parents=True, exist_ok=True)
    return c


def _indice_file() -> Path:
    return config_utente("registrazioni.json")


def _indice() -> dict:
    return leggi_json(_indice_file(), {})


def _comando() -> list[str] | None:
    if esiste("pw-record"):
        return ["pw-record", "--rate", str(FREQUENZA), "--channels", "1", "--format", "s16", "-"]
    if esiste("arecord"):
        return ["arecord", "-q", "-f", "S16_LE", "-r", str(FREQUENZA), "-c", "1", "-t", "raw"]
    return None


def _livello(dati: bytes) -> float:
    """Livello 0..1 di un pezzo (scala in dB da −50 a 0)."""
    campioni = array.array("h", dati[: len(dati) // 2 * 2])
    if not campioni:
        return 0.0
    rms = math.sqrt(sum(c * c for c in campioni[::4]) / max(1, len(campioni[::4]))) / 32768
    if rms <= 0:
        return 0.0
    return max(0.0, min(1.0, (20 * math.log10(rms) + 50) / 50))


def _riduci(livelli: list[float], n: int = 80) -> list[float]:
    if not livelli:
        return [0.0] * n
    out = []
    for i in range(n):
        a, b = int(i * len(livelli) / n), int((i + 1) * len(livelli) / n)
        parte = livelli[a:max(b, a + 1)]
        out.append(round(max(parte), 3))
    return out


class Registrazione:
    """Una registrazione in corso (una per volta)."""

    def __init__(self) -> None:
        self.livelli: list[float] = []
        self.secondi = 0.0
        self.in_pausa = False
        self.errore = ""
        self._fermo = threading.Event()
        comando = _comando()
        if not comando:
            raise RuntimeError(T("Manca il programma per registrare (pw-record o arecord)"))
        n = 1
        while True:
            nome = T("Registrazione {n}", n=n)
            if not any((cartella() / (nome + e)).exists() for e in ESTENSIONI):
                break
            n += 1
        self.nome = nome
        self.wav = cartella() / f".{nome}.wav"
        self._uscita = wave.open(str(self.wav), "wb")
        self._uscita.setnchannels(1)
        self._uscita.setsampwidth(2)
        self._uscita.setframerate(FREQUENZA)
        self._processo = subprocess.Popen(comando, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self._filo = threading.Thread(target=self._leggi, daemon=True)
        self._filo.start()

    def _leggi(self) -> None:
        flusso = self._processo.stdout
        while not self._fermo.is_set():
            dati = flusso.read(PEZZO * 2)
            if not dati:
                if self._processo.poll() is not None and not self._fermo.is_set():
                    self.errore = T("Il microfono non risponde")
                break
            if self.in_pausa:
                continue
            self._uscita.writeframes(dati)
            self.secondi += len(dati) / 2 / FREQUENZA
            self.livelli.append(_livello(dati))

    def stato(self) -> dict:
        return {"registra": True, "pausa": self.in_pausa, "secondi": self.secondi, "nome": self.nome,
                "livelli": self.livelli[-120:], "errore": self.errore}

    def ferma(self, tieni: bool = True) -> dict:
        self._fermo.set()
        try:
            self._processo.terminate()
            self._processo.wait(timeout=3)
        except (OSError, subprocess.TimeoutExpired):
            self._processo.kill()
        self._filo.join(timeout=3)
        self._uscita.close()
        if not tieni or self.secondi < 0.5:
            self.wav.unlink(missing_ok=True)
            return {"ok": False}
        finale = cartella() / (self.nome + ".wav")
        if shutil.which("ffmpeg"):
            m4a = cartella() / (self.nome + ".m4a")
            r = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(self.wav), "-c:a", "aac", "-b:a", "96k",
                                "-metadata", f"title={self.nome}", str(m4a)], capture_output=True, timeout=600)
            if r.returncode == 0 and m4a.exists():
                self.wav.unlink(missing_ok=True)
                finale = m4a
        if self.wav.exists():
            self.wav.rename(finale)
        indice = _indice()
        indice[finale.name] = {"durata": round(self.secondi, 2), "onde": _riduci(self.livelli), "creato": time.time()}
        scrivi_json(_indice_file(), indice)
        return {"ok": True, "id": finale.name}


_attuale: Registrazione | None = None


def avvia() -> dict:
    global _attuale
    if _attuale:
        return _attuale.stato()
    try:
        _attuale = Registrazione()
    except (RuntimeError, OSError) as e:
        return {"registra": False, "errore": str(e)}
    return _attuale.stato()


def pausa(si: bool) -> dict:
    if _attuale:
        _attuale.in_pausa = bool(si)
        return _attuale.stato()
    return stato()


def stato() -> dict:
    return _attuale.stato() if _attuale else {"registra": False}


def ferma(tieni: bool = True) -> dict:
    global _attuale
    if not _attuale:
        return {"ok": False}
    r = _attuale.ferma(tieni)
    _attuale = None
    return r


def _durata(f: Path) -> float:
    if f.suffix == ".wav":
        try:
            with wave.open(str(f)) as w:
                return w.getnframes() / w.getframerate()
        except (wave.Error, OSError, EOFError):
            return 0.0
    if shutil.which("ffprobe"):
        try:
            r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(f)],
                               capture_output=True, text=True, timeout=10)
            return float(r.stdout.strip() or 0)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            return 0.0
    return 0.0


def elenco() -> list[dict]:
    indice = _indice()
    cambiato = False
    voci = []
    for f in cartella().iterdir():
        if f.name.startswith(".") or f.suffix.lower() not in ESTENSIONI:
            continue
        info = indice.get(f.name)
        if not info:
            info = {"durata": round(_durata(f), 2), "onde": [], "creato": f.stat().st_mtime}
            indice[f.name] = info
            cambiato = True
        quando = datetime.fromtimestamp(info.get("creato") or f.stat().st_mtime)
        voci.append({"id": f.name, "nome": f.stem, "percorso": f.as_uri(), "durata": info.get("durata", 0),
                     "onde": info.get("onde") or [], "creato": info.get("creato", 0), "data": testo_data(quando)})
    for nome in [n for n in indice if not (cartella() / n).exists()]:
        del indice[nome]
        cambiato = True
    if cambiato:
        scrivi_json(_indice_file(), indice)
    voci.sort(key=lambda v: -v["creato"])
    return voci


def testo_data(d: datetime) -> str:
    oggi = datetime.now().date()
    if d.date() == oggi:
        return T("Oggi") + " " + d.strftime("%H:%M")
    if (oggi - d.date()).days == 1:
        return T("Ieri") + " " + d.strftime("%H:%M")
    return d.strftime("%d/%m/%Y")


def rinomina(ident: str, nome: str) -> dict:
    nome = "".join(c for c in str(nome).strip() if c not in '/\\:*?"<>|')[:80]
    sorgente = cartella() / Path(ident).name
    if not nome or not sorgente.exists():
        return {"ok": False}
    dest = sorgente.with_name(nome + sorgente.suffix)
    if dest.exists() and dest != sorgente:
        return {"ok": False, "messaggio": T("C'è già una registrazione con questo nome")}
    sorgente.rename(dest)
    indice = _indice()
    if sorgente.name in indice:
        indice[dest.name] = indice.pop(sorgente.name)
        scrivi_json(_indice_file(), indice)
    return {"ok": True, "id": dest.name}


def elimina(ident: str) -> bool:
    f = cartella() / Path(ident).name
    if not f.exists():
        return False
    try:
        nel_cestino = subprocess.run(["gio", "trash", str(f)], capture_output=True, timeout=10).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        nel_cestino = False
    if not nel_cestino:
        f.unlink(missing_ok=True)
    return True
