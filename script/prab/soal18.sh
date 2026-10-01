#!/bin/sh

ZONE=/etc/bind/db.iqbal.com

cp "$ZONE" /root/db.iqbal.com.before-soal18

echo "===== SEBELUM ====="
dig @127.0.0.1 abbey.iqbal.com A +noall +answer

sed -i -E 's/^\$TTL[[:space:]]+[0-9]+/\$TTL    15/' "$ZONE"
sed -i -E 's/^abbey[[:space:]]+IN[[:space:]]+A[[:space:]]+.*/abbey   IN      A       203.0.113.77/' "$ZONE"
sed -i -E 's/^([[:space:]]*)11([[:space:]]+; Serial)/\1 12\2/' "$ZONE"

named-checkconf /etc/bind/named.conf
named-checkzone iqbal.com "$ZONE"

pkill named 2>/dev/null || true
named

echo "===== SESUDAH ====="
dig @127.0.0.1 abbey.iqbal.com A +noall +answer
dig @127.0.0.1 iqbal.com SOA +short