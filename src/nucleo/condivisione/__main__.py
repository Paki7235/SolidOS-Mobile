"""Servizio Condivisione Vicina (demone utente, avviato da systemd --user)."""

import asyncio
import logging
import signal
import sys

from .servizio import Gestore


async def principale():
    gestore = Gestore()
    await gestore.avvia()
    fine = asyncio.Event()
    loop = asyncio.get_running_loop()
    for s in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(s, fine.set)
    await fine.wait()
    for b in gestore.backend.values():
        try:
            await b.ferma()
        except Exception:  # noqa: BLE001
            pass


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    asyncio.run(principale())
    return 0


if __name__ == "__main__":
    sys.exit(main())
