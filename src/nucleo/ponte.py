"""Ponte generico Python ↔ QML.

Ogni app definisce una classe Python normale con metodi pubblici. Il ponte li
espone al QML con due slot:

    ponte.chiama("metodo", [arg1, arg2])          → risultato immediato
    ponte.avvia("metodo", [arg1], "id")            → eseguito in un thread;
                                                     al termine emette
                                                     completato(id, risultato)
                                                     oppure errore(id, messaggio)

Il backend può emettere eventi verso il QML con self.emetti("nome", dati),
ricevuti in QML con  Connections { target: ponte; function onEvento(nome, dati) {} }.
"""

from __future__ import annotations

import threading
import traceback


def crea_ponte(backend):
    from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot

    class Ponte(QObject):
        completato = pyqtSignal(str, "QVariant")
        errore = pyqtSignal(str, str)
        evento = pyqtSignal(str, "QVariant")

        def __init__(self, oggetto):
            super().__init__()
            self._oggetto = oggetto
            oggetto.emetti = lambda nome, dati=None: self.evento.emit(nome, dati)

        def _metodo(self, nome: str):
            if nome.startswith("_"):
                raise AttributeError(nome)
            return getattr(self._oggetto, nome)

        @pyqtSlot(str, "QVariantList", result="QVariant")
        def chiama(self, nome, argomenti):
            try:
                return self._metodo(nome)(*argomenti)
            except Exception as e:  # noqa: BLE001 — l'errore va mostrato in interfaccia
                traceback.print_exc()
                return {"errore": str(e)}

        @pyqtSlot(str, result="QVariant")
        def chiama0(self, nome):
            return self.chiama(nome, [])

        @pyqtSlot(str, "QVariantList", str)
        def avvia(self, nome, argomenti, identificativo):
            argomenti = list(argomenti)

            def lavoro():
                try:
                    risultato = self._metodo(nome)(*argomenti)
                    self.completato.emit(identificativo, risultato)
                except Exception as e:  # noqa: BLE001
                    traceback.print_exc()
                    self.errore.emit(identificativo, str(e))

            threading.Thread(target=lavoro, daemon=True).start()

    return Ponte(backend)


class Backend:
    """Classe base facoltativa per i backend delle app."""

    def emetti(self, nome: str, dati=None) -> None:  # sostituito dal ponte
        pass
