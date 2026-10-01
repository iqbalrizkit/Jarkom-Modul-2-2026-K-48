#!/bin/sh

sysctl -w net.ipv4.ip_forward=1

iptables -t nat -C POSTROUTING -s 192.235.0.0/16 -o eth0 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 192.235.0.0/16 -o eth0 -j MASQUERADE

echo "===== IP FORWARDING ====="
sysctl net.ipv4.ip_forward

echo "===== NAT/MASQUERADE ====="
iptables -t nat -L POSTROUTING -n -v

echo "===== ROUTING ====="
ip route

echo "===== ROOTKIT READY ====="