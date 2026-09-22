# Upgrade Guide: DanBox v1.x → v2.0.0

## 🎯 What's Changed

### Major Change: Smart File Manager
- **v1.x**: Custom built-in file manager only
- **v2.0.0**: Auto-detect external file managers (TinyFM/FileBrowser/Fileman) dengan fallback ke built-in

### Benefits
✅ **Universal Compatibility** - Bekerja di semua firmware OpenWrt  
✅ **Better User Experience** - Gunakan file manager favorit Anda  
✅ **Advanced Features** - Terminal integration, compression, bulk operations (jika menggunakan TinyFM/FileBrowser)  
✅ **Zero Breaking Changes** - Built-in editor tetap ada sebagai fallback  

---

## 📦 Upgrade Steps

### 1. Backup Config (Opsional)
```bash
ssh root@192.168.1.1
cp /etc/config/danbox /etc/config/danbox.backup
cp -r /etc/sing-box /etc/sing-box.backup
```

### 2. Install v2.0.0

**Via opkg:**
```bash
# Download IPK
wget https://github.com/harimu63/danbox/releases/download/v2.0.0/luci-app-danbox_2.0.0_all.ipk

# Install (akan otomatis upgrade dari v1.x)
opkg install luci-app-danbox_2.0.0_all.ipk

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

**Via manual:**
```bash
cd /tmp
wget https://github.com/harimu63/danbox/archive/refs/tags/v2.0.0.tar.gz
tar -xzf v2.0.0.tar.gz
cd danbox-2.0.0

# Install files
cp -r luasrc/* /usr/lib/lua/luci/
cp -r root/* /
chmod +x /etc/init.d/danbox
chmod +x /usr/share/danbox/update-core.sh
chmod +x /usr/share/danbox/update-dashboard.sh

# Restart services
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

### 3. Install File Manager (Opsional - untuk fitur advanced)

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

**Note:** Jika tidak install file manager eksternal, DanBox akan tetap menggunakan built-in editor seperti di v1.x.

---

## 🧪 Verify Upgrade

### 1. Check Version
```bash
# Via LuCI
# Buka: LuCI → Services → DanBox
# Lihat footer atau package info

# Via opkg
opkg list-installed | grep luci-app-danbox
# Output: luci-app-danbox - 2.0.0-1
```

### 2. Test Editor Tab
```bash
# Buka: LuCI → Services → DanBox → Editor

# Expected behavior:
# - Jika punya TinyFM → redirect ke TinyFM (folder /etc/sing-box)
# - Jika punya FileBrowser → redirect ke FileBrowser (folder /etc/sing-box)
# - Jika tidak ada → tampilkan built-in editor (sama seperti v1.x)
```

### 3. Test Detection API
```bash
curl "http://192.168.1.1/cgi-bin/luci/admin/services/danbox/detect_filemgr"

# Output example:
# {"detected":"tinyfm","url":"/cgi-bin/luci/admin/system/tinyfm?path=/etc/sing-box","config_dir":"/etc/sing-box"}
```

---

## 🔄 Rollback (Jika Diperlukan)

Jika ada masalah, rollback ke v1.2.1:

```bash
# Download v1.2.1
wget https://github.com/harimu63/danbox/releases/download/v1.2.1/luci-app-danbox_1.2.1_all.ipk

# Install
opkg install luci-app-danbox_1.2.1_all.ipk

# Restart
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

# Restore config (jika ada backup)
cp /etc/config/danbox.backup /etc/config/danbox
```

---

## ❓ FAQ

### Q: Apakah config saya akan hilang setelah upgrade?
**A:** Tidak. Config di `/etc/config/danbox` dan `/etc/sing-box/` tetap ada dan tidak berubah.

### Q: Apakah saya harus install TinyFM?
**A:** Tidak wajib. Jika tidak install, DanBox akan menggunakan built-in editor seperti di v1.x.

### Q: Apa perbedaan TinyFM vs built-in editor?
**A:** 
- **TinyFM**: Full-featured, terminal integration, compression, bulk operations, syntax highlighting advanced
- **Built-in**: Simple, cepat, sudah cukup untuk edit config basic

### Q: File manager saya tidak terdeteksi?
**A:** Pastikan file manager sudah terinstall dan bisa diakses via LuCI. Cek dengan:
```bash
# TinyFM
ls -la /usr/lib/lua/luci/controller/tinyfm.lua

# FileBrowser
ls -la /usr/lib/lua/luci/controller/filebrowser.lua
```

### Q: Bagaimana cara memaksa menggunakan built-in editor?
**A:** Akses langsung via URL:
```
http://192.168.1.1/cgi-bin/luci/admin/services/danbox/editor_builtin
```

---

## 📝 What's Preserved

Semua fitur v1.2.1 tetap ada:
- ✅ Real-time Proxy Info
- ✅ 6 Dashboard UI Options
- ✅ Auto-Update Core & Dashboard
- ✅ Transparent Proxy (nftables)
- ✅ Service Control
- ✅ Multi-Log System
- ✅ Tab Order (App Config, Settings, Editor, Update Core, Log)

---

## 🆘 Support

- **Issues**: https://github.com/harimu63/danbox/issues
- **Discussions**: https://github.com/harimu63/danbox/discussions

---

**Upgrade Date:** 2026-09-22  
**From Version:** 1.x  
**To Version:** 2.0.0
