# LeadFlow AI — Setup

## Option A: Demo mode (no backend, 30 seconds)
```bash
flutter pub get
flutter run -d chrome
```
Sign in with **any email and password**. Data lives in memory only.

## Option B: Real Supabase (production-ready)

### 1. Create a Supabase project
Go to <https://supabase.com>, create a new project, wait ~2 minutes.

### 2. Run the migrations
**SQL Editor → New query**, run these **in order**:
1. `supabase/migrations/0001_initial_schema.sql`
2. `supabase/migrations/0002_auth_trigger.sql`

### 3. Turn off email confirmation (for testing)
**Authentication → Sign In / Providers → Email** → uncheck *Confirm email*.

### 4. Grab your credentials
**Project Settings → API** → copy Project URL and anon public key.

### 5. Run with them
```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

### 6. First run
Sign up → dashboard → tap center scan FAB → capture/gallery → OCR reads the card → review → 7 questions → save.

## OCR

Extraction uses a 4-tier fallback chain — full details in
[`OCR_SETUP.md`](./OCR_SETUP.md) and [`PADDLE_DEPLOY.md`](./PADDLE_DEPLOY.md).

**Primary tier — Google ML Kit** on Android/iOS (on-device, free, no key
needed). Auto-works when you `flutter run` on a mobile device.

**Web build tier — OCR.space** (free hosted API, 500 req/day). Sign up
at <https://ocr.space/ocrapi> for an API key, pass via
`--dart-define=OCR_SPACE_API_KEY=...`.

**Fallbacks** (optional, kicked in only if PaddleOCR fails):
- NVIDIA vision LLM (needs `NVIDIA_API_KEY`)
- Gemini vision LLM (needs `GEMINI_API_KEY`)
- On-device tesseract.js (web only, no config needed)

OCR quality still depends on the photo — if a card comes out blank on
every tier, retake in better light or crop closer.
