#!/bin/sh
# ==============================================================
#  SOAL 10 - Web dinamis PHP-FPM pada hostname core
#
#  Satu script untuk semua node. Cara pakai:
#      sh soal10.sh
#
#  Script membaca hostname dan menjalankan bagian yang sesuai:
#      oblada / molly  -> pasang dan jalankan Nginx + PHP-FPM
#      prab            -> tambah A record core di DNS
#      node lain       -> uji akses lewat hostname
#
#  Aplikasi:
#      /       -> halaman beranda
#      /profil -> halaman profil (rewrite ke profil.php)
#
#  URUTAN PENGERJAAN:
#      1. oblada : sh soal10.sh
#      2. molly  : sh soal10.sh
#      3. prab   : sh soal10.sh
#      4. tedd   : cek manual
#      5. klien  : sh soal10.sh
# ==============================================================


# ---------- PENGATURAN ----------
DOMAIN="iqbal.com"
HOST="core.$DOMAIN"

IP_OBLADA="192.235.1.6"
IP_MOLLY="192.235.1.7"

ZONE_FILE="/etc/bind/db.iqbal.com"

WEBROOT="/var/www/core"
# --------------------------------


# ==============================================================
#  BAGIAN A - WEB SERVER OBLADA / MOLLY
# ==============================================================
setup_webserver() {

    NODE=$(hostname)

    echo "=============================================================="
    echo " Menyiapkan Web Dinamis PHP-FPM pada $NODE"
    echo " Hostname : $HOST"
    echo "=============================================================="
    echo

    # ----------------------------------------------------------
    # 1. Instal Nginx, PHP, PHP-FPM, dan curl
    # ----------------------------------------------------------
    echo "[1/9] Instal Nginx, PHP-FPM, dan curl"

    apk update
    apk add nginx php84 php84-fpm curl

    # ----------------------------------------------------------
    # 2. Pastikan folder aplikasi tersedia
    # ----------------------------------------------------------
    echo "[2/9] Membuat folder aplikasi"

    mkdir -p "$WEBROOT"

    # ----------------------------------------------------------
    # 3. Buat halaman beranda
    # ----------------------------------------------------------
    echo "[3/9] Membuat index.php"

    cat > "$WEBROOT/index.php" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Core - Beranda</title>
</head>
<body>
    <h1>Selamat Datang di Core</h1>
    <p>Ini adalah halaman beranda aplikasi PHP-FPM.</p>
    <p><a href="/profil">Lihat Profil</a></p>
</body>
</html>
EOF

    # ----------------------------------------------------------
    # 4. Buat halaman profil
    # ----------------------------------------------------------
    echo "[4/9] Membuat profil.php"

    cat > "$WEBROOT/profil.php" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Profil</title>
</head>
<body>
    <h1>Profil</h1>
    <p>Nama: Iqbal Rizki Muhammad Fadhli</p>
    <p>Program Studi: Teknologi Informasi</p>
    <p>Institut Teknologi Sepuluh Nopember</p>
    <p><a href="/">Kembali ke Beranda</a></p>
</body>
</html>
EOF

    # ----------------------------------------------------------
    # 5. Pastikan PHP-FPM menggunakan port 9000
    # ----------------------------------------------------------
    echo "[5/9] Mengecek konfigurasi PHP-FPM"

    FPM_CONF="/etc/php84/php-fpm.d/www.conf"

    if [ -f "$FPM_CONF" ]; then
        sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' "$FPM_CONF"
    fi

    grep -n "listen =" "$FPM_CONF"

    # ----------------------------------------------------------
    # 6. Jalankan PHP-FPM jika belum berjalan
    # ----------------------------------------------------------
    echo "[6/9] Menjalankan PHP-FPM"

    if pgrep -f "php-fpm" > /dev/null 2>&1; then
        echo "      PHP-FPM sudah berjalan."
    else
        php-fpm84 -D
        sleep 1
    fi

    # ----------------------------------------------------------
    # 7. Buat konfigurasi Nginx untuk core.iqbal.com
    # ----------------------------------------------------------
    echo "[7/9] Membuat konfigurasi Nginx"

    mkdir -p /etc/nginx/http.d

    # Hapus konfigurasi core lama agar tidak duplikat
    rm -f /etc/nginx/http.d/core.conf

    cat > /etc/nginx/http.d/core.conf <<EOF
server {
    listen 80;
    server_name $HOST;

    root $WEBROOT;
    index index.php index.html;

    # URL bersih:
    # /profil -> /profil.php
    location = /profil {
        rewrite ^/profil$ /profil.php last;
    }

    # File dan folder biasa
    location / {
        try_files \$uri \$uri/ =404;
    }

    # PHP -> PHP-FPM
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass 127.0.0.1:9000;
    }

    access_log /var/log/nginx/core_access.log;
    error_log /var/log/nginx/core_error.log;
}
EOF

    # ----------------------------------------------------------
    # 8. Cek konfigurasi dan jalankan/reload Nginx
    # ----------------------------------------------------------
    echo "[8/9] Mengecek konfigurasi Nginx"

    nginx -t || {
        echo
        echo "SINTAKS NGINX ERROR."
        echo "Periksa konfigurasi sebelum melanjutkan."
        exit 1
    }

    echo
    echo "Konfigurasi Nginx valid."

    if pgrep nginx > /dev/null 2>&1; then
        echo "Nginx sedang berjalan -> reload"
        nginx -s reload
    else
        echo "Nginx belum berjalan -> start"
        nginx
    fi

    sleep 2

    # ----------------------------------------------------------
    # 9. Pengujian lokal menggunakan Host header
    # ----------------------------------------------------------
    echo
    echo "[9/9] Pengujian lokal"

    echo
    echo "--- Beranda ---"
    curl -s -H "Host: $HOST" http://127.0.0.1/ \
        | grep -E "Selamat Datang di Core|PHP-FPM" || true

    echo
    echo "--- /profil ---"
    curl -s -H "Host: $HOST" http://127.0.0.1/profil \
        | grep -E "<h1>Profil</h1>|Iqbal Rizki" || true

    echo
    echo "=============================================================="
    echo " Web server $NODE selesai."
    echo " Hostname : $HOST"
    echo " Webroot  : $WEBROOT"
    echo
    echo " Uji berikutnya:"
    echo "     curl http://$HOST/"
    echo "     curl http://$HOST/profil"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN B - DNS MASTER PRAB
# ==============================================================
setup_dns() {

    echo "=============================================================="
    echo " Menambahkan A record $HOST di DNS master"
    echo "=============================================================="
    echo

    # ----------------------------------------------------------
    # 1. Pastikan zone file tersedia
    # ----------------------------------------------------------
    if [ ! -f "$ZONE_FILE" ]; then
        echo "ERROR: Zone file tidak ditemukan:"
        echo "$ZONE_FILE"
        exit 1
    fi

    # ----------------------------------------------------------
    # 2. Tambahkan A record core
    # ----------------------------------------------------------
    echo "[1/4] Menambahkan A record core"

    [ -n "$(tail -c1 "$ZONE_FILE")" ] && echo >> "$ZONE_FILE"

    if grep -qE "^core[[:space:]]" "$ZONE_FILE"; then
        echo "      Record core sudah ada."
    else
        echo "core    IN    A    $IP_OBLADA" >> "$ZONE_FILE"
        echo "core    IN    A    $IP_MOLLY"  >> "$ZONE_FILE"

        echo "      Record ditambahkan:"
        echo "      $IP_OBLADA"
        echo "      $IP_MOLLY"
    fi

    # ----------------------------------------------------------
    # 3. Naikkan serial SOA
    # ----------------------------------------------------------
    echo
    echo "[2/4] Menaikkan serial SOA"

    OLD=$(grep -i "serial" "$ZONE_FILE" \
        | grep -oE '[0-9]+' \
        | head -1)

    if [ -z "$OLD" ]; then
        echo "ERROR: Serial SOA tidak ditemukan."
        echo "Naikkan serial secara manual:"
        echo "    vi $ZONE_FILE"
        exit 1
    fi

    NEW=$((OLD + 1))

    sed -i "/[Ss]erial/ s/$OLD/$NEW/" "$ZONE_FILE"

    echo "      Serial: $OLD -> $NEW"

    # ----------------------------------------------------------
    # 4. Validasi dan reload DNS
    # ----------------------------------------------------------
    echo
    echo "[3/4] Mengecek zone"

    if command -v named-checkzone > /dev/null 2>&1; then

        named-checkzone "$DOMAIN" "$ZONE_FILE" || {
            echo "ERROR: Zone tidak valid."
            exit 1
        }

    fi

    echo
    echo "[4/4] Reload BIND"

    rndc reload 2>/dev/null || {
        service bind9 restart 2>/dev/null || {
            pkill named 2>/dev/null
            named -u bind
        }
    }

    sleep 2

    echo
    echo "=============================================================="
    echo " Verifikasi DNS"
    echo "=============================================================="

    dig @localhost "$HOST" +short

    echo
    echo "Harus terdapat:"
    echo "    $IP_OBLADA"
    echo "    $IP_MOLLY"

    echo
    echo "Selanjutnya cek dari tedd:"
    echo "    dig @localhost $HOST +short"
    echo
    echo "Pastikan kedua IP muncul."
}


# ==============================================================
#  BAGIAN C - PENGUJIAN KLIEN
# ==============================================================
test_client() {

    echo "=============================================================="
    echo " Pengujian Soal 10 dari client: $(hostname)"
    echo "=============================================================="
    echo

    # ----------------------------------------------------------
    # 1. Pastikan curl dan dig tersedia
    # ----------------------------------------------------------
    echo "[1/5] Memastikan tools tersedia"

    apk add curl bind-tools > /dev/null 2>&1

    # ----------------------------------------------------------
    # 2. Cek resolver
    # ----------------------------------------------------------
    echo
    echo "[2/5] Resolver"

    cat /etc/resolv.conf

    # ----------------------------------------------------------
    # 3. Cek DNS
    # ----------------------------------------------------------
    echo
    echo "[3/5] Resolusi DNS $HOST"

    dig "$HOST" +short

    # ----------------------------------------------------------
    # 4. Akses beranda melalui hostname
    # ----------------------------------------------------------
    echo
    echo "[4/5] Akses beranda melalui hostname"

    curl -s "http://$HOST/" \
        | grep -E "Selamat Datang di Core|PHP-FPM" || true

    # ----------------------------------------------------------
    # 5. Akses /profil melalui hostname
    # ----------------------------------------------------------
    echo
    echo "[5/5] Akses /profil melalui hostname"

    curl -s "http://$HOST/profil" \
        | grep -E "<h1>Profil</h1>|Iqbal Rizki" || true

    echo
    echo "=============================================================="
    echo " PENGUJIAN SELESAI"
    echo
    echo " URL beranda:"
    echo "     http://$HOST/"
    echo
    echo " URL profil bersih:"
    echo "     http://$HOST/profil"
    echo
    echo " Pastikan URL profil TIDAK menggunakan .php"
    echo "=============================================================="
}


# ==============================================================
#  PROGRAM UTAMA
# ==============================================================

case "$(hostname)" in

    oblada|molly)
        setup_webserver
        ;;

    prab)
        setup_dns
        ;;

    tedd)
        echo "=============================================================="
        echo " DNS SECONDARY - $(hostname)"
        echo "=============================================================="
        echo
        echo "Jalankan pengecekan manual:"
        echo
        echo "    dig @localhost $HOST +short"
        echo
        echo "Hasil harus menampilkan:"
        echo "    $IP_OBLADA"
        echo "    $IP_MOLLY"
        ;;

    alpha|beta|gamma|delta|epsilon|abbey|penny)
        test_client
        ;;

    *)
        echo "=============================================================="
        echo " Node: $(hostname)"
        echo "=============================================================="
        echo
        echo "Node tidak dikenali oleh script."
        echo
        echo "Gunakan script pada:"
        echo "    oblada -> Web Server"
        echo "    molly  -> Web Server"
        echo "    prab   -> DNS Master"
        echo "    tedd   -> DNS Secondary"
        echo "    alpha/beta/gamma/delta/epsilon/abbey/penny -> Client"
        ;;
esac
```
