#!/bin/sh
# Costruisce SolidOS Mobile per un telefono supportato da postmarketOS.
#   telefono/costruisci.sh [CODICE]      (predefinito: huawei-warsaw = Huawei P10 Lite)
# Gira su Linux aarch64 (GitHub "ubuntu-24.04-arm"); serve sudo.
# Risultato: uscita/SolidOS-Mobile-<NOME>.zip con le immagini e LEGGIMI.txt
# (i comandi esatti per installarlo su quel telefono).
set -eu
DEVICE="${1:-${DEVICE:-huawei-warsaw}}"
RADICE=$(cd "$(dirname "$0")/.." && pwd)
LAVORO="$HOME/.local/var/pmbootstrap"
APORTS="$HOME/pmaports"    # fuori dalla cartella di lavoro: pmbootstrap la crea da solo
PMB="$HOME/pmbootstrap/pmbootstrap.py"
USCITA="$RADICE/uscita"
PASSWORD="${SOLIDOS_PASSWORD:-solidos}"

# Nome leggibile per i telefoni che conosciamo
case $DEVICE in
	huawei-warsaw)       NOME="Huawei P10 Lite";  FILE="P10-Lite" ;;
	oneplus-enchilada)   NOME="OnePlus 6";        FILE="OnePlus-6" ;;
	oneplus-fajita)      NOME="OnePlus 6T";       FILE="OnePlus-6T" ;;
	google-sargo)        NOME="Google Pixel 3a";  FILE="Pixel-3a" ;;
	fairphone-fp4)       NOME="Fairphone 4";      FILE="Fairphone-4" ;;
	shift-axolotl)       NOME="SHIFT6mq";         FILE="SHIFT6mq" ;;
	pine64-pinephonepro) NOME="PinePhone Pro";    FILE="PinePhone-Pro" ;;
	*)                   NOME="$DEVICE";          FILE="$DEVICE" ;;
esac
EXTRA="solidos-mobile"
[ "$DEVICE" = huawei-warsaw ] && EXTRA="$EXTRA,hisi-wlan"

echo "== $NOME ($DEVICE): pmbootstrap e pmaports"
[ -d "$HOME/pmbootstrap" ] || git -c advice.detachedHead=false clone -q --depth 1 --branch 3.12.1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git "$HOME/pmbootstrap"
[ -d "$APORTS" ] || git clone -q https://gitlab.postmarketos.org/postmarketOS/pmaports.git "$APORTS"

mkdir -p "$HOME/.config"
cat > "$HOME/.config/pmbootstrap_v3.cfg" <<CFG
[pmbootstrap]
aports = $APORTS
work = $LAVORO
device = $DEVICE
ui = console
user = solid
hostname = solidos
timezone = Europe/Rome
locale = it_IT.UTF-8
extra_packages = $EXTRA
jobs = $(nproc)

[providers]

[mirrors]
CFG

# Cartella di lavoro con il suo numero di versione (quello che farebbe "pmbootstrap init")
mkdir -p "$LAVORO"
python3 -c "import sys; sys.path.insert(0, '$HOME/pmbootstrap'); import pmb.config; print(pmb.config.work_version)" > "$LAVORO/version"

echo "== pacchetti solidos-mobile e hisi-wlan"
for p in solidos-mobile hisi-wlan; do
	rm -rf "$APORTS/main/$p" && mkdir -p "$APORTS/main/$p"
	cp "$RADICE/telefono/$p"/* "$APORTS/main/$p"/
done
tar -C "$RADICE" --exclude='__pycache__' -czf "$APORTS/main/solidos-mobile/solidos-mobile.tar.gz" src branding.env
python3 "$PMB" -y checksum solidos-mobile hisi-wlan

echo "== kernel, pacchetti e immagine (ci vuole un po')"
# Il firmware del Wi-Fi del P10 Lite è tra i pacchetti archiviati: va costruito a mano
if [ "$DEVICE" = huawei-warsaw ]; then
	python3 "$PMB" -y --details-to-stdout build --arch aarch64 firmware-huawei-warsaw
fi
python3 "$PMB" -y --details-to-stdout install --password "$PASSWORD" --no-sshd --no-fde
rm -rf "$LAVORO/esporta"
python3 "$PMB" -y export "$LAVORO/esporta"
ls -l "$LAVORO/esporta"

mkdir -p "$USCITA" && rm -rf "$USCITA"/*
INFO=$(ls "$APORTS"/device/*/device-"$DEVICE"/deviceinfo | head -n1)
METODO=$(sed -n 's/^deviceinfo_flash_method="\(.*\)"/\1/p' "$INFO" | head -n1)
VBMETA=$(sed -n 's/^deviceinfo_flash_fastboot_partition_vbmeta="\(.*\)"/\1/p' "$INFO" | head -n1)
LEGGIMI="$USCITA/LEGGIMI.txt"
{
	echo "SolidOS Mobile per $NOME ($DEVICE)"
	echo "=========================================================="
	echo
	echo "Guida completa: https://github.com/Paki7235/SolidOS-Mobile/blob/main/docs/installa-telefono.md"
	echo "Serve il bootloader SBLOCCATO. Utente: solid  Password: $PASSWORD (cambiala con: passwd)"
	echo
} > "$LEGGIMI"

if [ "$DEVICE" = huawei-warsaw ]; then
	echo "== kernel e ramdisk separati (il P10 Lite non ha la partizione boot)"
	TMP=$(mktemp -d)
	KERNEL=$(readlink -f "$LAVORO/esporta/vmlinuz")
	RAMDISK=$(readlink -f "$LAVORO/esporta/initramfs")
	if [ "$(head -c 2 "$KERNEL" | od -An -tx1 | tr -d ' ')" != "1f8b" ]; then gzip -9 -c "$KERNEL" > "$TMP/kernel.gz"; KERNEL="$TMP/kernel.gz"; fi
	BOOTIMG="python3 $RADICE/telefono/bootimg.py"
	$BOOTIMG --kernel - --ramdisk "$RAMDISK" --cmdline 'buildvariant=user' \
		--os_version 8.0.0 --os_patch_level 2018-06-05 -o "$USCITA/ramdisk.img"
	$BOOTIMG --kernel "$KERNEL" --ramdisk - \
		--cmdline 'loglevel=4 coherent_pool=512K page_tracker=on slub_min_objects=12 unmovable_isolate1=2:192M,3:224M,4:256M printktimer=0xfff0a000,0x534,0x538 androidboot.selinux=enforcing buildvariant=user' \
		--base 0x00478000 --kernel_offset 0x00008000 --ramdisk_offset 0x07b88000 --second_offset 0x00e88000 \
		--tags_offset 0x07988000 --os_version 8.0.0 --os_patch_level 2018-12-01 --pagesize 2048 -o "$USCITA/kernel.img"
	cp "$(readlink -f "$LAVORO/esporta/$DEVICE.img")" "$USCITA/solidos-mobile-sd.img"
	cat "$RADICE/telefono/LEGGIMI.txt" >> "$LEGGIMI"
elif [ "$METODO" = fastboot ]; then
	cp "$(readlink -f "$LAVORO/esporta/boot.img")" "$USCITA/boot.img"
	cp "$(readlink -f "$LAVORO/esporta/$DEVICE.img")" "$USCITA/solidos-mobile.img"
	if [ -e "$LAVORO/esporta/vbmeta.img" ]; then cp "$(readlink -f "$LAVORO/esporta/vbmeta.img")" "$USCITA/vbmeta.img"; fi
	{
		echo "Telefono in modalità fastboot (di solito: spento, Volume giù + Accensione), poi:"
		echo
		if [ -n "$VBMETA" ] && [ -e "$USCITA/vbmeta.img" ]; then echo "  fastboot flash $VBMETA vbmeta.img"; fi
		case $DEVICE in oneplus-*|shift-*) echo "  fastboot erase dtbo" ;; esac
		echo "  fastboot flash boot boot.img"
		echo "  fastboot flash userdata solidos-mobile.img"
		echo "  fastboot reboot"
		echo
		echo "La memoria del telefono viene cancellata (Android sparisce)."
		echo "Per tornare ad Android: usa il firmware originale del produttore."
	} >> "$LEGGIMI"
else
	cp "$(readlink -f "$LAVORO/esporta/$DEVICE.img")" "$USCITA/solidos-mobile.img"
	{
		echo "Scrivi solidos-mobile.img su una microSD (balenaEtcher o dd), inseriscila e accendi."
		echo "Il sistema parte dalla microSD; la memoria interna non viene toccata."
	} >> "$LEGGIMI"
fi

ZIP="SolidOS-Mobile-$FILE.zip"
(cd "$USCITA" && zip -9 -q "$ZIP" ./*.img LEGGIMI.txt)
echo "$ZIP" > "$USCITA/nome-zip.txt"
echo "$NOME" > "$USCITA/nome-telefono.txt"
ls -lh "$USCITA"
