#!/bin/sh

HOST=$(hostname)

echo "======================================"
echo "SOAL 5 - HOSTNAME"
echo "======================================"

case "$HOST" in
alpha|beta|gamma|delta|epsilon|prab|tedd|abbey|penny|obladi|desmond|oblada|molly)

    echo "Hostname : $HOST"
    echo "Domain   : $HOST.iqbal.com"

    echo "$HOST.iqbal.com $HOST" >> /etc/hosts

    echo ""
    echo "Current hostname:"
    hostname

    echo ""
    echo "Hosts entry:"
    grep "$HOST.iqbal.com" /etc/hosts

    ;;

rootkit)
    hostname rootkit
    echo "Hostname rootkit."
    ;;

*)
    echo "Node tidak termasuk Soal 5."
    ;;
esac
EOF