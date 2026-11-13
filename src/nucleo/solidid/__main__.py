"""Uso: python3 -m nucleo.solidid [servizio | sbloccato | stato]"""

import json
import sys


def main() -> int:
    azione = sys.argv[1] if len(sys.argv) > 1 else "stato"
    if azione == "servizio":
        from .servizio import main as servizio

        return servizio()
    if azione == "sbloccato":
        from .servizio import sbloccato

        sbloccato()
        return 0
    if azione == "stato":
        from . import utente

        print(json.dumps(utente(), ensure_ascii=False, indent=2))
        return 0
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
