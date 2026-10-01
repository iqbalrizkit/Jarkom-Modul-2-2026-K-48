# 1. Kembalikan konfigurasi abbey seperti semula
sed -i 's/^abbey[[:space:]]*15[[:space:]]*A[[:space:]]*.*/abbey   IN      A       192.235.2.2/' /etc/bind/db.iqbal.com

# 2. Naikkan serial dari 9 menjadi 10
sed -i 's/^[[:space:]]*9[[:space:]]*; Serial/                              10        ; Serial/' /etc/bind/db.iqbal.com

# 3. Cek konfigurasi
grep -E 'abbey|outbound|Serial' /etc/bind/db.iqbal.com

# 4. Validasi zone
named-checkzone iqbal.com /etc/bind/db.iqbal.com

# 5. Buat startup script agar named otomatis berjalan saat node start
cat > /root/init.sh <<'EOF'
#!/bin/sh
named
EOF

# 6. Berikan permission executable
chmod +x /root/init.sh

# 7. Cek named sedang berjalan
pidof named

# 8. Restart node prab melalui GNS3:
#    Stop prab → Start prab → buka console kembali

# 9. Setelah prab hidup kembali, cek named
pidof named

# 10. Pastikan konfigurasi nomor 19 tetap berjalan setelah restart
dig @192.235.1.2 outbound.iqbal.com A +noall +answer