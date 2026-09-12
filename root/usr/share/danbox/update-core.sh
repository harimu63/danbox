#!/bin/sh
# Copyright (C) 2026 Higen (harimu63)
# Download/update binary sing-box dari GitHub Releases resmi SagerNet

CONF="danbox"
UPDATE_LOG="/var/log/danbox-update.log"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$UPDATE_LOG"
}

: > "$UPDATE_LOG"
log "=== [1/5] Mendeteksi arsitektur perangkat ==="

ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
	x86_64)          SB_ARCH="amd64" ;;
	aarch64)         SB_ARCH="arm64" ;;
	armv7l|armv7)    SB_ARCH="armv7" ;;
	armv6l)          SB_ARCH="armv6" ;;
	mips)            SB_ARCH="mips-hardfloat" ;;
	mipsel)          SB_ARCH="mipsle-hardfloat" ;;
	riscv64)         SB_ARCH="riscv64" ;;
	*)               SB_ARCH="" ;;
esac

if [ -z "$SB_ARCH" ]; then
	log "GAGAL: arsitektur '$ARCH_RAW' belum dikenal script ini. Download manual dari GitHub Releases."
	exit 1
fi
log "Arsitektur terdeteksi: $ARCH_RAW -> sing-box arch: $SB_ARCH"

. /lib/config/uci.sh 2>/dev/null
config_load "$CONF"
BIN_PATH="/usr/bin/sing-box"
ENABLED="0"
config_get BIN_PATH config bin_path "/usr/bin/sing-box"
config_get ENABLED  config enabled  "0"

log "=== [2/5] Mengecek versi terpasang & versi terbaru di GitHub ==="

CURRENT_VER=""
[ -x "$BIN_PATH" ] && CURRENT_VER=$("$BIN_PATH" version 2>/dev/null | head -n1 | awk '{print $3}')
log "Versi terpasang saat ini: ${CURRENT_VER:-(belum ada)}"

API_JSON=$(wget -qO- https://api.github.com/repos/SagerNet/sing-box/releases/latest 2>>"$UPDATE_LOG")
if [ -z "$API_JSON" ]; then
	log "GAGAL: tidak bisa mengambil data rilis dari GitHub API. Cek koneksi internet router."
	exit 1
fi

if command -v jq >/dev/null 2>&1; then
	LATEST_TAG=$(echo "$API_JSON" | jq -r '.tag_name')
else
	LATEST_TAG=$(echo "$API_JSON" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
fi

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" = "null" ]; then
	log "GAGAL: tidak menemukan tag_name pada respons GitHub API."
	exit 1
fi
LATEST_VER="${LATEST_TAG#v}"
log "Versi terbaru di GitHub: $LATEST_TAG"

if [ -n "$CURRENT_VER" ] && [ "$CURRENT_VER" = "$LATEST_VER" ]; then
	log "Sudah versi terbaru ($CURRENT_VER). Tidak perlu update."
	exit 0
fi

ASSET_NAME="sing-box-${LATEST_VER}-linux-${SB_ARCH}.tar.gz"

if command -v jq >/dev/null 2>&1; then
	DOWNLOAD_URL=$(echo "$API_JSON" | jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name==$name) | .browser_download_url')
else
	DOWNLOAD_URL=$(echo "$API_JSON" | grep "\"browser_download_url\"" | grep "$ASSET_NAME" | head -n1 | sed -E 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
fi

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
	log "GAGAL: asset '$ASSET_NAME' tidak ditemukan pada rilis $LATEST_TAG."
	log "Cek manual di https://github.com/SagerNet/sing-box/releases/tag/$LATEST_TAG"
	exit 1
fi
log "Asset ditemukan: $ASSET_NAME"

log "=== [3/5] Mengunduh $ASSET_NAME ==="
TMP_DIR="/tmp/danbox-core-update"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if ! wget -q "$DOWNLOAD_URL" -O "$TMP_DIR/$ASSET_NAME" 2>>"$UPDATE_LOG"; then
	log "GAGAL: download gagal. Cek koneksi internet router."
	rm -rf "$TMP_DIR"
	exit 1
fi
log "Download selesai ($(du -h "$TMP_DIR/$ASSET_NAME" 2>/dev/null | cut -f1))."

log "=== [4/5] Mengekstrak & memasang binary ==="
if ! tar -xzf "$TMP_DIR/$ASSET_NAME" -C "$TMP_DIR" 2>>"$UPDATE_LOG"; then
	log "GAGAL: ekstrak tar.gz gagal (file corrupt / format tidak sesuai)."
	rm -rf "$TMP_DIR"
	exit 1
fi

EXTRACTED_BIN=$(find "$TMP_DIR" -type f -name "sing-box" | head -n1)
if [ -z "$EXTRACTED_BIN" ]; then
	log "GAGAL: binary sing-box tidak ditemukan di dalam arsip."
	rm -rf "$TMP_DIR"
	exit 1
fi

WAS_RUNNING=0
pgrep -f "$BIN_PATH run" >/dev/null 2>&1 && WAS_RUNNING=1

if [ "$WAS_RUNNING" = "1" ]; then
	log "Service sedang jalan, menghentikan dulu sebelum mengganti binary..."
	/etc/init.d/danbox stop >/dev/null 2>&1
	sleep 1
fi

mkdir -p "$(dirname "$BIN_PATH")"
cp -f "$EXTRACTED_BIN" "$BIN_PATH"
chmod 755 "$BIN_PATH"
log "Binary dipasang di $BIN_PATH dengan permission 755."

rm -rf "$TMP_DIR"

log "=== [5/5] Verifikasi ==="
NEW_VER_LINE=$("$BIN_PATH" version 2>/dev/null | head -n1)
log "Versi sekarang: $NEW_VER_LINE"
log "BERHASIL: sing-box berhasil diupdate/dipasang ke versi $LATEST_TAG."

if [ "$ENABLED" = "1" ]; then
	log "Menyalakan kembali service..."
	/etc/init.d/danbox start >/dev/null 2>&1
fi
