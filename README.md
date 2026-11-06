<div align="center">

# 🛡️ aaPanel WP Hardening & FIM Monitor

[![Bash](https://img.shields.io/badge/Script-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)]()
[![OS](https://img.shields.io/badge/OS-Ubuntu_24.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)]()
[![Panel](https://img.shields.io/badge/Panel-aaPanel-20A53A?style=flat-square)]()
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)]()

*Skrip Otomatisasi Immutable Filesystem & Pemantauan Integritas File (FIM) via Telegram untuk WordPress di aaPanel.*

</div>

---

## ✨ Fitur Utama

- 🔒 **Immutable Core:** Mengunci sistem file WordPress (`wp-admin`, `wp-includes`, `.php`) dari modifikasi malware menggunakan hak akses `root` dan atribut `chattr +i`.
- 🚨 **Telegram FIM:** Notifikasi *real-time* jika ada perubahan file `.php` atau `.html` (deteksi backdoor).
- 🛑 **Nginx Proxy Firewall:** Otomatis menginjeksi *rule* Nginx untuk memblokir eksekusi PHP di folder `wp-content/uploads`.
- 🕒 **Timezone Sync:** Konfigurasi otomatis zona waktu server (Asia/Jakarta) dengan NTP lokal.

---

## 📋 Prasyarat

Sebelum menjalankan skrip ini, pastikan Anda memiliki:
1. Akses **Root** ke server Ubuntu.
2. aaPanel terinstal dengan Nginx.
3. Direktori instalasi WordPress yang valid.
4. **Token Bot Telegram** & **Chat ID** (untuk fitur notifikasi).

---

## 🚀 Instalasi Cepat (One-Liner)

Jalankan perintah ini di terminal server Anda untuk mengunduh dan mengeksekusi skrip secara otomatis:

```bash
bash <(curl -sL [https://raw.githubusercontent.com/UsernameAnda/RepoAnda/main/wp-harden.sh](https://raw.githubusercontent.com/UsernameAnda/RepoAnda/main/wp-harden.sh))
