"""Funzioni comuni: comandi, helper privilegiato, notifiche, percorsi utente."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

from . import branding

HELPER = "/usr/libexec/nucleo/helper"


class ErroreComando(RuntimeError):
    pass


def esegui(comando: list[str], timeout: float = 20, ingresso: str | None = None,
           controlla: bool = False, ambiente: dict | None = None) -> subprocess.CompletedProcess:
    """Esegue un comando senza shell e restituisce il risultato (testo)."""
    env = None
    if ambiente:
        env = dict(os.environ)
        env.update(ambiente)
    try:
        risultato = subprocess.run(
            comando, input=ingresso, capture_output=True, text=True,
            timeout=timeout, env=env, check=False,
        )
    except FileNotFoundError as e:
        if controlla:
            raise ErroreComando(f"comando non trovato: {comando[0]}") from e
        return subprocess.CompletedProcess(comando, 127, "", str(e))
    except subprocess.TimeoutExpired as e:
        if controlla:
            raise ErroreComando(f"tempo scaduto: {' '.join(comando)}") from e
        return subprocess.CompletedProcess(comando, 124, "", "timeout")
    if controlla and risultato.returncode != 0:
        raise ErroreComando(risultato.stderr.strip() or f"errore {risultato.returncode}")
    return risultato


def uscita(comando: list[str], timeout: float = 20) -> str:
    """Restituisce lo stdout di un comando ('' in caso di errore)."""
    r = esegui(comando, timeout=timeout)
    return r.stdout if r.returncode == 0 else ""


def esiste(programma: str) -> bool:
    return shutil.which(programma) is not None


def avvia(comando: list[str]) -> None:
    """Avvia un programma staccato dal processo corrente."""
    ambiente = {k: v for k, v in os.environ.items() if k != "QT_WAYLAND_SHELL_INTEGRATION"}
    try:
        subprocess.Popen(comando, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         stdin=subprocess.DEVNULL, start_new_session=True, env=ambiente)
    except FileNotFoundError:
        pass


def helper(*argomenti: str, timeout: float = 600) -> subprocess.CompletedProcess:
    """Esegue un'operazione privilegiata tramite pkexec e l'helper autorizzato da polkit."""
    if os.geteuid() == 0:
        return esegui([HELPER, *argomenti], timeout=timeout)
    return esegui(["pkexec", HELPER, *argomenti], timeout=timeout)


def notifica(titolo: str, testo: str = "", icona: str = "", urgenza: str = "normal") -> None:
    cmd = ["notify-send", f"--app-name={branding.nome()}", f"--urgency={urgenza}"]
    if icona:
        cmd.append(f"--icon={icona}")
    cmd += [titolo, testo]
    avvia(cmd)


def cartella_utente(tipo: str, ripiego: str) -> Path:
    """Cartella XDG dell'utente (DOWNLOAD, PICTURES, DOCUMENTS…)."""
    valore = uscita(["xdg-user-dir", tipo]).strip()
    if valore and valore != str(Path.home()):
        return Path(valore)
    return Path.home() / ripiego


def config_utente(*parti: str) -> Path:
    base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    percorso = base / branding.id_os() / Path(*parti)
    percorso.parent.mkdir(parents=True, exist_ok=True)
    return percorso


def stato_utente(*parti: str) -> Path:
    base = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    percorso = base / branding.id_os() / Path(*parti)
    percorso.parent.mkdir(parents=True, exist_ok=True)
    return percorso


def leggi_json(percorso: Path, predefinito):
    try:
        return json.loads(Path(percorso).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return predefinito


def scrivi_json(percorso: Path, dati) -> None:
    percorso = Path(percorso)
    percorso.parent.mkdir(parents=True, exist_ok=True)
    temporaneo = percorso.with_suffix(percorso.suffix + ".tmp")
    temporaneo.write_text(json.dumps(dati, ensure_ascii=False, indent=2), encoding="utf-8")
    temporaneo.replace(percorso)


def ram_totale_mb() -> int:
    try:
        for riga in Path("/proc/meminfo").read_text().splitlines():
            if riga.startswith("MemTotal:"):
                return int(riga.split()[1]) // 1024
    except OSError:
        pass
    return 0


def in_sessione_live() -> bool:
    return Path("/run/live/medium").exists() or "boot=live" in Path("/proc/cmdline").read_text()


def parametro_avvio(nome: str) -> str | None:
    """Valore di un parametro del kernel <OS_ID>.<nome>=valore."""
    chiave = f"{branding.id_os()}.{nome}="
    try:
        for parte in Path("/proc/cmdline").read_text().split():
            if parte.startswith(chiave):
                return parte[len(chiave):]
    except OSError:
        pass
    return None


def avvia_desktop(desktop: str, file: list[str] | None = None) -> bool:
    """Avvia un'app dalla sua voce .desktop passando i file (codici %f %F %u %U)."""
    import configparser
    import shlex

    cartelle = [Path.home() / ".local/share/applications", Path("/usr/share/applications"),
                Path("/var/lib/flatpak/exports/share/applications"),
                Path.home() / ".local/share/flatpak/exports/share/applications"]
    nome = desktop if desktop.endswith(".desktop") else desktop + ".desktop"
    if desktop.startswith("/"):        # collegamento con percorso completo (es. sulla scrivania)
        cartelle, nome = [Path(desktop).parent], Path(desktop).name
    for cartella in cartelle:
        percorso = cartella / nome
        if not percorso.is_file():
            continue
        c = configparser.RawConfigParser(strict=False, interpolation=None)
        try:
            c.read(percorso, encoding="utf-8")
            voce = c["Desktop Entry"]
            exec_riga = voce["Exec"]
        except (configparser.Error, KeyError, UnicodeDecodeError):
            return False
        file = file or []
        argomenti = []
        try:
            parti = shlex.split(exec_riga)
        except ValueError:
            return False
        for parte in parti:
            if parte in ("%f", "%u"):
                argomenti += file[:1]
            elif parte in ("%F", "%U"):
                argomenti += file
            elif parte in ("%i", "%c", "%k", "%d", "%D", "%n", "%N", "%v", "%m"):
                continue
            elif parte in ("@@", "@@u", "@@f"):     # segnaposto di Flatpak per i file
                continue
            else:
                argomenti.append(parte.replace("%%", "%"))
        if not argomenti:
            return False
        import shutil

        if not (Path(argomenti[0]).is_file() or shutil.which(argomenti[0])):
            return False                    # programma mancante: chi chiama prova un'altra strada
        if voce.get("Terminal", "false").strip().lower() == "true":
            argomenti = ["qterminal", "-e", shlex.join(argomenti)]
        cartella_lavoro = voce.get("Path", "").strip()
        if cartella_lavoro and Path(cartella_lavoro).is_dir():
            ambiente = {k: v for k, v in os.environ.items() if k != "QT_WAYLAND_SHELL_INTEGRATION"}
            subprocess.Popen(argomenti, cwd=cartella_lavoro, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             stdin=subprocess.DEVNULL, start_new_session=True, env=ambiente)
        else:
            avvia(argomenti)
        return True
    return False


SFONDO_INIZIALE = "/usr/share/backgrounds/{id}/notte.png"


def sfondo_attuale() -> str:
    """Percorso dello sfondo scelto dall'utente (o quello iniziale).
    Gli sfondi del sistema esistono in coppia («nome.png» scuro, «nome-chiaro.png» chiaro):
    si usa da solo quello adatto al tema chiaro o scuro."""
    from . import branding

    percorso = SFONDO_INIZIALE.format(id=branding.id_os())
    f = config_utente("sfondo")
    if f.exists():
        scelto = f.read_text().strip()
        if scelto and Path(scelto).exists():
            percorso = scelto
    p = Path(percorso)
    if p.parent == Path(SFONDO_INIZIALE.format(id=branding.id_os())).parent:
        base = p.stem.removesuffix("-chiaro")
        chiaro = leggi_json(config_utente("aspetto.json"), {}).get("tema") == "chiaro"
        variante = p.with_name(base + ("-chiaro" if chiaro else "") + p.suffix)
        if variante.exists():
            return str(variante)
    return percorso


def imposta_sfondo(percorso: str) -> None:
    """Salva lo sfondo e lo applica subito: lo disegna la scrivania della shell."""
    from . import branding
    from .dbusutil import chiama

    config_utente("sfondo").write_text(str(percorso))
    nome = branding.nome_dbus("Shell")
    chiama(nome, branding.percorso_dbus("Shell"), nome, "AggiornaSfondo", timeout=2)
