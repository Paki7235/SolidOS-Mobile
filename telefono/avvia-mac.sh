#!/bin/sh
# Avvia SolidOS Mobile completo in un telefono virtuale sul Mac (processore Apple).
# Serve QEMU:  brew install qemu
# Uso (nella cartella dove hai estratto lo zip):  sh avvia-mac.sh
# Il telefono gira con l'accelerazione del Mac (HVF): non è emulato, è veloce.
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

echo "Avvio di SolidOS Mobile: dopo circa un minuto compare la schermata di blocco."
echo "Se la finestra è più alta dello schermo, trascinane l'angolo per rimpicciolirla. Per chiudere: chiudi la finestra."
exec qemu-system-aarch64 \
	-name "SolidOS Mobile" \
	-M virt,highmem=off -accel hvf -cpu host -smp 2 -m 2048 \
	-bios "$FIRMWARE" \
	-drive "file=$IMG,format=raw,if=virtio" \
	-device virtio-gpu-pci,xres=640,yres=1136 \
	-device virtio-tablet-pci -device virtio-keyboard-pci \
	-netdev user,id=rete -device virtio-net-pci,netdev=rete \
	-device virtio-rng-pci \
	-display cocoa,zoom-to-fit=on
