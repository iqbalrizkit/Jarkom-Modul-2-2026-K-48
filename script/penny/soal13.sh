#!/bin/sh

cat > /etc/apache2/httpd.conf.d/redirect.conf <<'EOF'
<VirtualHost *:80>
    ServerName 192.235.3.2
    ServerAlias penny.iqbal.com

    Redirect permanent / http://www.iqbal.com/
</VirtualHost>
EOF

httpd -t
pkill httpd 2>/dev/null || true
httpd -k start