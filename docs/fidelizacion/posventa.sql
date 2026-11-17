-- ============================================================================
-- CRM Lana Rosa — Posventa automática (propuesta de SQL)
-- Base destino: ngjoognzvehwjtpqwrqe (Lana Rosa ERP + SO)
--
-- ESTADO: PROPUESTA. NO SE HA APLICADO EN NINGUNA BASE. Diseño en docs/fidelizacion/posventa.md.
-- Antes de aplicar: revisión de WEB (Web Chat 5) y del Orquestador ERP (con Sara),
-- respuesta de la abogada (Ley 1581) y OK de Sara. Después: asesor de seguridad.
--
-- Qué hace: solo CREA objetos nuevos (crm_posventa*, v_crm_posventa_candidatas,
-- fn_crm_posventa_*, encuesta_posventa_*). No modifica ni borra nada existente.
-- NO cambia fn_correo_calificar, fn_correo_compra_web, cuentas_novedades ni ninguna tabla de la web.
--
-- Nace APAGADA: crm_posventa_config.activo = false. Mientras esté apagada no se programa
-- ni se envía nada. El programador de tareas (pg_cron) va comentado al final.
--
-- Excepción consciente a «funciones nuevas nacen cerradas»: encuesta_posventa_ver y
-- encuesta_posventa_responder deben ser ejecutables por anon (la clienta no inicia sesión).
-- Se protegen con un token aleatorio de 64 caracteres por pedido, vencimiento y un solo uso.
-- Esperado en el asesor de seguridad: 2 avisos de «SECURITY DEFINER ejecutable por anon».
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Configuración (una sola fila)
-- ----------------------------------------------------------------------------
create table public.crm_posventa_config (
  id                  boolean primary key default true check (id),   -- fuerza una sola fila
  activo              boolean not null default false,
  requiere_novedades  boolean not null default true,    -- true hasta que la abogada responda
  dias_espera         integer not null default 5   check (dias_espera between 1 and 30),
  dias_vigencia       integer not null default 30  check (dias_vigencia between 7 and 90),
  enfriamiento_dias   integer not null default 30  check (enfriamiento_dias >= 0),
  desde_entregados    date,                          -- obligatorio al activar: no se escribe al atraso
  remitente           text not null default 'Lana Rosa Crochet <contacto@lanarosacrochet.com>',
  url_encuesta        text not null default 'https://lanarosacrochet.com/encuesta.html',  -- WEB lo construye
  url_baja            text not null default 'https://lanarosacrochet.com/baja.html',      -- WEB lo construye
  url_resena_web      text not null default 'https://lanarosacrochet.com/cuenta.html',
  url_google          text not null default 'https://g.page/r/Cae2iIji5j_XEAI/review',    -- enlace directo de la ficha (Sara, 16-nov)
  updated_at          timestamptz not null default now(),
  constraint crm_posventa_config_activar_chk check (not activo or desde_entregados is not null)
);
insert into public.crm_posventa_config default values;
comment on table public.crm_posventa_config is
  'CRM posventa: interruptor y parámetros. activo=false al nacer; para encender exige desde_entregados.';


-- ----------------------------------------------------------------------------
-- 2. crm_posventa — un seguimiento por pedido entregado
-- ----------------------------------------------------------------------------
create table public.crm_posventa (
  id                uuid primary key default gen_random_uuid(),
  pedido_id         uuid not null unique references public.pedidos_canal_venta (id),
  tercero_id        uuid not null references public.terceros (id),
  token             text not null unique
                    default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  entregado_at      timestamptz not null,
  vence_at          timestamptz not null,
  correo_estado     text not null check (correo_estado in ('pendiente', 'enviado', 'omitido', 'error')),
  correo_enviado_at timestamptz,
  correo_detalle    text,
  whatsapp_estado   text not null check (whatsapp_estado in ('pendiente', 'enviado', 'omitido')),
  whatsapp_marcado_at timestamptz,
  respondida_at     timestamptz,
  created_at        timestamptz not null default now()
);
comment on table public.crm_posventa is
  'CRM posventa: un registro por pedido entregado, con el enlace único (token) de la encuesta y el estado de cada canal.';
create index crm_posventa_tercero_idx  on public.crm_posventa (tercero_id, created_at desc);
create index crm_posventa_correo_idx   on public.crm_posventa (created_at) where correo_estado = 'pendiente';
create index crm_posventa_whatsapp_idx on public.crm_posventa (created_at) where whatsapp_estado = 'pendiente' and respondida_at is null;


-- ----------------------------------------------------------------------------
-- 3. crm_posventa_respuestas — la encuesta (datos mínimos: sin nombre, sin teléfono, sin correo)
-- ----------------------------------------------------------------------------
create table public.crm_posventa_respuestas (
  posventa_id  uuid primary key references public.crm_posventa (id),   -- una respuesta por pedido
  felicidad    smallint not null check (felicidad between 1 and 5),
  atencion     smallint not null check (atencion between 1 and 5),
  a_tiempo     text not null check (a_tiempo in ('si', 'mas_o_menos', 'no')),
  comentario   text check (comentario is null or char_length(comentario) <= 1000),
  created_at   timestamptz not null default now()
);
comment on table public.crm_posventa_respuestas is
  'CRM posventa: respuestas de la encuesta. Solo se escribe por encuesta_posventa_responder (valida el token).';


-- ----------------------------------------------------------------------------
-- 4. Permisos y RLS: tablas cerradas; solo administrador. anon no ve ninguna tabla.
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['crm_posventa_config', 'crm_posventa', 'crm_posventa_respuestas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant select on table public.%I to authenticated', t);
    execute format(
      'create policy %I on public.%I for select to authenticated
         using (coalesce(public.fn_rol_actual()::text, '''') = ''administrador'')',
      t || '_admin_lee', t);
  end loop;
  -- la configuración la cambia la administradora (no hay otra forma de apagar/encender desde el CRM)
  grant update on table public.crm_posventa_config to authenticated;
  create policy crm_posventa_config_admin_edita on public.crm_posventa_config for update to authenticated
    using (coalesce(public.fn_rol_actual()::text, '') = 'administrador')
    with check (coalesce(public.fn_rol_actual()::text, '') = 'administrador');
end $$;


-- ----------------------------------------------------------------------------
-- 5. Candidatas: quién toca hoy. Vista cerrada (solo la usan las funciones de abajo).
--    Reglas:
--      · pedido entregado hace >= dias_espera días, y no más viejo que dias_vigencia
--      · entregado DESPUÉS de desde_entregados (nunca se escribe al atraso de 33 pedidos)
--      · cliente activo, con correo válido o con teléfono
--      · si requiere_novedades: cuenta web con cuentas_novedades.acepta = true
--      · un pedido = una posventa; un cliente = una posventa cada enfriamiento_dias
--        (si entregaron 2 pedidos casi juntos, se pregunta por el primero)
--    La fecha de entrega sale de pedidos_canal_historial (estado 'entregado').
-- ----------------------------------------------------------------------------
create view public.v_crm_posventa_candidatas as
with cfg as (select * from public.crm_posventa_config where id),
base as (
  select p.id as pedido_id, p.tercero_id, h.entregado_at,
         (coalesce(t.email, '') ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$') as tiene_correo,
         (coalesce(btrim(t.telefono), '') <> '') as tiene_telefono
    from public.pedidos_canal_venta p
    join lateral (select max(created_at) as entregado_at
                    from public.pedidos_canal_historial
                   where pedido_id = p.id and estado::text = 'entregado') h on h.entregado_at is not null
    join public.terceros t on t.id = p.tercero_id and t.activo
    cross join cfg
   where p.estado::text = 'entregado'
     and h.entregado_at >= cfg.desde_entregados::timestamptz
     and h.entregado_at <= now() - make_interval(days => cfg.dias_espera)
     and h.entregado_at >= now() - make_interval(days => cfg.dias_vigencia)
     and not exists (select 1 from public.crm_posventa x where x.pedido_id = p.id)
     and not exists (select 1 from public.crm_posventa x
                      where x.tercero_id = p.tercero_id
                        and x.created_at > now() - make_interval(days => cfg.enfriamiento_dias))
     and (not cfg.requiere_novedades
          or exists (select 1
                       from public.cuentas_clientes_web c
                       join public.cuentas_novedades n on n.user_id = c.user_id and n.acepta
                      where c.tercero_id = p.tercero_id))
)
select distinct on (tercero_id) pedido_id, tercero_id, entregado_at, tiene_correo, tiene_telefono
  from base
 where tiene_correo or tiene_telefono
 order by tercero_id, entregado_at;

revoke all on public.v_crm_posventa_candidatas from public, anon, authenticated;


-- ----------------------------------------------------------------------------
-- 6. Programar: crea los registros del día (solo si está activa). p_simular = true solo cuenta.
--    La ejecuta el programador (postgres), no hay permiso para nadie más.
-- ----------------------------------------------------------------------------
create or replace function public.fn_crm_posventa_programar(p_simular boolean default true)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_cfg public.crm_posventa_config; v_n integer;
begin
  select * into v_cfg from public.crm_posventa_config where id;
  if p_simular then
    select count(*) into v_n from public.v_crm_posventa_candidatas;   -- ojo: la vista ya usa desde_entregados
    return v_n;
  end if;
  if not v_cfg.activo then return 0; end if;

  insert into public.crm_posventa (pedido_id, tercero_id, entregado_at, vence_at, correo_estado, whatsapp_estado)
  select c.pedido_id, c.tercero_id, c.entregado_at,
         now() + make_interval(days => v_cfg.dias_vigencia),
         case when c.tiene_correo   then 'pendiente' else 'omitido' end,
         case when c.tiene_telefono then 'pendiente' else 'omitido' end
    from public.v_crm_posventa_candidatas c
  on conflict (pedido_id) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke all on function public.fn_crm_posventa_programar(boolean) from public, anon, authenticated;


-- ----------------------------------------------------------------------------
-- 7. Enviar el correo (mismo envío que la web: Resend con la llave `resend_api_key` de la bóveda,
--    vía pg_net). Una vez por pedido (Idempotency-Key). Texto: BORRADOR, lo aprueba Web Chat 8.
--    Nada de Navidad, santos ni Halloween. Las invitaciones a calificar van a TODAS, sin filtro.
-- ----------------------------------------------------------------------------
create or replace function public.fn_crm_posventa_enviar_correos(p_limite integer default 50)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_cfg public.crm_posventa_config; v_key text; r record; v_html text; v_nombre text;
  v_enc text; v_baja text; v_n integer := 0; v_req bigint;
begin
  select * into v_cfg from public.crm_posventa_config where id;
  if not v_cfg.activo then return 0; end if;
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'resend_api_key';
  if v_key is null then return 0; end if;

  for r in
    select s.id, s.token, s.pedido_id, t.email,
           coalesce(nullif(btrim(t.primer_nombre), ''), split_part(btrim(t.nombre_completo), ' ', 1)) as nombre,
           p.descripcion_producto
      from public.crm_posventa s
      join public.terceros t on t.id = s.tercero_id
      join public.pedidos_canal_venta p on p.id = s.pedido_id
     where s.correo_estado = 'pendiente' and s.respondida_at is null and s.vence_at > now()
     order by s.created_at
     limit p_limite
  loop
    v_nombre := initcap(replace(replace(replace(coalesce(r.nombre, ''), '&', ''), '<', ''), '>', ''));
    v_enc  := v_cfg.url_encuesta || '?t=' || r.token;
    v_baja := v_cfg.url_baja     || '?t=' || r.token;
    v_html := format(
      '<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#45454A">'
      || '<h2 style="color:#E74E96">¡Gracias por elegirnos! 💗</h2>'
      || '<p>Hola%s, esperamos que tu pedido ya esté contigo y que te haya encantado. '
      || 'Gracias por confiar en nosotras: cada pieza la teje una persona pensando en ti.</p>'
      || '<p>¿Nos cuentas cómo te fue? Son 4 preguntas rápidas (menos de un minuto):</p>'
      || '<p style="text-align:center;margin:22px 0"><a href="%s" style="background:#E74E96;color:#fff;text-decoration:none;padding:13px 26px;border-radius:999px;font-weight:bold">Contar mi experiencia</a></p>'
      || '<p>Y si quieres, tu opinión también ayuda a otras personas a conocernos:</p>'
      || '<p style="text-align:center"><a href="%s" style="color:#E74E96;font-weight:bold">Calificar en nuestra web</a> &nbsp;·&nbsp; <a href="%s" style="color:#E74E96;font-weight:bold">Calificar en Google</a></p>'
      || '<p style="font-size:13px;color:#6E6E73">Con cariño, Lana Rosa Crochet.</p>'
      || '<p style="font-size:11px;color:#9A9AA0">Recibes este correo porque aceptaste recibir novedades. '
      || '<a href="%s" style="color:#9A9AA0">Dejar de recibirlos</a>.</p></div>',
      case when v_nombre = '' then '' else ' ' || v_nombre end, v_enc, v_cfg.url_resena_web, v_cfg.url_google, v_baja);

    select net.http_post(
      url     := 'https://api.resend.com/emails',
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json',
                                    'Idempotency-Key', 'posventa-' || r.id),
      body    := jsonb_build_object(
                   'from', v_cfg.remitente, 'to', jsonb_build_array(r.email),
                   'subject', '💗 Gracias por tu pedido: ¿cómo te fue?', 'html', v_html,
                   'headers', jsonb_build_object('List-Unsubscribe', '<' || v_baja || '>'))
    ) into v_req;

    update public.crm_posventa
       set correo_estado = 'enviado', correo_enviado_at = now(), correo_detalle = 'pg_net request ' || v_req
     where id = r.id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;
revoke all on function public.fn_crm_posventa_enviar_correos(integer) from public, anon, authenticated;
-- Nota: pg_net es asíncrono. 'enviado' = entregado a Resend para envío. Si el ERP quiere registrar
-- también en correos_enviados o revisar rebotes (net._http_response / webhook de Resend), se agrega después.


-- ----------------------------------------------------------------------------
-- 8. Encuesta pública (sin sesión). Solo estas dos funciones tocan lo de la clienta.
-- ----------------------------------------------------------------------------
create or replace function public.encuesta_posventa_ver(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare r record;
begin
  select s.respondida_at, s.vence_at,
         coalesce(nullif(btrim(t.primer_nombre), ''), split_part(btrim(t.nombre_completo), ' ', 1)) as nombre,
         p.descripcion_producto
    into r
    from public.crm_posventa s
    join public.terceros t on t.id = s.tercero_id
    join public.pedidos_canal_venta p on p.id = s.pedido_id
   where s.token = p_token;
  if not found then return jsonb_build_object('estado', 'invalida'); end if;
  if r.respondida_at is not null then return jsonb_build_object('estado', 'respondida'); end if;
  if r.vence_at <= now() then return jsonb_build_object('estado', 'vencida'); end if;
  return jsonb_build_object('estado', 'abierta', 'nombre', initcap(r.nombre), 'producto', left(r.descripcion_producto, 80));
end $$;

create or replace function public.encuesta_posventa_responder(
  p_token text, p_felicidad integer, p_atencion integer, p_a_tiempo text, p_comentario text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare s public.crm_posventa; v_cfg public.crm_posventa_config; v_com text;
begin
  select * into s from public.crm_posventa where token = p_token for update;
  if not found then return jsonb_build_object('ok', false, 'estado', 'invalida'); end if;
  if s.respondida_at is not null then return jsonb_build_object('ok', false, 'estado', 'respondida'); end if;
  if s.vence_at <= now() then return jsonb_build_object('ok', false, 'estado', 'vencida'); end if;
  if p_felicidad is null or p_felicidad not between 1 and 5
     or p_atencion is null or p_atencion not between 1 and 5
     or p_a_tiempo is null or p_a_tiempo not in ('si', 'mas_o_menos', 'no') then
    return jsonb_build_object('ok', false, 'estado', 'datos_invalidos');
  end if;
  v_com := nullif(btrim(left(coalesce(p_comentario, ''), 1000)), '');

  insert into public.crm_posventa_respuestas (posventa_id, felicidad, atencion, a_tiempo, comentario)
  values (s.id, p_felicidad, p_atencion, p_a_tiempo, v_com);
  update public.crm_posventa set respondida_at = now() where id = s.id;

  -- Algo no salió bien: tarea interna para cuidar a la clienta (no cambia lo que se le muestra).
  if p_felicidad <= 3 or p_atencion <= 3 or p_a_tiempo = 'no' then
    insert into public.crm_tareas (tercero_id, titulo, vence)
    values (s.tercero_id, 'Posventa: la clienta marcó algo por mejorar. Escribirle personalmente.', current_date + 1);
  end if;

  -- Invitación a calificar para TODAS, sin importar las notas y sin dar nada a cambio.
  select * into v_cfg from public.crm_posventa_config where id;
  return jsonb_build_object('ok', true, 'estado', 'respondida',
                            'resena_web', v_cfg.url_resena_web, 'resena_google', v_cfg.url_google);
end $$;

revoke all on function public.encuesta_posventa_ver(text) from public;
revoke all on function public.encuesta_posventa_responder(text, integer, integer, text, text) from public;
grant execute on function public.encuesta_posventa_ver(text) to anon, authenticated;
grant execute on function public.encuesta_posventa_responder(text, integer, integer, text, text) to anon, authenticated;


-- ----------------------------------------------------------------------------
-- 9. Para la pantalla Seguimiento (solo administrador)
-- ----------------------------------------------------------------------------
create or replace function public.fn_crm_posventa_pendientes()
returns table (posventa_id uuid, pedido_consecutivo text, cliente text, telefono text,
               producto text, enlace text, entregado_at timestamptz, correo_estado text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'sin permiso' using errcode = '42501';
  end if;
  return query
    select s.id, p.consecutivo, t.nombre_completo, t.telefono, p.descripcion_producto,
           c.url_encuesta || '?t=' || s.token, s.entregado_at, s.correo_estado
      from public.crm_posventa s
      join public.terceros t on t.id = s.tercero_id
      join public.pedidos_canal_venta p on p.id = s.pedido_id
      cross join public.crm_posventa_config c
     where s.whatsapp_estado = 'pendiente' and s.respondida_at is null and s.vence_at > now()
     order by s.entregado_at;
end $$;

create or replace function public.fn_crm_posventa_marcar_whatsapp(p_posventa_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'sin permiso' using errcode = '42501';
  end if;
  update public.crm_posventa
     set whatsapp_estado = 'enviado', whatsapp_marcado_at = now()
   where id = p_posventa_id and whatsapp_estado = 'pendiente';
end $$;

create or replace function public.fn_crm_posventa_resultados(p_desde date default null)
returns table (respondida_at timestamptz, pedido_consecutivo text, cliente text, felicidad smallint,
               atencion smallint, a_tiempo text, comentario text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'sin permiso' using errcode = '42501';
  end if;
  return query
    select r.created_at, p.consecutivo, t.nombre_completo, r.felicidad, r.atencion, r.a_tiempo, r.comentario
      from public.crm_posventa_respuestas r
      join public.crm_posventa s on s.id = r.posventa_id
      join public.terceros t on t.id = s.tercero_id
      join public.pedidos_canal_venta p on p.id = s.pedido_id
     where p_desde is null or r.created_at::date >= p_desde
     order by r.created_at desc;
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'fn_crm_posventa_pendientes()', 'fn_crm_posventa_marcar_whatsapp(uuid)', 'fn_crm_posventa_resultados(date)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 10. Plantilla de WhatsApp (se agrega al texto existente 'posventa' de crm_plantillas_mensaje;
--     la pantalla reemplaza {enlace}). BORRADOR para Web Chat 8. Comercial: solo con novedades.
-- ----------------------------------------------------------------------------
-- update public.crm_plantillas_mensaje
--    set texto = E'Hola {nombre} 🌸 Gracias por elegir Lana Rosa Crochet. Esperamos que tu {producto} ya esté contigo y te haya encantado.\n\n¿Nos cuentas cómo te fue? Son 4 preguntas rápidas: {enlace}\n\nSi quieres, también puedes dejar tu opinión en Google y en nuestra web; nos ayuda muchísimo.\n\nCordialmente,\nLana Rosa Crochet'
--  where clave = 'posventa';


-- ----------------------------------------------------------------------------
-- 11. Programador diario (COMENTADO: se activa solo con crm_posventa_config.activo = true).
--     10:00 a. m. de Colombia = 15:00 UTC (Colombia no tiene horario de verano).
-- ----------------------------------------------------------------------------
-- select cron.schedule('crm_posventa_diario', '0 15 * * *',
--   $$select public.fn_crm_posventa_programar(false); select public.fn_crm_posventa_enviar_correos();$$);
-- Para apagar de inmediato: update public.crm_posventa_config set activo = false;
--   (y si hace falta) select cron.unschedule('crm_posventa_diario');
