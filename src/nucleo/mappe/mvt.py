"""Lettore delle «tessere vettoriali» (formato Mapbox Vector Tile, protobuf) senza librerie.

Una tessera contiene strati (acqua, strade, edifici, nomi…) e per ogni oggetto il tipo di
geometria, gli attributi e le coordinate in una griglia 0…extent (di solito 4096).
"""

from __future__ import annotations

import gzip
import struct


def _varint(b: bytes, i: int) -> tuple[int, int]:
    risultato = spostamento = 0
    while True:
        c = b[i]
        i += 1
        risultato |= (c & 0x7F) << spostamento
        if not c & 0x80:
            return risultato, i
        spostamento += 7


def _campi(b: bytes):
    """(numero del campo, tipo, valore) per ogni campo di un messaggio protobuf."""
    i, n = 0, len(b)
    while i < n:
        chiave, i = _varint(b, i)
        campo, tipo = chiave >> 3, chiave & 7
        if tipo == 0:
            v, i = _varint(b, i)
        elif tipo == 2:
            lung, i = _varint(b, i)
            v = b[i:i + lung]
            i += lung
        elif tipo == 5:
            v = b[i:i + 4]
            i += 4
        elif tipo == 1:
            v = b[i:i + 8]
            i += 8
        else:
            raise ValueError("protobuf non valido")
        yield campo, tipo, v


def _impacchettati(b: bytes) -> list[int]:
    out, i, n = [], 0, len(b)
    while i < n:
        v, i = _varint(b, i)
        out.append(v)
    return out


def _valore(b: bytes):
    for campo, _tipo, v in _campi(b):
        if campo == 1:
            return v.decode("utf-8", "replace")
        if campo == 2:
            return struct.unpack("<f", v)[0]
        if campo == 3:
            return struct.unpack("<d", v)[0]
        if campo in (4, 5):
            return v
        if campo == 6:
            return (v >> 1) ^ -(v & 1)
        if campo == 7:
            return bool(v)
    return None


def _geometria(comandi: list[int]) -> list[list[tuple[int, int]]]:
    """Le parti della geometria (anelli o linee) come elenchi di punti."""
    parti, attuale, x, y, i, n = [], [], 0, 0, 0, len(comandi)
    while i < n:
        c = comandi[i]
        i += 1
        cmd, quante = c & 7, c >> 3
        if cmd in (1, 2):
            for _ in range(quante):
                dx, dy = comandi[i], comandi[i + 1]
                i += 2
                x += (dx >> 1) ^ -(dx & 1)
                y += (dy >> 1) ^ -(dy & 1)
                if cmd == 1:
                    if attuale:
                        parti.append(attuale)
                    attuale = [(x, y)]
                else:
                    attuale.append((x, y))
        elif cmd == 7 and attuale:
            attuale.append(attuale[0])
    if attuale:
        parti.append(attuale)
    return parti


def leggi(dati: bytes) -> dict:
    """{nome_strato: {"extent": 4096, "oggetti": [{"tipo": 1|2|3, "attr": {...}, "geom": [...]}]}}"""
    if dati[:2] == b"\x1f\x8b":
        dati = gzip.decompress(dati)
    strati = {}
    for campo, _t, strato in _campi(dati):
        if campo != 3:
            continue
        nome, extent, chiavi, valori, grezzi = "", 4096, [], [], []
        for c, _t2, v in _campi(strato):
            if c == 1:
                nome = v.decode()
            elif c == 2:
                grezzi.append(v)
            elif c == 3:
                chiavi.append(v.decode())
            elif c == 4:
                valori.append(_valore(v))
            elif c == 5:
                extent = v
        oggetti = []
        for g in grezzi:
            tipo, tag, comandi = 0, [], []
            for c, _t3, v in _campi(g):
                if c == 2:
                    tag = _impacchettati(v)
                elif c == 3:
                    tipo = v
                elif c == 4:
                    comandi = _impacchettati(v)
            attr = {chiavi[tag[k]]: valori[tag[k + 1]] for k in range(0, len(tag) - 1, 2)
                    if tag[k] < len(chiavi) and tag[k + 1] < len(valori)}
            oggetti.append({"tipo": tipo, "attr": attr, "geom": _geometria(comandi)})
        strati[nome] = {"extent": extent, "oggetti": oggetti}
    return strati
