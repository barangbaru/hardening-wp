#!/bin/bash

# ==========================================
# aaPanel WordPress Ultimate Hardening Script
# ==========================================

# 0. Pastikan dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Script ini harus dijalankan sebagai root (sudo -i)"
  exit 1
fi

echo "=========================================="
echo "  Mulai Proses Hardening & Monitoring WP  "
echo "=========================================="

# 1. Prompt Input dari User
read -p "Masukkan Target Direktori WP (contoh: /www/wwwroot/domain.com): " WP_DIR
if [ ! -d "$WP_DIR" ]; then
  echo "❌ Error: Direktori $WP_DIR tidak ditemukan!"
  exit 1
fi

read -p "Masukkan Nama Domain di aaPanel (contoh: domain.com): " DOMAIN_NAME
NGINX_CONF="/www/server/panel/vhost/nginx/${DOMAIN_NAME}.conf"

if [ ! -f "$NGINX_CONF" ]; then
  echo "❌ Error: File konfigurasi Nginx $NGINX_CONF tidak ditemukan!"
  exit 1
fi

read -p "Masukkan Telegram Bot Token: " TG_TOKEN
read -p "Masukkan Telegram Chat ID: " TG_CHAT_ID

echo "------------------------------------------"
echo "⏳ [1/4] Mengatur Timezone Server (Asia/Jakarta)..."
timedatectl set-timezone Asia/Jakarta
timedatectl set-ntp on
systemctl restart systemd-timesyncd
echo "✅ Timezone diatur ke Asia/Jakarta (WIB)."

echo "------------------------------------------"
echo "⏳ [2/4] Setup Telegram File Monitor..."
# Instal dependensi jika belum ada
apt-get update -qq
apt-get install inotify-tools curl awk -y -qq

# Cek apakah script monitor sudah ada
if [ -f "/root/monitor-file.sh" ]; then
  echo "⚠️  Script /root/monitor-file.sh sudah ada. Melompati pembuatan file."
else
  echo "⏳ Membuat /root/monitor-file.sh baru..."
  cat << EOF > /root/monitor-file.sh
#!/bin/bash
TARGET_DIR="${WP_DIR}"
TOKEN="${TG_TOKEN}"
CHAT_ID="${TG_CHAT_ID}"
SERVER_HOSTNAME=\$(hostname)
SERVER_IP=\$(curl -s --max-time 3 ipv4.icanhazip.com || hostname -I | awk '{print \$1}')

inotifywait -m -r -e modify,create,delete,move -q --format '%e %w%f' "\$TARGET_DIR" |
while read EVENT FILE; do
    if [[ "\$FILE" =~ \.(php|html)$ ]]; then
        if [[ "\$FILE" == *"wp-content/cache"* ]]; then continue; fi
        
        WAKTU=\$(date +'%Y-%m-%d %H:%M:%S')
        PESAN="🚨 *PERINGATAN PERUBAHAN FILE!*%0A%0A*Server:* \`\$SERVER_HOSTNAME\`%0A*IP:* \`\$SERVER_IP\`%0A*Waktu:* \$WAKTU%0A*Aksi:* \`\$EVENT\`%0A*File:* \`\$FILE\`"
        
        curl -s -X POST "https://api.telegram.org/bot\$TOKEN/sendMessage" \
            -d chat_id="\$CHAT_ID" \
            -d text="\$PESAN" \
            -d parse_mode="Markdown" > /dev/null
    fi
done
EOF
  chmod +x /root/monitor-file.sh
fi

# Buat dan aktifkan Systemd Service
cat << EOF > /etc/systemd/system/telegram-monitor.service
[Unit]
Description=Real-time File Integrity Monitor Telegram
After=network.target

[Service]
Type=simple
User=root
ExecStart=/bin/bash /root/monitor-file.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable telegram-monitor.service --now
systemctl restart telegram-monitor.service
echo "✅ Telegram Monitor berjalan di background (Service aktif)."

echo "------------------------------------------"
echo "⏳ [3/4] Eksekusi Immutable Hardening (chown & chattr)..."
cd "$WP_DIR"

# Buka kunci (unlock) sementara jika sebelumnya pernah dikunci agar proses chown tidak gagal
chattr -R -i wp-admin wp-includes *.php 2>/dev/null

# Terapkan kepemilikan root pada core
chown -R root:root wp-admin wp-includes *.php

# Kunci (Immutable) file spesifik dan direktori core
chattr +i wp-config.php
chattr +i index.php
chattr -R +i wp-admin/
chattr -R +i wp-includes/

# Kembalikan hak tulis ke folder uploads untuk www (user standar aaPanel Nginx/PHP)
if [ ! -d "wp-content/uploads" ]; then
  mkdir -p wp-content/uploads
fi
chattr -R -i wp-content/uploads 2>/dev/null
chown -R www:www wp-content/uploads

echo "✅ Immutable Filesystem WordPress berhasil diterapkan."

echo "------------------------------------------"
echo "⏳ [4/4] Injeksi Nginx Rule aaPanel..."

# Cek apakah blok hardening sudah ada agar tidak duplikat
if grep -q "WP-HARDENING-BLOCK" "$NGINX_CONF"; then
  echo "⚠️  Rule Nginx Hardening sudah terpasang. Melompati langkah ini."
else
  # Menggunakan AWK untuk menginjeksi blok Nginx tepat di atas include enable-php
  awk '/include enable-php/{
      print "    # [WP-HARDENING-BLOCK]"
      print "    location ~* /(?:wp-content/uploads|wp-content/cache|wp-content/upgrade|wp-includes)/.*\\.php$ {"
      print "        deny all;"
      print "        access_log off;"
      print "        log_not_found off;"
      print "    }"
  }1' "$NGINX_CONF" > "${NGINX_CONF}.tmp" && mv "${NGINX_CONF}.tmp" "$NGINX_CONF"
  
  # Reload Nginx aaPanel
  /etc/init.d/nginx reload
  echo "✅ Nginx berhasil diinjeksi dan di-reload."
fi

echo "=========================================="
echo " 🎉 SEMUA PROSES HARDENING SELESAI! 🎉 "
echo "=========================================="
