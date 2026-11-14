#!/usr/bin/env python3
"""Controlli veloci prima della prova: errori di QML che Qt rifiuta e id ripetuti."""
import re
import sys
from pathlib import Path

errori = []
for f in sorted(Path(__file__).resolve().parents[1].glob("src/qml/**/*.qml")):
    testo = f.read_text(encoding="utf-8")
    for n, riga in enumerate(testo.splitlines(), 1):
        if re.search(r"\{\s*\}\s*;", riga):
            errori.append(f"{f.name}:{n}: un oggetto scritto su una riga («{{}}») non può essere seguito da «;»")
    if testo.count("{") != testo.count("}"):
        errori.append(f"{f.name}: graffe aperte {testo.count('{')} e chiuse {testo.count('}')}")
    ids = re.findall(r"^\s*id:\s*(\w+)", testo, re.M)
    for doppio in sorted({i for i in ids if ids.count(i) > 1}):
        errori.append(f"{f.name}: id ripetuto «{doppio}»")
for e in errori:
    print("ERRORE", e)
print("Controlli QML:", "problemi trovati" if errori else "tutto a posto")
sys.exit(1 if errori else 0)
