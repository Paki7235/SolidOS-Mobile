"""Server delle notifiche (org.freedesktop.Notifications, specifica 1.2).

Supporta: azioni, sostituzione (replaces_id), urgenza, icone e immagini
(image-path, image-data), suggerimento «value» per le barre di avanzamento,
Non disturbare e filtro per app (usato dagli Spazi di vita).
"""

from __future__ import annotations

import tempfile
import time
from pathlib import Path

import dbus
import dbus.service

from ..dbusutil import a_python

IFACE = "org.freedesktop.Notifications"
PERCORSO = "/org/freedesktop/Notifications"

# Motivi di chiusura previsti dalla specifica
SCADUTA, CHIUSA_UTENTE, CHIUSA_APP = 1, 2, 3

MAX_STORICO = 60


class ServerNotifiche(dbus.service.Object):
    def __init__(self, bus, avvisa):
        """avvisa(evento, dati) inoltra gli eventi all'interfaccia QML."""
        self._nome = dbus.service.BusName(IFACE, bus, do_not_queue=True)
        super().__init__(bus, PERCORSO)
        self._avvisa = avvisa
        self._prossimo = 1
        self.storico: list[dict] = []
        self.non_disturbare = False
        self.app_consentite: list[str] = []  # vuoto = tutte
        self._immagini = Path(tempfile.mkdtemp(prefix="notifiche-"))

    # ── Metodi della specifica ──────────────────────────────────────────────
    @dbus.service.method(IFACE, in_signature="", out_signature="as")
    def GetCapabilities(self):
        return ["actions", "body", "body-markup", "body-hyperlinks", "icon-static", "persistence"]

    @dbus.service.method(IFACE, in_signature="", out_signature="ssss")
    def GetServerInformation(self):
        from .. import branding

        return (f"{branding.nome()} Shell", branding.nome(), branding.get("OS_VERSION", "0"), "1.2")

    @dbus.service.method(IFACE, in_signature="susssasa{sv}i", out_signature="u")
    def Notify(self, app, sostituisce, icona, titolo, testo, azioni, suggerimenti, scadenza):
        suggerimenti = a_python(suggerimenti)
        ident = int(sostituisce) if sostituisce else self._prossimo
        if not sostituisce:
            self._prossimo += 1
        coppie = [str(a) for a in azioni]
        lista_azioni = [{"chiave": coppie[i], "testo": coppie[i + 1]}
                        for i in range(0, len(coppie) - 1, 2)]
        urgenza = int(suggerimenti.get("urgency", 1))
        notifica = {
            "id": ident,
            "app": str(app),
            "icona": self._icona(str(icona), suggerimenti, ident),
            "titolo": str(titolo),
            "testo": str(testo),
            "azioni": lista_azioni,
            "urgenza": urgenza,
            "valore": suggerimenti.get("value", -1),
            "residente": bool(suggerimenti.get("resident", False)),
            "transitoria": bool(suggerimenti.get("transient", False)),
            "scadenza": int(scadenza) if int(scadenza) > 0 else (0 if urgenza == 2 else 6000),
            "ora": time.strftime("%H:%M"),
        }
        if not notifica["transitoria"]:
            self.storico = [n for n in self.storico if n["id"] != ident]
            self.storico.insert(0, notifica)
            del self.storico[MAX_STORICO:]
        mostra = urgenza == 2 or not (self.non_disturbare or self._filtrata(notifica["app"]))
        self._avvisa("notifica", {"notifica": notifica, "mostra": mostra})
        return dbus.UInt32(ident)

    @dbus.service.method(IFACE, in_signature="u", out_signature="")
    def CloseNotification(self, ident):
        self.chiudi(int(ident), CHIUSA_APP)

    @dbus.service.signal(IFACE, signature="uu")
    def NotificationClosed(self, ident, motivo):
        pass

    @dbus.service.signal(IFACE, signature="us")
    def ActionInvoked(self, ident, chiave):
        pass

    # ── Usati dall'interfaccia ──────────────────────────────────────────────
    def chiudi(self, ident: int, motivo: int = CHIUSA_UTENTE) -> None:
        self._avvisa("chiusa", {"id": ident})
        self.NotificationClosed(dbus.UInt32(ident), dbus.UInt32(motivo))

    def azione(self, ident: int, chiave: str) -> None:
        self.ActionInvoked(dbus.UInt32(ident), chiave)
        notifica = next((n for n in self.storico if n["id"] == ident), None)
        if not notifica or not notifica["residente"]:
            self.chiudi(ident, CHIUSA_UTENTE)

    def rimuovi_da_storico(self, ident: int) -> None:
        self.storico = [n for n in self.storico if n["id"] != ident]

    def svuota_storico(self) -> None:
        self.storico = []

    def _filtrata(self, app: str) -> bool:
        return bool(self.app_consentite) and app not in self.app_consentite

    def _icona(self, icona: str, suggerimenti: dict, ident: int) -> str:
        dati = suggerimenti.get("image-data") or suggerimenti.get("image_data") or suggerimenti.get("icon_data")
        if dati and len(dati) == 7:
            percorso = self._salva_immagine(dati, ident)
            if percorso:
                return percorso
        for chiave in ("image-path", "image_path"):
            if suggerimenti.get(chiave):
                return str(suggerimenti[chiave]).removeprefix("file://")
        return icona.removeprefix("file://")

    def _salva_immagine(self, dati, ident: int) -> str:
        try:
            from PyQt6.QtGui import QImage

            larghezza, altezza, riga, alfa, _bit, _canali, pixel = dati
            formato = QImage.Format.Format_RGBA8888 if alfa else QImage.Format.Format_RGB888
            immagine = QImage(bytes(pixel), larghezza, altezza, riga, formato)
            percorso = self._immagini / f"{ident}-{int(time.time() * 1000)}.png"
            immagine.save(str(percorso))
            return str(percorso)
        except Exception:  # noqa: BLE001 — immagine non valida: si usa l'icona
            return ""
