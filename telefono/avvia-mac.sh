#!/bin/sh
# Avvia SolidOS Mobile completo in un telefono virtuale sul Mac (processore Apple).
# Serve QEMU:  brew install qemu
# Uso (nella cartella dove hai estratto lo zip):  sh avvia-mac.sh
#   sh avvia-mac.sh finestra   → nella finestra di QEMU invece che in Condivisione Schermo
# Il telefono gira con l'accelerazione del Mac (HVF): non è emulato, è veloce.
#
# Lo schermo del telefono è 640×1136: il firmware UEFI di QEMU sotto i 640 pixel di
# larghezza si blocca. Per vederlo intero e in proporzione si usa Condivisione Schermo
# del Mac, che rimpicciolisce la finestra mantenendo le proporzioni.
set -e
CARTELLA=$(cd "$(dirname "$0")" && pwd)
IMG="$CARTELLA/solidos-mobile.img"
[ -f "$IMG" ] || { echo "Non trovo solidos-mobile.img accanto a questo script."; exit 1; }
command -v qemu-system-aarch64 >/dev/null || { echo "Manca QEMU: installalo con  brew install qemu"; exit 1; }

# Firmware UEFI per ARM che arriva con QEMU
FIRMWARE=""
for f in /opt/homebrew/share/qemu/edk2-aarch64-code.fd /usr/local/share/qemu/edk2-aarch64-code.fd \
	"$(dirname "$(command -v qemu-system-aarch64)")/../share/qemu/edk2-aarch64-code.fd"; do
	[ -f "$f" ] && FIRMWARE="$f" && break
done
[ -n "$FIRMWARE" ] || { echo "Non trovo il firmware edk2-aarch64-code.fd di QEMU."; exit 1; }

# La prima volta il «telefono» riceve 8 GB di spazio (il sistema lo usa al primo avvio)
if [ "$(stat -f %z "$IMG")" -lt 8000000000 ]; then
	echo "Preparo 8 GB di spazio per il telefono virtuale (solo la prima volta)…"
	qemu-img resize -f raw "$IMG" 8G >/dev/null
fi

COMUNI="-name SolidOS-Mobile -M virt,highmem=off -accel hvf -cpu host -smp 2 -m 2048"
# Audio del Mac (altoparlante e microfono) per musica e chiamate via Internet.
# Il Mac chiede una volta il permesso per il microfono.
if qemu-system-aarch64 -device help 2>/dev/null | grep -q virtio-sound; then
	COMUNI="$COMUNI -audiodev coreaudio,id=suono -device virtio-sound-pci,audiodev=suono"
else
	echo "Questo QEMU non ha l'audio per il telefono virtuale: aggiornalo con  brew upgrade qemu"
fi
DISCO="file=$IMG,format=raw,if=virtio"

if [ "${1:-}" = finestra ]; then
	echo "Avvio di SolidOS Mobile nella finestra di QEMU (circa un minuto)."
	# shellcheck disable=SC2086
	exec qemu-system-aarch64 $COMUNI -bios "$FIRMWARE" -drive "$DISCO" \
		-device virtio-gpu-pci,xres=640,yres=1136 \
		-device virtio-tablet-pci -device virtio-keyboard-pci \
		-netdev user,id=rete -device virtio-net-pci,netdev=rete -device virtio-rng-pci \
		-display cocoa,zoom-to-fit=on
fi

# Schermo del telefono condiviso solo con questo Mac (127.0.0.1), con una password
PASSWORD=solidos
PORTA=5907
# shellcheck disable=SC2086
qemu-system-aarch64 $COMUNI -bios "$FIRMWARE" -drive "$DISCO" \
	-device virtio-gpu-pci,xres=640,yres=1136 \
	-device virtio-tablet-pci -device virtio-keyboard-pci \
	-netdev user,id=rete -device virtio-net-pci,netdev=rete -device virtio-rng-pci \
	-display none \
	-object secret,id=vncpw,data="$PASSWORD" \
	-vnc 127.0.0.1:$((PORTA - 5900)),password-secret=vncpw &
QEMU=$!
trap 'kill $QEMU 2>/dev/null' INT TERM EXIT
sleep 3
kill -0 $QEMU 2>/dev/null || { echo "QEMU non è partito."; exit 1; }

echo "SolidOS Mobile si sta avviando: dopo circa un minuto compare la schermata di blocco."
echo "Si apre Condivisione Schermo: se chiede la password scrivi  $PASSWORD"
echo "La finestra si può rimpicciolire: il telefono resta in proporzione."
echo "Per spegnere il telefono virtuale: premi Ctrl+C qui nel Terminale."
open "vnc://:$PASSWORD@127.0.0.1:$PORTA"
wait $QEMU
