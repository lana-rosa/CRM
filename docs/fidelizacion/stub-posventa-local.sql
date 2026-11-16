-- Tablas de mentira EXTRA para probar posventa.sql en local (se suma a ../fase1/stub-erp-local.sql). NUNCA en Supabase.
alter table terceros add column primer_nombre text;
create table pedidos_canal_historial (id uuid primary key default gen_random_uuid(), pedido_id uuid, estado estado_pedido, usuario uuid, created_at timestamptz default now());
create table if not exists cuentas_clientes_web (user_id uuid, tercero_id uuid);
create table cuentas_novedades (user_id uuid, acepta boolean);
create table crm_tareas (id uuid primary key default gen_random_uuid(), tercero_id uuid, titulo text not null, vence date, hecha boolean default false);
create schema vault; create table vault.decrypted_secrets (name text, decrypted_secret text);
insert into vault.decrypted_secrets values ('resend_api_key', 'llave-de-mentira');
create schema net; create table net._llamadas (id bigserial, url text, headers jsonb, body jsonb);
create function net.http_post(url text, headers jsonb default '{}', body jsonb default '{}') returns bigint language sql as
$$ insert into net._llamadas(url, headers, body) values (url, headers, body) returning id $$;
