# luci-app-danbox

LuCI web interface untuk menjalankan core [sing-box](https://github.com/SagerNet/sing-box) (SagerNet) langsung di OpenWrt — start/stop lewat Enable+Save&Apply, transparent proxy (nftables tproxy) otomatis, editor/file manager khusus folder config, log App/Core terpisah, dan menu Update Core yang mendeteksi arch+libc sendiri lalu download versi yang benar dari GitHub Releases.

## Fitur

### App Config (beranda)
- Status core: versi & Running/Not Running (auto-poll ringan tiap 3 detik).
- Kontrol service murni lewat checkbox **Enable** + tombol **Save & Apply** (centang → otomatis restart, uncentang → otomatis stop). Tombol RESTART dan RELOAD tetap tersedia untuk kontrol manual.
- Tombol **OPEN DASHBOARD** — buka `http://<ip-router>:<dashboard_port>/ui` (clash_api) di tab baru.
- Pengaturan lengkap: path binary, folder & nama file config, start delay, test-config sebelum start, dan parameter tproxy (port, fwmark, self_mark, routing table).
- Panel **Log (App)** — log tahapan service (start/stop/validasi/nftables), auto-refresh singkat (~12 detik) tiap kali Save & Apply/Restart/Reload lalu berhenti sendiri. Direset otomatis hanya saat service benar-benar di-start.

### Editor
File manager tabel (Name/Size/Modified/Perms/Actions) yang **di-sandbox** hanya ke dalam `config_dir` (default `/etc/sing-box`) — tidak bisa keluar folder itu. Bisa navigasi subfolder, buat file baru, Edit, Download, Delete.

### Log
Dua tab terpisah:
- **App Log** (`/var/log/danbox-app.log`) — pesan tahapan service dari init script.
- **Core Log** (`/var/log/danbox-core.log`) — output mentah proses `sing-box` sendiri (termasuk pesan `FATAL` kalau config salah). Kalau App Log bilang gagal, cek di sini untuk detail aslinya.

Keduanya direset otomatis hanya saat Start, dan tidak auto-refresh terus-menerus (refresh manual via tombol).

### Update Core
Download/update binary `sing-box` langsung dari GitHub Releases resmi, dengan logika **deterministik** (bukan coba-coba):
1. Deteksi arsitektur CPU (`uname -m`).
2. Deteksi libc sistem (musl vs glibc, via cek dynamic linker).
3. Hitung satu nama asset yang seharusnya cocok berdasarkan kombinasi arch+libc, lalu cari persis di daftar rilis GitHub.
4. Download, extract, **backup binary lama**, pasang binary baru dengan `chmod 755`.
5. **Verifikasi nyata** — benar-benar menjalankan binary baru (`sing-box version`) dan menangkap stderr asli. Kalau gagal (mismatch libc/arch dsb), **otomatis rollback** ke binary lama dan log alasannya jelas.

> **Catatan penting (sing-box issue [#4430](https://github.com/SagerNet/sing-box/issues/4430)):** sejak sing-box 1.13.0, asset *plain* (tanpa suffix) untuk `linux amd64/arm64/arm/386` membundel `libcronet.so` (fitur NaiveProxy) yang **dynamically-linked ke glibc** — gagal total dieksekusi di sistem musl-only seperti OpenWrt. Untuk arch itu, sing-box resmi menyediakan varian **`-musl`** (statis, tanpa dependency sistem) — lihat [dokumentasi resmi](https://sing-box.sagernet.org/configuration/outbound/naive). Script update ini otomatis memilih varian `-musl` kalau sistemnya musl (default OpenWrt), dan plain kalau glibc. Arch yang tidak punya varian `-musl` terpisah (mips/riscv64/dst) selalu pure-Go static sehingga plain sudah aman.

## Struktur
```
luci-app-danbox/
├── Makefile                          # definisi package OpenWrt (LUCI_PKGARCH:=all, tidak depend ke sing-box)
├── luasrc/
│   ├── controller/danbox.lua         # routing + semua endpoint JSON
│   └── view/danbox/
│       ├── status.htm                # tab "App Config"
│       ├── editor.htm                # tab "Editor" (file manager)
│       ├── log.htm                   # tab "Log" (App Log / Core Log)
│       └── update.htm                # tab "Update Core"
├── root/
│   ├── etc/init.d/danbox             # procd service script: start/stop, setup/teardown nftables tproxy
│   ├── etc/config/danbox             # default UCI config
│   └── usr/
│       ├── share/danbox/update-core.sh   # script download/update core (dipanggil dari controller)
│       └── share/rpcd/acl.d/luci-app-danbox.json
└── .github/workflows/build.yml       # CI build (single job, x86_64 SDK, karena LUCI_PKGARCH:=all)
```

## Log yang dipakai sistem
| File | Isi | Direset saat |
|---|---|---|
| `/var/log/danbox-app.log` | Tahapan service (start/stop, nftables) | Start |
| `/var/log/danbox-core.log` | Output mentah proses `sing-box` | Start |
| `/var/log/danbox-update.log` | Proses download/update core | Setiap kali tombol Update ditekan |

## UCI Config (`/etc/config/danbox`)
```
config danbox 'config'
	option enabled '0'
	option bin_path '/usr/bin/sing-box'
	option config_dir '/etc/sing-box'
	option config_file 'config.json'
	option start_delay '0'
	option test_config '1'
	option tproxy_port '9898'
	option fwmark '0x1'
	option self_mark '0xff'
	option rtable '100'
	option dashboard_port '9090'
```

## Cara pakai — dev/testing langsung di router (tanpa build .ipk)
```sh
cd /tmp
wget https://codeload.github.com/harimu63/danbox/tar.gz/refs/heads/main -O danbox.tar.gz
tar -xzf danbox.tar.gz
cd danbox-main

cp -r luasrc/* /usr/lib/lua/luci/
cp -r root/* /
chmod +x /etc/init.d/danbox
chmod +x /usr/share/danbox/update-core.sh
/etc/init.d/danbox enable

/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
rm -rf /tmp/danbox*
```
Buka **Services → DanBox**.

## Build resmi (.ipk) via GitHub Actions
Workflow `.github/workflows/build.yml` otomatis build setiap push ke `main` (atau manual lewat tab Actions → Run workflow). Karena `LUCI_PKGARCH:=all` (isinya cuma Lua/shell script, tanpa kode native), satu `.ipk` hasil build **universal** — bisa dipasang di router arsitektur apapun.

Hasil build diambil dari tab **Actions** → run yang sukses → bagian **Artifacts**. Extract, lalu:
```sh
scp luci-app-danbox_*.ipk root@192.168.1.1:/tmp/
ssh root@192.168.1.1
opkg install /tmp/luci-app-danbox_*.ipk
/etc/init.d/rpcd restart && /etc/init.d/uhttpd restart
```

**Penting:** commit paling tidak dua file ini dengan bit executable, atau `opkg install` akan gagal jalanin service/update dengan "Permission denied":
```sh
git update-index --chmod=+x root/etc/init.d/danbox
git update-index --chmod=+x root/usr/share/danbox/update-core.sh
```

## Catatan keamanan
- Editor di-sandbox hanya ke `config_dir` yang diset di App Config — tidak bisa jelajah ke luar folder itu.
- Permission diatur lewat rpcd ACL (`luci-app-danbox`), assign ke user/group yang boleh akses di **System → Users**.
- Update Core menyimpan backup binary lama (`sing-box.bak`) sampai verifikasi binary baru sukses, jadi kalau update gagal, sistem otomatis kembali ke binary yang terbukti jalan.

## Roadmap ide lanjutan
- Dropdown pemilih multi-profile config (mirip Nikki "Choose Profile").
- Syntax highlighting di editor (CodeMirror/Ace).
- Dashboard clash-api langsung ter-embed (bukan cuma tombol buka tab baru).
- Checksum/SHA256 verification setelah download core, sebelum dipasang.