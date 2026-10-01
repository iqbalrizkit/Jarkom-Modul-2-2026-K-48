#!/bin/sh
# Tambahkan CNAME outbound → http.badssl.com
sed -i '/static.*CNAME/a outbound    IN      CNAME   http.badssl.com.' /etc/bind/db.iqbal.com

# Naikkan serial dari 8 menjadi 9
sed -i 's/^[[:space:]]*8[[:space:]]*; Serial/                              9         ; Serial/' /etc/bind/db.iqbal.com

# Cek zone
named-checkzone iqbal.com /etc/bind/db.iqbal.com

# Reload BIND
kill -HUP $(pidof named)

# Cek CNAME
dig @127.0.0.1 outbound.iqbal.com CNAME +noall +answer

# Aktifkan recursive DNS dan gunakan resolver eksternal sebagai forwarder
sed -i 's/recursion no;/recursion yes;\n    forwarders { 192.168.122.1; };/g' /etc/bind/named.conf

# Cek konfigurasi BIND
named-checkconf /etc/bind/named.conf

# Reload BIND
kill -HUP $(pidof named)

# Tes CNAME sampai mendapatkan IP eksternal
dig @192.235.1.2 outbound.iqbal.com A +noall +answer

# Tes akhir sesuai soal
curl http://outbound.iqbal.com