#!/bin/sh

ZONE=/etc/bind/db.iqbal.com

sed -i -E 's/^alpha[[:space:]]+IN[[:space:]]+TXT.*/alpha       IN      TXT     "alpha.iqbal.com"/' "$ZONE"
sed -i -E 's/^beta[[:space:]]+IN[[:space:]]+TXT.*/beta        IN      TXT     "beta.iqbal.com"/' "$ZONE"
sed -i -E 's/^gamma[[:space:]]+IN[[:space:]]+TXT.*/gamma       IN      TXT     "gamma.iqbal.com"/' "$ZONE"
sed -i -E 's/^delta[[:space:]]+IN[[:space:]]+TXT.*/delta       IN      TXT     "delta.iqbal.com"/' "$ZONE"
sed -i -E 's/^epsilon[[:space:]]+IN[[:space:]]+TXT.*/epsilon    IN      TXT     "epsilon.iqbal.com"/' "$ZONE"

sed -i -E 's/^([[:space:]]*)10([[:space:]]+; Serial)/\1 11\2/' "$ZONE"

named-checkconf /etc/bind/named.conf
named-checkzone iqbal.com "$ZONE"

pkill named 2>/dev/null || true
named

echo "===== SOAL 17 BERHASIL ====="
dig @127.0.0.1 alpha.iqbal.com TXT +short
dig @127.0.0.1 beta.iqbal.com TXT +short
dig @127.0.0.1 gamma.iqbal.com TXT +short
dig @127.0.0.1 delta.iqbal.com TXT +short
dig @127.0.0.1 epsilon.iqbal.com TXT +short