"""«Le mie app»: le app prese dallo Store, legate al Solid ID (come «Acquistati» dell'App Store).

Quando si installa un'app dallo Store (PC o telefono) entra nell'elenco del proprio Solid ID.
Gli altri dispositivi collegati allo stesso Solid ID la mostrano in «Le mie app» e, con
«Scarica da sola le app prese sugli altri dispositivi» acceso, la installano da soli.
L'installazione con Flatpak riporta la percentuale, per la barra di avanzamento.
Tabella e regole: supabase/schema.sql (sezione «Le mie app»).
Stesso file su PC (SolidOS App) e telefono (Store).
"""

from __future__ import annotations

import os
import re
import select
import shutil
import subprocess
import time

from .i18n import T

_ID = re.compile(r"^[A-Za-z0-9._-]{3,200}$")
_PERCENTO = re.compile(r"(\d{1,3})\s?%")
_COLORI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def _sid():
    from . import solidid

    return solidid


def collegato() -> bool:
    try:
        return _sid().collegato()
    except Exception:  # noqa: BLE001
        return False


def dispositivo() -> str:
    return "telefono" if os.path.exists("/usr/share/solidos-mobile") else "pc"


def elenco() -> list:
    """[{app, nome, icona, dispositivo, aggiunta}] dal Solid ID (vuoto senza accesso o senza rete)."""
    if not collegato():
        return []
    try:
        return _sid().rest("GET", "app_mie", filtri="select=app,nome,icona,dispositivo,aggiunta&order=aggiunta.desc",
                           rappresenta=False) or []
    except Exception:  # noqa: BLE001
        return []


def aggiungi(app: str, nome: str = "", icona: str = "") -> None:
    """Dopo un'installazione riuscita: l'app entra nell'elenco del Solid ID (se c'è l'accesso)."""
    if not _ID.match(app or "") or not collegato():
        return
    corpo = {"app": app, "nome": (nome or "")[:120], "icona": (icona or "")[:400], "dispositivo": dispositivo()}
    try:
        _sid().rest("POST", "app_mie", corpo, filtri="on_conflict=utente,app",
                    extra={"Prefer": "return=minimal,resolution=merge-duplicates"})
    except Exception:  # noqa: BLE001 — senza rete: si riprova alla prossima installazione
        pass


def togli(app: str) -> dict:
    """Toglie l'app dall'elenco del Solid ID (non la disinstalla)."""
    if not _ID.match(app or "") or not collegato():
        return {"ok": False, "messaggio": T("Accedi al Solid ID")}
    try:
        _sid().rest("DELETE", "app_mie", filtri=f"app=eq.{app}", rappresenta=False)
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "messaggio": str(e)}
    return {"ok": True, "messaggio": T("Tolta da «Le mie app»")}


def da_scaricare(installate: set) -> list:
    """Le app dell'elenco che su questo dispositivo non ci sono."""
    return [a for a in elenco() if a.get("app") not in installate]


def flatpak_installa(ident: str, avanzamento=None, timeout: int = 3600) -> tuple[int, str]:
    """Installa con Flatpak e chiama avanzamento(percento, fase) mentre scarica.

    Flatpak mostra la percentuale solo se scrive su un terminale: lo si avvia dentro uno
    pseudo-terminale e si leggono i numeri «NN%» (e «1/3» per i pezzi da scaricare).
    """
    if not shutil.which("flatpak"):
        return 1, T("Flatpak non è installato")
    import pty

    padrone, servo = pty.openpty()
    ambiente = dict(os.environ, COLUMNS="120", LINES="40", TERM="xterm")
    try:
        proc = subprocess.Popen(["flatpak", "install", "--user", "-y", "flathub", ident], stdin=servo, stdout=servo,
                                stderr=servo, env=ambiente, close_fds=True, start_new_session=True)
    except OSError as e:
        os.close(padrone)
        os.close(servo)
        return 1, str(e)
    os.close(servo)
    uscita, ultimo, fine = "", -1, time.time() + timeout
    pezzo, pezzi = 1, 1
    while True:
        if time.time() > fine:
            proc.kill()
            break
        pronti, _, _ = select.select([padrone], [], [], 0.5)
        if pronti:
            try:
                dati = os.read(padrone, 4096).decode("utf-8", "replace")
            except OSError:
                dati = ""
            if not dati:
                if proc.poll() is not None:
                    break
                continue
            uscita = (uscita + dati)[-20000:]
            testo = _COLORI.sub("", dati)
            for m in re.finditer(r"(\d+)/(\d+)", testo):
                a, b = int(m.group(1)), int(m.group(2))
                if 0 < a <= b <= 50:
                    pezzo, pezzi = a, b
            numeri = _PERCENTO.findall(testo)
            if numeri and avanzamento:
                p = min(100, int(numeri[-1]))
                totale = int(((pezzo - 1) + p / 100) / max(1, pezzi) * 100)
                if totale != ultimo:
                    ultimo = totale
                    avanzamento(totale, T("Scaricamento") if totale < 100 else T("Installazione"))
        elif proc.poll() is not None:
            break
    os.close(padrone)
    codice = proc.wait()
    return codice, _COLORI.sub("", uscita)
