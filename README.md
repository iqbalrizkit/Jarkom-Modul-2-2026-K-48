1.
```sh
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
  address 192.235.1.1
  netmask 255.255.255.0

auto eth2
iface eth2 inet static
  address 192.235.2.1
  netmask 255.255.255.0

auto eth3
iface eth3 inet static
  address 192.235.3.1
  netmask 255.255.255.0

auto eth4
iface eth4 inet static
  address 192.235.4.1
  netmask 255.255.255.0

auto eth5
iface eth5 inet static
  address 192.235.5.1
  netmask 255.255.255.0
```

alpha
```sh
auto eth0
iface eth0 inet static
  address 192.235.1.2
  netmask 255.255.255.0
  gateway 192.235.1.1
```

beta
```sh
auto eth0
iface eth0 inet static
  address 192.235.1.3
  netmask 255.255.255.0
  gateway 192.235.1.1
```

gamma
```sh
auto eth0
iface eth0 inet static
  address 192.235.1.4
  netmask 255.255.255.0
  gateway 192.235.1.1
```

delta
```sh
auto eth0
iface eth0 inet static
  address 192.235.2.2
  netmask 255.255.255.0
  gateway 192.235.2.1
```

epsilon
```sh
auto eth0
iface eth0 inet static
  address 192.235.2.3
  netmask 255.255.255.0
  gateway 192.235.2.1
```

abbey
```sh
auto eth0
iface eth0 inet static
  address 192.235.3.2
  netmask 255.255.255.0
  gateway 192.235.3.1
```

penny
```sh
auto eth0
iface eth0 inet static
  address 192.235.4.2
  netmask 255.255.255.0
  gateway 192.235.4.1
```

prab
```sh
auto eth0
iface eth0 inet static
  address 192.235.5.2
  netmask 255.255.255.0
  gateway 192.235.5.1
```

tedd
```sh
auto eth0
iface eth0 inet static
  address 192.235.5.3
  netmask 255.255.255.0
  gateway 192.235.5.1
```

obladi
```sh
auto eth0
iface eth0 inet static
  address 192.235.5.4
  netmask 255.255.255.0
  gateway 192.235.5.1
```

desmond
```sh
auto eth0
iface eth0 inet static
  address 192.235.5.5
  netmask 255.255.255.0
  gateway 192.235.5.1
```

oblada
```sh
auto eth0
iface eth0 inet static
  address 192.235.5.6
  netmask 255.255.255.0
  gateway 192.235.5.1
```

molly
```sh
auto eth0
iface eth0 inet static
  address 192.235.5.7
  netmask 255.255.255.0
  gateway 192.235.5.1
```

4. install bind dan bind-tools
   ```sh
   apk update
   apk add bind bind-tools
   mkdir /etc/bind/jarkom
   nano /etc/bind/named.conf.local
           zone "iqbal.com" {
            type master;
            notify yes;
            also-notify { 192.235.1.3; };
            allow-transfer { 192.235.1.3; };
            file "/etc/bind/jarkom/iqbal.com";
           };
   nano /etc/bind/jarkom/iqbal.com
   $TTL    604800
    @       IN      SOA     prab.iqbal.com. root.iqbal.com. (
                            2026092801 ; Serial
                            604800     ; Refresh
                            86400      ; Retry
                            2419200    ; Expire
                            604800 )   ; Negative Cache TTL
    ;
    @       IN      NS      prab.iqbal.com.
    @       IN      NS      tedd.iqbal.com.
    prab    IN      A       192.235.1.2
    tedd    IN      A       192.235.1.3
    @       IN      A       192.235.3.2
   
   nano /etc/bind/named.conf.options
   options {
    directory "/var/bind";
    forwarders {
        192.168.122.1;
    };
    dnssec-validation no;
    allow-query { any; };
    auth-nxdomain no;
    listen-on-v6 { any; };
    };
   mkdir -p /var/bind

   nano /etc/bind/named.conf
   ```

   
