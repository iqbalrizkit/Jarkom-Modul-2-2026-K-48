#!/bin/sh
# ==============================================================
#  SOAL 12 - Basic Authentication pada Penny (Apache)
#
#  Tujuan:
#      Melindungi path /admin pada penny menggunakan
#      Basic Authentication.
#
#  Credential:
#      Username : prabs
#      Password : pakar_pinter_jadi_gob***
#
#  Node:
#      penny -> Apache
# ==============================================================


# ==============================================================
#  PENGATURAN
# ==============================================================

ADMIN_ROOT="/var/www/admin"
HTPASSWD_FILE="/etc/apache2/.htpasswd"
PENNY_CONF="/etc/apache2/conf.d/penny.conf"

USERNAME="prabs"
PASSWORD='pakar_pinter_jadi_gob***'


# ==============================================================
#  [1/7] INSTALASI APACHE DAN APACHE-UTILS
# ==============================================================

echo "=============================================================="
echo " [1/7] Instalasi Apache dan apache2-utils"
echo "=============================================================="

apk update
apk add apache2 apache2-proxy apache2-utils


# ==============================================================
#  [2/7] MEMBUAT USER BASIC AUTHENTICATION
# ==============================================================

echo
echo "=============================================================="
echo " [2/7] Membuat credential Basic Authentication"
echo "=============================================================="

htpasswd -cb "$HTPASSWD_FILE" "$USERNAME" "$PASSWORD"


# ==============================================================
#  [3/7] MEMBUAT DIREKTORI /admin
# ==============================================================

echo
echo "=============================================================="
echo " [3/7] Membuat halaman /admin"
echo "=============================================================="

mkdir -p "$ADMIN_ROOT"

cat > "$ADMIN_ROOT/index.html" <<'EOF'
<!doctype html>
<html>
<head>
    <title>Admin Area</title>
</head>
<body>
    <h1>Admin Area</h1>
    <p>Dokumen rahasia sindikat.</p>
</body>
</html>
EOF


# ==============================================================
#  [4/7] MEMBUAT KONFIGURASI BASIC AUTHENTICATION
# ==============================================================

echo
echo "=============================================================="
echo " [4/7] Membuat konfigurasi Apache"
echo "=============================================================="

cat > "$PENNY_CONF" <<'EOF'
ServerName penny

<VirtualHost *:80>

    ProxyPreserveHost On

    RequestHeader set X-Real