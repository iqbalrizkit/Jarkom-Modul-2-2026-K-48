# Backup database DNS
cp /etc/bind/db.iqbal.com /etc/bind/db.iqbal.com.bak

# Ubah A record abbey menjadi IP fiktif dengan TTL 15 detik
sed -i 's/^abbey[[:space:]]*IN[[:space:]]*A[[:space:]]*.*/abbey   15      A       203.0.113.77/' /etc/bind/db.iqbal.com

# Naikkan serial dari 7 menjadi 8
sed -i 's/^[[:space:]]*7[[:space:]]*; Serial/                              8         ; Serial/' /etc/bind/db.iqbal.com

# Cek konfigurasi zone
named-checkzone iqbal.com /etc/bind/db.iqbal.com

# Reload BIND
kill -HUP $(pidof named)

# Cek IP baru dari DNS authoritative
dig @127.0.0.1 abbey.iqbal.com A +noall +answer

# Cek cache resolver
dig @192.168.122.1 abbey.iqbal.com A +noall +answer