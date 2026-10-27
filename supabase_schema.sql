-- Esquema de rastro para Supabase.
-- Pégalo en: Supabase → SQL Editor → New query → Run.
-- Crea: participantes (alias, sin email), capturas (2 fotos + GPS), agenda de
-- notificaciones, y el bucket de almacenamiento para las fotos.
-- RLS permisivo: es un test cerrado con la publishable key (no datos sensibles de
-- terceros; los participantes dan consentimiento al postularse).

-- ── Tablas ──────────────────────────────────────────────────────────────────
create table if not exists public.perfiles (
  id uuid primary key default gen_random_uuid(),
  alias text not null,
  device_id text unique,
  created_at timestamptz default now()
);

create table if not exists public.capturas (
  id uuid primary key default gen_random_uuid(),
  alias text not null,
  device_id text,
  back_url text not null,
  front_url text,
  lat double precision,
  lng double precision,
  accuracy double precision,
  taken_at timestamptz not null,
  created_at timestamptz default now()
);

create table if not exists public.agenda (
  dia int primary key,     -- índice de día del test (0..6)
  hora int not null,       -- 0..23
  minuto int not null,     -- 0..59
  fecha date               -- opcional: fecha concreta
);

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.perfiles enable row level security;
alter table public.capturas enable row level security;
alter table public.agenda   enable row level security;

drop policy if exists "perfiles todo"   on public.perfiles;
drop policy if exists "capturas todo"   on public.capturas;
drop policy if exists "agenda lectura"  on public.agenda;

create policy "perfiles todo"  on public.perfiles for all    using (true) with check (true);
create policy "capturas todo"  on public.capturas for all    using (true) with check (true);
create policy "agenda lectura" on public.agenda   for select using (true);

-- ── Storage (bucket público para las fotos del test) ────────────────────────
insert into storage.buckets (id, name, public)
values ('capturas', 'capturas', true)
on conflict (id) do nothing;

drop policy if exists "capturas storage lectura" on storage.objects;
drop policy if exists "capturas storage subir"   on storage.objects;

create policy "capturas storage lectura" on storage.objects
  for select using (bucket_id = 'capturas');
create policy "capturas storage subir" on storage.objects
  for insert with check (bucket_id = 'capturas');

-- ── Agenda de ejemplo (puedes editarla después) ─────────────────────────────
-- Una hora por día del test. Cambia hora/minuto a tu gusto.
insert into public.agenda (dia, hora, minuto) values
  (0, 13, 0), (1, 18, 30), (2, 11, 15), (3, 20, 0),
  (4, 16, 45), (5, 12, 30), (6, 19, 0)
on conflict (dia) do nothing;
