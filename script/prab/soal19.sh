#!/bin/sh

ZONE=/etc/bind/db.iqbal.com

sed -i '/^outbound[[:space:]]\+IN[[:space:]]\+CNAME/d' "$ZONE"

echo 'outbound    IN      CNAME   http.badssl.com.' >> "$ZONE"

sed -i -E 's/^([[:space:]]*)12([[:space:]]+; Serial)/\1 13\2/' "$ZONE"

named-checkconf /etc/bind/named.conf
named-checkzone iqbal.com "$ZONE"

pkill named 2>/dev/null || true
named

echo "===== SOAL 19 ====="
dig @127.0.0.1 outbound.iqbal.com CNAME +short

echo "===== CURL ====="
curl -I http://outbound.iqbal.com