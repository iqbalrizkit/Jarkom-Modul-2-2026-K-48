#!/bin/sh

HOST=$(hostname)

case "$HOST" in

alpha)

echo "======================================"
echo "SOAL 16 - APACHE BENCH"
echo "======================================"

echo ""
echo "======================================"
echo "BENCHMARK www.iqbal.com"
echo "======================================"

ab -n 250 -c 10 -l \
-H "Host: www.iqbal.com" \
http://192.235.3.2/

echo ""
echo "======================================"
echo "BENCHMARK static.iqbal.com"
echo "======================================"

ab -n 250 -c 10 -l \
-H "Host: static.iqbal.com" \
http://192.235.2.2/

echo ""
echo "======================================"
echo "SOAL 16 SELESAI"
echo "======================================"

;;

*)
echo "Soal 16 hanya dijalankan dari Alpha."
;;

esac
EOF