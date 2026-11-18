#!/bin/sh
# Prepara l'aggiornamento firmato di SolidOS Mobile (lo usa il workflow «Telefoni»).
#   telefono/pacchetto-aggiornamento.sh NUMERO CHIAVE_PRIVATA.pem
# Crea in uscita-aggiornamento/: solidos-mobile-aggiornamento-NUMERO.tar.xz (la cartella
# /usr/share/solidos-mobile come la installa il pacchetto), versione.json e la sua firma.
set -eu
N=$1; CHIAVE=$2
RADICE=$(cd "$(dirname "$0")/.." && pwd)
OUT="$RADICE/uscita-aggiornamento"; ALBERO="$OUT/albero"
rm -rf "$OUT"; mkdir -p "$ALBERO"
cp -r "$RADICE/src/nucleo" "$RADICE/src/qml" "$ALBERO/"
cp -r "$RADICE/src/dati/font" "$ALBERO/font"
cp -r "$RADICE/src/dati/sfondi" "$ALBERO/sfondi"
cp -r "$RADICE/src/dati/icone" "$ALBERO/icone"
cp "$RADICE/branding.env" "$ALBERO/branding.env"
cp "$RADICE/telefono/solidos-mobile/chiave-aggiornamenti.pem" "$ALBERO/"
printf '%s\n' "$N" > "$ALBERO/versione"
find "$ALBERO" -name __pycache__ -prune -exec rm -rf {} +
FILE="solidos-mobile-aggiornamento-$N.tar.xz"
tar -C "$ALBERO" --owner=0 --group=0 -cJf "$OUT/$FILE" .
NOVITA=$(git -C "$RADICE" log -1 --format=%s)
python3 - "$N" "$OUT/$FILE" "$NOVITA" "$OUT/versione.json" <<'PY'
import hashlib, json, os, sys
n, file, novita, scheda = sys.argv[1:5]
sha = hashlib.sha256(open(file, "rb").read()).hexdigest()
json.dump({"versione": int(n), "file": os.path.basename(file), "sha256": sha, "novita": novita[:300]},
          open(scheda, "w"), ensure_ascii=False)
PY
openssl pkeyutl -sign -inkey "$CHIAVE" -rawin -in "$OUT/versione.json" -out "$OUT/versione.json.firma"
openssl pkeyutl -verify -pubin -inkey "$RADICE/telefono/solidos-mobile/chiave-aggiornamenti.pem" \
	-rawin -in "$OUT/versione.json" -sigfile "$OUT/versione.json.firma"
rm -rf "$ALBERO"
ls -la "$OUT"
