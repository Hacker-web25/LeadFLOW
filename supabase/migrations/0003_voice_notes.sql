-- Voice notes: raw audio + transcript, one row per recording.
-- Multiple per lead; user can play back and delete individually.

create table public.voice_notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  lead_id uuid not null references public.leads (id) on delete cascade,
  storage_path text not null,          -- {owner_id}/{lead_id}/{note_id}.{ext}
  transcript text,                     -- raw Whisper output
  summary text,                        -- clean paragraph derived by the LLM
  language text,                       -- 'auto' | 'en' | 'hi'
  duration_ms integer,
  file_ext text default 'm4a',
  created_at timestamptz not null default now()
);
create index voice_notes_lead_idx on public.voice_notes (lead_id, created_at desc);

alter table public.voice_notes enable row level security;
create policy "owner full access voice_notes" on public.voice_notes
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- Storage bucket for the audio blobs. Private, owner-scoped.
insert into storage.buckets (id, name, public) values ('voice-notes', 'voice-notes', false)
on conflict (id) do nothing;

create policy "voice notes: owner read" on storage.objects for select
  using (bucket_id = 'voice-notes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "voice notes: owner write" on storage.objects for insert
  with check (bucket_id = 'voice-notes' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "voice notes: owner delete" on storage.objects for delete
  using (bucket_id = 'voice-notes' and (storage.foldername(name))[1] = auth.uid()::text);
