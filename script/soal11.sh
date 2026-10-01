#!/bin/sh
# ==============================================================
#  SOAL - Reverse Proxy Penny (Apache) dan Abbey (Nginx)
#
#  Satu script untuk semua node. Cara pakai:
#      sh soal_reverse_proxy.sh
#
#  Script membaca hostname dan menjalankan bagian yang sesuai:
#      obladi / desmond -> backend VAULT (web statis, Nginx)
#      oblada / molly   -> backend CORE  (web dinamis, Nginx + PHP-FPM)
#      penny            -> reverse proxy Apache ke area vault
#      abbey            -> reverse proxy Nginx  ke area core
#      alpha..epsilon   -> uji distribusi dan header dari klien
#
#  Bukti header di backend (setelah tes dari klien):
#      sh soal_reverse_proxy.sh bukti      (di obladi/desmond/oblada/molly)
#
#  URUTAN PENGERJAAN (backend harus siap sebelum gerbang):
#      1. obladi  : sh soal_reverse_proxy.sh
#      2. desmond : sh soal_reverse_proxy.sh
#      3. oblada  : sh soal_reverse_proxy.sh
#      4. molly   : sh soal_reverse_proxy.sh
#      5. penny   : sh soal_reverse_proxy.sh
#      6. abbey   : sh soal_reverse_proxy.sh
#      7. klien   : sh soal_reverse_proxy.sh   (mis. alpha)
#      8. backend : sh soal_reverse_proxy.sh bukti
#
#  Uji failover (manual, lihat bagian akhir script).
# ==============================================================


# ---------- PENGATURAN ----------
IP_PENNY="192.235.3.2"
IP_ABBEY="192.235.2.2"

IP_OBLADI="192.235.1.4"
IP_DESMOND="192.235.1.5"
IP_OBLADA="192.235.1.6"
IP_MOLLY="192.235.1.7"

WEBROOT_VAULT="/var/www/vault"
WEBROOT_CORE="/var/www/core"
# --------------------------------


# ==============================================================
#  FUNGSI BANTU
# ==============================================================

# Pastikan apk bisa mengunduh paket. Jika DNS internal belum siap,
# sementara taruh 192.168.122.1 di baris pertama resolver.
RESOLV_BACKUP=""

ensure_net() {
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
        echo "ERROR: apk update tetap gagal. Cek NAT di rootkit dan koneksi."
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
}


# ==============================================================
#  BAGIAN A - BACKEND VAULT (OBLADI / DESMOND)
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
    mkdir -p "$WEBROOT_VAULT"

    cat > "$WEBROOT_VAULT/index.html" <<EOF
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
    echo " Bukti header setelah tes dari klien:"
    echo "     sh soal_reverse_proxy.sh bukti"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN B - BACKEND CORE (OBLADA / MOLLY)
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
    mkdir -p "$WEBROOT_CORE"

    cat > "$WEBROOT_CORE/index.php" <<'EOF'
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
    echo " Bukti header setelah tes dari klien:"
    echo "     sh soal_reverse_proxy.sh bukti"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN C - PENNY (APACHE) -> VAULT
# ==============================================================
setup_penny() {

    echo "=============================================================="
    echo " Menyiapkan PENNY (Apache reverse proxy) -> area vault"
    echo " Backend : obladi ($IP_OBLADI) dan desmond ($IP_DESMOND)"
    echo "=============================================================="
    echo

    echo "[1/5] Instal Apache dan modul proxy"
    ensure_net
    apk add apache2 apache2-proxy
    restore_net

    echo "[2/5] Mengaktifkan modul headers dan slotmem_shm"
    HTTPD_CONF="/etc/apache2/httpd.conf"
    sed -i -E 's/^#(LoadModule (headers|slotmem_shm)_module)/\1/' "$HTTPD_CONF"

    echo "[3/5] Membuat konfigurasi reverse proxy + load balancer"
    rm -f /etc/apache2/conf.d/penny.conf

    cat > /etc/apache2/conf.d/penny.conf <<EOF
ServerName penny

<VirtualHost *:80>
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

    echo "[4/5] Mengecek konfigurasi Apache"
    httpd -t 2>&1 | grep -v "already loaded" || true
    httpd -t > /dev/null 2>&1 || {
        echo
        echo "SINTAKS APACHE ERROR. Periksa konfigurasi sebelum melanjutkan."
        httpd -t
        exit 1
    }

    echo "[5/5] Menjalankan Apache"
    if pgrep httpd > /dev/null 2>&1; then
        echo "      Apache sedang berjalan -> restart"
        httpd -k restart 2>/dev/null
    else
        echo "      Apache belum berjalan -> start"
        httpd 2>/dev/null
    fi
    sleep 2

    echo
    echo "--- Modul yang aktif ---"
    httpd -M 2>/dev/null | grep -E "proxy_module|proxy_http|proxy_balancer|lbmethod_byrequests|headers_module"

    echo
    echo "--- Tes lokal (4 request, harus bergantian) ---"
    for i in 1 2 3 4; do
        wget -qO- http://localhost | grep -o "Area Vault - [a-z]*"
    done

    echo
    echo "=============================================================="
    echo " Penny selesai."
    echo " Uji dari klien: sh soal_reverse_proxy.sh"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN D - ABBEY (NGINX) -> CORE
# ==============================================================
setup_abbey() {

    echo "=============================================================="
    echo " Menyiapkan ABBEY (Nginx reverse proxy) -> area core"
    echo " Backend : oblada ($IP_OBLADA) dan molly ($IP_MOLLY)"
    echo "=============================================================="
    echo

    echo "[1/4] Instal Nginx"
    ensure_net
    apk add nginx
    restore_net

    echo "[2/4] Membuat konfigurasi reverse proxy + upstream"
    rm -f /etc/nginx/http.d/default.conf
    rm -f /etc/nginx/http.d/abbey.conf

    # zone core: supaya semua worker Nginx berbagi status giliran,
    # sehingga round robin benar-benar bergantian.
    cat > /etc/nginx/http.d/abbey.conf <<EOF
upstream core {
    zone core 64k;
    server $IP_OBLADA;
    server $IP_MOLLY;
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://core;

        # Teruskan Host dan IP asli klien
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

    grep -q 'proxy_set_header X-Real-IP \$remote_addr' /etc/nginx/http.d/abbey.conf || {
        echo "ERROR: baris proxy_set_header rusak. Salin ulang script."
        exit 1
    }

    echo "[3/4] Mengecek dan menjalankan Nginx"
    start_nginx

    echo "[4/4] Tes lokal (6 request, harus bergantian)"
    for i in 1 2 3 4 5 6; do
        wget -qO- http://localhost | grep -o "Area Core - [a-z]*"
    done

    echo
    echo "=============================================================="
    echo " Abbey selesai."
    echo " (X-Real-IP di tes lokal bernilai 127.0.0.1; itu wajar)"
    echo " Uji dari klien: sh soal_reverse_proxy.sh"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN E - PENGUJIAN KLIEN
# ==============================================================
test_client() {

    MYIP=$(ip -4 addr show eth0 | grep -o 'inet [0-9.]*' | cut -d' ' -f2)

    echo "=============================================================="
    echo " Pengujian dari klien: $(hostname)  (IP $MYIP)"
    echo "=============================================================="
    echo

    echo "[1/4] Penny -> area vault (4 request, harus bergantian)"
    for i in 1 2 3 4; do
        wget -qO- "http://$IP_PENNY" | grep -o "Area Vault - [a-z]*"
    done

    echo
    echo "[2/4] Abbey -> area core (6 request, harus bergantian)"
    for i in 1 2 3 4 5 6; do
        wget -qO- "http://$IP_ABBEY" | grep -o "Area Core - [a-z]*"
    done

    echo
    echo "[3/4] Header yang diterima backend core lewat Abbey"
    wget -qO- "http://$IP_ABBEY" \
        | sed 's/<\/p>/\n/g; s/<[^>]*>//g' \
        | grep -E "Host|X-Real-IP|REMOTE_ADDR"

    echo
    echo "[4/4] Pemeriksaan"
    echo "      X-Real-IP di atas harus sama dengan IP klien: $MYIP"
    echo "      Host di atas harus sama dengan alamat yang diakses: $IP_ABBEY"

    echo
    echo "=============================================================="
    echo " PENGUJIAN SELESAI"
    echo
    echo " Bukti header untuk area VAULT ada di log backend:"
    echo "     obladi / desmond : sh soal_reverse_proxy.sh bukti"
    echo "=============================================================="
}


# ==============================================================
#  BAGIAN F - BUKTI DI LOG BACKEND
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
    echo "    host=   = alamat yang diakses klien"
    echo "    realip= = IP klien asli (mis. 192.235.4.2 untuk alpha)"
}


# ==============================================================
#  PROGRAM UTAMA
# ==============================================================

if [ "$1" = "bukti" ]; then
    show_evidence
    exit 0
fi

case "$(hostname)" in

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
        echo "    obladi, desmond -> Backend Vault"
        echo "    oblada, molly   -> Backend Core"
        echo "    penny           -> Reverse Proxy Apache"
        echo "    abbey           -> Reverse Proxy Nginx"
        echo "    alpha..epsilon  -> Klien (pengujian)"
        ;;
esac


# ==============================================================
#  UJI FAILOVER (manual)
#
#  Vault:
#      obladi : nginx -s stop
#      alpha  : for i in 1 2 3 4; do wget -qO- http://192.235.3.2 | grep h1; done
#               -> semua "Area Vault - desmond"
#      obladi : nginx
#
#  Core:
#      molly  : nginx -s stop
#      alpha  : for i in 1 2 3 4; do wget -qO- http://192.235.2.2 | grep -o "Area Core - [a-z]*"; done
#               -> semua "Area Core - oblada"
#      molly  : nginx
# ==============================================================
