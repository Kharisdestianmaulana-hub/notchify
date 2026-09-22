# Design System Document: Notchify

## 1. Design Principles & Vision

Sistem desain **Notchify** dirancang untuk menyatukan estetika *Apple Hardware Blend* dengan fungsionalitas utilitas desktop modern. Prinsip utamanya adalah membuat antarmuka Notchify terasa seperti ekstensi fisik layar:

* **Organic & Fluid:** Transisi ukuran, bentuk, dan visibilitas terasa kenyal (*elastic spring*), tidak kaku atau sekadar memudar (*fade*).

* **High Contrast & Clarity:** Mengutamakan permukaan gelap pekat (*true pitch black*) dengan teks dan aksen warna kontras tinggi agar elemen terbaca sekilas (*glanceable*).

* **Non-Intrusive:** Kehadiran visual sekecil mungkin saat diam, hanya menampilkan detail fungsional saat kursor diarahkan ke area Notchify (*hover-on-demand*).

## 2. Color Palette & Surface Tokens

### 2.1 Core Surfaces

* **Canvas / Body:** `#000000` (Solid true black, selaras dengan warna fisik bezel dan modul kamera MacBook).

* **Surface Secondary (Cards/Sub-containers):** `#1A1A1E` (Translucent dark gray, opacity 80%).

* **Surface Hover / Highlight:** `#2C2C30` (Aksen saat hover pada tombol atau baris list).

* **Border Subtil:** `rgba(255, 255, 255, 0.08)` (Garis tepi tipis 0.5px untuk memisahkan kapsul dari wallpaper gelap pada monitor eksternal).

### 2.2 Functional Accents

* **Accent Active / System:** `#0A84FF` (Apple System Blue untuk toggle, slider, dan indikator aktif).

* **Accent Music / Waveform:** `#30D158` (Spotify Green) / `#FA2D48` (Apple Music Red).

* **Accent Warning / Timer End:** `#FF9F0A` (Orange amber untuk status peringatan atau timer habis).

* **Accent File Shelf Drop:** `#BF5AF2` (Purple highlight untuk visual cue area drop target Notchify).

### 2.3 Typography & Content Colors

* **Label Primary:** `#FFFFFF` (100% white, teks judul, durasi utama).

* **Label Secondary:** `rgba(255, 255, 255, 0.65)` (Sub-detail, nama artis, ukuran file).

* **Label Tertiary / Disabled:** `rgba(255, 255, 255, 0.35)` (Placeholder kalkulator, status idle).

## 3. Typography Hierarchy

Menggunakan sistem font native **San Francisco (SF Pro)** dengan rendering monospaced pada elemen angka:

| Peran UI | Ukuran Font | Weight | Tracking / Notes | 
 | ----- | ----- | ----- | ----- | 
| **Headline / Track Title** | 13pt | Semi-Bold (`.semibold`) | Truncate tail jika melebihi batas container | 
| **Body / Subtitle** | 11pt | Regular (`.regular`) | Digunakan untuk nama artis, rincian file | 
| **Monospace Numbers** | 12pt | Medium (`.medium`) | Font design `.monospacedDigit` untuk timer & HUD volume | 
| **Micro Caption / Badges** | 9pt | Bold (`.bold`) | Huruf kapital untuk badge status & drop count | 
| **Quick Input (Calc)** | 14pt | Regular (`.regular`) | Font design `.monospaced` untuk input kalkulator | 

## 4. Layout Dimensions & Corner Radius

### 4.1 Dimension Presets

* **Compact / Idle State:**

  * Physical Notch: Lebar dinamis mengikuti modul kamera hardware, tinggi \~32px.

  * Floating Pill: `180px × 30px` (Lebar × Tinggi), margin atas `8px` dari batas menu bar.

* **Hover Expanded (Media / Standard):**

  * Lebar: `380px`

  * Tinggi: `120px`

* **Shelf Expanded (Drop Zone Multi-item):**

  * Lebar: `420px`

  * Tinggi: `160px`

* **Mini HUD Expansion (Volume / Brightness):**

  * Lebar: `260px`

  * Tinggi: `44px`

### 4.2 Corner Radii

* **Outer Shell (Compact):** `15px` (Menghasilkan bentuk kapsul simetris sempurna).

* **Outer Shell (Expanded):** `22px` (Kontur membulat modern khas jendela sistem macOS).

* **Inner Containers / Album Art:** `8px` (Radius lembut pada sub-elemen seperti cover album atau kartu file).

* **Action Buttons:** `6px` atau pill penuh (`Circle()`).

## 5. Animation & Motion Guidelines

* **Expand Animation:**

  ```
  .spring(response: 0.38, dampingFraction: 0.72, blendDuration: 0)
  
  
  ```

  Menghasilkan efek membal (*elastic snap*) saat kursor menyentuh area Notchify.

* **Collapse Animation:**

  ```
  .spring(response: 0.30, dampingFraction: 0.85, blendDuration: 0)
  
  
  ```

  Menutup lebih cepat dan minim pantulan agar terasa cekatan (*snappy dismissal*).

* **Drop Zone Bounce (File Drop):**
  Skala sedikit membesar `1.03x` selama `0.15s` lalu kembali normal saat file dilepas ke area Notchify.

* **Waveform Rhythm:**
  Interpolasi nilai acak tiap `0.12s` dengan transisi `.easeInOut(duration: 0.1)`.

## 6. Component Specs

### 6.1 Media Card

* **Artwork:** Cover album berukuran `48px × 48px`, corner radius `8px`.

* **Metadata & Scrubber:** Judul lagu (13pt Semi-Bold) dan Artis (11pt Regular) disusun vertikal, disertai scrubber playback ramping tinggi `3px`.

* **Controls:** Kluster tombol kontrol Play/Pause dan Next berukuran `24px × 24px`.

### 6.2 Temporary Shelf Item Card

* Thumbnail preview file `36px × 36px` dengan icon native sesuai tipe ekstensi.

* File name label maksimal 1 baris di bawah thumbnail.

* Badge counter di pojok kanan atas shelf saat lebih dari 3 file ditampung.

### 6.3 System HUD Bar

* Ikon speaker / kecerahan di sisi kiri (`16px × 16px`).

* Horizontal progress track tinggi `6px` dengan background `#2C2C30` dan isian putih (`#FFFFFF`).

* Persentase numerik monospaced di ujung kanan.

### 6.4 Clipboard Stack Item

* Baris horizontal dengan tinggi kontainer `28px`, padding horizontal `8px`, corner radius `6px`.

* Background default transparan, berubah menjadi `#2C2C30` saat kursor berada di atasnya (*hover*).

* Label teks dibatasi 1 baris (*single-line truncate*) menggunakan SF Pro Regular 11pt.

* Ikon copy di ujung kanan berukuran `12px × 12px` dengan opasitas 50%.

### 6.5 Pomodoro & Quick Tool Capsule

* **Timer Mode:** Tampilan ringkas di mode *Compact* berupa dot oranye berdenyut pelan (`#FF9F0A`) di samping angka `MM:SS` berukuran 11pt monospaced.

* **Color Eyedropper:** Tombol lingkaran mini `24px × 24px` dengan border `0.5px rgba(255, 255, 255, 0.15)`. Menampilkan preview warna aktif di tengah dan teks kode HEX saat diperluas.

* **Single-Line Calc Bar:** Input box tinggi `30px`, teks monospaced 12pt putih, background `#1A1A1E` dengan sudut membulat `8px`.

## 7. Accessibility & Interactions

* **Hover Debounce:** Delay toleransi `120ms` saat kursor keluar (*mouseExited*) sebelum notch menciut kembali ke mode ringkas, mencegah panel tertutup tanpa sengaja.

* **Visual Cue Drop Zone:** Saat mendeteksi kursor sedang menyeret file (`isTargeted = true`), garis tepi Notchify berubah menjadi aksen ungu (`#BF5AF2`) dengan ketebalan `1.5px` dan denyut lembut.

* **Reduced Motion:** Jika fitur *Reduce Motion* sistem aktif (`NSWorkspace.accessibilityDisplayShouldReduceMotion`), ganti kurva animasi spring kenyal dengan transisi fade standar `.easeInOut(duration: 0.18)`.