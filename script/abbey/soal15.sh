#!/bin/sh

HOST=$(hostname)

echo "======================================"
echo "SOAL 15 - ETERNAL & ORION"
echo "======================================"

case "$HOST" in

penny)

echo "[PENNY] Configure /eternal"

mkdir -p /var/www/eternal

cat > /var/www/eternal/index.php <<'PHP'
<!DOCTYPE html>
<html>
<head>
    <title>Eternal</title>
</head>
<body>
    <h1>Eternal Area</h1>
    <p>PHP berjalan di Penny.</p>
    <p>Server: <?php echo gethostname(); ?></p>
    <p>PHP Version: <?php echo PHP_VERSION; ?></p>
</body>
</html>
PHP

cat > /etc/apache2/conf.d/php84-module.conf <<'CONF'
LoadModule php_module modules/mod_php84.so

DirectoryIndex index.php index.html

<FilesMatch \.php$>
    SetHandler application/x-httpd-php
</FilesMatch>
CONF

cat > /etc/apache2/conf.d/eternal.conf <<'CONF'
Alias /eternal/ /var/www/eternal/

<Directory /var/www/eternal>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
    DirectoryIndex index.php index.html
</Directory>
CONF

httpd -t

echo ""
echo "Test:"
wget -qO- --header="Host: www.iqbal.com" \
http://127.0.0.1/eternal/

;;

abbey)

echo "[ABBEY] Configure /orion"

mkdir -p /var/www/orion

cat > /var/www/orion/index.html <<'HTML'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Orion</title>
</head>
<body>
    <h1>Orion Area</h1>
    <p>Static content served by Abbey.</p>
    <p>Server: abbey</p>
</body>
</html>
HTML

cat > /etc/nginx/http.d/orion.conf <<'CONF'
server {
    listen 80;
    server_name static.iqbal.com;

    location /orion/ {
        root /var/www;
        index index.html;
    }
}
CONF

nginx -t

rm -f /run/nginx/nginx.pid
nginx 2>/dev/null || nginx -s reload

echo ""
echo "Test:"
wget -qO- --header="Host: static.iqbal.com" \
http://127.0.0.1/orion/

;;

*)
echo "Node $HOST tidak digunakan untuk Soal 15."
;;

esac
EOF