#!/bin/sh

HOST=$(hostname)

case "$HOST" in

prab)

DOMAIN="iqbal.com"
ZONE="/etc/bind/db.iqbal.com"

echo "======================================"
echo "SOAL 4 - DNS MASTER"
echo "======================================"

echo "[1] Install BIND"
apk add --no-cache bind bind-tools

echo "[2] Create DNS options"

cat > /etc/bind/named.conf.options <<'CONF'
options {
    directory "/var/bind";
    pid-file "/var/run/named/named.pid";

    forwarders {
        192.168.122.1;
    };

    dnssec-validation no;

    listen-on { any; };
    listen-on-v6 { none; };

    allow-query { any; };
    allow-recursion { any; };

    recursion yes;
};
CONF

echo "[3] Create authoritative zone"

cat > /etc/bind/named.conf.local <<'CONF'
zone "iqbal.com" {
    type master;
    file "/etc/bind/db.iqbal.com";
    notify yes;
    also-notify { 192.235.1.3; };
    allow-transfer { 192.235.1.3; };
};
CONF

cat > "$ZONE" <<'DNS'
$TTL 86400
@   IN  SOA prab.iqbal.com. prab.iqbal.com. (
        7
        3600
        600
        86400
        3600
)
    IN NS prab.iqbal.com.
    IN NS tedd.iqbal.com.

@       IN A 192.235.3.2
prab    IN A 192.235.1.2
tedd    IN A 192.235.1.3
abbey   IN A 192.235.2.2
penny   IN A 192.235.3.2
obladi  IN A 192.235.1.4
desmond IN A 192.235.1.5
oblada  IN A 192.235.1.6
molly   IN A 192.235.1.7

vault   IN A 192.235.1.4
vault   IN A 192.235.1.5

core    IN A 192.235.1.6
core    IN A 192.235.1.7

www     IN CNAME penny.iqbal.com.
static  IN CNAME abbey.iqbal.com.
DNS

echo "[4] Check zone"
named-checkzone iqbal.com "$ZONE"

echo ""
echo "SOAL 4 MASTER SELESAI"

;;

tedd)

echo "======================================"
echo "SOAL 4 - DNS SLAVE"
echo "======================================"

apk add --no-cache bind bind-tools

mkdir -p /var/bind

cat > /etc/bind/named.conf.options <<'CONF'
options {
    directory "/var/bind";
    pid-file "/var/run/named/named.pid";

    forwarders {
        192.168.122.1;
    };

    dnssec-validation no;

    listen-on { any; };
    listen-on-v6 { none; };

    allow-query { any; };
    allow-recursion { any; };

    recursion yes;
};
CONF

cat > /etc/bind/named.conf.local <<'CONF'
zone "iqbal.com" {
    type slave;
    file "/var/bind/db.iqbal.com";
    masters { 192.235.1.2; };
};
CONF

echo ""
echo "Slave configuration selesai."
echo "Zone akan ditransfer dari Prab."

;;

*)
echo "Node $HOST tidak digunakan untuk Soal 4."
;;

esac
EOF