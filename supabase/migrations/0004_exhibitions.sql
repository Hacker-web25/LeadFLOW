-- LeadFlow AI · Exhibitions (folder metadata) + card image uniqueness
--
-- What this migration does:
--   1. Adds a unique constraint on business_card_images(lead_id, side).
--      Without this, the app's upsert(onConflict: 'lead_id,side') was
--      silently failing, so no thumbnails ever landed in the table —
--      that's why the Leads list only ever showed initials avatars.
--   2. Creates an `exhibitions` table so folders have real identity:
--      an id, a creation date, and a canonical name. Leads still
--      reference a folder by its name in `event_name` (backward-
--      compatible), but the metadata now lives in one place so we can
--      show a "created X ago" hint, rename atomically, and delete.
--
-- Safe to re-run: everything is guarded with IF NOT EXISTS.

-- ─── 1. Card image dedup ────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'business_card_images_lead_side_uniq'
  ) then
    alter table public.business_card_images
      add constraint business_card_images_lead_side_uniq
      unique (lead_id, side);
  end if;
end $$;

-- ─── 2. Exhibitions (folders) ───────────────────────────────────────────
create table if not exists public.exhibitions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, name)
);

create index if not exists exhibitions_owner_created_idx
  on public.exhibitions (owner_id, created_at desc);

-- updated_at trigger (reuses touch_updated_at from 0001).
do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'exhibitions_touch'
  ) then
    create trigger exhibitions_touch
      before update on public.exhibitions
      for each row execute function public.touch_updated_at();
  end if;
end $$;

-- RLS
alter table public.exhibitions enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'exhibitions'
      and policyname = 'owner full access'
  ) then
    create policy "owner full access" on public.exhibitions
      for all using (owner_id = auth.uid())
      with check (owner_id = auth.uid());
  end if;
end $$;

-- ─── 3. Backfill: every distinct event_name a user has ever used
--         becomes an Exhibition row so their existing scans light up
--         as real folders immediately after this migration. ─────────────
insert into public.exhibitions (owner_id, name, created_at)
select
  l.owner_id,
  trim(l.event_name),
  min(l.captured_at) as created_at
from public.leads l
where l.event_name is not null
  and trim(l.event_name) <> ''
group by l.owner_id, trim(l.event_name)
on conflict (owner_id, name) do nothing;
