#!/bin/sh
# Avvia l'interfaccia di SolidOS Mobile in una finestra grande come un telefono.
# Esempi:  scripts/anteprima.sh
#          scripts/anteprima.sh --schermata=home --tema=chiaro
#          scripts/anteprima.sh --schermata=libreria --foto=libreria.png
RADICE=$(cd "$(dirname "$0")/.." && pwd)
export PYTHONPATH="$RADICE/src${PYTHONPATH:+:$PYTHONPATH}"
export NUCLEO_BRANDING="$RADICE/branding.env"
export NUCLEO_QML="$RADICE/src/qml"
exec python3 -m nucleo.mobile "$@"
