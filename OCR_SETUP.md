# Card scanning — extraction chain

Extraction runs as a **5-tier fallback chain**. Whichever tiers are
configured / available on the current platform run in order; each falls
back to the next on any failure.

| Tier | Engine | Platform | Cost | Setup |
|---|---|---|---|---|
| 1 | **Google ML Kit** | Android + iOS only | **Free**, no key | Just build the mobile app — auto-works |
| 2 | **OCR.space** | Web + mobile | **Free**, 500 req/day | Email signup for API key |
| 3 | NVIDIA vision LLM | Web + mobile | Free (rate-limited) | `NVIDIA_API_KEY` |
| 4 | Gemini vision LLM | Web + mobile | Free (rate-limited) | `GEMINI_API_KEY` |
| 5 | Tesseract.js | Web only | Free | Nothing |

Tier 1 (ML Kit) is the best experience — on-device, ~500ms, no network,
no cost, no rate limit. It only works on Android/iOS builds; on web the
chain skips to tier 2.

Tier 2 (OCR.space) is the best experience on **web** — one email signup
and you're done.

---

## Quickstart

### For web (Chrome) — set up OCR.space

1. Go to <https://ocr.space/ocrapi> → **Register for Free API Key** →
   enter email → check inbox for a key like `K12345678901234`.
2. Run with the key:
   ```powershell
   flutter run -d chrome `
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY `
     --dart-define=OCR_SPACE_API_KEY=K12345678901234
   ```

### For mobile (Android / iOS) — nothing to configure

ML Kit works out of the box. First build takes a few extra seconds
downloading the model. Run:

```bash
flutter run
```

You can still pass `OCR_SPACE_API_KEY` — it becomes a fallback if ML Kit
returns nothing on a specific card.

---

## Optional: keep NVIDIA / Gemini as extra safety nets

Both still slot in as tiers 3-4 automatically if their keys are set. See
the tiers table above. Not required — tiers 1-2 handle the common case.

### NVIDIA
1. <https://build.nvidia.com> → sign up (free, no card).
2. Any model page → **Generate API Key** → copy `nvapi-...`.
3. Add `--dart-define=NVIDIA_API_KEY=nvapi-...`.

### Gemini
1. <https://aistudio.google.com/apikey> → create key `AIza...`.
2. Add `--dart-define=GEMINI_API_KEY=AIza...`.

---

## Improving accuracy on a specific card

The extracted fields go through a pure-Dart parser
(`lib/features/scan/data/parsers/business_card_parser.dart`) that turns
raw OCR lines + boxes into structured card fields. If a particular
field keeps coming back wrong, add to the parser's dictionaries:

- new **title keywords** to `_titleKeywords` (industry roles)
- new **company suffixes** to `_companyMarkers` (regional legal suffixes)
- new **street terms** to `_streetMarkers`
- new **country names** to `_countries`

Rebuild the Flutter app — no OCR service change required.

---

## Notes on OCR.space limits

- **500 requests/day** on the free tier — resets at UTC midnight.
- **1 MB per image** — the scan screen already caps at 1600 px which
  keeps typical card photos under 500 KB.
- If you regularly hit 500/day, request a free "PRO" key (still $0) at
  their site — bumps to 25,000/mo.
- No rate-limit per minute; short bursts are fine.
