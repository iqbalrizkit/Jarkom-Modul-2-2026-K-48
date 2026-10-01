#!/bin/sh
# ==============================================================
#  SOAL - Redirect ke nama kanonik pada Penny dan Abbey
#
#  Aturan:
#      Penny : akses lewat IP atau penny.iqbal.com
#              -> 301 (permanen) ke http://www.iqbal.com/
#      Abbey : akses lewat IP atau abbey.iqbal.com
#              -> 302 (sementara) ke http://static.iqbal.com/
#
#  Nama kanonik tetap diteruskan ke backend:
#      www.iqbal.com    -> Penny (Apache) -> obladi, desmond
#      static.iqbal.com -> Abbey (Nginx)  -> oblada, molly
#  dengan header Host dan X-Real-IP.
#
#  Satu script untuk semua node. Cara pakai:
#      sh soal_redirect_kanonik.sh
#
#  Script membaca hostname dan menjalankan bagian yang sesuai:
#      prab             -> jalankan BIND, pastikan record DNS lengkap
#      tedd             -> jalankan BIND (slave)
#      obladi / desmond -> backend VAULT (web statis, Nginx)
#      oblada / molly   -> backend CORE  (Nginx + PHP-FPM 8.4)
#      penny            -> Apache: redirect 301 + reverse proxy
#      abbey            -> Nginx : redirect 302 + reverse proxy
#      alpha..epsilon   -> uji redirect, distribusi, dan header
#
#  Perintah tambahan (di node mana pun):
#      sh soal_redirect_kanonik.sh status   (cek layanan yang berjalan)
#      sh soal_redirect_kanonik.sh bukti    (log header di backend)
#
#  URUTAN PENGERJAAN:
#      0. rootkit : iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#      1. prab    : sh soal_redirect_kanonik.sh
#      2. tedd    : sh soal_redirect_kanonik.sh
#      3. obladi  : sh soal_redirect_kanonik.sh
#      4. desmond : sh soal_redirect_kanonik.sh
#      5. oblada  : sh soal_redirect_kanonik.sh
#      6. molly   : sh soal_redirect_kanonik.sh
#      7. penny   : sh soal_redirect_kanonik.sh
#      8. abbey   : sh soal_redirect_kanonik.sh
#      9. klien   : sh soal_redirect_kanonik.sh   (mis. alpha)
#     10. backend : sh soal_redirect_kanonik.sh bukti
#
#  PENTING: jangan jalankan soal_reverse_proxy.sh (script lama)
#  di penny dan abbey. Script lama menimpa konfigurasi redirect.
# ==============================================================


# ---------- PENGATURAN ----------
DOMAIN="iqbal.com"

WWW="www.$DOMAIN"
STATIC="static.$DOMAIN"
PENNY_HOST="penny.$DOMAIN"
ABBEY_HOST="abbey.$DOMAIN"

IP_PRAB="192.235.1.2"
IP_TEDD="192.235.1.3"
IP_PENNY="192.235.3.2"
IP_ABBEY="192.235.2.2"
IP_OBLADI="192.235.1.4"
IP_DESMOND="192.235.1.5"
IP_OBLADA="192.235.1.6"
IP_MOLLY="192.235.1.7"

ZONE_FILE="/etc/bind/db.$DOMAIN"
# --------------------------------


# ==============================================================
#  FUNGSI BANTU
# ==============================================================

# Isi resolver kalau kosong (terjadi setelah node restart).
# Urutan akhir: prab -> tedd -> 192.168.122.1
ensure_resolver() {
    if ! grep -q '^nameserver' /etc/resolv.conf 2>/dev/null; then
        echo "      resolv.conf kosong -> diisi ulang"
        cat > /etc/resolv.conf <<EOF
nameserver $IP_PRAB
nameserver $IP_TEDD
nameserver 192.168.122.1
EOF
    fi
}

# Pastikan apk bisa mengunduh paket. Jika DNS internal belum siap,
# sementara taruh 192.168.122.1 di baris pertama resolver.
RESOLV_BACKUP=""

ensure_net() {
    ensure_resolver

    if apk update > /dev/null 2>&1; then
        return 0
    fi

    echo "      apk update gagal, mencoba resolver 192.168.122.1 sementara"
    RESOLV_BACKUP="/tmp/resolv.conf.bak"
    cp /etc/resolv.conf "$RESOLV_BACKUP"
    {
        echo "nameserver 192.168.122.1"
        cat "$RESOLV_BACKUP"
    } > /etc/resolv.conf

    apk update || {
        echo "ERROR: apk update tetap gagal. Cek NAT di rootkit (iptables MASQUERADE)."
        restore_net
        exit 1
    }
}

restore_net() {
    if [ -n "$RESOLV_BACKUP" ] && [ -f "$RESOLV_BACKUP" ]; then
        cp "$RESOLV_BACKUP" /etc/resolv.conf
        echo "      Resolver dikembalikan seperti semula."
    fi
}

# Jalankan nginx, atau reload kalau sudah berjalan
start_nginx() {
    mkdir -p /run/nginx

    nginx -t || {
        echo
        echo "SINTAKS NGINX ERROR. Periksa konfigurasi sebelum melanjutkan."
        exit 1
    }

    if pgrep nginx > /dev/null 2>&1; then
        echo "      Nginx sedang berjalan -> reload"
        nginx -s reload
    else
        echo "      Nginx belum berjalan -> start"
        nginx
    fi
    sleep 1

    pgrep nginx > /dev/null 2>&1 || {
        echo "ERROR: Nginx tidak berjalan. Lihat /var/log/nginx/error.log"
        exit 1
    }
}

# Jalankan BIND (user di Alpine bernama 'named', bukan 'bind')
start_named() {
    named-checkconf || {
        echo "ERROR: named.conf tidak valid."
        exit 1
    }

    if pgrep named > /dev/null 2>&1; then
        echo "      BIND sudah berjalan."
    else
        named -u named
        sleep 2
    fi

    pgrep named > /dev/null 2>&1 || {
        echo "ERROR: BIND tidak mau berjalan. Coba: named -g -u named"
        exit 1
    }
}


# ==============================================================
#  BAGIAN A - DNS: PRAB (MASTER)
# ==============================================================
setup_prab() {

    echo "=============================================================="
    echo " Menyiapkan DNS master PRAB"
    echo "=============================================================="
    echo

    if [ ! -f "$ZONE_FILE" ]; then
        echo "ERROR: zone file tidak ditemukan: $ZONE_FILE"
        exit 1
    fi

    echo "[1/3] Memastikan record yang dibutuhkan ada di zone"

    # Tambah newline di akhir file kalau belum ada
    [ -n "$(tail -c1 "$ZONE_FILE")" ] && echo >> "$ZONE_FILE"

    CHANGED=0

    add_record() {
        # $1 = nama, $2 = baris record lengkap
        if grep -qE "^$1[[:space:]]" "$ZONE_FILE"; then
            echo "      $1 sudah ada."
        else
            echo "$2" >> "$ZONE_FILE"
            echo "      $1 ditambahkan."
            CHANGED=1
        fi
    }

    add_record "penny"  "penny   IN  A       $IP_PENNY"
    add_record "abbey"  "abbey   IN  A       $IP_ABBEY"
    add_record "www"    "www     IN  CNAME   penny.$DOMAIN."
    add_record "static" "static  IN  CNAME   abbey.$DOMAIN."

    if [ "$CHANGED" = "1" ]; then
        echo
        echo "[2/3] Menaikkan serial SOA (angka pertama setelah baris SOA)"

        LN=$(awk '/SOA/{f=1;next} f && /^[[:space:]]*[0-9]+/{print NR; exit}' "$ZONE_FILE")
        if [ -z "$LN" ]; then
            echo "ERROR: baris serial tidak ditemukan. Naikkan manual di $ZONE_FILE"
            exit 1
        fi
        OLD=$(sed -n "${LN}p" "$ZONE_FILE" | grep -oE '[0-9]+' | head -1)
        NEW=$((OLD + 1))
        sed -i "${LN}s/$OLD/$NEW/" "$ZONE_FILE"
        echo "      Serial: $OLD -> $NEW"

        if command -v named-checkzone > /dev/null 2>&1; then
            named-checkzone "$DOMAIN" "$ZONE_FILE" || {
                echo "ERROR: zone tidak valid."
                exit 1
            }
        fi
    else
        echo
        echo "[2/3] Zone tidak berubah, serial tidak perlu dinaikkan"
    fi

    echo
    echo "[3/3] Menjalankan / me-reload BIND"
    start_named
    [ "$CHANGED" = "1" ] && rndc reload 2>/dev/null

    echo
    echo "--- Verifikasi ---"
    for N in www static penny abbey; do
        echo "$N.$DOMAIN :"
        dig @localhost "$N.$DOMAIN" +short 2>/dev/null | grep -v '^;;'
    done

    echo
    echo "=============================================================="
    echo " Harus terlihat:"
    echo "     www    -> penny.$DOMAIN. lalu $IP_PENNY"
    echo "     static -> abbey.$DOMAIN. lalu $IP_ABBEY"
    echo "     penny  -> $IP_PENNY"
    echo "     abbey  -> $IP_ABBEY"
    echo " Lanjut: jalankan script ini di tedd."
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN B - DNS: TEDD (SLAVE)
# ==============================================================
setup_tedd() {

    echo "=============================================================="
    echo " Menyiapkan DNS slave TEDD"
    echo "=============================================================="
    echo

    echo "[1/2] Menjalankan BIND"
    start_named

    echo "[2/2] Memaksa transfer zone dari prab"
    rndc retransfer "$DOMAIN" 2>/dev/null
    sleep 2

    echo
    echo "--- Verifikasi ---"
    for N in www static; do
        echo "$N.$DOMAIN :"
        dig @localhost "$N.$DOMAIN" +short 2>/dev/null | grep -v '^;;'
    done

    echo
    echo "=============================================================="
    echo " Hasil harus sama dengan prab."
    echo " Kalau kosong, tunggu beberapa detik lalu ulangi:"
    echo "     dig @localhost $WWW +short"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN C - BACKEND VAULT (OBLADI / DESMOND)
# ==============================================================
setup_vault() {

    NODE=$(hostname)

    echo "=============================================================="
    echo " Menyiapkan backend VAULT (web statis) pada $NODE"
    echo "=============================================================="
    echo

    echo "[1/4] Instal Nginx"
    ensure_net
    apk add nginx
    restore_net

    echo "[2/4] Membuat halaman statis"
    mkdir -p /var/www/vault

    cat > /var/www/vault/index.html <<EOF
<!doctype html>
<html>
<head><title>Vault - $NODE</title></head>
<body>
    <h1>Area Vault - $NODE</h1>
    <p>Repositori web statis.</p>
</body>
</html>
EOF

    echo "[3/4] Membuat konfigurasi Nginx (log mencatat Host dan X-Real-IP)"
    rm -f /etc/nginx/http.d/default.conf
    rm -f /etc/nginx/http.d/vault.conf

    cat > /etc/nginx/http.d/vault.conf <<'EOF'
log_format vault '$remote_addr - [$time_local] "$request" $status host=$http_host realip=$http_x_real_ip';

server {
    listen 80 default_server;
    server_name _;

    root /var/www/vault;
    index index.html;

    access_log /var/log/nginx/vault_access.log vault;
}
EOF

    # Pastikan tanda $ tidak hilang saat script disalin
    grep -q 'realip=\$http_x_real_ip' /etc/nginx/http.d/vault.conf || {
        echo "ERROR: baris log_format rusak (tanda \$ hilang). Salin ulang script."
        exit 1
    }

    echo "[4/4] Menjalankan Nginx"
    start_nginx

    echo
    echo "--- Tes lokal ---"
    wget -qO- http://localhost | grep "<h1>"

    echo
    echo "=============================================================="
    echo " Backend $NODE selesai."
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN D - BACKEND CORE (OBLADA / MOLLY)
# ==============================================================
setup_core() {

    NODE=$(hostname)

    echo "=============================================================="
    echo " Menyiapkan backend CORE (web dinamis) pada $NODE"
    echo "=============================================================="
    echo

    echo "[1/6] Instal Nginx dan PHP-FPM 8.4"
    ensure_net
    apk add nginx php84 php84-fpm
    restore_net

    echo "[2/6] Membuat halaman PHP (menampilkan bukti header)"
    mkdir -p /var/www/core

    cat > /var/www/core/index.php <<'EOF'
<?php
echo "<h1>Area Core - " . gethostname() . "</h1>";
echo "<p>PHP: " . PHP_VERSION . "</p>";
echo "<p>Host: " . ($_SERVER['HTTP_HOST'] ?? '-') . "</p>";
echo "<p>X-Real-IP: " . ($_SERVER['HTTP_X_REAL_IP'] ?? '-') . "</p>";
echo "<p>REMOTE_ADDR: " . $_SERVER['REMOTE_ADDR'] . "</p>";
EOF

    echo "[3/6] Mengecek konfigurasi PHP-FPM (port 9000)"
    FPM_CONF="/etc/php84/php-fpm.d/www.conf"
    if [ -f "$FPM_CONF" ]; then
        sed -i 's/^listen = .*/listen = 127.0.0.1:9000/' "$FPM_CONF"
    fi
    grep -n "^listen =" "$FPM_CONF"

    echo "[4/6] Menjalankan PHP-FPM"
    if pgrep -f "php-fpm" > /dev/null 2>&1; then
        echo "      PHP-FPM sudah berjalan."
    else
        php-fpm84 -D
        sleep 1
    fi

    echo "[5/6] Membuat konfigurasi Nginx (log mencatat Host dan X-Real-IP)"
    rm -f /etc/nginx/http.d/default.conf
    rm -f /etc/nginx/http.d/core.conf

    cat > /etc/nginx/http.d/core.conf <<'EOF'
log_format core '$remote_addr - [$time_local] "$request" $status host=$http_host realip=$http_x_real_ip';

server {
    listen 80 default_server;
    server_name _;

    root /var/www/core;
    index index.php;

    access_log /var/log/nginx/core_access.log core;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi.conf;
        fastcgi_pass 127.0.0.1:9000;
    }
}
EOF

    grep -q 'realip=\$http_x_real_ip' /etc/nginx/http.d/core.conf || {
        echo "ERROR: baris log_format rusak (tanda \$ hilang). Salin ulang script."
        exit 1
    }

    echo "[6/6] Menjalankan Nginx"
    start_nginx

    echo
    echo "--- Tes lokal ---"
    wget -qO- http://localhost | sed 's/<\/p>/\n/g; s/<[^>]*>//g'

    echo
    echo "=============================================================="
    echo " Backend $NODE selesai."
    echo " (X-Real-IP bernilai - karena tes lokal tanpa proxy; itu wajar)"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN E - PENNY (APACHE): 301 + REVERSE PROXY KE VAULT
# ==============================================================
setup_penny() {

    echo "=============================================================="
    echo " Menyiapkan PENNY (Apache)"
    echo "   IP / $PENNY_HOST  -> 301 ke http://$WWW/"
    echo "   $WWW -> proxy ke obladi ($IP_OBLADI) dan desmond ($IP_DESMOND)"
    echo "=============================================================="
    echo

    echo "[1/5] Instal Apache, modul proxy, dan curl"
    ensure_net
    apk add apache2 apache2-proxy curl
    restore_net

    echo "[2/5] Mengaktifkan modul headers dan slotmem_shm"
    sed -i -E 's/^#(LoadModule (headers|slotmem_shm)_module)/\1/' /etc/apache2/httpd.conf

    echo "[3/5] Membuat konfigurasi (VirtualHost pertama = default = redirect)"
    rm -f /etc/apache2/conf.d/penny.conf

    cat > /etc/apache2/conf.d/penny.conf <<EOF
ServerName $PENNY_HOST

# VirtualHost pertama = default.
# Akses lewat IP, $PENNY_HOST, atau nama lain -> 301 ke nama kanonik
<VirtualHost *:80>
    ServerName $PENNY_HOST
    ServerAlias $IP_PENNY
    Redirect permanent / http://$WWW/
</VirtualHost>

# Nama kanonik: diteruskan ke area vault
<VirtualHost *:80>
    ServerName $WWW

    # Teruskan header Host asli dari klien
    ProxyPreserveHost On

    # Teruskan IP asli klien sebagai X-Real-IP
    RequestHeader set X-Real-IP "expr=%{REMOTE_ADDR}"

    <Proxy "balancer://vault">
        BalancerMember http://$IP_OBLADI
        BalancerMember http://$IP_DESMOND
        ProxySet lbmethod=byrequests
    </Proxy>

    ProxyPass "/" "balancer://vault/"
    ProxyPassReverse "/" "balancer://vault/"
</VirtualHost>
EOF

    grep -q 'Redirect permanent' /etc/apache2/conf.d/penny.conf || {
        echo "ERROR: konfigurasi penny tidak tertulis dengan benar."
        exit 1
    }

    echo "[4/5] Mengecek konfigurasi Apache"
    httpd -t 2>&1 | grep -v "already loaded"
    httpd -t > /dev/null 2>&1 || {
        echo
        echo "SINTAKS APACHE ERROR. Periksa konfigurasi sebelum melanjutkan."
        httpd -t
        exit 1
    }

    echo "[5/5] Menjalankan Apache"
    if pgrep httpd > /dev/null 2>&1; then
        echo "      Apache sedang berjalan -> restart"
        httpd -k restart
    else
        echo "      Apache belum berjalan -> start"
        httpd
    fi
    sleep 2

    pgrep httpd > /dev/null 2>&1 || {
        echo "ERROR: Apache tidak berjalan. Lihat /var/www/logs/error.log"
        exit 1
    }

    echo
    echo "--- Tes lokal: akses tanpa nama kanonik (harus 301) ---"
    curl -sI http://localhost | grep -E "^HTTP|^Location"

    echo
    echo "--- Tes lokal: Host kanonik (harus 200 dari backend) ---"
    curl -sI -H "Host: $WWW" http://localhost | grep -E "^HTTP|^Server"

    echo
    echo "=============================================================="
    echo " Penny selesai."
    echo " Uji dari klien: sh soal_redirect_kanonik.sh"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN F - ABBEY (NGINX): 302 + REVERSE PROXY KE CORE
# ==============================================================
setup_abbey() {

    echo "=============================================================="
    echo " Menyiapkan ABBEY (Nginx)"
    echo "   IP / $ABBEY_HOST -> 302 ke http://$STATIC/"
    echo "   $STATIC -> proxy ke oblada ($IP_OBLADA) dan molly ($IP_MOLLY)"
    echo "=============================================================="
    echo

    echo "[1/4] Instal Nginx dan curl"
    ensure_net
    apk add nginx curl
    restore_net

    echo "[2/4] Membuat konfigurasi (server default = redirect)"
    rm -f /etc/nginx/http.d/default.conf
    rm -f /etc/nginx/http.d/abbey.conf

    # Heredoc berkutip: tanda $ milik Nginx tidak diubah shell.
    # Penanda @...@ diganti dengan nilai sebenarnya oleh sed.
    cat > /etc/nginx/http.d/abbey.conf <<'EOF'
upstream core {
    zone core 64k;
    server @IP_OBLADA@;
    server @IP_MOLLY@;
}

# Default: akses lewat IP, @ABBEY_HOST@, atau nama lain -> 302
server {
    listen 80 default_server;
    server_name @ABBEY_HOST@ @IP_ABBEY@ _;

    return 302 http://@STATIC@$request_uri;
}

# Nama kanonik: diteruskan ke area core
server {
    listen 80;
    server_name @STATIC@;

    location / {
        proxy_pass http://core;

        # Teruskan Host dan IP asli klien
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

    sed -i \
        -e "s/@IP_OBLADA@/$IP_OBLADA/g" \
        -e "s/@IP_MOLLY@/$IP_MOLLY/g" \
        -e "s/@IP_ABBEY@/$IP_ABBEY/g" \
        -e "s/@ABBEY_HOST@/$ABBEY_HOST/g" \
        -e "s/@STATIC@/$STATIC/g" \
        /etc/nginx/http.d/abbey.conf

    # Pastikan tanda $ tidak hilang saat script disalin
    grep -q 'proxy_set_header X-Real-IP \$remote_addr' /etc/nginx/http.d/abbey.conf && \
    grep -q 'return 302 http://.*\$request_uri' /etc/nginx/http.d/abbey.conf || {
        echo "ERROR: konfigurasi rusak (tanda \$ hilang). Salin ulang script."
        exit 1
    }

    echo "[3/4] Mengecek dan menjalankan Nginx"
    start_nginx

    echo "[4/4] Tes lokal"
    echo
    echo "--- Akses tanpa nama kanonik (harus 302) ---"
    curl -sI http://localhost | grep -E "^HTTP|^Location"

    echo
    echo "--- Host kanonik, 4 request (harus bergantian oblada/molly) ---"
    for i in 1 2 3 4; do
        curl -s -H "Host: $STATIC" http://localhost | grep -o "Area Core - [a-z]*"
    done

    echo
    echo "=============================================================="
    echo " Abbey selesai."
    echo " Uji dari klien: sh soal_redirect_kanonik.sh"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN G - PENGUJIAN KLIEN
# ==============================================================
test_client() {

    MYIP=$(ip -4 addr show eth0 | grep -o 'inet [0-9.]*' | cut -d' ' -f2)

    echo "=============================================================="
    echo " Pengujian dari klien: $(hostname)  (IP $MYIP)"
    echo "=============================================================="
    echo

    echo "[1/6] Memastikan tools tersedia"
    ensure_resolver
    apk add curl bind-tools > /dev/null 2>&1

    echo
    echo "[2/6] DNS internal (harus IP kita, bukan IP publik)"
    for N in $WWW $STATIC $PENNY_HOST $ABBEY_HOST; do
        echo "$N :"
        dig "$N" +short 2>/dev/null | grep -v '^;;'
    done

    echo
    echo "[3/6] Penny -> harus 301 ke http://$WWW/"
    echo "--- via IP ---"
    curl -sI "http://$IP_PENNY" | grep -E "^HTTP|^Location"
    echo "--- via $PENNY_HOST ---"
    curl -sI "http://$PENNY_HOST" | grep -E "^HTTP|^Location"

    echo
    echo "[4/6] Abbey -> harus 302 ke http://$STATIC/"
    echo "--- via IP ---"
    curl -sI "http://$IP_ABBEY" | grep -E "^HTTP|^Location"
    echo "--- via $ABBEY_HOST ---"
    curl -sI "http://$ABBEY_HOST" | grep -E "^HTTP|^Location"

    echo
    echo "[5/6] Nama kanonik -> distribusi harus bergantian"
    echo "--- $WWW (obladi/desmond) ---"
    for i in 1 2 3 4; do
        curl -s "http://$WWW" | grep -o "Area Vault - [a-z]*"
    done
    echo "--- $STATIC (oblada/molly) ---"
    for i in 1 2 3 4; do
        curl -s "http://$STATIC" | grep -o "Area Core - [a-z]*"
    done

    echo
    echo "[6/6] Header yang diterima backend core lewat $STATIC"
    HDR=$(curl -s "http://$STATIC" | sed 's/<\/p>/\n/g; s/<[^>]*>//g' \
        | grep -E "Host|X-Real-IP|REMOTE_ADDR")
    echo "$HDR"

    echo
    echo "$HDR" | grep -q "X-Real-IP: $MYIP" \
        && echo "      X-Real-IP = IP klien ($MYIP)  -> OK" \
        || echo "      X-Real-IP TIDAK sama dengan IP klien ($MYIP)  -> PERIKSA"
    echo "$HDR" | grep -q "Host: $STATIC" \
        && echo "      Host      = $STATIC  -> OK" \
        || echo "      Host TIDAK sama dengan $STATIC  -> PERIKSA"

    echo
    echo "=============================================================="
    echo " PENGUJIAN SELESAI"
    echo
    echo " Bukti header di area VAULT ada di log backend:"
    echo "     obladi / desmond : sh soal_redirect_kanonik.sh bukti"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN H - BUKTI DI LOG BACKEND
# ==============================================================
show_evidence() {

    case "$(hostname)" in
        obladi|desmond) LOG="/var/log/nginx/vault_access.log" ;;
        oblada|molly)   LOG="/var/log/nginx/core_access.log"  ;;
        *)
            echo "Perintah 'bukti' dijalankan di obladi/desmond/oblada/molly."
            exit 1
            ;;
    esac

    echo "=============================================================="
    echo " Bukti header di $(hostname)  ($LOG)"
    echo "=============================================================="
    echo
    echo "Baris dari klien (realip terisi, bukan localhost):"
    grep -v "realip=-" "$LOG" | grep -v "realip=127.0.0.1" | tail -n 5
    echo
    echo "Yang harus terlihat:"
    echo "    alamat paling kiri = IP gerbang (penny/abbey)"
    echo "    host=   = nama kanonik ($WWW atau $STATIC)"
    echo "    realip= = IP klien asli (mis. 192.235.4.2 untuk alpha)"
}


# ==============================================================
#  BAGIAN I - STATUS LAYANAN
# ==============================================================
show_status() {

    echo "=============================================================="
    echo " Status layanan di $(hostname)"
    echo "=============================================================="

    echo "IP        : $(ip -4 addr show eth0 | grep -o 'inet [0-9.]*' | cut -d' ' -f2)"
    echo "Resolver  : $(grep '^nameserver' /etc/resolv.conf 2>/dev/null | cut -d' ' -f2 | tr '\n' ' ')"

    for P in named nginx httpd php-fpm; do
        if pgrep -f "$P" > /dev/null 2>&1; then
            echo "$P : BERJALAN"
        else
            echo "$P : mati / tidak terpasang"
        fi
    done
}


# ==============================================================
#  PROGRAM UTAMA
# ==============================================================

case "$1" in
    bukti)  show_evidence; exit 0 ;;
    status) show_status;   exit 0 ;;
esac

case "$(hostname)" in

    prab)
        setup_prab
        ;;

    tedd)
        setup_tedd
        ;;

    obladi|desmond)
        setup_vault
        ;;

    oblada|molly)
        setup_core
        ;;

    penny)
        setup_penny
        ;;

    abbey)
        setup_abbey
        ;;

    alpha|beta|gamma|delta|epsilon)
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
        echo "    prab            -> DNS Master"
        echo "    tedd            -> DNS Slave"
        echo "    obladi, desmond -> Backend Vault"
        echo "    oblada, molly   -> Backend Core"
        echo "    penny           -> Apache (301 + proxy)"
        echo "    abbey           -> Nginx  (302 + proxy)"
        echo "    alpha..epsilon  -> Klien (pengujian)"
        ;;
esac


# ==============================================================
#  Jika node baru restart dan semuanya mati, urutan pemulihan:
#      rootkit : iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#      lalu ulangi urutan pengerjaan di bagian atas script.
#
#  Cek cepat kondisi node:
#      sh soal_redirect_kanonik.sh status
# ==============================================================
