#!/bin/sh

apk add --no-cache nginx

cat > /etc/nginx/http.d/abbey-proxy.conf <<'EOF'
upstream core_backend {
    server 192.235.1.6;
    server 192.235.1.7;
}

server {
    listen 80;
    server_name core.iqbal.com;

    location / {
        proxy_pass http://core_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

nginx -t
pkill nginx 2>/dev/null || true
nginx