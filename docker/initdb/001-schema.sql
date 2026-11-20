-- OpenIPTV standalone schema (plain PostgreSQL, lowercase column names)
-- Mounted automatically by docker-compose on first start.

create extension if not exists "pgcrypto";

create table if not exists users (
  id            uuid primary key default gen_random_uuid(),
  email         text not null unique,
  password_hash text not null,
  created_at    timestamptz not null default now()
);

create table if not exists profiles (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users on delete cascade,
  name         text not null,
  avatar_color text not null default '#4F8CFF',
  is_kids      boolean not null default false,
  created_at   timestamptz not null default now(),
  unique (user_id, name)
);

create table if not exists playlists (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references profiles on delete cascade,
  name        text not null,
  kind        text not null check (kind in ('xtream','m3u')),
  host        text,
  m3u_url     text,
  epg_url     text,
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  unique (profile_id, name)
);

create table if not exists favorites (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles on delete cascade,
  playlist_id uuid,
  item_kind  text not null check (item_kind in ('live','vod','series')),
  item_id    text not null,
  title      text not null,
  logo_url   text,
  state      text not null default 'favorite' check (state in ('favorite','hidden','locked')),
  updated_at timestamptz not null default now(),
  unique (profile_id, item_kind, item_id, state)
);

create table if not exists watch_progress (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references profiles on delete cascade,
  playlist_id uuid,
  item_kind   text not null,
  item_id     text not null,
  title       text not null,
  position_ms bigint not null default 0,
  duration_ms bigint not null default 0,
  updated_at  timestamptz not null default now(),
  unique (profile_id, item_kind, item_id)
);

create table if not exists views (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles on delete cascade,
  item_kind  text not null,
  item_id    text not null,
  updated_at timestamptz not null default now(),
  unique (profile_id, item_kind, item_id)
);

create index if not exists idx_favorites_profile on favorites (profile_id, updated_at);
create index if not exists idx_progress_profile on watch_progress (profile_id, updated_at);
create index if not exists idx_views_profile    on views (profile_id, updated_at);
create index if not exists idx_epg_root         on playlists (profile_id);
