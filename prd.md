# Product Requirement Document (PRD): Notchify

## 1. Overview & Objectives
**Notchify** adalah utilitas antarmuka cerdas berbasis macOS yang menghadirkan interaksi fungsional bergaya *Dynamic Island* di area tengah atas layar. Notchify dirancang sebagai panel mengambang yang sangat responsif untuk kontrol media, staging area file sementara, visualisasi status sistem HUD, produktivitas, serta quick tools tanpa menginterupsi alur kerja pengguna.

Target deployment Notchify diatur secara spesifik untuk **macOS 12.0 (Monterey)** ke atas, memastikan kompatibilitas penuh baik pada laptop MacBook dengan notch fisik maupun layar flat/eksternal.

---

## 2. Technical Scope & System Constraints
* **Product Name:** Notchify
* **Bundle Identifier:** `com.notchify.app`
* **Minimum OS:** macOS 12.0 Monterey (Tanpa dependensi API macOS 13+ seperti `MenuBarExtra` baru)
* **Arsitektur Binary:** Universal Binary (Apple Silicon ARM64 & Intel x86_64)
* **Bahasa & UI Framework:** Swift 5.5+, SwiftUI (macOS 12 compatible), AppKit (`NSPanel`)
* **Background Footprint:** Konsumsi memori idle < 50 MB, CPU idle < 0.5%
* **Privasi & Izin:** Aksesibilitas (Accessibility API) opsional untuk overlay HUD, seluruh data pasteboard & file hanya disimpan di RAM lokal tanpa network telemetry.

---

## 3. UI/UX States & Adaptive Layout

### 3.1 Adaptive Notch Detection
* **Physical Notch Mode:** Notchify mendeteksi `auxiliaryTopLeftArea` dan `auxiliaryTopRightArea` dari `NSScreen.main`. Panel terikat tepat di bawah dan di samping modul kamera hardware.
* **Floating Pill Mode:** Fallback otomatis saat tidak ada notch fisik (MacBook bezel klasik, iMac, atau monitor eksternal). Menampilkan kapsul hitam melayang dengan jarak ~8px dari menu bar.

### 3.2 Display States
* **Compact / Idle State:** Bentuk kapsul hitam minimalis yang menampilkan indikator kontekstual kecil (misal: visualizer musik, ikon file saat drag, atau hitung mundur timer).
* **Hover / Expanded State:** Panel melebar halus secara horizontal dan vertikal saat kursor mendekat/berada di atas area notch menggunakan kurva animasi spring kenyal.
* **Lock / Pin Mode:** Opsi pin agar panel Notchify tetap terbuka saat berinteraksi intensif.

---

## 4. Comprehensive Feature Specifications

### 4.1 Live Media Controller & Waveform
* **Integrasi:** Apple Music dan Spotify via `DistributedNotificationCenter` (`com.apple.Music.playerInfo` / `com.spotify.client.PlaybackStateChanged`) serta AppleScript bridge.
* **Tampilan:** Artwork album mini, judul lagu, nama artis, scrubber durasi, dan tombol navigasi (*Play/Pause*, *Next*, *Prev*).
* **Audio Waveform:** Efek gelombang animasi minimalis yang aktif hanya ketika audio berstatus *Playing*.

### 4.2 Temporary File Shelf (Drop Zone)
* **Staging Area:** Menjadi drop-target sementara untuk file dari Finder atau browser.
* **Drag & Drop Workflow:** Pengguna men-drag file ke notch saat melintasi workspace/desktop, lalu men-drag keluar file tersebut ke aplikasi tujuan (Telegram, browser upload form, folder lain).
* **Multi-item Support:** Penampungan batch file dengan badge counter dan preview thumbnail kecil.

### 4.3 Minimalist Clipboard History
* **Stack Ringkas:** Menyimpan 3–5 riwayat cuplikan teks terakhir dari `NSPasteboard.general`.
* **Quick Action:** Klik tunggal pada cuplikan untuk mengembalikan teks tersebut ke clipboard utama dan siap di-paste.
* **Pembersihan Otomatis:** Tombol hapus riwayat atau auto-clear saat aplikasi ditutup demi privasi.

### 4.4 System HUD Replacements (Volume & Brightness)
* Menggantikan HUD default macOS yang besar di tengah layar dengan animasi ramping yang mengembang langsung dari notch.
* Slider visual vertikal/horizontal saat tombol fungsi keyboard (F1-F3, F10-F12) ditekan.
* Menggunakan event listener lokal via `CGEventTap` atau deteksi perubahan audio default.

### 4.5 Live Focus / Pomodoro Timer
* Timer hitung mundur terintegrasi untuk siklus kerja (misal: 25 menit kerja, 5 menit istirahat).
* Tampilan ringkas di mode *Compact* (format `MM:SS`) tanpa menyita ruang menu bar.
* Notifikasi suara halus dan visual pulse pada Notchify saat waktu habis.

### 4.6 Quick Tools Suite
* **Color Eyedropper:** Alat pipet warna cepat yang membaca pixel layar (`NSColorSampler`) dan langsung menyalin format HEX/RGB ke clipboard.
* **Single-Line Quick Calculator:** Input ekspresi matematika sederhana (contoh: `24*15` atau `120/4`) dengan hasil instan tanpa membuka aplikasi Calculator terpisah.
* **Battery & Accessory Status:** Tampilan persentase baterai laptop serta status perangkat Bluetooth terkoneksi (misal: AirPods / mouse Bluetooth) via `IOKit`.

---

## 5. Technical Architecture & Implementation Details (macOS 12)

### 5.1 Window Hierarchy (`NSPanel`)
* Subclass `NSPanel` dengan konfigurasi:
  * `styleMask: [.nonactivatingPanel, .borderless]` (tidak mencuri focus aplikasi lain yang sedang diketik).
  * `level: .mainMenu + 1` (melayang di atas menu bar sistem).
  * `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]` (muncul konsisten di semua Space/Desktop dan aplikasi full screen).
  * `isOpaque = false`, `backgroundColor = .clear`.

### 5.2 Event & Power Management
* **Zero Timer Polling:** Seluruh pembaruan UI berbasis event listener atau publisher Combine.
* **Tracking Area:** Implementasi `NSTrackingArea` pada `NSView` container Notchify untuk mendeteksi `mouseEntered` dan `mouseExited` secara instan tanpa lag.