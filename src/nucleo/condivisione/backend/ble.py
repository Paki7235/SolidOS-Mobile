"""Annunci Bluetooth LE tramite BlueZ (D-Bus di sistema).

- Quick Share: servizio 0xFE2C, fa comparire il PC sui telefoni Android vicini.
Nota: niente «from __future__ import annotations» (dbus-next legge le annotazioni).
"""

import logging
import secrets

from dbus_next import BusType, Variant
from dbus_next.aio import MessageBus
from dbus_next.service import PropertyAccess, ServiceInterface, dbus_property, method

log = logging.getLogger("condivisione.ble")
PERCORSO = "/org/nucleo/annuncio"


class _Annuncio(ServiceInterface):
    def __init__(self, uuid_servizi, dati_servizio, dati_produttore):
        super().__init__("org.bluez.LEAdvertisement1")
        self._uuid = uuid_servizi
        self._servizio = dati_servizio
        self._produttore = dati_produttore

    @method()
    def Release(self):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def Type(self) -> "s":
        return "broadcast"

    @dbus_property(access=PropertyAccess.READ)
    def ServiceUUIDs(self) -> "as":
        return self._uuid

    @dbus_property(access=PropertyAccess.READ)
    def ServiceData(self) -> "a{sv}":
        return {k: Variant("ay", v) for k, v in self._servizio.items()}

    @dbus_property(access=PropertyAccess.READ)
    def ManufacturerData(self) -> "a{qv}":
        return {k: Variant("ay", v) for k, v in self._produttore.items()}


class AnnuncioBLE:
    def __init__(self, nome, uuid_servizi=None, dati_servizio=None, dati_produttore=None):
        self.nome = nome
        self.oggetto = _Annuncio(uuid_servizi or [], dati_servizio or {}, dati_produttore or {})
        self.percorso = f"{PERCORSO}/{nome}"
        self.bus = None
        self.adattatore = "/org/bluez/hci0"

    @classmethod
    def quick_share(cls):
        dati = bytes([0xFC, 0x12, 0x8E, 0x01, 0x42, 0, 0, 0, 0, 0, 0, 0, 0, 0]) + secrets.token_bytes(10)
        return cls("quickshare", ["fe2c"], {"fe2c": dati})

    async def avvia(self) -> bool:
        try:
            self.bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
            self.bus.export(self.percorso, self.oggetto)
            intro = await self.bus.introspect("org.bluez", self.adattatore)
            adattatore = self.bus.get_proxy_object("org.bluez", self.adattatore, intro)
            gestore = adattatore.get_interface("org.bluez.LEAdvertisingManager1")
            await gestore.call_register_advertisement(self.percorso, {})
            log.info("annuncio BLE %s attivo", self.nome)
            return True
        except Exception as e:  # noqa: BLE001 — Bluetooth assente o spento: si continua senza
            log.info("annuncio BLE %s non disponibile: %s", self.nome, e)
            await self.ferma()
            return False

    async def ferma(self):
        if not self.bus:
            return
        try:
            intro = await self.bus.introspect("org.bluez", self.adattatore)
            adattatore = self.bus.get_proxy_object("org.bluez", self.adattatore, intro)
            await adattatore.get_interface("org.bluez.LEAdvertisingManager1").call_unregister_advertisement(self.percorso)
        except Exception:  # noqa: BLE001
            pass
        self.bus.disconnect()
        self.bus = None
