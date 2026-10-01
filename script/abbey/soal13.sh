#!/bin/sh

rm -f /etc/nginx/http.d/default.conf

cat > /etc/nginx/http.d/redirect.conf <<'EOF'
server {
    listen 80;
    server_name abbey.iqbal.com 192.235.2.2;

    return 302 http://static.iqbal.com$request_uri;
}
EOF

nginx -t
pkill nginx 2>/dev/null || true
nginx