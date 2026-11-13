"""Piccole utilità D-Bus basate su dbus-python (integrato nel ciclo eventi Qt/GLib)."""

from __future__ import annotations

_PRONTO = False


def inizializza():
    """Collega dbus-python al ciclo eventi GLib (usato anche da Qt su Linux)."""
    global _PRONTO
    if not _PRONTO:
        from dbus.mainloop.glib import DBusGMainLoop

        DBusGMainLoop(set_as_default=True)
        _PRONTO = True


def chiama(nome: str, percorso: str, interfaccia: str, metodo: str, *argomenti,
           sistema: bool = False, timeout: float = 5.0):
    """Chiamata sincrona; restituisce None se il servizio non risponde."""
    import dbus

    try:
        bus = dbus.SystemBus() if sistema else dbus.SessionBus()
        oggetto = bus.get_object(nome, percorso, introspect=False)  # niente introspezione: rispetta il timeout
        return oggetto.get_dbus_method(metodo, interfaccia)(*argomenti, timeout=timeout)
    except dbus.exceptions.DBusException:
        return None


def a_python(valore):
    """Converte i tipi dbus-python in tipi Python semplici (per il QML)."""
    import dbus

    if isinstance(valore, (dbus.String, dbus.ObjectPath, dbus.Signature)):
        return str(valore)
    if isinstance(valore, dbus.Boolean):
        return bool(valore)
    if isinstance(valore, (dbus.Byte, dbus.Int16, dbus.Int32, dbus.Int64,
                           dbus.UInt16, dbus.UInt32, dbus.UInt64)):
        return int(valore)
    if isinstance(valore, dbus.Double):
        return float(valore)
    if isinstance(valore, (dbus.Array, list, tuple, dbus.Struct)):
        return [a_python(v) for v in valore]
    if isinstance(valore, (dbus.Dictionary, dict)):
        return {str(k): a_python(v) for k, v in valore.items()}
    return valore
