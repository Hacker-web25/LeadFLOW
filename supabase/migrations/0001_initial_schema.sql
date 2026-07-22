-- LeadFlow AI · Initial schema
-- Normalized, UUID PKs, RLS-ready. Every user-owned table carries owner_id.

create extension if not exists "pgcrypto";

-- ─── Enums (typed questionnaire answers → indexable filters) ─────────────
create type lead_temperature as enum ('hot', 'warm', 'cold');
create type requirement_timeline as enum ('immediate', 'one_to_three_months', 'three_to_six_months', 'exploring');
create type customer_type as enum ('end_user', 'distributor', 'retailer', 'oem', 'consultant', 'other');
create type lead_status as enum ('new', 'contacted', 'qualified', 'won', 'lost');
create type activity_type as enum ('scan', 'note', 'call', 'email', 'meeting', 'status_change', 'follow_up_done');
create type follow_up_status as enum ('pending', 'done', 'skipped');

-- ─── Profiles (mirrors auth.users) ───────────────────────────────────────
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  company_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ─── Companies ───────────────────────────────────────────────────────────
create table public.companies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  website text,
  industry text,
  city text,
  country text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, name)
);

-- ─── Contacts ────────────────────────────────────────────────────────────
create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  company_id uuid references public.companies (id) on delete set null,
  full_name text not null,
  designation text,
  email text,
  phone text,
  alt_phone text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ─── Leads (questionnaire answers are typed columns → indexable filters) ─
create table public.leads (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  contact_id uuid not null references public.contacts (id) on delete cascade,
  company_id uuid references public.companies (id) on delete set null,
  event_name text,
  status lead_status not null default 'new',
  temperature lead_temperature,
  timeline requirement_timeline,
  customer_type customer_type,
  is_decision_maker boolean,
  export_requirement boolean,
  sales_team_required boolean,
  additional_notes text,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index leads_owner_captured_idx on public.leads (owner_id, captured_at desc);
create index leads_owner_temperature_idx on public.leads (owner_id, temperature);
create index leads_owner_timeline_idx on public.leads (owner_id, timeline);

-- ─── Business card images (rows point into the private storage bucket) ──
create table public.business_card_images (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  lead_id uuid not null references public.leads (id) on delete cascade,
  storage_path text not null,          -- {owner_id}/{lead_id}/front.jpg
  side text not null default 'front' check (side in ('front', 'back')),
  ocr_raw jsonb,                       -- raw extraction payload for audit/retry
  created_at timestamptz not null default now()
);

-- ─── Activities (immutable timeline) ─────────────────────────────────────
create table public.activities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  lead_id uuid not null references public.leads (id) on delete cascade,
  type activity_type not null,
  summary text not null,
  metadata jsonb,
  occurred_at timestamptz not null default now()
);
create index activities_owner_occurred_idx on public.activities (owner_id, occurred_at desc);

-- ─── Follow-ups ──────────────────────────────────────────────────────────
create table public.follow_ups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  lead_id uuid not null references public.leads (id) on delete cascade,
  due_at timestamptz not null,
  status follow_up_status not null default 'pending',
  note text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index follow_ups_owner_due_idx on public.follow_ups (owner_id, status, due_at);

-- ─── Notes ───────────────────────────────────────────────────────────────
create table public.notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  lead_id uuid not null references public.leads (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ─── Tags (M:N with leads) ───────────────────────────────────────────────
create table public.tags (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  label text not null,
  color text,
  unique (owner_id, label)
);
create table public.lead_tags (
  lead_id uuid not null references public.leads (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  primary key (lead_id, tag_id)
);

-- ─── updated_at trigger ──────────────────────────────────────────────────
create or replace function public.touch_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

do $$
declare t text;
begin
  foreach t in array array['profiles','companies','contacts','leads','notes'] loop
    execute format(
      'create trigger %I_touch before update on public.%I for each row execute function public.touch_updated_at()', t, t);
  end loop;
end $$;

-- ─── Row Level Security ──────────────────────────────────────────────────
alter table public.profiles enable row level security;
create policy "own profile" on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['companies','contacts','leads','business_card_images',
                           'activities','follow_ups','notes','tags'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "owner full access" on public.%I for all using (owner_id = auth.uid()) with check (owner_id = auth.uid())', t);
  end loop;
end $$;

alter table public.lead_tags enable row level security;
create policy "owner via lead" on public.lead_tags for all
  using (exists (select 1 from public.leads l where l.id = lead_id and l.owner_id = auth.uid()))
  with check (exists (select 1 from public.leads l where l.id = lead_id and l.owner_id = auth.uid()));

-- ─── Storage: private bucket for card images ─────────────────────────────
insert into storage.buckets (id, name, public) values ('business-cards', 'business-cards', false)
on conflict (id) do nothing;

create policy "card images: owner read" on storage.objects for select
  using (bucket_id = 'business-cards' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "card images: owner write" on storage.objects for insert
  with check (bucket_id = 'business-cards' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "card images: owner delete" on storage.objects for delete
  using (bucket_id = 'business-cards' and (storage.foldername(name))[1] = auth.uid()::text);
