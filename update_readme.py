import re

with open('README.md', 'r', encoding='utf-8') as f:
    text = f.read()

features = """### 5 Fitur Utama Zcl (v1.1.0)
1. **Auto-Install Claude Code**: Jika belum terpasang, Zcl akan menawarkan instalasi otomatis via npm.
2. **zcl doctor**: Melakukan cek kesehatan sistem, API key, Node.js, dan koneksi internet ke server Z.ai.
3. **zcl clean**: Membersihkan cache / memori chat Claude lama agar tidak halusinasi atau context full.
4. **zcl alias**: Membuat shortcut terminal secara instan (misal `zcl alias c`, cukup ketik `c` ke depannya).
5. **Auto-Update Checker**: Notifikasi elegan saat ada versi Zcl terbaru di GitHub.

"""
text = text.replace("## ⚡ Instalasi Cepat\n", features + "## ⚡ Instalasi Cepat\n")

# Update subcommands table
subcmd_old = """| 1 | `zcl config <KEY>` | Diset langsung via CLI, tanpa prompt |
| 2 | `~/.config/zcl/config` | Key yang disimpan dari run sebelumnya |"""
subcmd_new = """| Perintah Tambahan | Fungsi |
|-------------------|--------|
| `zcl model` | Memilih model Z.ai secara interaktif |
| `zcl doctor` | Cek status sistem, koneksi, & API key |
| `zcl clean` | Hapus direktori memori `.claude` lokal |
| `zcl alias [c]` | Mendaftarkan shortcut Zcl di Bash/PowerShell |

| Prioritas | Sumber | Keterangan |
|-----------|--------|------------|
| 1 | `zcl config <KEY>` | Diset langsung via CLI, tanpa prompt |
| 2 | `~/.config/zcl/config` | Key yang disimpan dari run sebelumnya |"""
text = text.replace(subcmd_old, subcmd_new)

with open('README.md', 'w', encoding='utf-8') as f:
    f.write(text)
