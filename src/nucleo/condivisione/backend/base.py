"""Interfaccia comune dei backend."""

from __future__ import annotations

from ..modelli import Dispositivo, Trasferimento


class Backend:
    nome = ""
    stabile = True

    def __init__(self, gestore):
        self.gestore = gestore          # Gestore (servizio principale)

    def disponibile(self) -> tuple[bool, str]:
        return True, ""

    async def avvia(self) -> None:
        """Avvia server e scoperta (sempre attivi finché il servizio gira)."""

    async def ferma(self) -> None:
        pass

    async def visibilita(self, modalita: str) -> None:
        """«nessuno» | «associati» | «tutti10»: annunci attivi o no."""

    async def scopri(self, secondi: int = 15) -> None:
        """Cerca attivamente dispositivi (es. quando si apre «Condividi»)."""

    async def invia(self, dispositivo: Dispositivo, trasferimento: Trasferimento) -> None:
        raise NotImplementedError
