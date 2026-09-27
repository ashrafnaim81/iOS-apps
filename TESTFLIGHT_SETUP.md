# Setup TestFlight (tanpa komputer)

Semua langkah boleh dibuat di iPhone melalui Safari. GitHub Actions akan build app di mesin macOS milik GitHub dan upload terus ke TestFlight.

## 1. Cipta rekod app di App Store Connect

1. Buka https://appstoreconnect.apple.com → **Apps** → **+** → **New App**
2. Isi:
   - Platform: **iOS**
   - Name: `Sudoku` (atau nama lain yang belum diambil)
   - Primary language: English atau Malay
   - Bundle ID: pilih **com.ashrafnaim.sudoku**
     - Jika tiada dalam senarai, daftar dulu di https://developer.apple.com/account/resources/identifiers → **+** → App IDs → App → Explicit: `com.ashrafnaim.sudoku`
   - SKU: `sudoku001`

## 2. Cipta App Store Connect API Key

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys** → **+**
2. Name: `GitHub Actions`, Access: **Admin** (diperlukan untuk cipta sijil signing secara automatik)
3. Simpan tiga perkara:
   - **Issuer ID** (di atas senarai key)
   - **Key ID**
   - Fail **AuthKey_XXXX.p8** (boleh dimuat turun sekali sahaja!)

## 3. Cari Team ID

https://developer.apple.com/account → **Membership details** → **Team ID** (10 aksara)

## 4. Masukkan GitHub Secrets

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Nama secret | Nilai |
|---|---|
| `APPLE_TEAM_ID` | Team ID |
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_PRIVATE_KEY` | Keseluruhan kandungan fail `.p8`, termasuk baris `-----BEGIN PRIVATE KEY-----` dan `-----END PRIVATE KEY-----` |

Tip untuk iPhone: buka fail `.p8` dalam app **Files**. Jika tidak dapat dipaparkan, tukar nama kepada `AuthKey.txt`, buka, **Select All** → **Copy**.

## 5. Jalankan build

Repo → **Actions** → **Build & Upload to TestFlight** → **Run workflow**

Build mengambil masa ~10 minit. Selepas itu Apple memproses build selama 5–15 minit.

Workflow juga berjalan automatik setiap kali kod app di-push.

## 6. Uji di iPhone

1. App Store Connect → app anda → **TestFlight**
2. Jika diminta, jawab soalan **Export Compliance** (app ini tidak guna enkripsi, jadi jawapannya "None")
3. **Internal Testing** → **+** → cipta kumpulan → tambah diri anda
4. Pasang app **TestFlight** dari App Store di iPhone → buka jemputan → **Install**

## Masalah biasa

- **"No profiles for com.ashrafnaim.sudoku"**: Bundle ID belum didaftarkan (langkah 1), atau API key bukan peranan Admin.
- **"Missing GitHub secrets"**: Semak nama secret dalam langkah 4 (mesti huruf besar, tepat).
- **"Bundle version must be higher"**: Jalankan semula workflow; nombor build naik secara automatik.
