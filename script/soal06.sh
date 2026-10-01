#!/bin/sh

HOST=$(hostname)

echo "======================================"
echo "SOAL 6 - ZONE TRANSFER"
echo "======================================"

case "$HOST" in

prab)

echo "=== MASTER SERIAL ==="
dig @192.235.1.2 iqbal.com SOA +short

echo ""
echo "=== ALLOW TRANSFER TEST ==="
dig @192.235.1.2 iqbal.com AXFR

;;

tedd)

echo "=== SLAVE SERIAL ==="
dig @192.235.1.3 iqbal.com SOA +short

echo ""
echo "=== FORWARD ZONE ==="
dig @192.235.1.3 iqbal.com AXFR

echo ""
echo "=== ZONE FILE ==="
ls -lh /var/bind/db.iqbal.com

;;

*)
echo "Jalankan Soal 6 pada prab atau tedd."
;;

esac
EOF