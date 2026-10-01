#!/bin/sh

apk add --no-cache apache2 apache2-utils

mkdir -p /var/www/admin

htpasswd -bc /etc/apache2/.htpasswd prabs 'pakar_pinter_jadi_gob***'

cat > /etc/apache2/httpd.conf.d/admin-auth.conf <<'EOF'
<Location "/admin">
    AuthType Basic
    AuthName "Restricted Area"
    AuthUserFile "/etc/apache2/.htpasswd"
    Require valid-user
</Location>
EOF

httpd -t
pkill httpd 2>/dev/null || true
httpd -k start