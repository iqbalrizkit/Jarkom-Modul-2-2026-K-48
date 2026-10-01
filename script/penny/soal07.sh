#!/bin/sh

HOST=$(hostname)

echo "======================================"
echo "SOAL 7 - DNS SERVICE RECORD"
echo "======================================"

case "$HOST" in

prab|tedd)

echo "=== VAULT ==="
dig @$([ "$HOST" = "prab" ] && echo 192.235.1.2 || echo 192.235.1.3) vault.iqbal.com A +short

echo ""
echo "=== CORE ==="
dig @$([ "$HOST" = "prab" ] && echo 192.235.1.2 || echo 192.235.1.3) core.iqbal.com A +short

echo ""
echo "=== WWW ==="
dig @$([ "$HOST" = "prab" ] && echo 192.235.1.2 || echo 192.235.1.3) www.iqbal.com CNAME +short

echo ""
echo "=== STATIC ==="
dig @$([ "$HOST" = "prab" ] && echo 192.235.1.2 || echo 192.235.1.3) static.iqbal.com CNAME +short

;;

alpha|beta|gamma|delta|epsilon)

echo "=== DNS TEST FROM $HOST ==="

dig vault.iqbal.com A +short
echo ""

dig core.iqbal.com A +short
echo ""

dig www.iqbal.com CNAME +short
echo ""

dig static.iqbal.com CNAME +short

;;

*)
echo "Node tidak digunakan untuk Soal 7."
;;

esac
EOF