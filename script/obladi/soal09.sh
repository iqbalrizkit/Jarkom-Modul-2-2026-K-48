#!/bin/sh

apk add --no-cache apache2

mkdir -p /var/www/vault/arsip

cat > /var/www/vault/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Vault</title>
</head>
<body>
    <h1>Vault Repository</h1>
    <p>Static web server - obladi</p>
</body>
</html>
EOF

echo "Dokumen arsip vault." > /var/www/vault/arsip/dokumen.txt

cat > /etc/apache2/httpd.conf <<'EOF'
ServerRoot "/etc/apache2"
Listen 80
LoadModule mpm_event_module modules/mod_mpm_event.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule dir_module modules/mod_dir.so
LoadModule mime_module modules/mod_mime.so
LoadModule autoindex_module modules/mod_autoindex.so

User apache
Group apache

ServerName localhost

DocumentRoot "/var/www/vault"

<Directory "/var/www/vault">
    AllowOverride None
    Require all granted
</Directory>

<Directory "/var/www/vault/arsip">
    Options +Indexes
    AllowOverride None
    Require all granted
</Directory>

DirectoryIndex index.html
EOF

httpd -t
pkill httpd 2>/dev/null || true
httpd -k start