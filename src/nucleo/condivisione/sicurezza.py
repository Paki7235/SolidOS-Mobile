"""Regole di sicurezza per i file ricevuti."""

from __future__ import annotations

import os
import re
import shutil
from pathlib import Path

from ..formati import estensione_ingannevole, tipo_mime

ESTENSIONI_RISCHIOSE = {".exe", ".msi", ".bat", ".cmd", ".com", ".scr", ".ps1", ".vbs", ".js", ".jar",
                        ".sh", ".run", ".bin", ".appimage", ".desktop", ".deb", ".rpm", ".apk", ".lnk"}


def nome_sicuro(nome: str) -> str:
    """Rimuove percorsi, caratteri di controllo e nomi riservati."""
    nome = nome.replace("\\", "/").split("/")[-1]
    nome = re.sub(r"[\x00-\x1f<>:\"|?*]", "_", nome).strip(" .")
    return nome[:200] or "file"


def percorso_libero(cartella: Path, nome: str) -> Path:
    """Non sovrascrive mai: aggiunge (1), (2)…"""
    cartella.mkdir(parents=True, exist_ok=True)
    candidato = cartella / nome
    base, est = os.path.splitext(nome)
    n = 1
    while candidato.exists():
        candidato = cartella / f"{base} ({n}){est}"
        n += 1
    return candidato


def spazio_sufficiente(cartella: Path, byte: int) -> bool:
    cartella.mkdir(parents=True, exist_ok=True)
    return shutil.disk_usage(cartella).free > byte + 200 * 1024 * 1024


def rischioso(nome: str) -> bool:
    return Path(nome).suffix.lower() in ESTENSIONI_RISCHIOSE


def dopo_ricezione(percorso: Path) -> dict:
    """Toglie il permesso di esecuzione e controlla tipo reale ed estensione."""
    try:
        percorso.chmod(0o644)
    except OSError:
        pass
    return {"mime": tipo_mime(str(percorso)), "ingannevole": estensione_ingannevole(str(percorso)),
            "rischioso": rischioso(percorso.name)}
