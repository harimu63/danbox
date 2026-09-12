#!/bin/sh
# Copyright (C) 2026 Higen (harimu63)
# Download/update binary sing-box dari GitHub Releases resmi SagerNet
#
# CATATAN PENTING (sing-box issue #4430):
# Sejak sing-box 1.13.0, build DEFAULT untuk linux amd64/arm64/arm/386
# membundel libcronet.so (buat fitur NaiveProxy) dan ITU DYNAMICALLY
# LINKED KE GLIBC -> gagal total dieksekusi di sistem musl-only seperti
# OpenWrt ("no such file or directory" walau file-nya ada, itu tandanya
# loader glibc-nya hilang). Untuk arch itu, sing-box resmi juga
# menyediakan varian "-musl" (statis, tanpa dependency sistem apapun).
# Script ini SELALU coba varian -musl dulu untuk 386/amd64/arm/arm64,
# baru fallback ke plain kalau -musl tidak tersedia di rilis tsb.

CONF="danbox"
UPDATE_LOG="/var/log/danbox-update.log"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$UPDATE_LOG"
}

: > "$UPDATE_LOG"
log "=== [1/6] Mendeteksi arsitektur perangkat ==="

ARCH_RAW=$(uname -m)
# arch dasar -> dipakai buat cari nama asset (bisa lebih dari satu kandidat,
# karena beberapa arch punya varian -musl yang WAJIB dipakai di OpenWrt)
case "$ARCH_RAW" in
	x86_64)          SB_ARCH="amd64";  HAS_MUSL_VARIANT=1 ;;
	aarch64)         SB_ARCH="arm64";  HAS_MUSL_VARIANT=1 ;;
	armv7l|armv7)    SB_ARCH="armv7";  HAS_MUSL_VARIANT=1 ;;
	armv6l)          SB_ARCH="armv6";  HAS_MUSL_VARIANT=0 ;;
	i386|i686)       SB_ARCH="386";    HAS_MUSL_VARIANT=1 ;;
	mips)            SB_ARCH="mips-hardfloat";   HAS_MUSL_VARIANT=0 ;;
	mipsel)          SB_ARCH="mipsle-hardfloat"; HAS_MUSL_VARIANT=0 ;;
	mips64)          SB_ARCH="mips64";  HAS_MUSL_VARIANT=0 ;;
	mips64el)        SB_ARCH="mips64le"; HAS_MUSL_VARIANT=0 ;;
	riscv64)         SB_ARCH="riscv64"; HAS_MUSL_VARIANT=0 ;;
	*)               SB_ARCH="" ;;
esac

if [ -z "$SB_ARCH" ]; then
	log "GAGAL: arsitektur '$ARCH_RAW' belum dikenal script ini. Download manual dari GitHub Releases."
	exit 1
fi
log "Arsitektur terdeteksi: $ARCH_RAW -> sing-box arch: $SB_ARCH (varian -musl tersedia: $([ "$HAS_MUSL_VARIANT" = "1" ] && echo ya || echo tidak))"

. /lib/functions.sh 2>/dev/null
config_load "$CONF"
BIN_PATH="/usr/bin/sing-box"
ENABLED="0"
config_get BIN_PATH config bin_path "/usr/bin/sing-box"
config_get ENABLED  config enabled  "0"

log "=== [2/6] Mengecek versi terpasang & versi terbaru di GitHub ==="

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

find_asset_url() {
	local name="$1"
	if command -v jq >/dev/null 2>&1; then
		echo "$API_JSON" | jq -r --arg name "$name" '.assets[] | select(.name==$name) | .browser_download_url'
	else
		echo "$API_JSON" | grep "\"browser_download_url\"" | grep "\"$name\"" -A0 | grep "/$name\"" | head -n1 | sed -E 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
	fi
}

log "=== [3/6] Mencari asset yang kompatibel (prioritas: musl-static) ==="

ASSET_NAME=""
DOWNLOAD_URL=""

if [ "$HAS_MUSL_VARIANT" = "1" ]; then
	CANDIDATE="sing-box-${LATEST_VER}-linux-${SB_ARCH}-musl.tar.gz"
	URL=$(find_asset_url "$CANDIDATE")
	if [ -n "$URL" ] && [ "$URL" != "null" ]; then
		ASSET_NAME="$CANDIDATE"
		DOWNLOAD_URL="$URL"
		log "Ditemukan varian musl-static (aman untuk OpenWrt): $ASSET_NAME"
	else
		log "Varian -musl tidak ditemukan untuk rilis ini, coba varian plain (waspada: bisa jadi glibc-linked)."
	fi
fi

if [ -z "$DOWNLOAD_URL" ]; then
	CANDIDATE="sing-box-${LATEST_VER}-linux-${SB_ARCH}.tar.gz"
	URL=$(find_asset_url "$CANDIDATE")
	if [ -n "$URL" ] && [ "$URL" != "null" ]; then
		ASSET_NAME="$CANDIDATE"
		DOWNLOAD_URL="$URL"
		log "Menggunakan asset plain: $ASSET_NAME"
	fi
fi

if [ -z "$DOWNLOAD_URL" ]; then
	log "GAGAL: tidak menemukan asset yang cocok untuk arch '$SB_ARCH' pada rilis $LATEST_TAG."
	log "Cek manual di https://github.com/SagerNet/sing-box/releases/tag/$LATEST_TAG"
	exit 1
fi

log "=== [4/6] Mengunduh $ASSET_NAME ==="
TMP_DIR="/tmp/danbox-core-update"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if ! wget -q "$DOWNLOAD_URL" -O "$TMP_DIR/$ASSET_NAME" 2>>"$UPDATE_LOG"; then
	log "GAGAL: download gagal. Cek koneksi internet router."
	rm -rf "$TMP_DIR"
	exit 1
fi
log "Download selesai ($(du -h "$TMP_DIR/$ASSET_NAME" 2>/dev/null | cut -f1))."

log "=== [5/6] Mengekstrak, backup binary lama, dan memasang binary baru ==="
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

BACKUP_PATH=""
if [ -x "$BIN_PATH" ]; then
	BACKUP_PATH="${BIN_PATH}.bak"
	cp -f "$BIN_PATH" "$BACKUP_PATH"
	log "Binary lama di-backup ke $BACKUP_PATH (jaga-jaga kalau binary baru ternyata tidak kompatibel)."
fi

mkdir -p "$(dirname "$BIN_PATH")"
cp -f "$EXTRACTED_BIN" "$BIN_PATH"
chmod 755 "$BIN_PATH"
rm -rf "$TMP_DIR"
log "Binary baru dipasang di $BIN_PATH dengan permission 755."

log "=== [6/6] Verifikasi: menjalankan binary baru untuk memastikan benar-benar kompatibel ==="
# PENTING: stderr TIDAK dibuang, supaya kalau exec gagal (mis. mismatch
# glibc/musl, "exec format error", dst) alasannya kelihatan jelas di log.
VERIFY_OUT=$("$BIN_PATH" version 2>&1)
VERIFY_LINE=$(echo "$VERIFY_OUT" | head -n1)

if [ -z "$VERIFY_LINE" ] || echo "$VERIFY_OUT" | grep -qiE 'not found|cannot execute|exec format error|no such file'; then
	log "GAGAL: binary baru TIDAK BISA dijalankan di sistem ini. Detail: ${VERIFY_OUT:-(tidak ada output sama sekali, kemungkinan besar binary glibc vs sistem musl)}"
	if [ -n "$BACKUP_PATH" ] && [ -x "$BACKUP_PATH" ]; then
		cp -f "$BACKUP_PATH" "$BIN_PATH"
		chmod 755 "$BIN_PATH"
		log "Binary lama DIKEMBALIKAN dari backup. sing-box tetap di versi sebelumnya (${CURRENT_VER:-tidak diketahui})."
	else
		rm -f "$BIN_PATH"
		log "Tidak ada backup untuk dikembalikan (ini instalasi pertama). Binary yang gagal dihapus."
	fi
	if [ "$WAS_RUNNING" = "1" ] && [ "$ENABLED" = "1" ]; then
		log "Menyalakan kembali service dengan binary lama..."
		/etc/init.d/danbox start >/dev/null 2>&1
	fi
	exit 1
fi

log "Verifikasi OK: $VERIFY_LINE"
log "BERHASIL: sing-box berhasil diupdate/dipasang ke versi $LATEST_TAG ($ASSET_NAME)."

if [ -n "$BACKUP_PATH" ]; then
	rm -f "$BACKUP_PATH"
fi

if [ "$ENABLED" = "1" ]; then
	log "Menyalakan kembali service..."
	/etc/init.d/danbox start >/dev/null 2>&1
fi