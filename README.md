# LeadFlow AI

AI-powered Exhibition Lead CRM. **Scan once. Organize forever.**

Scan a business card → AI extracts the details → confirm → answer 7 quick
questions → the lead lands on a live dashboard with search and advanced
filters.

## Run it

```bash
flutter pub get

# Demo mode (no backend needed — seeded exhibition data)
flutter run

# Production mode (Supabase)
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Without Supabase credentials the app boots in **demo mode**: an in-memory
repository seeded with realistic exhibition leads, follow-ups and activity,
so every screen — including the full scan flow — works end-to-end today.

## Backend setup

1. Create a Supabase project.
2. Run `supabase/migrations/0001_initial_schema.sql` in the SQL editor
   (tables, enums, indexes, RLS policies, and the private
   `business-cards` storage bucket).
3. Enable email auth (or your provider of choice).
4. Pass the URL and anon key via `--dart-define` as above.

## Architecture

Feature-first Clean Architecture:

```
lib/
├── core/          config · design tokens · theme · router · Result<T> · shared widgets
└── features/<x>/
    ├── domain/        entities + repository interfaces (pure Dart)
    ├── data/          DTO mappers + Supabase / mock implementations
    └── presentation/  Riverpod providers + screens + widgets
```

Key decisions:

- **Riverpod as DI** — repositories are providers; demo/production/test
  implementations swap with one override.
- **Errors as values** — repositories return `Result<T>`; every screen
  handles loading, empty, and error states explicitly.
- **Scan pipeline behind an interface** — `CardExtractionService` is a
  contract with a stub implementation. Dropping in ML Kit or an LLM
  vision model later requires zero UI changes.
- **Declarative questionnaire** — the 7 questions are data
  (`exhibitionQuestionnaire`); adding a question is a list entry.
- **Typed questionnaire columns** — answers are Postgres enums on
  `leads`, so every dashboard filter is an indexed `WHERE`, not JSON
  spelunking.

## Design system

Ink `#16161D` · Iris `#5B5BD6` accent · cool canvas `#F7F7F9` · hairline
borders · Inter with tabular figures and letterspaced eyebrows · 8pt grid
(`AppSpacing`) · 150–250ms motion (`AppMotion`) · glowing temperature dots
as the product signature · thumb-reachable scan bar for the exhibition floor.

## Roadmap hooks already in place

- OCR/AI extraction → implement `CardExtractionService`
- Card image upload → `business_card_images` + `business-cards` bucket
- Push notifications → notifications screen already renders live follow-ups
- Auth → GoRouter redirect + `profiles` table are ready
