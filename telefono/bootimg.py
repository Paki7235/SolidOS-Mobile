#!/usr/bin/env python3
"""Crea un'immagine di avvio Android (header versione 0), come «mkbootimg» di AOSP.

Il Huawei P10 Lite non ha la partizione «boot»: kernel e ramdisk vanno in due
partizioni separate, ognuna con la sua immagine. Uso:

  bootimg.py --kernel FILE|- --ramdisk FILE|- --cmdline "..." [--base 0x..]
             [--kernel_offset 0x..] [--ramdisk_offset 0x..] [--second_offset 0x..]
             [--tags_offset 0x..] [--pagesize 2048] [--os_version 8.0.0]
             [--os_patch_level 2018-06-05] -o USCITA

«-» (o /dev/null) vuol dire parte vuota.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import struct


def _leggi(percorso: str) -> bytes:
    if percorso in ("-", "/dev/null", ""):
        return b""
    with open(percorso, "rb") as f:
        return f.read()


def _versione_os(versione: str, patch: str) -> int:
    a, b, c = (int(x) for x in (versione.split(".") + ["0", "0"])[:3])
    m = re.match(r"^(\d{4})-(\d{2})", patch)
    anno, mese = (int(m.group(1)), int(m.group(2))) if m else (2000, 0)
    return ((a << 14) | (b << 7) | c) << 11 | ((anno - 2000) << 4) | mese


def _riempi(dati: bytes, pagina: int) -> bytes:
    resto = len(dati) % pagina
    return dati + b"\0" * ((pagina - resto) if resto else 0)


def crea(kernel: bytes, ramdisk: bytes, cmdline: str, base: int, kernel_offset: int, ramdisk_offset: int,
         second_offset: int, tags_offset: int, pagina: int, versione_os: int) -> bytes:
    sha = hashlib.sha1()
    for parte in (kernel, ramdisk, b""):
        sha.update(parte)
        sha.update(struct.pack("<I", len(parte)))
    ident = sha.digest().ljust(32, b"\0")
    riga = cmdline.encode()
    if len(riga) > 512 + 1024 - 2:
        raise SystemExit("cmdline troppo lunga")
    principale, extra = riga[:511], riga[511:]
    testata = struct.pack(
        "<8s10I16s512s32s1024s",
        b"ANDROID!",
        len(kernel), base + kernel_offset,
        len(ramdisk), base + ramdisk_offset,
        0, base + second_offset,
        base + tags_offset,
        pagina,
        0,              # header_version
        versione_os,
        b"",            # nome
        principale.ljust(512, b"\0"),
        ident,
        extra.ljust(1024, b"\0"),
    )
    return _riempi(testata, pagina) + _riempi(kernel, pagina) + _riempi(ramdisk, pagina)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--kernel", default="-")
    p.add_argument("--ramdisk", default="-")
    p.add_argument("--cmdline", default="")
    numero = lambda x: int(x, 0)  # noqa: E731
    p.add_argument("--base", type=numero, default=0x10000000)
    p.add_argument("--kernel_offset", type=numero, default=0x00008000)
    p.add_argument("--ramdisk_offset", type=numero, default=0x01000000)
    p.add_argument("--second_offset", type=numero, default=0x00F00000)
    p.add_argument("--tags_offset", type=numero, default=0x00000100)
    p.add_argument("--pagesize", type=int, default=2048)
    p.add_argument("--os_version", default="0.0.0")
    p.add_argument("--os_patch_level", default="2000-00")
    p.add_argument("-o", "--output", required=True)
    a = p.parse_args()
    dati = crea(_leggi(a.kernel), _leggi(a.ramdisk), a.cmdline, a.base, a.kernel_offset, a.ramdisk_offset,
                a.second_offset, a.tags_offset, a.pagesize, _versione_os(a.os_version, a.os_patch_level))
    with open(a.output, "wb") as f:
        f.write(dati)


if __name__ == "__main__":
    main()
