#!/bin/sh
# ==============================================================
# SOAL 9
# Jalankan layanan web statis pada hostname di node area vault
# (menggunakan apache). Buka folder direktori /arsip/ dan aktifkan
# fitur autoindex (directory listing) pada konfigurasi Apache
# sehingga seluruh daftar file di dalamnya dapat ditelusuri
# langsung dari browser. Akses pengujian harus dilakukan melalui
# hostname, bukan IP address.
# ==============================================================
#
# DATA:
#   Domain   : iqbal.com
#   obladi   : 192.235.1.4   (Alpine, tanpa OpenRC)
#   desmond  : 192.235.1.5   (Alpine, tanpa OpenRC)
#   tedd     : 192.235.1.3
#
# CARA PAKAI:
#   File ini berisi 5 langkah untuk node yang BERBEDA.
#   Salin hanya bagian untuk node yang sedang kamu buka,
#   jangan menjalankan seluruh file di satu node.
#
#   Langkah 1 -> obladi
#   Langkah 2 -> desmond (sama persis dengan langkah 1)
#   Langkah 3 -> prab
#   Langkah 4 -> tedd
#   Langkah 5 -> klien (alpha / beta / gamma)
# ==============================================================


# ==============================================================
# LANGKAH 1 dan 2 - JALANKAN DI: obladi, LALU DI: desmond
# ==============================================================

# 1. Instal Apache dan curl
apk update
apk add apache2 curl

# 2. Buat folder /arsip dan isi contoh
mkdir -p /var/www/arsip/dokumen
echo "file satu"   > /var/www/arsip/file1.txt
echo "file dua"    > /var/www/arsip/file2.txt
echo "isi dokumen" > /var/www/arsip/dokumen/catatan.txt
chmod -R 755 /var/www/arsip

# 3. Konfigurasi Apache dengan autoindex (Options +Indexes)
cat <<'EOF' > /etc/apache2/conf.d/vault.conf
<VirtualHost *:80>
    ServerName vault.iqbal.com
    DocumentRoot /var/www/localhost/htdocs

    Alias /arsip /var/www/arsip
    <Directory /var/www/arsip>
        Options +Indexes
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

# 4. Pastikan modul aktif dan folder conf.d dibaca
sed -i 's/^#\(LoadModule alias_module\)/\1/' /etc/apache2/httpd.conf
sed -i 's/^#\(LoadModule autoindex_module\)/\1/' /etc/apache2/httpd.conf
grep -qE 'conf\.d' /etc/apache2/httpd.conf || \
    echo "IncludeOptional /etc/apache2/conf.d/*.conf" >> /etc/apache2/httpd.conf
mkdir -p /run/apache2

# 5. Cek sintaks (harus "Syntax OK"), lalu jalankan Apache
httpd -t
httpd -k start
# Kalau Apache sudah berjalan sebelumnya, pakai: httpd -k restart

# 6. Cek cepat dari node ini sendiri (harus muncul "Index of /arsip")
curl -H "Host: vault.iqbal.com" http://localhost/arsip/


# ==============================================================
# LANGKAH 3 - JALANKAN DI: prab
# (setelah obladi dan desmond selesai)
# ==============================================================

# 1. Tambah dua A record vault (obladi dan desmond)
cat <<'EOF' >> /etc/bind/db.iqbal.com
vault   IN   A   192.235.1.4
vault   IN   A   192.235.1.5
EOF

# 2. Naikkan serial SOA (wajib, supaya tedd menyalin perubahan)
#    Buka file, cari angka di baris "; Serial", naikkan +1
vi /etc/bind/db.iqbal.com

# 3. Reload zona
rndc reload
# Kalau rndc gagal: pkill named ; named -u bind

# 4. Verifikasi (harus muncul 192.235.1.4 dan 192.235.1.5)
dig @localhost vault.iqbal.com +short


# ==============================================================
# LANGKAH 4 - JALANKAN DI: tedd
# ==============================================================

# Dua IP harus muncul, dan serial SOA harus sama dengan prab
dig @localhost vault.iqbal.com +short
dig @localhost iqbal.com SOA +short


# ==============================================================
# LANGKAH 5 - JALANKAN DI: klien (alpha / beta / gamma)
# PENGUJIAN AKHIR - harus lewat HOSTNAME, bukan IP
# ==============================================================

apk add curl bind-tools

# resolver harus: IP prab, 192.235.1.3 (tedd), 192.168.122.1
cat /etc/resolv.conf

# hostname harus ter-resolve ke dua IP
dig vault.iqbal.com +short

# harus muncul HTML "Index of /arsip" berisi file1.txt, file2.txt, dokumen/
curl http://vault.iqbal.com/arsip/