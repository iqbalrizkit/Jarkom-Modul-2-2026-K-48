#!/bin/sh

HOST=$(hostname)

echo "======================================"
echo "SOAL 3 - NETWORK CONFIGURATION"
echo "======================================"
echo "HOST: $HOST"
echo ""

case "$HOST" in

alpha)
    IP="192.235.4.2"
    GW="192.235.4.1"
    ;;

beta)
    IP="192.235.4.3"
    GW="192.235.4.1"
    ;;

gamma)
    IP="192.235.4.4"
    GW="192.235.4.1"
    ;;

delta)
    IP="192.235.5.2"
    GW="192.235.5.1"
    ;;

epsilon)
    IP="192.235.5.3"
    GW="192.235.5.1"
    ;;

abbey)
    IP="192.235.2.2"
    GW="192.235.2.1"
    ;;

penny)
    IP="192.235.3.2"
    GW="192.235.3.1"
    ;;

prab)
    IP="192.235.1.2"
    GW="192.235.1.1"
    ;;

tedd)
    IP="192.235.1.3"
    GW="192.235.1.1"
    ;;

obladi)
    IP="192.235.1.4"
    GW="192.235.1.1"
    ;;

desmond)
    IP="192.235.1.5"
    GW="192.235.1.1"
    ;;

oblada)
    IP="192.235.1.6"
    GW="192.235.1.1"
    ;;

molly)
    IP="192.235.1.7"
    GW="192.235.1.1"
    ;;

*)
    echo "Node tidak termasuk Soal 3."
    exit 0
    ;;
esac

echo "[1] IP Address : $IP"
echo "[2] Gateway    : $GW"

echo ""
echo "[3] Configure resolver"
cat > /etc/resolv.conf <<RESOLV
nameserver 192.168.122.1
RESOLV

echo ""
echo "[4] Current routing:"
ip route

echo ""
echo "[5] Resolver:"
cat /etc/resolv.conf

echo ""
echo "SOAL 3 SELESAI"
EOF