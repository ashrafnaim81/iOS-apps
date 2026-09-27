# Panduan Hantar v1.0 ke App Store — Sudoku Santai

Semua langkah boleh dibuat di iPhone melalui Safari di **https://appstoreconnect.apple.com**
(atau app **App Store Connect**). Salin teks di bawah terus ke medan yang berkenaan.

---

## 1. Maklumat App (App Information)

| Medan | Isi |
|---|---|
| Name | `Sudoku Santai: Classic Puzzle` |
| Subtitle | `Calm daily puzzles & a cat pal` |
| Primary Category | **Games → Puzzle** |
| Secondary Category | **Games → Board** |
| Content Rights | "This app does not contain, show, or access third-party content" |
| Age Rating | Jawab **None / No** untuk semua soalan → hasilnya **4+** |

## 2. Harga (Pricing and Availability)

- Price: **Free (RM 0.00)**
- Availability: semua negara (atau pilih ikut kehendak anda)

## 3. App Privacy

- Privacy Policy URL: `https://github.com/ashrafnaim81/iOS-apps/blob/HEAD/AppStore/PRIVACY.md`
- Data collection: pilih **"No, we do not collect data from this app"**
- Hasilnya: label **Data Not Collected**

## 4. Versi 1.0 (halaman iOS App 1.0)

### Promotional Text (≤170)
```
Meet Si Santai, your sleepy ginger cat. Solve a fresh Daily Challenge, grow your streak and unwind to soft jazz. No ads, no accounts, no pressure.
```

### Description
```
Sudoku Santai is the calm, classic number puzzle — made for relaxing, not rushing.

Solve beautifully clean puzzles with Si Santai, a sleepy ginger cat who cheers when you finish a row, covers his eyes when you slip up, and naps when you pause. Soft bossa nova and jazz piano play in the background while you think.

DAILY CHALLENGE
• A fresh puzzle every day — the same one for everyone
• A calendar to track your completed days and replay the ones you missed
• Grow your daily streak

PLAY YOUR WAY
• Four levels: Easy, Medium, Hard and Expert
• Every puzzle has exactly one solution
• Pencil notes that tidy themselves up as you solve
• Undo, erase and gentle hints whenever you need them
• Highlights for the row, column, box and matching numbers
• Pause any time and pick up exactly where you left off

REWARDING, NEVER STRESSFUL
• Earn up to three stars for every puzzle
• Unlock 20 achievements
• Track your best times and flawless solves
• Satisfying animations, sounds and haptics

MADE WITH CARE
• No ads, no accounts, no tracking
• Works fully offline
• Beautiful in light and dark mode
• Designed for iPhone and iPad

Relax. Think. Solve.
```

### Keywords (≤100)
```
sudoku,puzzle,number,logic,brain,daily,classic,relax,calm,offline,cat,jazz,free,game,mind,easy
```

### Support URL
```
https://github.com/ashrafnaim81/iOS-apps/blob/HEAD/AppStore/SUPPORT.md
```

### Copyright
```
© 2026 Ashraf Naim
```
_(Tukar kepada nama anda / syarikat anda jika berbeza.)_

### Screenshots
Fail siap ada dalam repo, folder `AppStore/screenshots/`:
- **iPhone 6.9" Display** → semua fail dalam `iphone-6.9/` (1320 × 2868)
- **iPad 13" Display** → semua fail dalam `ipad-13/`

Muat naik mengikut urutan nombor (1-home, 2-game, 3-daily, 4-win, 5-achievements).
Di iPhone: buka fail di GitHub → **Download** → simpan ke Photos → muat naik dari Photos.

### Build
Tekan **Add Build** dan pilih build TestFlight terkini.

## 5. App Review Information

- Sign-in required: **tidak ditanda** (tiada log masuk)
- Contact: nama, telefon dan emel anda
- **Notes** (salin):
```
Sudoku Santai is a free, offline single-player Sudoku game. No account, no ads, no in-app purchases and no data collection.

Unique features: an original animated cat mascot (Si Santai) drawn in code, a Daily Challenge with a calendar and streaks, 20 achievements, pencil notes, and original background music and sound effects generated specifically for this app.

All content, artwork and audio are original. Nothing requires special setup to review; the tutorial appears on first launch and can be replayed from Settings > How to Play.
```

## 6. Hantar

- Version Release: **Automatically release this version** (atau Manual jika mahu pilih tarikh)
- Tekan **Add for Review** → **Submit to App Review**

Masa review biasa: **24–48 jam**. Status akan bertukar: Waiting for Review → In Review → Ready for Sale.

---

## Pilihan: Penyenaraian Bahasa Melayu

App Store Connect → App Information → **Localizable Information** → tambah bahasa **Malay**.
(Antara muka app masih Bahasa Inggeris; ini hanya teks kedai.)

- Subtitle: `Teka-teki tenang, kucing comel`
- Keywords: `sudoku,teka-teki,nombor,logik,otak,harian,santai,tenang,luar talian,kucing,percuma,permainan`
- Promotional Text:
```
Kenali Si Santai, kucing oren yang manja. Selesaikan Cabaran Harian, kekalkan streak anda dan berehat dengan muzik jazz lembut. Tiada iklan, tiada tekanan.
```
- Description:
```
Sudoku Santai ialah teka-teki nombor klasik yang tenang — untuk berehat, bukan untuk tergesa-gesa.

Selesaikan teka-teki bersama Si Santai, kucing oren yang bersorak bila anda siapkan satu baris, menutup mata bila anda tersilap, dan tidur bila anda berehat. Muzik bossa nova dan piano jazz yang lembut menemani anda berfikir.

CABARAN HARIAN
• Teka-teki baru setiap hari — sama untuk semua pemain
• Kalendar untuk jejak hari yang diselesaikan dan main semula hari yang terlepas
• Kekalkan streak harian anda

MAIN IKUT CARA ANDA
• Empat tahap: Easy, Medium, Hard dan Expert
• Setiap teka-teki ada tepat satu penyelesaian
• Nota pensel yang dikemas secara automatik
• Undo, padam dan hint bila-bila masa
• Sorotan baris, lajur, kotak dan nombor yang sama
• Jeda bila-bila masa dan sambung semula

MENYERONOKKAN, TANPA TEKANAN
• Kumpul sehingga tiga bintang setiap teka-teki
• Buka 20 pencapaian
• Jejak masa terbaik dan penyelesaian sempurna
• Animasi, bunyi dan getaran yang memuaskan

DIBINA DENGAN TELITI
• Tiada iklan, tiada akaun, tiada penjejakan
• Berfungsi tanpa internet
• Cantik dalam mod cerah dan gelap
• Untuk iPhone dan iPad

Santai. Fikir. Selesai.
```

---

## Nota: IAP untuk v1.1 (Santai Plus)

1. **Business → Agreements**: pastikan **Paid Apps Agreement** berstatus **Active**
   (maklumat bank + borang cukai lengkap). Tanpa ini IAP tidak akan diproses.
2. Cipta IAP (Non-Consumable "Santai Plus" + Consumable tip jar) — setiap satu perlu
   **Review Screenshot** dan **Review Notes**, status mesti **Ready to Submit**.
3. IAP **pertama** mesti dihantar **bersama versi app baru** (v1.1): di halaman versi,
   bahagian **In-App Purchases and Subscriptions** → tambah IAP tersebut → hantar.
