"""Strutture dati condivise tra i backend."""

from __future__ import annotations

import secrets
import time
from dataclasses import dataclass, field


@dataclass
class Dispositivo:
    id: str                    # univoco per backend, es. "quickshare:AB12"
    nome: str
    tipo: str = "telefono"     # telefono | tablet | computer
    backend: str = ""
    indirizzo: str = ""
    porta: int = 0
    extra: dict = field(default_factory=dict)
    visto: float = field(default_factory=time.time)

    def pubblico(self) -> dict:
        return {"id": self.id, "nome": self.nome, "tipo": self.tipo, "backend": self.backend}


@dataclass
class FileInArrivo:
    nome: str
    dimensione: int
    mime: str = "application/octet-stream"


@dataclass
class Trasferimento:
    direzione: str             # "ricevi" | "invia"
    backend: str
    dispositivo: str           # nome leggibile
    file: list = field(default_factory=list)   # FileInArrivo o percorsi
    id: str = field(default_factory=lambda: secrets.token_hex(6))
    totale: int = 0
    trasferiti: int = 0
    stato: str = "in attesa"   # in attesa | accettato | rifiutato | in corso | completato | errore | annullato
    percorsi: list = field(default_factory=list)
    annullato: bool = False
    codice: str = ""           # codice di verifica (Quick Share)
    anteprima: str = ""        # percorso di un'immagine di anteprima, se disponibile

    def percentuale(self) -> int:
        return int(self.trasferiti * 100 / self.totale) if self.totale else 0
