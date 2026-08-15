create extension if not exists pgcrypto;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  project_id text not null,
  title text not null default 'Untitled Project',
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, project_id)
);

create table if not exists public.sync_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null,
  record_id text not null,
  action text not null default 'upsert' check (action in ('upsert', 'delete')),
  base_revision integer not null default 0 check (base_revision >= 0),
  revision integer not null default 0 check (revision >= 0),
  payload jsonb not null default '{}'::jsonb,
  device_id text,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, record_type, record_id)
);

alter table public.projects enable row level security;
alter table public.sync_records enable row level security;

create policy "Users can view their own projects"
on public.projects
for select
using (auth.uid() = user_id);

create policy "Users can insert their own projects"
on public.projects
for insert
with check (auth.uid() = user_id);

create policy "Users can update their own projects"
on public.projects
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their own projects"
on public.projects
for delete
using (auth.uid() = user_id);

create policy "Users can view their own sync records"
on public.sync_records
for select
using (auth.uid() = user_id);

create policy "Users can insert their own sync records"
on public.sync_records
for insert
with check (auth.uid() = user_id);

create policy "Users can update their own sync records"
on public.sync_records
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their own sync records"
on public.sync_records
for delete
using (auth.uid() = user_id);

create index if not exists idx_projects_user_updated_at
  on public.projects (user_id, updated_at desc);

create index if not exists idx_sync_records_user_record
  on public.sync_records (user_id, record_type, record_id, updated_at desc);
