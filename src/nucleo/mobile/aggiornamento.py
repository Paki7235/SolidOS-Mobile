"""Aggiornamenti automatici e firmati di SolidOS Mobile.

Ogni build (workflow «Telefoni» su GitHub) pubblica nella Release «aggiornamento»:
- `solidos-mobile-aggiornamento-N.tar.xz`: la cartella /usr/share/solidos-mobile nuova
  (nucleo, qml, caratteri, icone, branding, versione);
- `versione.json`: numero della build, nome del file, somma SHA-256, novità;
- `versione.json.firma`: firma Ed25519 della scheda, fatta con la chiave segreta di SolidOS
  (sta solo nei segreti delle build). Il telefono la verifica con la chiave pubblica
  installata; senza firma valida non installa niente.

Il telefono controlla una volta al giorno (solidos-mobile-aggiornamenti.timer, come root):
1. scheda firmata e più nuova della versione installata;
2. scarica il pacchetto e ne verifica la somma;
3. lo estrae accanto a quello in uso e lo PROVA: avvia l'interfaccia nuova senza schermo e
   controlla che si carichi. Se non parte, la scarta e il telefono resta com'è;
4. scambia le cartelle tenendo la versione precedente in /usr/share/solidos-mobile.precedente
   (per tornare indietro: `solidos-mobile-aggiorna --torna-indietro`).
La nuova versione si usa dal prossimo avvio dell'interfaccia.

Uso (root): python3 -m nucleo.mobile.aggiornamento [--forza | --torna-indietro]
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
from pathlib import Path

CARTELLA = Path(os.environ.get("SOLIDOS_MOBILE_CARTELLA", "/usr/share/solidos-mobile"))
PRECEDENTE = CARTELLA.with_name(CARTELLA.name + ".precedente")
NUOVA = CARTELLA.with_name(CARTELLA.name + ".nuova")
STATO = Path("/var/lib/solidos-mobile/aggiornamento.json")
URL = "https://github.com/Paki7235/SolidOS-Mobile/releases/download/aggiornamento"
AGENTE = {"User-Agent": "SolidOS-Mobile-Aggiornamenti"}


def versione_installata(cartella: Path = CARTELLA) -> int:
    try:
        return int((cartella / "versione").read_text().split()[0])
    except (OSError, ValueError, IndexError):
        return 0


def stato() -> dict:
    """Per Impostazioni › Info: versione installata, ultimo controllo ed esito."""
    try:
        s = json.loads(STATO.read_text())
    except (OSError, ValueError):
        s = {}
    return {"versione": versione_installata(), "ultimo": s.get("ultimo", ""), "esito": s.get("esito", ""),
            "precedente": PRECEDENTE.is_dir()}


def firma_valida(dati: bytes, firma: bytes, chiave: Path | None = None) -> bool:
    """True se «firma» è la firma Ed25519 di «dati» fatta con la chiave di SolidOS."""
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.serialization import load_pem_public_key

    chiave = chiave or CARTELLA / "chiave-aggiornamenti.pem"
    try:
        pubblica = load_pem_public_key(chiave.read_bytes())
        pubblica.verify(firma, dati)
        return True
    except (OSError, ValueError, TypeError, InvalidSignature):
        return False


def _scarica(nome: str, limite: int = 1 << 20) -> bytes:
    with urllib.request.urlopen(urllib.request.Request(f"{URL}/{nome}", headers=AGENTE), timeout=30) as r:
        return r.read(limite)


def _scrivi_stato(esito: str) -> None:
    STATO.parent.mkdir(parents=True, exist_ok=True)
    STATO.write_text(json.dumps({"ultimo": time.strftime("%d/%m/%Y %H:%M"), "esito": esito}, ensure_ascii=False))
    STATO.chmod(0o644)


def _prova(cartella: Path) -> bool:
    """Avvia l'interfaccia nuova senza schermo, con dati di prova: deve caricarsi e uscire da sola."""
    with tempfile.TemporaryDirectory(prefix="prova-solidos-") as casa:
        foto = Path(casa) / "prova.png"
        ambiente = dict(os.environ, HOME=casa, PYTHONPATH=str(cartella), NUCLEO_QML=str(cartella / "qml"),
                        NUCLEO_BRANDING=str(cartella / "branding.env"), NUCLEO_DEMO="1", QT_QPA_PLATFORM="offscreen",
                        QT_QUICK_BACKEND="software")
        try:
            r = subprocess.run([sys.executable, "-m", "nucleo.mobile", f"--foto={foto}"], env=ambiente,
                               capture_output=True, timeout=90)
        except subprocess.TimeoutExpired:
            return False
        return r.returncode == 0 and foto.is_file() and foto.stat().st_size > 0


def _estrai(pacchetto: Path, dove: Path) -> None:
    shutil.rmtree(dove, ignore_errors=True)
    dove.mkdir(parents=True)
    with tarfile.open(pacchetto) as t:
        sicuri = [m for m in t.getmembers() if (m.isfile() or m.isdir())
                  and not m.name.startswith("/") and ".." not in Path(m.name).parts]
        t.extractall(dove, members=sicuri, filter="data")


def aggiorna(forza: bool = False) -> str:
    try:
        grezza, firma = _scarica("versione.json"), _scarica("versione.json.firma")
    except OSError:
        return "Server degli aggiornamenti non raggiungibile"
    if not firma_valida(grezza, firma):
        return "Aggiornamento rifiutato: la firma non è di SolidOS"
    try:
        scheda = json.loads(grezza)
        nuova, nome, atteso = int(scheda["versione"]), str(scheda["file"]), str(scheda["sha256"]).lower()
    except (ValueError, KeyError, TypeError):
        return "Scheda dell'aggiornamento non valida"
    installata = versione_installata()
    if nuova <= installata and not forza:
        return f"Già aggiornato (versione {installata})"
    if "/" in nome or not nome.endswith(".tar.xz") or len(atteso) != 64:
        return "Scheda dell'aggiornamento non valida"

    with tempfile.TemporaryDirectory(prefix="aggiorna-mobile-") as c:
        pacchetto = Path(c) / nome
        h = hashlib.sha256()
        try:
            with urllib.request.urlopen(urllib.request.Request(f"{URL}/{nome}", headers=AGENTE), timeout=300) as r, \
                    open(pacchetto, "wb") as f:
                while blocco := r.read(1 << 20):
                    h.update(blocco)
                    f.write(blocco)
        except OSError as e:
            return f"Download non riuscito: {e}"
        if h.hexdigest() != atteso:
            return "File scaricato danneggiato: si riprova domani"
        _estrai(pacchetto, NUOVA)

    if versione_installata(NUOVA) != nuova or not _prova(NUOVA):
        shutil.rmtree(NUOVA, ignore_errors=True)
        return f"La versione {nuova} non si avvia: resta quella di prima"
    shutil.rmtree(PRECEDENTE, ignore_errors=True)
    CARTELLA.rename(PRECEDENTE)
    NUOVA.rename(CARTELLA)
    _file_di_sistema()
    mancanti = _pacchetti_richiesti()
    return f"Aggiornato alla versione {nuova} (si usa dal prossimo avvio)" + (f"; installati: {', '.join(mancanti)}" if mancanti else "")


def _file_di_sistema(cartella: Path = CARTELLA) -> None:
    """Servizi e cartelle di sistema arrivati con l'aggiornamento (cartella «sistema»): si
    installano se sono nuovi o cambiati, poi si attivano (es. la richiesta «Aggiorna ora»)."""
    sorgente = cartella / "sistema"
    if not sorgente.is_dir() or not shutil.which("systemctl"):
        return
    cambiati = []
    for f in sorgente.iterdir():
        dest = Path("/usr/lib/tmpfiles.d") / f.name if f.suffix == ".conf" else Path("/usr/lib/systemd/system") / f.name
        try:
            if not dest.exists() or dest.read_bytes() != f.read_bytes():
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(f, dest)
                cambiati.append(dest)
        except OSError:
            continue
    if not cambiati:
        return
    subprocess.run(["systemd-tmpfiles", "--create"], capture_output=True)
    subprocess.run(["systemctl", "daemon-reload"], capture_output=True)
    for d in cambiati:
        if d.suffix == ".path":
            subprocess.run(["systemctl", "enable", "--now", d.name], capture_output=True)


def _pacchetti_richiesti(cartella: Path = CARTELLA) -> list[str]:
    """I programmi che servono alla versione nuova (dati/pacchetti-richiesti.txt), se mancano:
    un telefono installato da un'immagine vecchia li riceve così (per esempio il motore web
    delle videochiamate)."""
    import re

    f = cartella / "dati" / "pacchetti-richiesti.txt"
    if not f.is_file() or not shutil.which("apk"):
        return []
    nomi = [r.strip() for r in f.read_text().splitlines() if r.strip() and not r.startswith("#")]
    nomi = [n for n in nomi if re.fullmatch(r"[a-z0-9][a-z0-9.+_-]{1,80}", n)]
    mancanti = [n for n in nomi if subprocess.run(["apk", "info", "-e", n], capture_output=True).returncode != 0]
    if mancanti:
        try:
            subprocess.run(["apk", "add", "--no-interactive", *mancanti], capture_output=True, timeout=3600)
        except (OSError, subprocess.TimeoutExpired):
            return []
        mancanti = [n for n in mancanti if subprocess.run(["apk", "info", "-e", n], capture_output=True).returncode == 0]
    return mancanti


def torna_indietro() -> str:
    if not PRECEDENTE.is_dir():
        return "Non c'è una versione precedente"
    scambio = CARTELLA.with_name(CARTELLA.name + ".scambio")
    shutil.rmtree(scambio, ignore_errors=True)
    CARTELLA.rename(scambio)
    PRECEDENTE.rename(CARTELLA)
    scambio.rename(PRECEDENTE)
    return f"Tornato alla versione {versione_installata()}"


def main() -> None:
    if os.geteuid() != 0:
        print("Serve l'amministratore")
        sys.exit(1)
    _scrivi_stato("In corso")          # Impostazioni mostra «Scarico e controllo…»
    esito = torna_indietro() if "--torna-indietro" in sys.argv else aggiorna("--forza" in sys.argv)
    _scrivi_stato(esito)
    print(esito)


if __name__ == "__main__":
    main()
