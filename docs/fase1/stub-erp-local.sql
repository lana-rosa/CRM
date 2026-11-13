-- ============================================================================
-- TABLAS DE MENTIRA para probar docs/fase1/propuesta.sql en un Postgres LOCAL.
-- No es el ERP: solo imita lo mínimo (columnas que usa la propuesta) y los permisos por
-- defecto de Supabase. NUNCA correr esto en Supabase.
--
-- Uso (base vacía y desechable):
--   createdb prueba_fase1
--   psql -v ON_ERROR_STOP=1 -d prueba_fase1 -f stub-erp-local.sql
--   psql -v ON_ERROR_STOP=1 -1 -d prueba_fase1 -f propuesta.sql
--   psql -d prueba_fase1 -f prueba-casas-local.sql
-- ============================================================================
drop schema if exists auth cascade;
create schema auth;
create or replace function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claims', true)::json->>'sub', '')::uuid $$;

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;

create type rol_usuario as enum ('administrador', 'cajero', 'taller', 'contador');
create type tipo_tercero as enum ('cliente', 'proveedor', 'empleado', 'mixto', 'financiadora');
create type tipo_documento as enum ('CC', 'CE', 'NIT', 'PASAPORTE', 'TI');
create type estado_pedido as enum ('esperando_pago', 'en_preparacion', 'listo_despacho', 'entregado');
create type canal_pedido as enum ('whatsapp', 'instagram', 'facebook', 'tienda_virtual');
create type tipo_inventario as enum ('merceria', 'producto_terminado');

create table usuarios_roles (user_id uuid, rol rol_usuario, activo boolean default true);
create table tejedoras_usuarios (user_id uuid);

create function public.fn_rol_actual() returns rol_usuario language sql stable security definer
  set search_path = public as $$ select rol from usuarios_roles where user_id = auth.uid() and activo limit 1 $$;
create function public.fn_es_tejedora() returns boolean language sql stable security definer
  set search_path = public as $$ select exists (select 1 from tejedoras_usuarios where user_id = auth.uid()) $$;

create table centros_costo (id uuid primary key default gen_random_uuid(), codigo text not null unique, nombre text not null);
insert into centros_costo (codigo, nombre) values
  ('01', 'Tienda/Mercería'), ('02', 'Marketplace'), ('03', 'Taller de Tejido'),
  ('04', 'Lana Rosa Academy'), ('05', 'Cursos (Hotmart)'), ('06', 'YouTube');

create table terceros (
  id uuid primary key default gen_random_uuid(), tipo tipo_tercero not null default 'cliente',
  tipo_documento tipo_documento not null default 'CC', numero_documento text not null,
  nombre_completo text not null, email text, telefono text, ciudad text,
  acepta_tratamiento_datos boolean not null default false, fecha_aceptacion_datos timestamptz,
  activo boolean not null default true, puntos_fidelizacion int not null default 0,
  medio_autorizacion text, version_politica text, codigo_pais text not null default 'CO');

create table inventario_items (id uuid primary key default gen_random_uuid(), tipo tipo_inventario not null, nombre text not null);

create table pedidos_canal_venta (
  id uuid primary key default gen_random_uuid(), consecutivo text, canal canal_pedido not null,
  centro_costo_id uuid not null, tercero_id uuid, inventario_item_id uuid,
  descripcion_producto text not null, total_pedido numeric not null, estado estado_pedido not null,
  created_at timestamptz not null default now());
create table pedidos_canal_lineas (
  id uuid primary key default gen_random_uuid(), pedido_id uuid not null, inventario_item_id uuid,
  descripcion text, cantidad numeric not null, valor_unitario numeric not null);

create table ventas_pos (
  id uuid primary key default gen_random_uuid(), consecutivo text, fecha timestamptz not null default now(),
  tercero_id uuid, centro_costo_id uuid not null, total numeric not null, estado text not null, canal text not null);
create table ventas_pos_detalle (
  id uuid primary key default gen_random_uuid(), venta_id uuid not null, inventario_item_id uuid,
  descripcion text, cantidad numeric, precio_unitario numeric, subtotal_linea numeric not null);

create table ventas_academia (
  id uuid primary key default gen_random_uuid(), fecha date not null, area_formacion text not null,
  descripcion text not null, monto numeric not null, tercero_id uuid);

create table oportunidades_venta (
  id uuid primary key default gen_random_uuid(), consecutivo text not null, tercero_id uuid,
  cliente_nombre_libre text, cliente_telefono_libre text, descripcion text not null,
  monto_estimado numeric not null default 0, etapa text not null, origen text not null default 'manual',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table cuentas_clientes_web (user_id uuid primary key, tercero_id uuid);
create table pedidos_web (
  id uuid primary key default gen_random_uuid(), user_id uuid, estado text not null,
  es_prueba boolean not null default false, es_digital boolean not null default false,
  erp_pedidos uuid[], created_at timestamptz not null default now());
create table pedidos_web_items (
  id uuid primary key default gen_random_uuid(), pedido_id uuid not null, producto_id uuid,
  nombre text, precio numeric not null, cantidad integer not null);

grant usage on schema public, auth to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;
