# DanBox v2.0.0 - Smart File Manager

## 🎉 What's New

### 🔍 Smart File Manager Auto-Detection

Tab **Editor** sekarang secara otomatis mendeteksi file manager yang tersedia di router Anda dan redirect ke yang paling sesuai!

**Supported File Managers (Priority Order):**
1. **TinyFM** (luci-app-tinyfm) - Full-featured dengan terminal integration
2. **FileBrowser** (luci-app-filebrowser) - Modern file browser
3. **LuCI RPC Fileman** (luci-mod-rpc) - Classic file manager  
4. **Built-in Editor** - Custom file manager sebagai fallback

**Key Features:**
- ✅ **Universal Compatibility** - Bekerja di semua firmware OpenWrt
- ✅ **Auto-Redirect** - Langsung ke folder sing-box (`/etc/sing-box`)
- ✅ **Zero Configuration** - Tidak perlu instalasi tambahan (opsional untuk fitur advanced)
- ✅ **Smart Fallback** - Jika tidak ada file manager eksternal, gunakan built-in editor
- ✅ **Seamless Experience** - Klik Editor → langsung siap pakai

**Cara Kerja:**
1. Klik tab **Editor** di DanBox
2. System otomatis detect file manager yang terinstall
3. Redirect ke file manager terbaik yang tersedia
4. Langsung buka folder `/etc/sing-box`
5. Edit, upload, download file dengan mudah

---

## 📦 Installation

### Install DanBox v2.0.0

**Via opkg:**
```bash
wget https://github.com/harimu63/danbox/releases/download/v2.0.0/luci-app-danbox_2.0.0_all.ipk
opkg install luci-app-danbox_2.0.0_all.ipk
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

**Manual install:**
```bash
cd /tmp
wget https://github.com/harimu63/danbox/archive/refs/tags/v2.0.0.tar.gz
tar -xzf v2.0.0.tar.gz
cd danbox-2.0.0
cp -r luasrc/* /usr/lib/lua/luci/
cp -r root/* /
chmod +x /etc/init.d/danbox
chmod +x /usr/share/danbox/update-core.sh
chmod +x /usr/share/danbox/update-dashboard.sh
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

### Install File Manager (Opsional - untuk fitur advanced)

**TinyFM (Recommended):**
```bash
opkg update
opkg install luci-app-tinyfm
/etc/init.d/uhttpd restart
```

**FileBrowser:**
```bash
opkg update
opkg install luci-app-filebrowser
/etc/init.d/uhttpd restart
```

> **Note:** Jika tidak ada file manager eksternal terinstall, DanBox akan otomatis menggunakan built-in editor yang sudah ada.

---

## 🔄 Upgrade from v1.x

```bash
# Backup config (opsional)
cp /etc/config/danbox /etc/config/danbox.backup

# Install versi baru
opkg install luci-app-danbox_2.0.0_all.ipk

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

Config file Anda akan tetap ada dan tidak perlu setting ulang.

---

## 📝 Previous Features (from v1.2.1)

- ✅ **Real-time Proxy Info** - IP publik & lokasi (City/Region/Country/ISP)
- ✅ **6 Dashboard UI Options** - MetaCubeX, Yacd, Zashboard, MetaCubeXD, dll
- ✅ **Tab Reordering** - Settings next to App Config, Log moved to end
- ✅ **Auto-Update Core** - Download sing-box dari GitHub Releases dengan deteksi arch otomatis
- ✅ **Transparent Proxy** - nftables tproxy setup otomatis
- ✅ **Service Control** - Enable/Disable, Start/Stop/Restart/Reload
- ✅ **Multi-Log** - App Log, Core Log, Update Log, Dashboard Log

---

## 🐛 Bug Fixes

- Fixed file manager routing untuk universal compatibility
- Improved error handling untuk file manager detection
- Better fallback mechanism jika tidak ada file manager eksternal

---

## 📚 Documentation

- **Full README**: [README.md](https://github.com/harimu63/danbox/blob/main/README.md)
- **Changelog**: [CHANGELOG-UPDATE.md](https://github.com/harimu63/danbox/blob/main/CHANGELOG-UPDATE.md)
- **Deploy Guide**: [DEPLOY-READY.md](https://github.com/harimu63/danbox/blob/main/DEPLOY-READY.md)

---

## 🆘 Support

- **Issues**: https://github.com/harimu63/danbox/issues
- **Discussions**: https://github.com/harimu63/danbox/discussions

---

## ⭐ Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Full Changelog**: https://github.com/harimu63/danbox/compare/v1.2.1...v2.0.0

**License**: GPL-3.0  
**Author**: Higen (harimu63)
