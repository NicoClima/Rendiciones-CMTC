-- ============================================================
-- Rendiciones — schema para Supabase
-- Corre esto en: Supabase → tu proyecto → SQL Editor → New query
-- Este script es seguro de volver a correr las veces que quieras
-- (no duplica tablas, columnas ni datos ya creados).
-- ============================================================

-- 1) Tabla principal
create table if not exists public.rendiciones (
  id                  bigint generated always as identity primary key,
  tecnico             text not null,
  cuenta_responsable  text not null,  -- cuenta con la que se pagó
  motivo              text not null,
  fecha               date not null,
  monto               numeric not null,
  centro_costo        text not null,
  foto_urls           text[] not null default '{}',
  proveedor           text,            -- lo completa Claude leyendo la foto
  folio               text,            -- lo completa Claude leyendo la foto
  categoria           text,            -- lo completa Claude leyendo la foto
  periodo             text,            -- ej: '2026-07', se asigna al consolidar
  estado              text not null default 'pendiente', -- 'pendiente' | 'procesado'
  notas_verificacion  text,            -- alertas si algo no calza con la foto
  created_at          timestamptz not null default now()
);

-- Por si la tabla ya existía de una corrida anterior sin esta columna
alter table public.rendiciones
  add column if not exists cuenta_responsable text;

alter table public.rendiciones enable row level security;

-- Permitir que la app (usando la anon key) lea, cree y actualice registros.
-- Igual nivel de acceso que usa hoy tu app ClimaPro operativa.
drop policy if exists "rendiciones_select_anon" on public.rendiciones;
create policy "rendiciones_select_anon"
  on public.rendiciones for select
  to anon
  using (true);

drop policy if exists "rendiciones_insert_anon" on public.rendiciones;
create policy "rendiciones_insert_anon"
  on public.rendiciones for insert
  to anon
  with check (true);

drop policy if exists "rendiciones_update_anon" on public.rendiciones;
create policy "rendiciones_update_anon"
  on public.rendiciones for update
  to anon
  using (true)
  with check (true);

-- 2) Cuentas responsables (editable desde el panel admin, pestaña "Cuentas")
create table if not exists public.cuentas_responsables (
  id      bigint generated always as identity primary key,
  nombre  text not null unique,
  activo  boolean not null default true
);

alter table public.cuentas_responsables enable row level security;

drop policy if exists "cuentas_select_anon" on public.cuentas_responsables;
create policy "cuentas_select_anon"
  on public.cuentas_responsables for select
  to anon
  using (true);

drop policy if exists "cuentas_insert_anon" on public.cuentas_responsables;
create policy "cuentas_insert_anon"
  on public.cuentas_responsables for insert
  to anon
  with check (true);

drop policy if exists "cuentas_update_anon" on public.cuentas_responsables;
create policy "cuentas_update_anon"
  on public.cuentas_responsables for update
  to anon
  using (true)
  with check (true);

insert into public.cuentas_responsables (nombre, activo) values
  ('Eduardo M.', true),
  ('Yerko P.', true),
  ('Nicolás R.', true)
on conflict (nombre) do nothing;

-- 3) Bucket de Storage para las fotos de boletas
insert into storage.buckets (id, name, public)
values ('boletas', 'boletas', true)
on conflict (id) do nothing;

drop policy if exists "boletas_public_read" on storage.objects;
create policy "boletas_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'boletas');

drop policy if exists "boletas_anon_upload" on storage.objects;
create policy "boletas_anon_upload"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'boletas');

-- ============================================================
-- Notas:
-- - El bucket queda público de lectura para poder mostrar las fotos
--   en el panel admin y para que Claude pueda leerlas al consolidar.
--   Si las boletas tienen datos sensibles (ej. RUT visible) y prefieres
--   que no sean públicas, avísame y cambiamos a bucket privado + URLs firmadas.
-- - No se agregó política de DELETE a propósito (nadie puede borrar
--   registros por accidente desde la app).
-- ============================================================
