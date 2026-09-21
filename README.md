<div align="center">
  <h1>Notchify</h1>
  <p><b>Bring the Dynamic Island experience to any Mac!</b></p>
  <p><i>Bawa pengalaman Dynamic Island ke semua Mac!</i></p>
</div>

---

## English Version

### About The Project
**Notchify** is a sleek and highly customizable macOS utility application that brings an interactive "Dynamic Island" style overlay to the top-center of your screen. Built natively with SwiftUI and AppKit, Notchify acts as a productivity hub that expands smoothly to reveal various mini-apps and system indicators, keeping your workspace clean and efficient.

### Key Features
*   **Juicy Blossom Animations:** Fluid, spring-based physics for expanding and collapsing the notch.
*   **Bilingual Support:** Fully translated in English and Indonesian, toggleable on the fly from Settings.
*   **Smart Fullscreen Detection:** Automatically slides up and hides itself when you enter fullscreen mode in apps like YouTube or Netflix, and bounces back down when you exit.
*   **Global Keyboard Shortcut:** Instantly summon or dismiss Notchify from anywhere using `Cmd + Shift + N`.
*   **Customizable Triggers:** Choose between hovering over the top edge or clicking directly to expand the Notch.
*   **Modular Mini-Apps:** 
    *   **Media:** Shows current playing music info.
    *   **Clipboard Manager:** Keeps track of your recently copied text, images, and files.
    *   **Dropzone:** A temporary holding space to drag and drop files.
    *   **Pomodoro Timer:** Stay focused with 25m/5m timers.
    *   **System Monitor:** Real-time CPU and RAM usage tracking.
    *   **Weather:** Current temperature and conditions.
    *   **Agenda & Events:** Built-in event manager for daily planning.
    *   **Calculator:** Quick math without opening the main app.
*   **Modern Settings UI:** Drag-and-drop to reorder tabs, adjust glass transparency, toggle glow effects, and manage permissions.

### Installation & Build
Notchify is built for macOS 12.0 and above. To compile it locally:

```bash
# 1. Clone the repository
git clone https://github.com/Kharisdestianmaulana-hub/notchify.git
cd notchify

# 2. Build using xcodebuild
xcodebuild build -project Notchify.xcodeproj -scheme Notchify -configuration Debug -derivedDataPath $(PWD)/DerivedData SYMROOT=$(PWD)/build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. Apply Ad-Hoc Code Signature (Required for accessibility features)
codesign --force --deep -s - ./build/Debug/Notchify.app

# 4. Run the App!
open ./build/Debug/Notchify.app
```

### Permissions Required
To function properly, Notchify requests the following macOS permissions:
*   **Accessibility:** Required for the global keyboard shortcut (`Cmd+Shift+N`).
*   **Screen Recording:** Required strictly to detect when other windows go into Fullscreen mode (so Notchify can auto-hide). *We do not record your screen content.*

---
<br/>

## Versi Indonesia

### Tentang Proyek
**Notchify** adalah aplikasi utilitas macOS elegan yang menghadirkan pengalaman "Dynamic Island" interaktif di bagian atas tengah layar Anda. Dibangun secara *native* menggunakan SwiftUI dan AppKit, Notchify berfungsi sebagai pusat produktivitas yang bisa mekar secara mulus untuk menampilkan berbagai aplikasi mini dan indikator sistem.

### Fitur Utama
*   **Animasi Mekar yang "Juicy":** Menggunakan pergerakan *spring physics* yang sangat halus (membal/bouncy) saat membuka dan menutup notch.
*   **Dukungan Dwibahasa (Bilingual):** Mendukung Bahasa Inggris dan Indonesia secara penuh yang dapat diubah langsung dari menu Pengaturan.
*   **Deteksi Fullscreen Otomatis:** Notchify akan otomatis meluncur ke atas (sembunyi) saat Anda menonton YouTube/Netflix dalam mode layar penuh, dan turun kembali saat selesai.
*   **Pintasan Keyboard Global:** Panggil atau sembunyikan Notchify dari mana saja cukup dengan menekan `Cmd + Shift + N`.
*   **Pemicu Bebas Atur:** Pilih apakah Notch ingin dibuka dengan cara disentuh kursor (*Hover*) atau diklik langsung (*Click*).
*   **Aplikasi Mini Modular:** 
    *   **Media:** Menampilkan info musik yang sedang diputar.
    *   **Clipboard Manager:** Menyimpan riwayat teks, gambar, dan file yang baru saja disalin.
    *   **Dropzone:** Tempat penampungan sementara untuk drag & drop file.
    *   **Pomodoro Timer:** Tetap fokus dengan timer 25m/5m.
    *   **Pemantau Sistem:** Melacak penggunaan CPU dan RAM secara real-time.
    *   **Cuaca:** Info suhu dan kondisi cuaca saat ini.
    *   **Agenda & Jadwal:** Manajer acara bawaan untuk aktivitas harian Anda.
    *   **Kalkulator:** Hitung cepat tanpa perlu buka aplikasi kalkulator.
*   **UI Pengaturan Modern:** Geser (*drag & drop*) untuk mengatur urutan tab, ubah transparansi kaca, aktifkan efek cahaya (*Glow*), dan kelola perizinan dengan mudah.

### Instalasi & Build
Notchify dirancang untuk macOS 12.0 ke atas. Cara kompilasi lokal:

```bash
# 1. Clone repositori ini
git clone https://github.com/Kharisdestianmaulana-hub/notchify.git
cd notchify

# 2. Build menggunakan xcodebuild
xcodebuild build -project Notchify.xcodeproj -scheme Notchify -configuration Debug -derivedDataPath $(PWD)/DerivedData SYMROOT=$(PWD)/build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. Terapkan Ad-Hoc Code Signature (Wajib agar fitur shortcut & integrasi sistem berjalan)
codesign --force --deep -s - ./build/Debug/Notchify.app

# 4. Jalankan Aplikasinya!
open ./build/Debug/Notchify.app
```

### Izin Sistem (Permissions)
Agar bekerja maksimal, Notchify membutuhkan izin berikut:
*   **Aksesibilitas (Accessibility):** Diperlukan agar pintasan keyboard global (`Cmd+Shift+N`) dapat mendeteksi ketikan di aplikasi apa pun.
*   **Perekaman Layar (Screen Recording):** Hanya digunakan secara ketat untuk mendeteksi apakah ada jendela aplikasi lain yang sedang *Fullscreen* (sehingga Notchify bisa otomatis sembunyi). *Aplikasi ini tidak pernah merekam isi layar Anda.*
