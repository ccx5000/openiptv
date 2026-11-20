-- OpenIPTV Supabase schema
-- Run this whole file once in the Supabase SQL editor.

-- 1. Multi-user profiles inside one account (like Netflix).
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  avatar_color text not null default '#4F8CFF',
  is_kids boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

-- 2. Linked playlist subscriptions (metadata only; credentials stay on-device).
create table if not exists public.playlists (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles on delete cascade,
  name text not null,
  kind text not null check (kind in ('xtream','m3u')),
  host text,
  m3u_url text,
  epg_url text,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

-- 3. Favourites, hidden items and per-item metadata.
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles on delete cascade,
  playlist_id uuid,
  item_kind text not null check (item_kind in ('live','vod','series')),
  item_id text not null,
  title text not null,
  logo_url text,
  state text not null default 'favorite' check (state in ('favorite','hidden','locked')),
  updated_at timestamptz not null default now(),
  unique (profile_id, item_kind, item_id, state)
);

-- 4. Continue-watching positions (.channels share item_id = stream id / url hash).
create table if not exists public.watch_progress (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles on delete cascade,
  playlist_id uuid,
  item_kind text not null,
  item_id text not null,
  title text not null,
  position_ms bigint not null default 0,
  duration_ms bigint not null default 0,
  updated_at timestamptz not null default now(),
  unique (profile_id, item_kind, item_id)
);

-- 5. Watched marker for series/VOD.
create table if not exists public.views (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles on delete cascade,
  item_kind text not null,
  item_id text not null,
  updated_at timestamptz not null default now(),
  unique (profile_id, item_kind, item_id)
);

-- Row level security: a user only ever sees its own rows.
alter table public.profiles        enable row level security;
alter table public.playlists       enable row level security;
alter table public.favorites       enable row level security;
alter table public.watch_progress  enable row level security;
alter table public.views           enable row level security;

create policy "own profiles"       on public.profiles       for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own playlists"      on public.playlists      for all using (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid())) with check (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid()));
create policy "own favorites"      on public.favorites      for all using (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid())) with check (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid()));
create policy "own watch progress" on public.watch_progress for all using (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid())) with check (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid()));
create policy "own views"          on public.views          for all using (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid())) with check (exists (select 1 from public.profiles p where p.id = profile_id and p.user_id = auth.uid()));

-- One default profile for each new account.
create or replace function public.create_default_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, name, is_kids)
  values (new.id, 'Hauptprofil', false)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.create_default_profile();

-- Fast "everything changed since" pull query.
create or replace view public.sync_payload as
select p.id, 'profile' as entity, to_jsonb(p) as data from public.profiles p
union all
select pl.id, 'playlist', to_jsonb(pl) from public.playlists pl
union all
select f.id, 'favorite', to_jsonb(f) from public.favorites f
union all
select w.id, 'progress', to_jsonb(w) from public.watch_progress w
union all
select v.id, 'view', to_jsonb(v) from public.views v;
