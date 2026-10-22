# luci-app-danbox

LuCI web interface untuk menjalankan [sing-box](https://github.com/SagerNet/sing-box) di OpenWrt dengan transparent proxy (nftables tproxy), file manager, update core otomatis, info IP proxy real-time, dan 6 pilihan dashboard UI.

**Repo**: https://github.com/harimu63/danbox  
**Releases**: https://github.com/harimu63/danbox/releases

---

## ✨ Fitur Utama

- 🚀 **Transparent Proxy** dengan nftables tproxy otomatis
- 🌍 **Info Proxy Real-time** - lihat IP & lokasi proxy yang aktif
- 📊 **6 Dashboard UI** - Yacd-meta, MetaCubeXD, Zashboard, dll
- 📝 **File Manager** - edit config langsung dari web
- 🔄 **Auto Update Core** - deteksi arch & download otomatis dari GitHub
- 📋 **Multi-Log Viewer** - App, Core, Update, Dashboard terpisah
- 📱 **Responsive UI** - tampilan optimal untuk desktop & mobile

---

## 📦 Instalasi

### 1. Download `.ipk` dari Releases
```bash
# Download versi terbaru dari:
https://github.com/harimu63/danbox/releases
```

### 2. Upload & Install di Router
```bash
# Upload ke router
scp luci-app-danbox_*.ipk root@192.168.1.1:/tmp/

# SSH ke router
ssh root@192.168.1.1

# Install package
opkg install /tmp/luci-app-danbox_*.ipk

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

### 3. Akses DanBox
Buka LuCI → **Services → DanBox**

---

## ⚙️ Cara Setup Config

### Opsi 1: Generate Config via Bot Telegram
1. Chat bot: **[@clashhhhhh_bot](https://t.me/clashhhhhh_bot)**
2. Generate config sing-box dari bot
3. Copy config JSON yang dihasilkan

### Opsi 2: Buat Manual
Contoh config minimal:
```json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns-remote",
        "address": "https://1.1.1.1/dns-query",
        "detour": "proxy-out"
      },
      {
        "tag": "dns-local",
        "address": "223.5.5.5",
        "detour": "direct-out"
      }
    ],
    "rules": [
      {
        "geosite": "cn",
        "server": "dns-local"
      }
    ]
  },
  "inbounds": [
    {
      "type": "tproxy",
      "tag": "tproxy-in",
      "listen": "::",
      "listen_port": 9898,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": "vmess",
      "tag": "proxy-out",
      "server": "your-server.com",
      "server_port": 443,
      "uuid": "your-uuid-here",
      "security": "auto",
      "alter_id": 0,
      "tls": {
        "enabled": true,
        "server_name": "your-server.com"
      }
    },
    {
      "type": "direct",
      "tag": "direct-out"
    }
  ],
  "route": {
    "rules": [
      {
        "geosite": "cn",
        "outbound": "direct-out"
      },
      {
        "geoip": "cn",
        "outbound": "direct-out"
      }
    ],
    "default_mark": 255
  },
  "experimental": {
    "clash_api": {
      "external_controller": "0.0.0.0:9090",
      "external_ui": "/etc/sing-box/ui",
      "secret": ""
    }
  }
}
```

### Upload Config ke Router
```bash
# Via SSH
scp config.json root@192.168.1.1:/etc/sing-box/

# Atau upload lewat Editor di web DanBox
```

---

## 🚀 Quick Start

1. **Download Core** (jika belum ada):
   - Buka tab **Update Core** → klik **Download / Update Sekarang**

2. **Setup Config**:
   - Buka tab **Editor** → buat file `config.json`
   - Paste config dari bot atau buat manual

3. **Download Dashboard** (opsional):
   - Tab **Settings** → pilih Dashboard Source
   - Tab **App Config** → klik **UPDATE DASHBOARD**

4. **Start Service**:
   - Tab **App Config**
   - Centang **Enable**
   - Klik **Save & Apply**
   - Status berubah jadi **Running** (hijau)

5. **Cek Proxy Info**:
   - Lihat IP & lokasi proxy di bagian **Proxy Info**
   - Klik **Refresh** untuk update manual

6. **Buka Dashboard** (jika clash_api aktif):
   - Klik **OPEN DASHBOARD** di App Config

---

## 🔧 Settings Penting

**Transparent Proxy** (harus match dengan config.json):
- TPROXY Port: `9898` → sama dengan `inbounds.tproxy.listen_port`
- self_mark: `0xff` (255) → sama dengan `route.default_mark`

**Dashboard** (jika pakai clash_api):
- Dashboard Port: `9090` → sama dengan `experimental.clash_api.external_controller`
- Dashboard Directory: `/etc/sing-box/ui` → sama dengan `experimental.clash_api.external_ui`

---

## 📋 Log & Monitoring

Buka tab **Log** untuk melihat:
- **App Log** - proses start/stop, validasi, nftables
- **Core Log** - output sing-box (error config muncul di sini)
- **Update Log** - proses update core
- **Dashboard Log** - proses update dashboard

---

## 🗑️ Uninstall

```bash
# Stop service
/etc/init.d/danbox stop

# Hapus package
opkg remove luci-app-danbox

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

# Bersihkan sisa (opsional)
nft delete table inet danbox_tproxy 2>/dev/null
rm -f /etc/config/danbox
rm -f /var/log/danbox-*.log
```

---

## 🆘 Troubleshooting

**Service tidak start:**
- Cek **Core Log** di tab Log untuk error detail
- Validasi config: `sing-box check -c /etc/sing-box/config.json`

**Proxy tidak jalan:**
- Pastikan parameter tproxy di **Settings** sama dengan `config.json`
- Cek nftables: `nft list table inet danbox_tproxy`
- Restart service setelah ubah Settings

**Dashboard tidak bisa dibuka:**
- Pastikan config punya section `experimental.clash_api`
- Klik **UPDATE DASHBOARD** di App Config
- Cek port 9090 tidak bentrok: `netstat -tuln | grep 9090`

---

## 📝 Catatan

- Package ini **tidak** bundle binary sing-box — download terpisah via menu Update Core
- Sejak sing-box 1.13.0+, gunakan varian `-musl` untuk OpenWrt (auto-detect)
- Editor di-sandbox hanya ke folder config (keamanan)

---

## 🙏 Support

- Bot Telegram Config: [@clashhhhhh_bot](https://t.me/clashhhhhh_bot)
- GitHub Issues: https://github.com/harimu63/danbox/issues
- Star ⭐ repo ini jika bermanfaat!

---

**Lisensi**: GPL-3.0  
**Author**: Higen (harimu63)
