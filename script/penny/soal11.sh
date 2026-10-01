#!/bin/sh

apk add --no-cache apache2

sed -i 's/^#LoadModule proxy_module/LoadModule proxy_module/' /etc/apache2/httpd.conf
sed -i 's/^#LoadModule proxy_http_module/LoadModule proxy_http_module/' /etc/apache2/httpd.conf
sed -i 's/^#LoadModule proxy_balancer_module/LoadModule proxy_balancer_module/' /etc/apache2/httpd.conf
sed -i 's/^#LoadModule slotmem_shm_module/LoadModule slotmem_shm_module/' /etc/apache2/httpd.conf
sed -i 's/^#LoadModule lbmethod_byrequests_module/LoadModule lbmethod_byrequests_module/' /etc/apache2/httpd.conf
sed -i 's/^#LoadModule headers_module/LoadModule headers_module/' /etc/apache2/httpd.conf

cat > /etc/apache2/httpd.conf.d/penny-proxy.conf <<'EOF'
<VirtualHost *:80>
    ServerName www.iqbal.com

    ProxyPreserveHost On

    <Proxy "balancer://vault">
        BalancerMember "http://192.235.1.4"
        BalancerMember "http://192.235.1.5"
        ProxySet lbmethod=byrequests
    </Proxy>

    ProxyPass "/" "balancer://vault/"
    ProxyPassReverse "/" "balancer://vault/"

    RequestHeader set X-Real-IP "%{REMOTE_ADDR}s"
</VirtualHost>
EOF

httpd -t
pkill httpd 2>/dev/null || true
httpd -k start