"""Codifica/decodifica protobuf minima (senza codice generato).

Un messaggio è rappresentato da un dizionario {numero_campo: valore}:
- int → varint; bytes/str → length-delimited; dict → sotto-messaggio;
- list → campo ripetuto.
In decodifica si ottiene {numero_campo: [valori grezzi]} (int o bytes):
i sotto-messaggi si decodificano a richiesta con decodifica(valore).
"""


def _varint(n: int) -> bytes:
    if n < 0:
        n += 1 << 64
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def codifica(messaggio: dict) -> bytes:
    out = bytearray()
    for numero in sorted(messaggio):
        valori = messaggio[numero]
        if valori is None:
            continue
        if not isinstance(valori, list):
            valori = [valori]
        for v in valori:
            if isinstance(v, bool):
                out += _varint(numero << 3) + _varint(int(v))
            elif isinstance(v, int):
                out += _varint(numero << 3) + _varint(v)
            elif isinstance(v, (bytes, bytearray)):
                out += _varint((numero << 3) | 2) + _varint(len(v)) + bytes(v)
            elif isinstance(v, str):
                b = v.encode("utf-8")
                out += _varint((numero << 3) | 2) + _varint(len(b)) + b
            elif isinstance(v, dict):
                b = codifica(v)
                out += _varint((numero << 3) | 2) + _varint(len(b)) + b
            else:
                raise TypeError(f"tipo non supportato per il campo {numero}: {type(v)}")
    return bytes(out)


def _leggi_varint(dati: bytes, pos: int) -> tuple[int, int]:
    risultato, spostamento = 0, 0
    while True:
        b = dati[pos]
        pos += 1
        risultato |= (b & 0x7F) << spostamento
        if not b & 0x80:
            return risultato, pos
        spostamento += 7


def decodifica(dati: bytes) -> dict:
    campi: dict[int, list] = {}
    pos = 0
    while pos < len(dati):
        chiave, pos = _leggi_varint(dati, pos)
        numero, tipo = chiave >> 3, chiave & 7
        if tipo == 0:
            valore, pos = _leggi_varint(dati, pos)
        elif tipo == 2:
            lunghezza, pos = _leggi_varint(dati, pos)
            valore = dati[pos:pos + lunghezza]
            pos += lunghezza
        elif tipo == 1:
            valore = dati[pos:pos + 8]
            pos += 8
        elif tipo == 5:
            valore = dati[pos:pos + 4]
            pos += 4
        else:
            raise ValueError(f"tipo di campo protobuf non supportato: {tipo}")
        campi.setdefault(numero, []).append(valore)
    return campi


def primo(campi: dict, numero: int, predefinito=None):
    valori = campi.get(numero)
    return valori[0] if valori else predefinito


def sotto(campi: dict, numero: int) -> dict:
    valore = primo(campi, numero)
    return decodifica(valore) if isinstance(valore, (bytes, bytearray)) else {}


def intero_con_segno(n: int) -> int:
    return n - (1 << 64) if n >= 1 << 63 else n
