-- LeadFlow AI · Pending actions
--
-- Every voice note the AI processes can now produce a set of "things to
-- do next" — e.g. "call him Tuesday", "send WhatsApp with catalog PDF".
-- Those live here as first-class rows so the app can:
--   • badge the lead card with a count in the list
--   • render a checklist on Lead Detail with a "mark done" button
--   • later, hand each row off to an automation worker (email agent,
--     WhatsApp agent, dialer) via the `automation_status` column.

create type pending_action_kind as enum (
  'call', 'email', 'whatsapp', 'sms', 'meeting', 'other'
);

create type pending_action_status as enum (
  'pending', 'done', 'skipped'
);

-- 'manual'      — user did it (or will do it) themselves
-- 'queued'      — waiting for the automation worker
-- 'processing'  — automation worker picked it up
-- 'automated'   — automation worker completed it
create type pending_action_automation as enum (
  'manual', 'queued', 'processing', 'automated'
);

create table if not exists public.pending_actions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  lead_id uuid not null references public.leads (id) on delete cascade,
  voice_note_id uuid references public.voice_notes (id) on delete set null,

  kind pending_action_kind not null,
  description text not null,
  due_at timestamptz,

  status pending_action_status not null default 'pending',
  automation_status pending_action_automation not null default 'manual',

  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists pending_actions_lead_status_idx
  on public.pending_actions (lead_id, status);

create index if not exists pending_actions_owner_status_idx
  on public.pending_actions (owner_id, status, created_at desc);

-- updated_at style trigger not needed: rows are essentially append-only,
-- edited only when marked done (which stamps completed_at directly).

-- RLS
alter table public.pending_actions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'pending_actions'
      and policyname = 'owner full access'
  ) then
    create policy "owner full access" on public.pending_actions
      for all using (owner_id = auth.uid())
      with check (owner_id = auth.uid());
  end if;
end $$;
