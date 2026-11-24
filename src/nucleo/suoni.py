"""Suoni di SolidOS generati qui (niente file di altri): la suoneria della sveglia e del timer,
tre note morbide che si ripetono. Si suonano con il primo programma che c'è (PipeWire,
PulseAudio o ALSA)."""

from __future__ import annotations

import math
import os
import shutil
import struct
import subprocess
import wave
from pathlib import Path

from . import branding

FREQ = 44100


def _nota(f: float, durata: float, volume: float = 0.35) -> list[int]:
    n = int(FREQ * durata)
    campioni = []
    for i in range(n):
        t = i / FREQ
        inviluppo = min(1.0, t / 0.01) * math.exp(-3.2 * t / durata)   # attacco breve, coda morbida
        v = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t)   # un po' di armonico: suono di campanella
        campioni.append(int(32767 * volume * inviluppo * v / 1.25))
    return campioni


def suoneria() -> Path:
    """Il file della suoneria (creato la prima volta in ~/.cache)."""
    f = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os() / "suoni" / "suoneria.wav"
    if f.is_file():
        return f
    f.parent.mkdir(parents=True, exist_ok=True)
    campioni = []
    for f_hz, dur in ((880.0, 0.32), (1108.7, 0.32), (1318.5, 0.6)):   # La, Do#, Mi: accordo maggiore
        campioni += _nota(f_hz, dur)
    campioni += [0] * int(FREQ * 0.55)
    tmp = f.with_suffix(".tmp")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FREQ)
        w.writeframes(struct.pack(f"<{len(campioni)}h", *campioni))
    tmp.replace(f)
    return f


def _scrivi(nome: str, campioni: list[int]) -> Path:
    f = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / branding.id_os() / "suoni" / nome
    if f.is_file():
        return f
    f.parent.mkdir(parents=True, exist_ok=True)
    tmp = f.with_suffix(".tmp")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(FREQ)
        w.writeframes(struct.pack(f"<{len(campioni)}h", *campioni))
    tmp.replace(f)
    return f


def squillo() -> Path:
    """Chiamata in arrivo: due trilli brevi (Mi-Sol# veloci) e una pausa."""
    c: list[int] = []
    for _ in range(2):
        for _ in range(6):
            c += _nota(1318.5, 0.05, 0.3) + _nota(1661.2, 0.05, 0.3)
        c += [0] * int(FREQ * 0.25)
    return _scrivi("squillo.wav", c + [0] * int(FREQ * 1.2))


def attesa() -> Path:
    """Tono di chi chiama mentre l'altro squilla (425 Hz: 1 secondo sì, 4 no, come in Italia)."""
    n = FREQ
    c = [int(32767 * 0.18 * min(1.0, i / 400, (n - i) / 400) * math.sin(2 * math.pi * 425 * i / FREQ)) for i in range(n)]
    return _scrivi("attesa.wav", c + [0] * (FREQ * 4))


def suona(volte: int = 1, file: Path | None = None) -> subprocess.Popen | None:
    """Suona la suoneria (o il file dato) «volte» volte, in sottofondo; None se non c'è modo di suonare."""
    lettore = next((p for p in ("pw-play", "paplay", "aplay") if shutil.which(p)), None)
    if not lettore:
        return None
    f = str(file or suoneria())
    comando = " ; ".join([f"{lettore} {f!r}"] * max(1, volte))
    return subprocess.Popen(["sh", "-c", comando], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
