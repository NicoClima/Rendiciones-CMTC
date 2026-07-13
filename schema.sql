-- ============================================================
-- Rendiciones — schema para Supabase
-- Corre esto en: Supabase → tu proyecto → SQL Editor → New query
-- Este script es seguro de volver a correr las veces que quieras
-- (no duplica tablas, columnas ni datos ya creados).
-- ============================================================

-- 1) Tabla principal
create table if not exists public.rendiciones (
  id                  bigint generated always as identity primary key,
  cuenta_responsable  text not null,  -- Responsable del Fondo: Yerko P. / Eduardo M. / Nicolás R.
  responsable_rendicion text not null, -- quién hizo la compra: puede ser el mismo del fondo u otro (técnico)
  motivo              text not null,
  fecha               date not null,
  monto               numeric not null,
  centro_costo        text not null,
  foto_urls           text[] not null default '{}',
  proveedor           text,            -- lo completa Claude leyendo la foto
  folio               text,            -- N° de boleta: lo detecta el OCR en terreno, el técnico lo valida, y Claude lo revisa al consolidar
  tipo_documento      text not null default 'Boleta', -- 'Boleta' | 'Factura'
  categoria           text,            -- lo completa Claude leyendo la foto
  periodo             text,            -- ej: '2026-07', se asigna al consolidar
  estado              text not null default 'pendiente', -- 'pendiente' | 'procesado'
  notas_verificacion  text,            -- alertas si algo no calza con la foto
  created_at          timestamptz not null default now()
);

-- Migraciones por si la tabla ya existía de una corrida anterior
alter table public.rendiciones add column if not exists cuenta_responsable text;
alter table public.rendiciones add column if not exists responsable_rendicion text;
alter table public.rendiciones add column if not exists tipo_documento text not null default 'Boleta';

-- Si existe la columna vieja "tecnico" y todavía no se migró, la traspasamos
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='rendiciones' and column_name='tecnico') then
    update public.rendiciones set responsable_rendicion = tecnico where responsable_rendicion is null;
    alter table public.rendiciones drop column tecnico;
  end if;
end $$;

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

-- Se agregó política de DELETE para poder borrar registros duplicados
-- desde el panel de administración (con confirmación en pantalla antes
-- de borrar). No borra las fotos ya subidas al bucket, solo la fila.
drop policy if exists "rendiciones_delete_anon" on public.rendiciones;
create policy "rendiciones_delete_anon"
  on public.rendiciones for delete
  to anon
  using (true);

-- 2) Responsables del Fondo (editable desde el panel admin, pestaña "Responsables del Fondo")
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

-- 2b) Usuarios (técnicos u otras personas que pueden figurar como
-- Responsable Rendición además de los Responsables del Fondo). Editable
-- desde el panel admin, pestaña "Usuarios".
create table if not exists public.usuarios (
  id      bigint generated always as identity primary key,
  nombre  text not null unique,
  activo  boolean not null default true
);

alter table public.usuarios enable row level security;

drop policy if exists "usuarios_select_anon" on public.usuarios;
create policy "usuarios_select_anon"
  on public.usuarios for select
  to anon
  using (true);

drop policy if exists "usuarios_insert_anon" on public.usuarios;
create policy "usuarios_insert_anon"
  on public.usuarios for insert
  to anon
  with check (true);

drop policy if exists "usuarios_update_anon" on public.usuarios;
create policy "usuarios_update_anon"
  on public.usuarios for update
  to anon
  using (true)
  with check (true);

insert into public.usuarios (nombre, activo) values
  ('Jorge C.', true),
  ('Demis S.', true),
  ('No Aplica', true)
on conflict (nombre) do nothing;

-- 2c) Centros de Costo / Proyecto (editable desde el panel admin,
-- pestaña "Centros de Costo").
create table if not exists public.centros_costo (
  id      bigint generated always as identity primary key,
  nombre  text not null unique,
  activo  boolean not null default true
);

alter table public.centros_costo enable row level security;

drop policy if exists "centros_select_anon" on public.centros_costo;
create policy "centros_select_anon"
  on public.centros_costo for select
  to anon
  using (true);

drop policy if exists "centros_insert_anon" on public.centros_costo;
create policy "centros_insert_anon"
  on public.centros_costo for insert
  to anon
  with check (true);

drop policy if exists "centros_update_anon" on public.centros_costo;
create policy "centros_update_anon"
  on public.centros_costo for update
  to anon
  using (true)
  with check (true);

insert into public.centros_costo (nombre, activo) values
  ('General', true),
  ('Administración', true),
  ('Proyecto A', true),
  ('Proyecto B', true),
  ('Terreno', true)
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
-- - "cuenta_responsable" = Responsable del Fondo (Yerko/Eduardo/Nicolás), se
--   elige al entrar a la app y se administra en admin.html.
-- - "responsable_rendicion" = quién hizo la compra específica: puede ser el
--   mismo Responsable del Fondo, o un técnico (Jorge C., Demis S., No Aplica).
-- - El bucket queda público de lectura para poder mostrar las fotos en el
--   panel admin y para que Claude pueda leerlas al consolidar. Si las
--   boletas muestran datos sensibles y prefieres que no sean públicas,
--   avísame y cambiamos a bucket privado + URLs firmadas.
-- - Sí existe política de DELETE en "rendiciones", para poder borrar
--   registros duplicados desde el panel admin. El propio admin.html pide
--   confirmación antes de borrar, y no hay forma de borrar desde index.html.
-- ============================================================
