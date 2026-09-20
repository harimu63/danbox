# luci-app-danbox

LuCI web interface untuk menjalankan core [sing-box](https://github.com/SagerNet/sing-box) (SagerNet) langsung di OpenWrt — start/stop lewat Enable+Save&Apply, transparent proxy (nftables tproxy) otomatis, editor/file manager khusus folder config, log App/Core terpisah, menu Update Core yang mendeteksi arch+libc sendiri lalu download versi yang benar dari GitHub Releases, **info IP & lokasi proxy real-time**, dan **pilihan 6 dashboard UI berbeda**.

Repo: **https://github.com/harimu63/danbox**
Rilis (`.ipk` siap pakai): **https://github.com/harimu63/danbox/releases**

## Fitur

### App Config (beranda)
- **Status core**: versi & Running/Not Running.
- **Info Proxy**: IP publik, lokasi (City/Region/Country), ISP/Organization - update otomatis atau manual lewat tombol Refresh.
- **Kontrol service**: checkbox **Enable** + tombol **Save & Apply** (centang → otomatis nyala, uncentang → otomatis mati). Tombol RESTART dan RELOAD tersedia untuk kontrol manual.
- Tombol **OPEN DASHBOARD** — buka dashboard clash_api di tab baru.
- Tombol **UPDATE DASHBOARD** — download/update dashboard UI sesuai pilihan di tab Settings.
- Pengaturan lengkap: path binary, folder & nama file config, start delay, test-config sebelum start.
- Panel Log (App) langsung di beranda.

### Settings
- **Transparent Proxy**: konfigurasi nftables tproxy (port, fwmark, self_mark, routing table).
- **Dashboard**: pilih dari **6 dashboard UI** berbeda:
  - **Yacd-meta (MetaCubeX)** - yacd.metacubex.one *(default)*
  - **Yacd (Haishan)** - yacd.haishan.me
  - **Clash Dashboard (Razord)** - clash.razord.top
  - **Yacd-meta (Taamarin)** - yacd-meta-taamarin.vercel.app
  - **MetaCubeXD** - Modern dashboard dengan fitur lengkap
  - **Zashboard** - Minimalist & cepat
- Setting port dan direktori dashboard (external_ui).
- **Save tanpa restart service** - perubahan tersimpan tanpa mengganggu koneksi yang sedang berjalan.

### Editor
File manager (Name/Size/Modified/Perms/Actions) yang di-sandbox hanya ke dalam folder config sing-box — tidak bisa keluar dari folder itu. Bisa navigasi subfolder, buat file baru, Edit, Download, Delete.

### Log
Empat tab terpisah:
- **App Log** — tahapan service (validasi, start, nftables setup)
- **Core Log** — output mentah sing-box, termasuk error asli kalau config salah
- **Update Log** — proses download/update core
- **Dashboard Log** — proses download/update dashboard UI

### Update Core
Download/update binary `sing-box` langsung dari GitHub Releases resmi SagerNet — deteksi arsitektur & libc (musl/glibc) otomatis, backup binary lama, dan verifikasi nyata sebelum dianggap berhasil.

---

## Instalasi

### Cara 1 — Install dari file `.ipk` release (direkomendasikan)

1. **Download file `.ipk`** dari GitHub Releases:
   ```
   https://github.com/harimu63/danbox/releases
   ```
   Pilih versi terbaru dan download file `luci-app-danbox_*.ipk`

2. **Upload ke router** (pilih salah satu):

   **Via SCP** (dari komputer):
   ```bash
   scp luci-app-danbox_*.ipk root@192.168.1.1:/tmp/
   ```

   **Via LuCI Web UI**:
   - Buka LuCI → System → Software
   - Tab "Upload Package"
   - Pilih file `.ipk` → Upload

3. **Install lewat SSH** ke router:
   ```bash
   ssh root@192.168.1.1
   
   # Install package
   opkg install /tmp/luci-app-danbox_*.ipk
   
   # Restart services
   /etc/init.d/rpcd restart
   /etc/init.d/uhttpd restart
   ```

4. **Akses DanBox**:
   - Buka LuCI → **Services → DanBox**
   - Interface akan muncul dengan 5 tab: App Config, Settings, Editor, Update Core, Log

> **Catatan**: Package ini `arch: all` (isinya Lua/shell script, bukan binary native), jadi `.ipk` yang sama bisa dipasang di router arsitektur apapun (arm64, mips, x86, dst).

### Cara 2 — Langsung dari source, tanpa `.ipk` (buat testing cepat)

Jalankan langsung di router lewat SSH:
```bash
cd /tmp
wget https://codeload.github.com/harimu63/danbox/tar.gz/refs/heads/main -O danbox.tar.gz
tar -xzf danbox.tar.gz
cd danbox-main

cp -r luasrc/* /usr/lib/lua/luci/
cp -r root/* /
chmod +x /etc/init.d/danbox
chmod +x /usr/share/danbox/update-core.sh
chmod +x /usr/share/danbox/update-dashboard.sh

/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
rm -rf /tmp/danbox*
```

---

## Cara Penggunaan

### Setup Awal

1. **Download binary sing-box** (jika belum ada):
   - Buka tab **Update Core**
   - Klik **Download / Update Sekarang**
   - Script otomatis deteksi arsitektur & libc router, download versi yang kompatibel dari GitHub
   - Tunggu hingga selesai (cek progress di Update Log)

2. **Siapkan file config**:
   - Buka tab **Editor**
   - Buat/upload `config.json` ke folder config (default `/etc/sing-box/`)
   - Atau upload manual lewat `scp`:
     ```bash
     scp config.json root@192.168.1.1:/etc/sing-box/
     ```

3. **Download dashboard UI** (opsional, untuk clash_api):
   - Buka tab **Settings**
   - Pilih **Dashboard Source** yang diinginkan (default: Yacd-meta MetaCubeX)
   - Klik **Save**
   - Kembali ke tab **App Config**
   - Klik **UPDATE DASHBOARD**
   - Tunggu hingga selesai (cek Dashboard Log)

4. **Konfigurasi App**:
   - Buka tab **App Config**
   - Cek/isi parameter:
     - **Binary Path**: `/usr/bin/sing-box` (default)
     - **Config Directory**: `/etc/sing-box` (default)
     - **Config File**: Pilih dari dropdown (otomatis scan file `.json`)
     - **Test Config Before Start**: Centang (direkomendasikan)
   
5. **Konfigurasi Settings** (jika perlu custom):
   - Buka tab **Settings**
   - **Transparent Proxy**:
     - TPROXY Port: `9898` (harus sama dengan `inbounds.tproxy.listen_port` di config.json)
     - fwmark: `0x1` (untuk marking paket)
     - self_mark: `0xff` (harus sama dengan `route.default_mark` di config.json)
     - Routing Table: `100`
   - **Dashboard**:
     - Dashboard Source: Pilih UI yang diinginkan
     - Dashboard Port: `9090` (harus sama dengan `experimental.clash_api.external_controller`)
     - Dashboard Directory: `/etc/sing-box/ui` (harus sama dengan `experimental.clash_api.external_ui`)
   - Klik **Save**

### Menjalankan Service

1. **Start service**:
   - Buka tab **App Config**
   - Centang **Enable**
   - Klik **Save & Apply**
   - DanBox akan:
     - Validasi config (`sing-box check`)
     - Jalankan core sing-box
     - Monitor startup (cek error dalam 3 detik)
     - Pasang nftables tproxy + ip rule/route
   - Status berubah jadi **Running** (hijau)
   - Cek **App Log** untuk detail proses

2. **Monitoring**:
   - **Info Proxy**: Lihat IP & lokasi yang terdeteksi (klik Refresh untuk update)
   - **Status**: Core version & running status
   - **App Log**: Log tahapan service di beranda
   - Tab **Log**: 
     - **App Log** — Detail step-by-step (validasi, start, nftables)
     - **Core Log** — Output asli sing-box (error config akan muncul di sini)
     - **Update Log** — Proses update core
     - **Dashboard Log** — Proses update dashboard

3. **Akses Dashboard** (jika clash_api aktif):
   - Pastikan config sing-box punya section `experimental.clash_api`
   - Klik tombol **OPEN DASHBOARD** di App Config
   - Dashboard terbuka di tab baru (`http://router-ip:9090/ui`)

### Kontrol Service

- **RESTART**: Restart core saja, nftables tetap dipertahankan (cepat untuk reload config)
- **RELOAD**: Reload full (core + nftables)
- **Enable/Disable**: Centang/uncentang Enable → Save & Apply
  - Enable = Start service + pasang nftables
  - Disable = Stop service + hapus nftables

### Update & Maintenance

1. **Update Core sing-box**:
   - Tab **Update Core** → klik **Download / Update Sekarang**
   - Proses otomatis: stop service → backup binary lama → download → verify → start service
   - Rollback otomatis jika binary baru tidak kompatibel

2. **Ganti Dashboard**:
   - Tab **Settings** → pilih **Dashboard Source** baru
   - Klik **Save**
   - Tab **App Config** → klik **UPDATE DASHBOARD**
   - Backup otomatis dashboard lama
   - Rollback otomatis jika download gagal

3. **Edit Config**:
   - Tab **Editor** → navigasi file/folder
   - Edit file JSON → Save
   - Tab **App Config** → klik **RESTART** untuk apply

---

## Fitur Detail

### Info IP & Lokasi Proxy
- Menampilkan IP publik yang terlihat dari internet
- Lokasi geografis (City, Region, Country)
- ISP/Organization
- **Auto-refresh** saat halaman dibuka
- Tombol **Refresh** untuk update manual
- Menggunakan API ipapi.co (gratis, 30k requests/bulan)
- Jika proxy aktif → menampilkan IP & lokasi proxy
- Jika proxy tidak aktif → menampilkan IP asli router

### Multi Dashboard UI
6 pilihan dashboard dengan karakteristik berbeda:

1. **Yacd-meta (MetaCubeX)** - *Default*
   - Full-featured, modern UI
   - Support semua fitur clash meta
   - Update aktif

2. **Yacd (Haishan)**
   - Original yacd, stabil
   - Lightweight, cepat

3. **Clash Dashboard (Razord)**
   - Classic clash dashboard
   - Simple & clean

4. **Yacd-meta (Taamarin)**
   - Fork yacd-meta dengan custom tweaks
   - Optimized untuk mobile

5. **MetaCubeXD**
   - Modern, sleek design
   - Rich features & visualization
   - Best untuk power users

6. **Zashboard**
   - Minimalist design
   - Sangat ringan & cepat
   - Best untuk low-end devices

### Transparent Proxy (nftables tproxy)
- Auto-setup nftables rules untuk intercept traffic
- Marking paket dengan fwmark
- IP rule & route table untuk routing marked packets
- Exclude private IP (LAN, loopback)
- Prevent routing loop dengan self_mark
- Auto-cleanup saat service stop
- Auto-reinstall saat firewall reload

### File Editor
- Sandboxed ke `config_dir` (tidak bisa akses di luar folder)
- Navigasi subfolder
- Create, Edit, Download, Delete
- Syntax highlighting (jika browser support)
- File size & permission info

### Log System
- **4 log terpisah** untuk clarity
- Auto-refresh (1 detik untuk log aktif, 3 detik untuk status)
- Color-coded messages (error=merah, success=hijau, info=biru)
- Tail 400 baris terakhir (cukup untuk debugging)
- ANSI color stripping untuk clean display

---

## Cara Menghapus (Uninstall) di OpenWrt

### Kalau diinstall lewat `.ipk` / opkg
```bash
# Stop & disable service
/etc/init.d/danbox stop
/etc/init.d/danbox disable

# Hapus package
opkg remove luci-app-danbox

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

### Bersih-bersih sisa file (opsional)
`opkg remove` menghapus file package, tapi **tidak** menghapus config UCI, log, atau nftables rule yang lagi aktif. Kalau mau benar-benar bersih total:

```bash
# Hapus rule jaringan yang mungkin masih terpasang
nft delete table inet danbox_tproxy 2>/dev/null
ip rule del fwmark 0x1 lookup 100 2>/dev/null
ip route flush table 100 2>/dev/null

# Hapus config, log, dan file nftables sisa
rm -f /etc/config/danbox
rm -f /etc/danbox-tproxy.nft
rm -f /var/log/danbox-app.log
rm -f /var/log/danbox-core.log
rm -f /var/log/danbox-update.log
rm -f /var/log/danbox-dashboard.log
```

> Sesuaikan `fwmark`/`lookup table` di atas kalau kamu pernah mengubahnya dari default (`0x1` / `100`) di Settings.

### Kalau diinstall lewat metode manual (Cara 2)
```bash
/etc/init.d/danbox stop
/etc/init.d/danbox disable

rm -f /etc/init.d/danbox
rm -f /usr/lib/lua/luci/controller/danbox.lua
rm -rf /usr/lib/lua/luci/view/danbox
rm -rf /usr/share/danbox
rm -f /usr/share/rpcd/acl.d/luci-app-danbox.json

# Lalu bersih-bersih sisa seperti di bagian atas (nftables, config, log)
```

Binary sing-box sendiri (`/usr/bin/sing-box` atau path custom kamu) **tidak ikut terhapus** oleh langkah manapun di atas — hapus manual kalau memang tidak dipakai lagi.

---

## Troubleshooting

### Service tidak mau start
1. Cek **Core Log** di tab Log — error config akan muncul di sini
2. Cek **App Log** — lihat di step mana proses berhenti
3. Verifikasi manual: `sing-box check -c /etc/sing-box/config.json`
4. Pastikan binary executable: `chmod 755 /usr/bin/sing-box`

### Dashboard tidak bisa dibuka
1. Cek config sing-box punya section `experimental.clash_api`:
   ```json
   "experimental": {
     "clash_api": {
       "external_controller": "0.0.0.0:9090",
       "external_ui": "/etc/sing-box/ui",
       "secret": ""
     }
   }
   ```
2. Pastikan dashboard sudah didownload: `ls -la /etc/sing-box/ui/`
3. Pastikan port tidak bentrok: `netstat -tuln | grep 9090`
4. Cek firewall allow port 9090

### Proxy tidak jalan / traffic tidak lewat sing-box
1. Cek nftables rules: `nft list table inet danbox_tproxy`
2. Cek ip rule: `ip rule show | grep 100`
3. Cek ip route: `ip route show table 100`
4. Pastikan parameter tproxy di Settings **sama persis** dengan config.json:
   - `tproxy_port` = `inbounds.tproxy.listen_port`
   - `self_mark` = `route.default_mark`
5. Restart service setelah ubah Settings

### Update core gagal
1. Cek **Update Log** di tab Log
2. Pastikan koneksi internet router OK: `ping -c 3 8.8.8.8`
3. Cek space disk cukup: `df -h`
4. Download manual jika perlu dari: https://github.com/SagerNet/sing-box/releases

### Info Proxy tidak muncul
1. Pastikan router punya koneksi internet
2. Cek manual: `wget -qO- https://ipapi.co/json/`
3. Jika API ipapi.co down, tunggu beberapa saat atau ganti API di controller (edit `action_proxy_info()`)

---

## Catatan Penting

- Sejak sing-box 1.13.0, asset rilis *plain* untuk `linux amd64/arm64/arm/386` dynamically-linked ke **glibc** (karena `libcronet.so` untuk NaiveProxy) dan gagal jalan di sistem musl-only seperti OpenWrt. Menu **Update Core** sudah otomatis memilih varian `-musl` untuk arch yang punya varian itu.
- Editor di-sandbox hanya ke `config_dir` yang diset di App Config.
- Permission LuCI diatur lewat rpcd ACL (`luci-app-danbox`) — assign ke user/group yang boleh akses di **System → Users** kalau perlu dibatasi.
- Proxy info menggunakan API gratis dengan rate limit, jangan spam tombol Refresh.
- Dashboard tersimpan lokal di router, tidak perlu koneksi internet setelah didownload.

---

## Kontribusi & Support

- GitHub Issues: https://github.com/harimu63/danbox/issues
- Pull Requests welcome!
- Star ⭐ repo ini jika bermanfaat

---

**Lisensi**: GPL-3.0  
**Author**: Higen (harimu63)