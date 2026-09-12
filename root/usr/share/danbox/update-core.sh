#!/bin/sh
# Copyright (C) 2026 Higen (harimu63)
# Download/update binary sing-box dari GitHub Releases resmi SagerNet
#
# LOGIKA (deterministik, bukan coba-coba):
#   1. Deteksi arsitektur CPU (uname -m)
#   2. Deteksi libc sistem (musl / glibc)
#   3. Hitung SATU nama asset yang seharusnya cocok, berdasarkan
#      kombinasi arch + libc
#   4. Cari nama itu persis di daftar release GitHub. Kalau tidak ada,
#      GAGAL dengan jelas -- tidak menebak-nebak asset lain.
#
# CATATAN PENTING (sing-box issue #4430, dikonfirmasi resmi):
# Sejak sing-box 1.13.0, asset "plain" (tanpa suffix) untuk
# linux amd64/arm64/arm/386 membundel libcronet.so (fitur NaiveProxy)
# yang DYNAMICALLY LINKED KE GLIBC -> gagal total dieksekusi di sistem
# musl-only seperti OpenWrt. Untuk arch itu, sing-box resmi menyediakan
# varian "-musl" (statis, tanpa dependency sistem) khusus buat kasus ini.
# Dokumentasi resmi: https://sing-box.sagernet.org/configuration/outbound/naive

CONF="danbox"
UPDATE_LOG="/var/log/danbox-update.log"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$UPDATE_LOG"
}

: > "$UPDATE_LOG"

# -----------------------------------------------------------------------
# [1/6] Deteksi arsitektur
# -----------------------------------------------------------------------
log "=== [1/6] Mendeteksi arsitektur CPU ==="

ARCH_RAW=$(uname -m)
# SB_ARCH        = penamaan arch versi sing-box
# HAS_MUSL_ASSET = 1 kalau arch ini punya rilis khusus "-musl" terpisah
#                  dari plain (cuma amd64/arm64/armv7/386 yang punya,
#                  arch lain selalu pure-Go static jadi plain sudah aman)
case "$ARCH_RAW" in
	x86_64)       SB_ARCH="amd64";               HAS_MUSL_ASSET=1 ;;
	aarch64)      SB_ARCH="arm64";                HAS_MUSL_ASSET=1 ;;
	armv7l|armv7) SB_ARCH="armv7";                HAS_MUSL_ASSET=1 ;;
	i386|i686)    SB_ARCH="386";                  HAS_MUSL_ASSET=1 ;;
	armv6l)       SB_ARCH="armv6";                HAS_MUSL_ASSET=0 ;;
	mips)         SB_ARCH="mips-hardfloat";       HAS_MUSL_ASSET=0 ;;
	mipsel)       SB_ARCH="mipsle-hardfloat";     HAS_MUSL_ASSET=0 ;;
	mips64)       SB_ARCH="mips64";               HAS_MUSL_ASSET=0 ;;
	mips64el)     SB_ARCH="mips64le";             HAS_MUSL_ASSET=0 ;;
	riscv64)      SB_ARCH="riscv64";              HAS_MUSL_ASSET=0 ;;
	*)            SB_ARCH="" ;;
esac

if [ -z "$SB_ARCH" ]; then
	log "GAGAL: arsitektur '$ARCH_RAW' belum dikenal script ini. Download manual dari GitHub Releases."
	exit 1
fi
log "uname -m: $ARCH_RAW -> penamaan sing-box: $SB_ARCH"

# -----------------------------------------------------------------------
# [2/6] Deteksi libc (musl vs glibc)
# -----------------------------------------------------------------------
log "=== [2/6] Mendeteksi libc sistem ==="

detect_libc() {
	# cara paling akurat di OpenWrt: cek dynamic linker musl langsung ada atau tidak
	if ls /lib/ld-musl-*.so.1 >/dev/null 2>&1; then
		echo "musl"
		return
	fi
	# indikasi glibc: linker glibc standar ada
	if [ -f /lib/libc.so.6 ] || [ -f /lib64/libc.so.6 ] || [ -f /usr/lib/libc.so.6 ]; then
		echo "glibc"
		return
	fi
	# fallback terakhir: baca banner ldd (musl mencetak "musl libc" ke stderr)
	if ldd --version 2>&1 | grep -qi musl; then
		echo "musl"
		return
	fi
	echo "unknown"
}

SYS_LIBC=$(detect_libc)
if [ "$SYS_LIBC" = "unknown" ]; then
	# OpenWrt praktis selalu musl; kalau deteksi gagal total, aman diasumsikan musl
	# tapi tetap dicatat sebagai peringatan supaya bisa dicek manual kalau salah
	log "PERINGATAN: libc sistem tidak terdeteksi pasti, diasumsikan musl (default OpenWrt)."
	SYS_LIBC="musl"
else
	log "libc sistem terdeteksi: $SYS_LIBC"
fi

# -----------------------------------------------------------------------
# [3/6] Hitung nama asset yang HARUS dipakai (bukan coba-coba)
# -----------------------------------------------------------------------
log "=== [3/6] Menentukan asset yang sesuai (arch=$SB_ARCH, libc=$SYS_LIBC) ==="

. /lib/functions.sh 2>/dev/null
config_load "$CONF"
BIN_PATH="/usr/bin/sing-box"
ENABLED="0"
config_get BIN_PATH config bin_path "/usr/bin/sing-box"
config_get ENABLED  config enabled  "0"

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

# nama asset dihitung LANGSUNG dari arch+libc, bukan trial-and-error:
#   - arch punya varian -musl  DAN sistem musl  -> pakai "-musl"
#   - arch punya varian -musl  DAN sistem glibc  -> pakai plain (memang glibc-linked)
#   - arch TIDAK punya varian -musl (mips/riscv64/dst, selalu pure-Go static) -> pakai plain
if [ "$HAS_MUSL_ASSET" = "1" ] && [ "$SYS_LIBC" = "musl" ]; then
	ASSET_NAME="sing-box-${LATEST_VER}-linux-${SB_ARCH}-musl.tar.gz"
else
	ASSET_NAME="sing-box-${LATEST_VER}-linux-${SB_ARCH}.tar.gz"
fi
log "Asset yang dicari: $ASSET_NAME"

if command -v jq >/dev/null 2>&1; then
	DOWNLOAD_URL=$(echo "$API_JSON" | jq -r --arg name "$ASSET_NAME" '.assets[] | select(.name==$name) | .browser_download_url')
else
	DOWNLOAD_URL=$(echo "$API_JSON" | grep "\"browser_download_url\"" | grep "/${ASSET_NAME}\"" | head -n1 | sed -E 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
fi

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
	log "GAGAL: asset '$ASSET_NAME' tidak ditemukan pada rilis $LATEST_TAG."
	log "Cek daftar asset asli di https://github.com/SagerNet/sing-box/releases/tag/$LATEST_TAG"
	exit 1
fi
log "Asset ditemukan di rilis GitHub."

# -----------------------------------------------------------------------
# [4/6] Download
# -----------------------------------------------------------------------
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

# -----------------------------------------------------------------------
# [5/6] Ekstrak, backup binary lama, pasang binary baru
# -----------------------------------------------------------------------
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
	log "Binary lama di-backup ke $BACKUP_PATH (buat jaga-jaga kalau binary baru gagal jalan)."
fi

mkdir -p "$(dirname "$BIN_PATH")"
cp -f "$EXTRACTED_BIN" "$BIN_PATH"
chmod 755 "$BIN_PATH"
rm -rf "$TMP_DIR"
log "Binary baru dipasang di $BIN_PATH dengan permission 755."

# -----------------------------------------------------------------------
# [6/6] Verifikasi nyata (bukan asumsi)
# -----------------------------------------------------------------------
log "=== [6/6] Verifikasi: menjalankan binary baru untuk memastikan benar-benar kompatibel ==="
VERIFY_OUT=$("$BIN_PATH" version 2>&1)
VERIFY_LINE=$(echo "$VERIFY_OUT" | head -n1)

if [ -z "$VERIFY_LINE" ] || echo "$VERIFY_OUT" | grep -qiE 'not found|cannot execute|exec format error|no such file'; then
	log "GAGAL: binary baru TIDAK BISA dijalankan di sistem ini. Detail: ${VERIFY_OUT:-(tidak ada output, kemungkinan besar mismatch libc/arch)}"
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

[ -n "$BACKUP_PATH" ] && rm -f "$BACKUP_PATH"

if [ "$ENABLED" = "1" ]; then
	log "Menyalakan kembali service..."
	/etc/init.d/danbox start >/dev/null 2>&1
fi