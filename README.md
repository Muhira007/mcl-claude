# 🌟 Mcl (MiMo Claude Code Wrapper)

> Jalankan **[Claude Code](https://docs.claude.com/en/docs/claude-code)** menggunakan teknologi terdepan dari **[Xiaomi MiMo API](https://mimo.mi.com)** yang sepenuhnya kompatibel dengan protokol Anthropic.

---

## 📖 Apa itu Mcl?

**Mcl** adalah script perantara (_wrapper_) canggih yang memungkinkan Anda untuk menggunakan CLI resmi Claude Code dari Anthropic, namun dengan me- _routing_ semua permintaan _(request)_ ke server **Xiaomi MiMo**. 

Claude Code pada dasarnya hanya mendukung Anthropic, tetapi dengan Mcl, Anda bisa menikmati model bahasa raksasa **mimo-v2.5** (dengan konteks hingga 1 Juta token!) baik menggunakan mode pembayaran reguler maupun paket berlangganan.

### ✨ Fitur Unggulan

- 🧠 **Dukungan Penuh Model MiMo-v2.5**: Model _flagship_ berkemampuan tinggi dengan context window 1M untuk analisis _codebase_ berskala besar.
- 💳 **Auto-Detect Token Plan (Subscription)**: Mcl secara pintar mendeteksi jenis API Key Anda. Jika menggunakan token berlangganan (`tp-xxxxx`), aplikasi akan otomatis mengarahkan koneksi ke endpoint Token Plan khusus. Jika menggunakan token standar (`sk-xxxxx`), rute otomatis diarahkan ke Pay-As-You-Go.
- 🛡️ **Safe Mode Terintegrasi**: Cegah eksekusi _shell_ berbahaya tanpa konfirmasi saat Anda berada di direktori yang tidak dipercaya.
- 🩺 **Mcl Doctor & Verify**: Diagnosis masalah sistem dan validasi kesehatan koneksi API Key ke server MiMo hanya dengan satu perintah.
- 🔄 **Otomatis Update**: Tinggal ketik `mcl update` untuk selalu mendapatkan versi terbaru.

---

## 📦 Instalasi

Pastikan Anda sudah menginstal [Claude Code](https://docs.claude.com/en/docs/claude-code) dan **Node.js** di perangkat Anda sebelum menginstal Mcl.

### 🍎 macOS / 🐧 Linux
Jalankan perintah ini di terminal Anda:
```bash
curl -fsSL https://raw.githubusercontent.com/Muhira007/mcl-claude/main/install.sh | bash
```

### 🪟 Windows (PowerShell)
Buka PowerShell (disarankan Run as Administrator) lalu eksekusi:
```powershell
irm https://raw.githubusercontent.com/Muhira007/mcl-claude/main/install.ps1 | iex
```

---

## 🚀 Memulai Penggunaan

Sangat mudah! Buka terminal Anda dan ketikkan perintah pertama:

```bash
mcl
```

Mcl akan meminta Anda untuk memasukkan **MiMo API Key** untuk pertama kalinya. 
Anda dapat mengambil API Key Anda di konsol [Xiaomi MiMo Open Platform](https://mimo.mi.com/manage-apikey/apikey-list). 
Mcl mendukung dua format kunci:
1. **Reguler / Pay-As-You-Go** (contoh: `abc123xyz.abcdefghijklmnopqrstuvwxyz`)
2. **Token Plan / Berlangganan** (contoh: `tp-abc123xyz.abcdefghijkl`)

Setelah berhasil, Anda cukup memanggil `mcl` dengan prompt layaknya memanggil `claude`:
```bash
mcl "tolong perbaiki bug di src/auth.js"
mcl --safe "refactor seluruh file di folder utils"
```

---

## 🛠️ Daftar Perintah (Commands)

| Perintah | Deskripsi |
|----------|-----------|
| `mcl config [KEY]` | Memasukkan atau mengubah API Key secara langsung. |
| `mcl verify` | Memeriksa validitas API Key langsung ke server MiMo. |
| `mcl model` | Memilih model MiMo (v2.5, Flash, dsb.) secara interaktif. |
| `mcl doctor` | Menjalankan pemeriksaan kesehatan pada lingkungan sistem Anda. |
| `mcl update` | Memperbarui Mcl ke rilis versi terbaru dari repositori GitHub. |
| `mcl reset` | Menghapus kunci API yang tersimpan di sistem lokal. |
| `mcl clean` | Membersihkan memori / cache memori dari Claude Code di proyek lokal. |
| `mcl alias [huruf]` | Membuat _shortcut_ shell yang sangat ringkas (contoh: jadikan `c` sebagai alias dari `mcl`). |
| `mcl show-config`| Melihat konfigurasi Base URL, Timeout, dan Token tersembunyi Anda saat ini. |

---

## ⚙️ Cara Kerja & Arsitektur

Mcl mengalihkan aliran (traffic) _Anthropic Messages API_ dengan melakukan override pada Environment Variables sebelum binary `claude` dijalankan.

```
Mcl mengekspor variabel ini ➜ Claude CLI membacanya ➜ Request dikirim ke MiMo 
```

Variabel yang diubah mencakup:
- `ANTHROPIC_BASE_URL` (Diatur dinamis ke `https://api.mimo.mi.com/v1` atau `https://token-plan-sgp.xiaomimimo.com/anthropic` bergantung pada jenis key Anda).
- `ANTHROPIC_AUTH_TOKEN` (API Key Anda)
- `ANTHROPIC_DEFAULT_OPUS_MODEL`, `SONNET`, `HAIKU` (Diubah menjadi `mimo-v2.5`)
- `API_TIMEOUT_MS` (Diatur hingga 50 menit guna menunjang tugas _long-thinking_ dan konteks masif)

---

## 🔐 Privasi dan Keamanan
Semua _API Key_ Anda dienkripsi (secara izin OS `chmod 600`) dan disimpan murni di mesin lokal Anda. Mcl tidak melakukan *tracking* ataupun mengirim telemetri. Data Anda hanya berjalan dua arah antara komputer lokal dan endpoint resmi Xiaomi MiMo.

---

> Dibuat dan dikelola oleh [Muhira007](https://github.com/Muhira007) | Repositori resmi: [mcl-claude](https://github.com/Muhira007/mcl-claude)
