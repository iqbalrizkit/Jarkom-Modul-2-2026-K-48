#!/bin/sh

# Siapkan direktori BIND
mkdir -p /etc/bind

# Salin zone file dari backup
cp /root/backup/db.iqbal.com /etc/bind/db.iqbal.com

# Tambahkan TXT record dan ubah serial
sed -i 's/^[[:space:]]*6[[:space:]]*; Serial/                              7         ; Serial/' /etc/bind/db.iqbal.com

cat >> /etc/bind/db.iqbal.com <<'EOF'

alpha   IN      TXT     "alpha"
beta    IN      TXT     "beta"
gamma   IN      TXT     "gamma"
delta   IN      TXT     "delta"
epsilon IN      TXT     "epsilon"
EOF

# Install BIND
apk update
apk add bind bind-tools

# Buat konfigurasi BIND
cat > /etc/bind/named.conf <<'EOF'
options {
    directory "/var/bind";
    listen-on { any; };
    allow-query { any; };
    recursion no;
};

zone "iqbal.com" {
    type master;
    file "/etc/bind/db.iqbal.com";
};
EOF

# Cek konfigurasi zone
named-checkzone iqbal.com /etc/bind/db.iqbal.com

# Jalankan BIND
named

# Uji seluruh TXT record
for host in alpha beta gamma delta epsilon
do
    echo "=== $host ==="
    dig @127.0.0.1 $host.iqbal.com TXT +short
done