#!/bin/sh

HOST=$(hostname)

case "$HOST" in

obladi|desmond)

echo "======================================"
echo "SOAL 14 - VAULT REAL CLIENT IP"
echo "======================================"

cat > /etc/nginx/http.d/realip.conf <<'CONF'
log_format vault '$remote_addr - [$time_local] "$request" $status host=$http_host realip=$http_x_real_ip';

server {
    listen 80 default_server;
    server_name _;

    set_real_ip_from 192.235.3.2;
    real_ip_header X-Real-IP;
    real_ip_recursive on;

    root /var/www/vault;
    index index.html;

    access_log /var/log/nginx/vault_access.log vault;
}
CONF

nginx -t

rm -f /run/nginx/nginx.pid
nginx 2>/dev/null || nginx -s reload

echo ""
echo "Access log:"
tail -n 5 /var/log/nginx/vault_access.log 2>/dev/null

;;

oblada|molly)

echo "======================================"
echo "SOAL 14 - CORE REAL CLIENT IP"
echo "======================================"

cat > /etc/nginx/http.d/realip.conf <<'CONF'
log_format core '$remote_addr - [$time_local] "$request" $status host=$http_host realip=$http_x_real_ip';

server {
    listen 80 default_server;
    server_name _;

    set_real_ip_from 192.235.2.2;
    real_ip_header X-Real-IP;
    real_ip_recursive on;

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
CONF

nginx -t

rm -f /run/nginx/nginx.pid
nginx 2>/dev/null || nginx -s reload

echo ""
echo "Access log:"
tail -n 5 /var/log/nginx/core_access.log 2>/dev/null

;;

*)
echo "Node $HOST tidak digunakan untuk Soal 14."
;;

esac
EOF