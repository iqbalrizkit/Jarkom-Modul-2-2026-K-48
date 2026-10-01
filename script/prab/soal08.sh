#!/bin/sh

HOST=$(hostname)

echo "======================================"
echo "SOAL 8 - REVERSE DNS"
echo "======================================"

case "$HOST" in

prab|tedd)

echo "=== 192.235.1.4 ==="
dig -x 192.235.1.4 +short

echo ""
echo "=== 192.235.1.5 ==="
dig -x 192.235.1.5 +short

echo ""
echo "=== 192.235.1.6 ==="
dig -x 192.235.1.6 +short

echo ""
echo "=== 192.235.1.7 ==="
dig -x 192.235.1.7 +short

echo ""
echo "=== 192.235.2.2 ==="
dig -x 192.235.2.2 +short

echo ""
echo "=== 192.235.3.2 ==="
dig -x 192.235.3.2 +short

;;

alpha|beta|gamma|delta|epsilon)

echo "=== REVERSE DNS FROM $HOST ==="

dig -x 192.235.1.4 +short
dig -x 192.235.1.5 +short
dig -x 192.235.1.6 +short
dig -x 192.235.1.7 +short

;;

*)
echo "Node tidak digunakan untuk Soal 8."
;;

esac
EOF