#!/bin/sh

HOST=$(hostname)

case "$HOST" in

rootkit)
    echo "======================================"
    echo "SOAL 2 - NAT ROOTKIT"
    echo "======================================"

    echo "[1] Enable IP forwarding"
    echo 1 > /proc/sys/net/ipv4/ip_forward

    echo "[2] Install iptables"
    apk add --no-cache iptables

    echo "[3] Configure NAT"
    iptables -t nat -F POSTROUTING
    iptables -t nat -A POSTROUTING \
        -s 192.235.0.0/16 \
        -o eth0 \
        -j MASQUERADE

    echo ""
    echo "[4] IP forwarding:"
    cat /proc/sys/net/ipv4/ip_forward

    echo ""
    echo "[5] NAT rule:"
    iptables -t nat -L POSTROUTING -n -v

    echo ""
    echo "SOAL 2 SELESAI"
    ;;

*)
    echo "Node $HOST tidak digunakan untuk Soal 2."
    ;;

esac
EOF