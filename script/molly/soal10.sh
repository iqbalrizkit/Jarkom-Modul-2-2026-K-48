#!/bin/sh

apk add --no-cache nginx php84-fpm

mkdir -p /var/www/core

cat > /var/www/core/index.php <<'EOF'
<?php
echo "<h1>Core Repository</h1>";
echo "<p>Dynamic web server - oblada</p>";
?>
EOF

cat > /var/www/core/profil.php <<'EOF'
<?php
echo "<h1>Profil</h1>";
echo "<p>Halaman profil dynamic web.</p>";
?>
EOF

cat > /etc/nginx/http.d/core.conf <<'EOF'
server {
    listen 80;
    server_name core.iqbal.com;

    root /var/www/core;
    index index.php;

    location / {
        try_files $uri $uri/ $uri.php?$query_string;
    }

    location /profil {
        try_files $uri $uri.php =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass 127.0.0.1:9000;
    }
}
EOF

php-fpm84 -D
nginx -t
pkill nginx 2>/dev/null || true
nginx