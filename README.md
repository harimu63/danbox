# luci-app-danbox

LuCI web interface untuk menjalankan core [sing-box](https://github.com/SagerNet/sing-box) (SagerNet) langsung di OpenWrt — start/stop lewat Enable+Save&Apply, transparent proxy (nftables tproxy) otomatis, editor/file manager khusus folder config, log App/Core terpisah, dan menu Update Core yang mendeteksi arch+libc sendiri lalu download versi yang benar dari GitHub Releases.

Repo: **https://github.com/harimu63/danbox**
Rilis (`.ipk` siap pakai): **https://github.com/harimu63/danbox/releases**

## Fitur

### App Config (beranda)
- Status core: versi & Running/Not Running.
- Kontrol service lewat checkbox **Enable** + tombol **Save & Apply** (centang → otomatis nyala, uncentang → otomatis mati). Tombol RESTART dan RELOAD tersedia untuk kontrol manual.
- Tombol **OPEN DASHBOARD** — buka dashboard clash_api di tab baru.
- Pengaturan lengkap: path binary, folder & nama file config, start delay, test-config sebelum start, dan parameter tproxy (port, fwmark, self_mark, routing table).
- Panel Log (App) langsung di beranda.

### Editor
File manager (Name/Size/Modified/Perms/Actions) yang di-sandbox hanya ke dalam folder config sing-box — tidak bisa keluar dari folder itu. Bisa navigasi subfolder, buat file baru, Edit, Download, Delete.

### Log
Dua tab terpisah — **App Log** (tahapan service) dan **Core Log** (output mentah sing-box, termasuk error asli kalau config salah).

### Update Core
Download/update binary `sing-box` langsung dari GitHub Releases resmi SagerNet — deteksi arsitektur & libc (musl/glibc) otomatis, backup binary lama, dan verifikasi nyata sebelum dianggap berhasil.

---

## Instalasi

### Cara 1 — Install dari file `.ipk` release (direkomendasikan)
1. Buka **https://github.com/harimu63/danbox/releases**, download file `.ipk` paling baru ke laptop/HP kamu.
2. Kirim ke router:
   ```sh
   scp luci-app-danbox_*.ipk root@192.168.1.1:/tmp/
   ```
3. Install lewat SSH ke router:
   ```sh
   opkg install /tmp/luci-app-danbox_*.ipk
   /etc/init.d/rpcd restart
   /etc/init.d/uhttpd restart
   ```
4. Buka LuCI → **Services → DanBox**.

> Package ini `arch: all` (isinya Lua/shell script, bukan binary native), jadi `.ipk` yang sama bisa dipasang di router arsitektur apapun (arm64, mips, x86, dst).

### Cara 2 — Langsung dari source, tanpa `.ipk` (buat testing cepat)
Jalankan langsung di router lewat SSH:
```sh
cd /tmp
wget https://codeload.github.com/harimu63/danbox/tar.gz/refs/heads/main -O danbox.tar.gz
tar -xzf danbox.tar.gz
cd danbox-main

cp -r luasrc/* /usr/lib/lua/luci/
cp -r root/* /
chmod +x /etc/init.d/danbox
chmod +x /usr/share/danbox/update-core.sh

/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
rm -rf /tmp/danbox*
```

---

## Cara Penggunaan

1. **Siapkan binary sing-box.** Kalau belum ada, buka tab **Update Core** di LuCI → klik **Download / Update Sekarang**. Script otomatis deteksi arsitektur & libc router kamu, download versi yang kompatibel dari GitHub Releases SagerNet, extract, dan `chmod 755`.
2. **Siapkan file config.** Buka tab **Editor**, buat/upload `config.json` ke folder config (default `/etc/sing-box/`). Bisa juga taruh manual lewat `scp`/SSH kalau lebih nyaman.
3. **Atur App Config.** Buka tab **App Config**, cek/isi:
   - Binary Path & Config Directory/File (kalau tidak dipindah, biarkan default).
   - Parameter tproxy (TPROXY Port, fwmark, self_mark, Routing Table) — samakan dengan yang dipakai di `config.json` kamu (khususnya `inbounds.tproxy.listen_port` dan `route.default_mark`).
   - Dashboard Port (`clash_api`), kalau dipakai.
4. **Nyalakan.** Centang **Enable**, klik **Save & Apply**. DanBox akan: validasi config → jalankan sing-box → cek benar-benar hidup → baru pasang nftables tproxy + ip rule/route. Status "Running" dan info di panel Log (App) akan update otomatis.
5. **Pantau.** Kalau ada masalah, cek tab **Log**:
   - **App Log** → tahu di step mana prosesnya berhenti.
   - **Core Log** → lihat pesan error asli dari sing-box sendiri (mis. config salah, dependency outbound tidak ketemu, dst).
6. **Matikan.** Uncentang **Enable** → **Save & Apply**. Service berhenti dan nftables/ip rule/route otomatis dibersihkan.
7. **Update core kapan saja** lewat tab **Update Core** — proses akan otomatis stop service dulu kalau lagi jalan, ganti binary, lalu nyalain lagi.

---

## Cara Menghapus (Uninstall) di OpenWrt

### Kalau diinstall lewat `.ipk` / opkg
```sh
# matikan & disable dulu service-nya
/etc/init.d/danbox stop
/etc/init.d/danbox disable

# hapus package
opkg remove luci-app-danbox

/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

### Bersih-bersih sisa file yang tidak ikut kehapus otomatis
`opkg remove` menghapus file package, tapi **tidak** menghapus config UCI (`/etc/config/danbox`, biar setting kamu tidak hilang kalau install ulang), log, atau nftables rule yang lagi aktif. Kalau mau benar-benar bersih total:
```sh
# hapus rule jaringan yang mungkin masih terpasang
nft delete table inet danbox_tproxy 2>/dev/null
ip rule del fwmark 0x1 lookup 100 2>/dev/null
ip route flush table 100 2>/dev/null

# hapus config, log, dan file nftables sisa
rm -f /etc/config/danbox
rm -f /etc/danbox-tproxy.nft
rm -f /var/log/danbox-app.log /var/log/danbox-core.log /var/log/danbox-update.log
```
> Sesuaikan `fwmark`/`lookup table` di atas kalau kamu pernah mengubahnya dari default (`0x1` / `100`) di App Config.

### Kalau diinstall lewat metode manual (Cara 2 di atas, tanpa opkg)
```sh
/etc/init.d/danbox stop
/etc/init.d/danbox disable

rm -f /etc/init.d/danbox
rm -f /usr/lib/lua/luci/controller/danbox.lua
rm -rf /usr/lib/lua/luci/view/danbox
rm -rf /usr/share/danbox
rm -f /usr/share/rpcd/acl.d/luci-app-danbox.json

# lalu bersih-bersih sisa seperti di bagian atas (nftables, config, log)
```

Binary sing-box sendiri (`/usr/bin/sing-box` atau path custom kamu) **tidak ikut terhapus** oleh langkah manapun di atas — hapus manual kalau memang tidak dipakai lagi.

---

## Catatan penting

- Sejak sing-box 1.13.0, asset rilis *plain* untuk `linux amd64/arm64/arm/386` dynamically-linked ke **glibc** (gara-gara `libcronet.so` untuk NaiveProxy) dan gagal jalan di sistem musl-only seperti OpenWrt. Menu **Update Core** sudah otomatis memilih varian `-musl` untuk arch yang punya varian itu.
- Editor di-sandbox hanya ke `config_dir` yang diset di App Config.
- Permission LuCI diatur lewat rpcd ACL (`luci-app-danbox`) — assign ke user/group yang boleh akses di **System → Users** kalau perlu dibatasi.