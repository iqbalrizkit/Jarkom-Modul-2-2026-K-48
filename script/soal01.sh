#!/bin/sh

HOST=$(hostname)

echo "======================================"
echo "SOAL 1 - IP ADDRESS & GATEWAY"
echo "======================================"
echo "HOST: $HOST"
echo ""

case "$HOST" in

rootkit)

echo "[ROOTKIT]"
echo "eth0 = 192.168.122.145/24"
echo "eth1 = 192.235.1.1/24"
echo "eth2 = 192.235.2.1/24"
echo "eth3 = 192.235.3.1/24"
echo "eth4 = 192.235.4.1/24"
echo "eth5 = 192.235.5.1/24"

echo ""
echo "Current interfaces:"
ip -br addr

echo ""
echo "Routing:"
ip route

;;

alpha)

echo "IP      = 192.235.4.2/24"
echo "Gateway = 192.235.4.1"
ip -br addr
ip route

;;

beta)

echo "IP      = 192.235.4.3/24"
echo "Gateway = 192.235.4.1"
ip -br addr
ip route

;;

gamma)

echo "IP      = 192.235.4.4/24"
echo "Gateway = 192.235.4.1"
ip -br addr
ip route

;;

delta)

echo "IP      = 192.235.5.2/24"
echo "Gateway = 192.235.5.1"
ip -br addr
ip route

;;

epsilon)

echo "IP      = 192.235.5.3/24"
echo "Gateway = 192.235.5.1"
ip -br addr
ip route

;;

abbey)

echo "IP      = 192.235.2.2/24"
echo "Gateway = 192.235.2.1"
ip -br addr
ip route

;;

penny)

echo "IP      = 192.235.3.2/24"
echo "Gateway = 192.235.3.1"
ip -br addr
ip route

;;

prab)

echo "IP      = 192.235.1.2/24"
echo "Gateway = 192.235.1.1"
ip -br addr
ip route

;;

tedd)

echo "IP      = 192.235.1.3/24"
echo "Gateway = 192.235.1.1"
ip -br addr
ip route

;;

obladi)

echo "IP      = 192.235.1.4/24"
echo "Gateway = 192.235.1.1"
ip -br addr
ip route

;;

desmond)

echo "IP      = 192.235.1.5/24"
echo "Gateway = 192.235.1.1"
ip -br addr
ip route

;;

oblada)

echo "IP      = 192.235.1.6/24"
echo "Gateway = 192.235.1.1"
ip -br addr
ip route

;;

molly)

echo "IP      = 192.235.1.7/24"
echo "Gateway = 192.235.1.1"
ip -br addr
ip route

;;

*)

echo "Node $HOST tidak termasuk Soal 1."

;;

esac
EOF