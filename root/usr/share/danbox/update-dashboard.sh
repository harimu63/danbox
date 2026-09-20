#!/bin/sh
# Copyright (C) 2026 Higen (harimu63)
# Download/update dashboard UI untuk sing-box clash_api (external_ui)

CONF="danbox"
DASH_LOG="/var/log/danbox-dashboard.log"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$DASH_LOG"
}

: > "$DASH_LOG"
log "=== [1/5] Menyiapkan target folder ==="

. /lib/functions.sh 2>/dev/null
config_load "$CONF"
DASH_DIR="/etc/sing-box/ui"
DASH_SOURCE="metacubex"
config_get DASH_DIR config dashboard_dir "/etc/sing-box/ui"
config_get DASH_SOURCE config dashboard_source "metacubex"
log "Target folder dashboard: $DASH_DIR"
log "Dashboard source: $DASH_SOURCE"

# Get dashboard URL based on source
case "$DASH_SOURCE" in
	metacubex)
		DASH_ZIP_URL="https://github.com/MetaCubeX/Yacd-meta/archive/gh-pages.zip"
		DASH_NAME="Yacd-meta (MetaCubeX)"
		;;
	haishan)
		DASH_ZIP_URL="https://github.com/haishanh/yacd/archive/gh-pages.zip"
		DASH_NAME="Yacd (Haishan)"
		;;
	razord)
		DASH_ZIP_URL="https://github.com/Dreamacro/clash-dashboard/archive/gh-pages.zip"
		DASH_NAME="Clash Dashboard (Razord)"
		;;
	taamarin)
		DASH_ZIP_URL="https://github.com/taamarin/yacd-meta/archive/gh-pages.zip"
		DASH_NAME="Yacd-meta (Taamarin)"
		;;
	metacubexd)
		DASH_ZIP_URL="https://github.com/MetaCubeX/metacubexd/archive/gh-pages.zip"
		DASH_NAME="MetaCubeXD"
		;;
	zashboard)
		DASH_ZIP_URL="https://github.com/Zephyruso/zashboard/archive/gh-pages.zip"
		DASH_NAME="Zashboard"
		;;
	*)
		log "GAGAL: Dashboard source '$DASH_SOURCE' tidak dikenal."
		exit 1
		;;
esac

log "Menggunakan: $DASH_NAME"
log "URL: $DASH_ZIP_URL"

if ! command -v unzip >/dev/null 2>&1; then
	log "GAGAL: perintah 'unzip' tidak tersedia di router ini."
	log "Install dulu: opkg update && opkg install unzip"
	exit 1
fi

log "=== [2/5] Mengunduh dashboard ($DASH_NAME) ==="
TMP_DIR="/tmp/danbox-dashboard-update"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if ! wget -q "$DASH_ZIP_URL" -O "$TMP_DIR/dashboard.zip" 2>>"$DASH_LOG"; then
	log "GAGAL: download gagal. Cek koneksi internet router."
	rm -rf "$TMP_DIR"
	exit 1
fi
log "Download selesai ($(du -h "$TMP_DIR/dashboard.zip" 2>/dev/null | cut -f1))."

log "=== [3/5] Mengekstrak dashboard ==="
mkdir -p "$TMP_DIR/extracted"
if ! unzip -q "$TMP_DIR/dashboard.zip" -d "$TMP_DIR/extracted" 2>>"$DASH_LOG"; then
	log "GAGAL: ekstrak zip gagal (file corrupt / format tidak sesuai)."
	rm -rf "$TMP_DIR"
	exit 1
fi

# arsip GitHub selalu punya satu folder root di dalamnya, mis. yacd-meta-gh-pages/
SRC_DIR=$(find "$TMP_DIR/extracted" -mindepth 1 -maxdepth 1 -type d | head -n1)
if [ -z "$SRC_DIR" ] || [ ! -f "$SRC_DIR/index.html" ]; then
	log "GAGAL: struktur arsip tidak sesuai dugaan (index.html tidak ditemukan di dalamnya)."
	rm -rf "$TMP_DIR"
	exit 1
fi
log "Arsip valid, index.html ditemukan."

log "=== [4/5] Backup dan instalasi ==="
BACKUP_DIR=""
if [ -d "$DASH_DIR" ] && [ -f "$DASH_DIR/index.html" ]; then
	BACKUP_DIR="${DASH_DIR}.bak"
	rm -rf "$BACKUP_DIR"
	cp -rf "$DASH_DIR" "$BACKUP_DIR"
	log "Dashboard lama di-backup ke $BACKUP_DIR (jaga-jaga kalau yang baru bermasalah)."
fi

rm -rf "$DASH_DIR"
mkdir -p "$(dirname "$DASH_DIR")"
cp -rf "$SRC_DIR" "$DASH_DIR"
find "$DASH_DIR" -type d -exec chmod 755 {} \;
find "$DASH_DIR" -type f -exec chmod 644 {} \;
rm -rf "$TMP_DIR"
log "Dashboard dipasang di $DASH_DIR."

log "=== [5/5] Verifikasi ==="
if [ -f "$DASH_DIR/index.html" ]; then
	log "Verifikasi OK: index.html ditemukan di $DASH_DIR."
	log "BERHASIL: dashboard ($DASH_NAME) berhasil diupdate/dipasang."
	[ -n "$BACKUP_DIR" ] && rm -rf "$BACKUP_DIR"
	log "PENTING: pastikan experimental.clash_api.external_ui di config sing-box kamu mengarah ke: $DASH_DIR"
else
	log "GAGAL: index.html tidak ditemukan setelah dipasang."
	if [ -n "$BACKUP_DIR" ]; then
		rm -rf "$DASH_DIR"
		mv "$BACKUP_DIR" "$DASH_DIR"
		log "Dashboard lama DIKEMBALIKAN dari backup."
	fi
	exit 1
fi
