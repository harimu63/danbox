# luci-app-danbox

LuCI web interface untuk menjalankan core [sing-box](https://github.com/SagerNet/sing-box) (SagerNet) langsung di OpenWrt — start/stop/restart, edit config, dan lihat log, mirip alur kerja Nikki/OpenClash tapi khusus core sing-box murni.

## Fitur
- **App Config**: status core (versi, running/not running), tombol Start / Stop / Restart / Reload, pengaturan path binary, folder config, nama file config, start delay, dan test-config sebelum start.
- **Editor**: file manager mini yang di-sandbox ke folder config sing-box (default `/etc/sing-box`) — bisa lihat isi folder, buka file, edit, dan simpan langsung dari browser.
- **Log**: tail log service (via `logread`), auto-refresh tiap 3 detik.

## Struktur
```
luci-app-danbox/
├── Makefile                          # definisi package OpenWrt
├── luasrc/
│   ├── controller/danbox.lua         # routing + semua endpoint JSON
│   └── view/danbox/
│       ├── status.htm                # tab "App Config"
│       ├── editor.htm                # tab "Editor"
│       └── log.htm                   # tab "Log"
├── root/
│   ├── etc/init.d/danbox             # procd service script (start/stop/restart)
│   ├── etc/config/danbox             # default UCI config
│   └── usr/share/rpcd/acl.d/...json  # ACL permission
└── .github/workflows/build.yml       # CI build pakai OpenWrt SDK
```

## Cara pakai (development di router)
```sh
scp -r luci-app-danbox root@192.168.1.1:/tmp/
ssh root@192.168.1.1
cd /tmp/luci-app-danbox
cp -r luasrc/* /usr/lib/lua/luci/
cp -r root/* /
chmod +x /etc/init.d/danbox
/etc/init.d/danbox enable
rm -rf /tmp/luci-luci-*  2>/dev/null
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```
Lalu buka **Services → DanBox** di LuCI.

## Build resmi (ipk) via SDK
Package ini sudah didaftarkan `LUCI_DEPENDS:=+sing-box`, jadi asumsinya feed `sing-box` sudah ada (paket resmi `sing-box` sudah masuk feed packages OpenWrt). Build:
```sh
git clone https://github.com/<username>/luci-app-danbox.git package/luci-app-danbox
make package/luci-app-danbox/compile V=s
```
Workflow GitHub Actions di `.github/workflows/build.yml` sudah otomatis build untuk `aarch64_generic` (mis. Amlogic B860H) dan `x86_64`.

## Catatan keamanan
- Editor dibatasi (path-sandboxed) hanya ke `config_dir` yang diset di App Config — tidak bisa jelajah ke luar folder itu.
- Permission diatur lewat rpcd ACL (`luci-app-danbox`), assign ke user/group yang boleh akses di **System → Users**.

## Roadmap ide lanjutan
- Tambah dropdown pemilih multi-profile config (mirip Nikki "Choose Profile").
- Tambah syntax highlighting di editor (CodeMirror/Ace).
- Tambah dashboard clash-api (kalau config sing-box mengaktifkan `experimental.clash_api`).
- Tambah validasi JSON on-the-fly sebelum save.
