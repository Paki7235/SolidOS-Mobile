#!/bin/sh
# Prova SolidOS Mobile sul Mac, in una finestra grande come un telefono.
#   scripts/anteprima-mac.sh
#   scripts/anteprima-mac.sh --schermata=dove --tema=chiaro
# La prima volta prepara tutto DENTRO la cartella del progetto (niente nel sistema):
#   .anteprima/venv          Python con PyQt6
#   .anteprima/share/icons   icone Papirus (le stesse del telefono)
# Per togliere tutto basta cancellare la cartella .anteprima.
set -e
RADICE=$(cd "$(dirname "$0")/.." && pwd)
CACHE="$RADICE/.anteprima"
mkdir -p "$CACHE"

if [ ! -x "$CACHE/venv/bin/python3" ] || ! "$CACHE/venv/bin/python3" -c "import PyQt6.QtQuick" 2>/dev/null; then
	echo "Preparo Python con PyQt6 (solo la prima volta, qualche minuto)…"
	python3 -m venv "$CACHE/venv"
	"$CACHE/venv/bin/python3" -m pip install --quiet --upgrade pip
	"$CACHE/venv/bin/python3" -m pip install --quiet PyQt6
fi

if [ ! -d "$CACHE/share/icons/Papirus" ]; then
	echo "Scarico le icone Papirus (solo la prima volta)…"
	tmp="$CACHE/papirus-tmp"
	rm -rf "$tmp"
	git clone --quiet --depth 1 --filter=blob:none --sparse \
		https://github.com/PapirusDevelopmentTeam/papirus-icon-theme.git "$tmp"
	git -C "$tmp" sparse-checkout set Papirus Papirus-Dark Papirus-Light
	mkdir -p "$CACHE/share/icons"
	mv "$tmp/Papirus" "$tmp/Papirus-Dark" "$tmp/Papirus-Light" "$CACHE/share/icons/"
	rm -rf "$tmp"
fi

export XDG_DATA_DIRS="$CACHE/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
export NUCLEO_TEMA_ICONE="${NUCLEO_TEMA_ICONE:-Papirus-Dark}"
export NUCLEO_DEMO="${NUCLEO_DEMO:-1}"     # dati di esempio (contatti, messaggi, foto…)
export PATH="$CACHE/venv/bin:$PATH"
exec "$RADICE/scripts/anteprima.sh" "$@"
