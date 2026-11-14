#!/bin/sh
# Costruisce SolidOS Mobile per il Huawei P10 Lite (postmarketOS, dispositivo "huawei-warsaw").
# Gira su Linux aarch64 (la prova di GitHub "ubuntu-24.04-arm"); serve sudo.
# Risultato: uscita/SolidOS-Mobile-P10-Lite.zip con
#   kernel.img   → fastboot flash kernel kernel.img
#   ramdisk.img  → fastboot flash ramdisk ramdisk.img
#   solidos-mobile-sd.img → da scrivere sulla scheda microSD (il sistema parte da lì)
set -eu
RADICE=$(cd "$(dirname "$0")/.." && pwd)
LAVORO="$HOME/.local/var/pmbootstrap"
APORTS="$HOME/pmaports"    # fuori dalla cartella di lavoro: pmbootstrap la crea da solo
PMB="$HOME/pmbootstrap/pmbootstrap.py"
USCITA="$RADICE/uscita"
PASSWORD="${SOLIDOS_PASSWORD:-solidos}"

echo "== pmbootstrap e pmaports"
[ -d "$HOME/pmbootstrap" ] || git -c advice.detachedHead=false clone -q --depth 1 --branch 3.12.1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git "$HOME/pmbootstrap"
[ -d "$APORTS" ] || git clone -q https://gitlab.postmarketos.org/postmarketOS/pmaports.git "$APORTS"

mkdir -p "$HOME/.config"
cat > "$HOME/.config/pmbootstrap_v3.cfg" <<CFG
[pmbootstrap]
aports = $APORTS
work = $LAVORO
device = huawei-warsaw
ui = none
user = solid
hostname = solidos
timezone = Europe/Rome
locale = it_IT.UTF-8
extra_packages = solidos-mobile
jobs = $(nproc)

[providers]

[mirrors]
CFG

# Cartella di lavoro con il suo numero di versione (quello che farebbe "pmbootstrap init")
mkdir -p "$LAVORO"
python3 -c "import sys; sys.path.insert(0, '$HOME/pmbootstrap'); import pmb.config; print(pmb.config.work_version)" > "$LAVORO/version"

echo "== pacchetto solidos-mobile"
DEST="$APORTS/main/solidos-mobile"
rm -rf "$DEST" && mkdir -p "$DEST"
cp "$RADICE"/telefono/solidos-mobile/* "$DEST"/
tar -C "$RADICE" --exclude='__pycache__' -czf "$DEST/solidos-mobile.tar.gz" src branding.env
python3 "$PMB" -y checksum solidos-mobile

echo "== kernel, pacchetti e immagine (ci vuole un po')"
python3 "$PMB" -y --details-to-stdout install --password "$PASSWORD" --no-sshd --no-fde
python3 "$PMB" -y export "$LAVORO/esporta"

echo "== kernel e ramdisk separati (il P10 Lite non ha la partizione boot)"
mkdir -p "$USCITA" && rm -rf "$USCITA"/*
TMP=$(mktemp -d)
BOOT=$(readlink -f "$LAVORO/esporta/boot.img")
unpack_bootimg --boot_img "$BOOT" --out "$TMP" >/dev/null
KERNEL="$TMP/kernel"
if [ "$(head -c 2 "$KERNEL" | od -An -tx1 | tr -d ' ')" != "1f8b" ]; then gzip -9 -c "$KERNEL" > "$TMP/kernel.gz"; KERNEL="$TMP/kernel.gz"; fi
mkbootimg --kernel /dev/null --ramdisk "$TMP/ramdisk" --cmdline 'buildvariant=user' \
	--os_version 8.0.0 --os_patch_level 2018-06-05 -o "$USCITA/ramdisk.img"
mkbootimg --kernel "$KERNEL" --ramdisk /dev/null \
	--cmdline 'loglevel=4 coherent_pool=512K page_tracker=on slub_min_objects=12 unmovable_isolate1=2:192M,3:224M,4:256M printktimer=0xfff0a000,0x534,0x538 androidboot.selinux=enforcing buildvariant=user' \
	--base 0x00478000 --kernel_offset 0x00008000 --ramdisk_offset 0x07b88000 --second_offset 0x00e88000 \
	--tags_offset 0x07988000 --os_version 8.0.0 --os_patch_level 2018-12-01 --pagesize 2048 -o "$USCITA/kernel.img"

echo "== immagine per la microSD"
IMG=$(readlink -f "$LAVORO/esporta/huawei-warsaw.img")
cp "$IMG" "$USCITA/solidos-mobile-sd.img"
cp "$RADICE/telefono/LEGGIMI.txt" "$USCITA/"
(cd "$USCITA" && zip -9 -q SolidOS-Mobile-P10-Lite.zip kernel.img ramdisk.img solidos-mobile-sd.img LEGGIMI.txt)
ls -lh "$USCITA"
