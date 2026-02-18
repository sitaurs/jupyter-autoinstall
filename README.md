# 🐍 Jupyter Auto-Installer

> **One command. Python + Jupyter Notebook = installed.**

Otomatis install Python, pip, dan Jupyter Notebook di Windows. Tinggal copy-paste satu baris, selesai.

---

## ⚡ Quick Install

Buka **PowerShell** (Run as Administrator), lalu paste:

```powershell
irm https://raw.githubusercontent.com/sitaurs/jupyter-autoinstall/main/install.ps1 | iex
```

Atau **download repo** lalu double-click `install.bat`.

---

## 🔧 Yang Dilakukan Script

| Step | Aksi |
|------|------|
| 1 | Cek apakah Python sudah terinstall |
| 2 | Download & install Python jika belum ada |
| 3 | Install & upgrade pip |
| 4 | Install Jupyter Notebook + package tambahan |
| 5 | Buat shortcut desktop (opsional) |
| 6 | Langsung buka Jupyter Notebook |

---

## ⚙️ Kustomisasi

Edit `config.json` untuk mengatur:

```json
{
  "python_version": "3.13.7",
  "install_dir": "C:\\Python313",
  "packages": ["notebook", "numpy", "pandas", "matplotlib"],
  "create_shortcut": true,
  "auto_launch": true
}
```

| Field | Deskripsi | Default |
|-------|-----------|---------|
| `python_version` | Versi Python yang diinstall | `3.13.7` |
| `install_dir` | Folder instalasi Python | `C:\Python313` |
| `packages` | Daftar pip packages | `["notebook"]` |
| `create_shortcut` | Buat shortcut di Desktop | `true` |
| `auto_launch` | Langsung buka Jupyter setelah install | `true` |

---

## 📁 Struktur Project

```
jupyter-autoinstall/
├── install.ps1    # Script utama (PowerShell)
├── install.bat    # Double-click wrapper (CMD)
├── config.json    # Konfigurasi
├── README.md      # Dokumentasi
├── LICENSE        # MIT License
└── .gitignore
```

---

## 🛠️ Cara Pakai Lainnya

### Clone & Run
```bash
git clone https://github.com/sitaurs/jupyter-autoinstall.git
cd jupyter-autoinstall
.\install.bat
```

### PowerShell Langsung
```powershell
.\install.ps1
```

### Tanpa Clone (One-liner)
```powershell
irm https://raw.githubusercontent.com/sitaurs/jupyter-autoinstall/main/install.ps1 | iex
```

---

## 📋 Requirements

- **OS:** Windows 10/11
- **Terminal:** PowerShell 5.1+ atau CMD
- **Internet:** Diperlukan untuk download Python & packages
- **Admin:** Disarankan Run as Administrator

---

## 📜 License

[MIT](LICENSE)
