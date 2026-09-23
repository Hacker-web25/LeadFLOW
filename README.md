<p align="center">
  <h1 align="center">LeadFlow AI</h1>
  <p align="center">
    <strong>AI-powered Exhibition Lead CRM</strong><br/>
    Scan once. Organize forever.
  </p>
  <p align="center">
    <a href="#features">Features</a> · 
    <a href="#tech-stack">Tech Stack</a> · 
    <a href="#architecture">Architecture</a> · 
    <a href="#getting-started">Getting Started</a> · 
    <a href="#ocr-pipeline">OCR Pipeline</a> · 
    <a href="#project-structure">Project Structure</a>
  </p>
</p>

---

## The Problem

Exhibition and trade-show teams collect hundreds of business cards per event. The current workflow: stuff cards in a bag → manually type them into a spreadsheet days later → lose context on who was hot and who was browsing. **80% of trade-show leads never get followed up.**

## The Solution

**LeadFlow AI** turns a phone camera into a full lead-capture pipeline:

> 📸 Scan a card → 🤖 AI extracts contact details → ✅ Review & confirm → 📋 Answer 7 quick qualification questions → 📊 Lead lands on a live dashboard with filters, scoring & follow-up reminders

No manual data entry. No lost cards. No forgotten follow-ups.

---

## Features

| Feature | Description |
|---|---|
| **AI Card Scanning** | Multi-tier OCR pipeline extracts name, designation, company, email, phone, address from any business card |
| **Smart Review** | AI-extracted fields shown with confidence scores — tap to edit before saving |
| **Lead Qualification** | 7-question structured questionnaire (temperature, timeline, customer type, decision-maker, etc.) |
| **Live Dashboard** | Stats row, recent leads, upcoming follow-ups, activity feed — all in one view |
| **Advanced Filters** | Filter by temperature (hot/warm/cold), timeline, customer type, status, exhibition |
| **Full-Text Search** | Search across names, companies, emails, notes instantly |
| **Voice Notes** | Record voice memos per lead — transcribed via Groq Whisper (English + Hindi + Hinglish) |
| **Follow-Up Tracking** | Set and track follow-up actions with due dates and completion status |
| **Bulk Edit** | Spreadsheet-style grid view for batch-editing leads (powered by PlutoGrid) |
| **Excel Export/Import** | Export leads to `.xlsx`, edit offline, re-import — round-trip supported |
| **Exhibition Management** | Organize leads by exhibition/event with folder-based grouping |
| **Demo Mode** | Full app works without any backend — seeded with realistic data for instant evaluation |
| **CI/CD** | Automated APK builds via Codemagic on every push |

---

## Tech Stack

### Frontend
| Technology | Purpose |
|---|---|
| **Flutter** | Cross-platform mobile + web from a single codebase |
| **Dart** | Type-safe language with null safety |
| **Riverpod** | State management + dependency injection |
| **GoRouter** | Declarative routing with auth guards |
| **PlutoGrid** | Excel-like data grid for bulk editing |
| **Google Fonts (Inter)** | Typography with tabular figures |

### Backend
| Technology | Purpose |
|---|---|
| **Supabase** | PostgreSQL database + Auth + Storage + Realtime |
| **Row-Level Security** | Per-user data isolation at the database level |
| **Postgres Enums** | Typed questionnaire columns → indexed `WHERE` filters, not JSON |
| **Storage Buckets** | Private bucket for scanned card images |
| **Edge Functions** | Serverless AI orchestration (CORS-safe API key routing) |

### AI / OCR Pipeline
| Tier | Engine | Platform | Cost |
|---|---|---|---|
| 1 | **Google ML Kit** | Android + iOS | Free, on-device, ~500ms |
| 2 | **OCR.space** | Web + Mobile | Free, 500 req/day |
| 3 | **Google Cloud Vision** | Web + Mobile | Free tier: 1000 req/month |
| 4 | **Gemini Vision** | Web + Mobile | Free tier (rate-limited) |
| 5 | **NVIDIA NIM** | Web + Mobile | Free tier (rate-limited) |
| 6 | **Groq Vision** | Web + Mobile | Free tier |
| 7 | **Tesseract.js** | Web only | Free, no config |

### Voice Transcription
| Technology | Purpose |
|---|---|
| **Groq Whisper (large-v3)** | Speech-to-text for voice notes — English, Hindi, Hinglish auto-detected |
| **record** package | Cross-platform mic recording |
| **just_audio** | Playback of saved voice notes |

### DevOps
| Technology | Purpose |
|---|---|
| **Codemagic** | CI/CD — automated debug APK builds |
| **Supabase Migrations** | Versioned SQL schema management |

---

## Architecture

**Feature-first Clean Architecture** with strict separation of concerns:

```
lib/
├── core/
│   ├── config/          # Environment configuration (dart-define injection)
│   ├── constants/       # Spacing, radii, durations, breakpoints
│   ├── theme/           # Colors, typography, app theme
│   ├── router/          # GoRouter setup + auth redirects + app shell
│   ├── supabase/        # Supabase client + global providers
│   ├── utils/           # Result<T> monad, date extensions
│   └── widgets/         # Shared UI components (LfCard, LfChip, LfAvatar...)
│
└── features/
    ├── auth/            # Sign in, sign up, forgot password
    ├── dashboard/       # Home screen — stats, recent leads, follow-ups, activity
    ├── leads/           # Lead list, detail, bulk edit, filters
    ├── scan/            # Camera → OCR → Review → Questionnaire → Save
    ├── exhibitions/     # Exhibition/event management + folder organization
    ├── voice_note/      # Record, transcribe (Groq Whisper), playback
    ├── actions/         # Follow-up actions with due dates
    ├── search/          # Full-text search across all lead fields
    ├── follow_ups/      # Follow-up domain models
    ├── notifications/   # Notifications screen
    ├── profile/         # User profile
    └── settings/        # App settings
```

Each feature follows the same three-layer pattern:

```
features/<name>/
├── domain/        # Entities + repository interfaces (pure Dart, no dependencies)
├── data/          # Supabase implementations + mock/demo implementations + DTOs
└── presentation/  # Riverpod providers + screens + widgets
```

### Key Architectural Decisions

- **Riverpod as DI** — Repositories are providers; demo/production/test implementations swap with a single override
- **Errors as values** — Repositories return `Result<T>` (Ok/Err); every screen handles loading, empty, and error states explicitly
- **Scan pipeline behind an interface** — `CardExtractionService` is a contract; swapping OCR engines requires zero UI changes
- **Declarative questionnaire** — The 7 qualification questions are data (`exhibitionQuestionnaire`); adding a question is adding a list entry
- **Typed questionnaire columns** — Answers stored as Postgres enums on `leads` table → every dashboard filter is an indexed `WHERE`, not JSON parsing
- **Conditional imports** — Platform-specific code (ML Kit, web OCR, audio) uses Dart conditional imports with stubs for unsupported platforms

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.4.0`
- Dart SDK `>=3.4.0`
- Android Studio / Xcode (for mobile builds)
- Chrome (for web builds)

### Quick Start — Demo Mode

No backend needed. The app boots with seeded exhibition data:

```bash
git clone https://github.com/Hacker-web25/LeadFLOW.git
cd LeadFLOW
flutter pub get
flutter run        # mobile
flutter run -d chrome  # web
```

Sign in with **any email and password** — data lives in memory only.

### Production Mode — With Supabase

1. **Create a Supabase project** at [supabase.com](https://supabase.com)

2. **Run migrations** in the SQL Editor (in order):
   ```
   supabase/migrations/0001_initial_schema.sql
   supabase/migrations/0002_auth_trigger.sql
   supabase/migrations/0003_voice_notes.sql
   supabase/migrations/0004_exhibitions.sql
   supabase/migrations/0005_pending_actions.sql
   supabase/migrations/0006_address_and_first_name.sql
   ```

3. **Disable email confirmation** (for testing):
   Authentication → Sign In / Providers → Email → uncheck *Confirm email*

4. **Run with credentials:**
   ```bash
   flutter run -d chrome \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
   ```

### Environment Variables

All secrets are injected at build time via `--dart-define`. **Never hardcode keys in source.**

| Variable | Required | Description |
|---|---|---|
| `SUPABASE_URL` | For production | Supabase project URL |
| `SUPABASE_ANON_KEY` | For production | Supabase anonymous/public key |
| `OCR_SPACE_API_KEY` | For web OCR | Free API key from [ocr.space](https://ocr.space/ocrapi) |
| `GEMINI_API_KEY` | Optional | Google Gemini for AI card extraction |
| `GROQ_API_KEY` | Optional | Groq Whisper for voice transcription |
| `GCV_API_KEY` | Optional | Google Cloud Vision for high-accuracy OCR |
| `NVIDIA_API_KEY` | Optional | NVIDIA NIM for vision-based extraction |

---

## OCR Pipeline

The scan flow uses a **multi-tier fallback chain** — each tier cascades to the next on failure:

```
Card Image
    │
    ▼
┌─────────────────────┐
│  Tier 1: ML Kit     │ ← Android/iOS only, on-device, ~500ms, free
│  (skip on web)      │
└────────┬────────────┘
         │ fallback
         ▼
┌─────────────────────┐
│  Tier 2: OCR.space  │ ← Web primary, 500 req/day free
└────────┬────────────┘
         │ fallback
         ▼
┌─────────────────────┐
│  Tier 3: GCV        │ ← Google Cloud Vision, highest accuracy
└────────┬────────────┘
         │ fallback
         ▼
┌─────────────────────┐
│  Tier 4: Gemini     │ ← Vision LLM, understands layout context
└────────┬────────────┘
         │ fallback
         ▼
┌─────────────────────┐
│  Tier 5: NVIDIA NIM │ ← Vision LLM, alternative provider
└────────┬────────────┘
         │ fallback
         ▼
┌─────────────────────┐
│  Tier 6: Groq       │ ← Vision model fallback
└────────┬────────────┘
         │ fallback
         ▼
┌─────────────────────┐
│  Tier 7: Tesseract  │ ← Web only, local JS, last resort
└─────────────────────┘
         │
         ▼
  Business Card Parser
  (pure Dart: regex + dictionaries → structured fields)
```

Raw OCR text is post-processed by a **pure-Dart business card parser** that uses regex patterns, keyword dictionaries, and heuristics to extract structured fields (name, designation, company, email, phone, address).

---

## Database Schema

```
profiles ──────────── auth.users (1:1)

companies ─────┐
               ├──── leads ──── business_card_images
contacts ──────┘        │
                        ├──── activities
                        ├──── follow_ups
                        └──── voice_notes

exhibitions (folder-based lead organization)
pending_actions (follow-up task queue)
```

All tables enforce **Row-Level Security** — users can only access their own data. Questionnaire answers are stored as **Postgres enums** for indexed filtering.

---

## Design System

| Token | Value |
|---|---|
| **Primary** | Ink `#16161D` |
| **Accent** | Iris `#5B5BD6` |
| **Canvas** | Cool white `#F7F7F9` |
| **Typography** | Inter — tabular figures, letterspaced eyebrows |
| **Grid** | 8pt spacing system (`AppSpacing`) |
| **Motion** | 150–250ms transitions (`AppMotion`) |
| **Signature** | Glowing temperature dots (hot/warm/cold) |
| **Layout** | Thumb-reachable scan FAB for the exhibition floor |

---

## CI/CD

Automated builds via **Codemagic**:
- Push to `main` triggers a debug APK build
- API keys stored as **encrypted environment variables** (never in source)
- Artifacts: debug APK available for download after each build

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is proprietary. All rights reserved.

---

<p align="center">
  Built with Flutter + Supabase + AI<br/>
  <strong>Scan once. Organize forever.</strong>
</p>
