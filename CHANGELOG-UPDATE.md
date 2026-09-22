# DanBox Update - Changelog

## v2.0.0 (2026-09-22)

### 🎉 New Features

#### 1. **Smart File Manager Auto-Detection**
Tab **Editor** sekarang otomatis mendeteksi file manager yang tersedia di router dan redirect ke yang paling sesuai:

**Priority Detection:**
1. **TinyFM** (luci-app-tinyfm) - Full-featured dengan terminal integration
2. **FileBrowser** (luci-app-filebrowser) - Modern file browser
3. **LuCI RPC Fileman** (luci-mod-rpc) - Classic file manager
4. **Built-in Editor** - Fallback jika tidak ada file manager eksternal

**Fitur:**
- ✅ Auto-detect file manager yang terinstall
- ✅ Otomatis redirect ke folder config sing-box (`/etc/sing-box`)
- ✅ Universal support - bekerja di semua OpenWrt firmware
- ✅ Fallback ke built-in editor jika tidak ada file manager eksternal
- ✅ Tidak perlu instalasi tambahan (opsional untuk fitur advanced)

**Endpoint baru:**
- `/admin/services/danbox/detect_filemgr` - GET detected file manager info
- `/admin/services/danbox/editor_builtin` - Built-in editor fallback

#### 2. **Universal OpenWrt Compatibility**
- Support semua firmware OpenWrt (tidak terbatas pada TinyFM saja)
- Deteksi otomatis file manager yang tersedia
- Seamless experience di berbagai setup router

### 🔄 Changes
- Tab Editor sekarang menggunakan `call("action_editor")` dengan auto-detection logic
- Built-in editor tetap tersedia sebagai fallback
- File `editor.htm` tetap dipertahankan untuk fallback mode

---

## v1.2.1 (2026-09-20)

### Perubahan yang Dilakukan

### 1. **Reorder Tab Menu**
- **App Config** - Tab 1 (tetap di posisi pertama)
- **Settings** - Tab 2 (dipindah dari posisi 5 ke samping App Config)
- **Editor** - Tab 3
- **Update Core** - Tab 4
- **Log** - Tab 5 (dipindah ke paling belakang)

### 2. **Fitur Baru: Info IP & Lokasi Proxy**
Ditambahkan di tab **App Config** (status.htm):
- Menampilkan IP publik router
- Lokasi (City, Region, Country)
- ISP/Organization
- Timezone
- Tombol **Refresh** untuk update manual
- Auto-load saat halaman dibuka pertama kali
- Menggunakan API ipapi.co (gratis, tanpa API key)

**Endpoint baru:**
- /admin/services/danbox/proxy_info - GET proxy information

### 3. **Fitur Baru: Multi Dashboard Source**
Ditambahkan dropdown pilihan dashboard di tab **Settings**:

**6 Pilihan Dashboard:**
1. **Yacd-meta (MetaCubeX)** - yacd.metacubex.one (default)
2. **Yacd (Haishan)** - yacd.haishan.me
3. **Clash Dashboard (Razord)** - clash.razord.top
4. **Yacd-meta (Taamarin)** - yacd-meta-taamarin.vercel.app
5. **MetaCubeXD** - Modern dashboard
6. **Zashboard** - Minimalist dashboard

**Cara Kerja:**
1. Pilih dashboard source di tab **Settings**
2. Klik **Save**
3. Kembali ke tab **App Config**
4. Klik tombol **UPDATE DASHBOARD**
5. Script akan otomatis download dashboard sesuai pilihan

### 4. **File yang Dimodifikasi**

#### Controller (luasrc/controller/danbox.lua)
- Reorder entry tabs
- Tambah endpoint proxy_info
- Tambah field dashboard_source di get_cfg()
- Update action_config_save_only() untuk save dashboard_source
- Tambah fungsi action_proxy_info() untuk ambil info IP/lokasi

#### View - Status (luasrc/view/danbox/status.htm)
- Tambah section Proxy Info dengan table display
- Tambah fungsi dbRefreshProxyInfo() untuk fetch proxy info
- Auto-refresh proxy info saat page load

#### View - Settings (luasrc/view/danbox/settings.htm)
- Tambah dropdown Dashboard Source dengan 6 opsi
- Update load dan save functions untuk dashboard_source

#### Script Update Dashboard (root/usr/share/danbox/update-dashboard.sh)
- Refactor untuk support multiple dashboard sources
- Dynamic URL selection berdasarkan pilihan user

#### Config Default (root/etc/config/danbox)
- Tambah option dashboard_source 'metacubex'

---

**Update Date:** 2026-09-20  
**Version:** 1.2.1
