-- ============================================================================
-- CRM Lana Rosa — FASE 1 (propuesta): el CRM pasa a vivir en la base del ERP
-- Base destino: ngjoognzvehwjtpqwrqe (Lana Rosa ERP + SO)
--
-- ESTADO: PROPUESTA. NO SE HA APLICADO EN NINGUNA BASE.
-- Antes de aplicar: revisión del Orquestador ERP (con Sara) y del Orquestador WEB
-- (Web Chat 5). Después de aplicar: asesor de seguridad con 0 errores nuevos.
--
-- Qué hace: solo CREA objetos nuevos con prefijo crm_ / fn_crm_. No modifica ni
-- borra nada existente: ninguna tabla del ERP cambia de forma (ni columnas, ni
-- políticas), ningún DROP, ningún ALTER ... DROP COLUMN. No toca el puente
-- CRM -> ERP (fn_trg_estado_pedido_a_erp), que vive en la base del CRM.
--
-- Reglas que sigue (docs/temas/datos-integracion-erp.md, "Pautas para la Fase 1"):
--   * RLS encendida desde el primer momento en toda tabla crm_*.
--   * Nada abierto a anon ni a PUBLIC. Supabase da permisos por defecto a anon y
--     authenticated en objetos nuevos de public: aquí se revocan explícitamente.
--   * Roles con fn_rol_actual() del ERP. Todo lo del CRM es solo 'administrador'.
--   * Funciones nuevas: security definer, search_path fijo, execute solo para
--     authenticated, y adentro se vuelve a chequear el rol.
--   * El CRM NO escribe en terceros/pedidos_*/ventas_*: solo las lee por RPC.
--   * Ley 1581: los prospectos sin autorización de datos van a crm_contactos
--     (datos mínimos), nunca a terceros.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0. Función de apoyo: updated_at (security invoker, sin acceso a datos)
-- ----------------------------------------------------------------------------
create or replace function public.fn_crm_set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

revoke all on function public.fn_crm_set_updated_at() from public, anon, authenticated;


-- ----------------------------------------------------------------------------
-- 1. crm_contactos — prospectos SIN autorización de tratamiento de datos
--    Datos mínimos a propósito: sin cédula, sin fecha de nacimiento, sin dirección,
--    sin correo. Cuando la persona autorice, se promueve a terceros (ver sección 7).
-- ----------------------------------------------------------------------------
create table public.crm_contactos (
  id                      uuid primary key default gen_random_uuid(),
  nombre                  text not null,
  telefono                text,
  usuario_redes           text,
  canal                   text,
  ciudad                  text,
  como_llego              text,
  notas                   text,
  fecha_primer_contacto   date not null default current_date,
  estado                  text not null default 'contacto'
                          check (estado in ('contacto', 'promovido', 'descartado')),
  tercero_id              uuid references public.terceros (id),      -- se llena al promoverlo
  crm_cliente_id_origen   uuid,                                      -- id en la base vieja del CRM, si vino de allí
  conservar_hasta         date,                                      -- plazo de conservación: lo define la abogada
  created_by              uuid default auth.uid(),
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  constraint crm_contactos_promovido_chk
    check (estado <> 'promovido' or tercero_id is not null)
);
comment on table public.crm_contactos is
  'CRM: prospectos sin autorización de datos (Ley 1581). Datos mínimos. Se promueven a terceros cuando aceptan.';

create index crm_contactos_tercero_idx on public.crm_contactos (tercero_id) where tercero_id is not null;
create unique index crm_contactos_origen_unq on public.crm_contactos (crm_cliente_id_origen) where crm_cliente_id_origen is not null;

create trigger trg_crm_contactos_updated
  before update on public.crm_contactos
  for each row execute function public.fn_crm_set_updated_at();


-- ----------------------------------------------------------------------------
-- 2. crm_interacciones — historial de contacto con un cliente (tercero) o un contacto
-- ----------------------------------------------------------------------------
create table public.crm_interacciones (
  id           uuid primary key default gen_random_uuid(),
  tercero_id   uuid references public.terceros (id),
  contacto_id  uuid references public.crm_contactos (id),
  pedido_id    uuid references public.pedidos_canal_venta (id),
  tipo         text not null,
  resumen      text,
  created_by   uuid default auth.uid(),
  created_at   timestamptz not null default now(),
  constraint crm_interacciones_quien_chk check (num_nonnulls(tercero_id, contacto_id) = 1)
);
comment on table public.crm_interacciones is 'CRM: llamadas, mensajes y notas con un cliente (terceros) o contacto (crm_contactos).';

create index crm_interacciones_tercero_idx  on public.crm_interacciones (tercero_id, created_at desc) where tercero_id is not null;
create index crm_interacciones_contacto_idx on public.crm_interacciones (contacto_id, created_at desc) where contacto_id is not null;
create index crm_interacciones_pedido_idx   on public.crm_interacciones (pedido_id) where pedido_id is not null;


-- ----------------------------------------------------------------------------
-- 3. crm_tareas — pendientes de seguimiento
-- ----------------------------------------------------------------------------
create table public.crm_tareas (
  id              uuid primary key default gen_random_uuid(),
  tercero_id      uuid references public.terceros (id),
  contacto_id     uuid references public.crm_contactos (id),
  oportunidad_id  uuid references public.oportunidades_venta (id),
  titulo          text not null,
  vence           date,
  hecha           boolean not null default false,
  hecha_at        timestamptz,
  created_by      uuid default auth.uid(),
  created_at      timestamptz not null default now(),
  constraint crm_tareas_quien_chk check (num_nonnulls(tercero_id, contacto_id) <= 1)
);
comment on table public.crm_tareas is 'CRM: tareas de seguimiento (a quién escribirle y cuándo).';

create index crm_tareas_pendientes_idx on public.crm_tareas (vence) where not hecha;
create index crm_tareas_tercero_idx    on public.crm_tareas (tercero_id) where tercero_id is not null;
create index crm_tareas_contacto_idx   on public.crm_tareas (contacto_id) where contacto_id is not null;
create index crm_tareas_oport_idx      on public.crm_tareas (oportunidad_id) where oportunidad_id is not null;


-- ----------------------------------------------------------------------------
-- 4. crm_fechas_especiales — solo de clientes (terceros) que ya autorizaron
--    Ojo Ley 1581: la web NO pide fecha de nacimiento. Pedirla o guardarla es un dato
--    nuevo con finalidad propia: consultar a la abogada antes de usar esta tabla
--    para cumpleaños.
-- ----------------------------------------------------------------------------
create table public.crm_fechas_especiales (
  id           uuid primary key default gen_random_uuid(),
  tercero_id   uuid not null references public.terceros (id),
  tipo         text not null,
  fecha        date not null,
  descripcion  text,
  para_quien   text,
  created_by   uuid default auth.uid(),
  created_at   timestamptz not null default now()
);
comment on table public.crm_fechas_especiales is
  'CRM: fechas especiales de un cliente. Ley 1581: ver nota en propuesta.sql antes de usar para cumpleaños.';

create index crm_fechas_tercero_idx on public.crm_fechas_especiales (tercero_id);
create index crm_fechas_fecha_idx   on public.crm_fechas_especiales (fecha);


-- ----------------------------------------------------------------------------
-- 5. crm_plantillas_mensaje — textos de WhatsApp
--    es_comercial = true: solo se envía a quien marcó la casilla opcional de novedades
--    y con enlace de baja (acuerdo con la Web, 13-nov). Marca: nada de Navidad,
--    santos ni Halloween.
-- ----------------------------------------------------------------------------
create table public.crm_plantillas_mensaje (
  id            uuid primary key default gen_random_uuid(),
  clave         text not null unique,
  titulo        text not null,
  texto         text not null,
  es_comercial  boolean not null default true,
  activa        boolean not null default true,
  orden         integer not null default 0,
  updated_at    timestamptz not null default now()
);
comment on table public.crm_plantillas_mensaje is
  'CRM: plantillas de mensaje. es_comercial=true exige autorización de novedades (publicidad).';

create trigger trg_crm_plantillas_updated
  before update on public.crm_plantillas_mensaje
  for each row execute function public.fn_crm_set_updated_at();


-- ----------------------------------------------------------------------------
-- 6. crm_oportunidades_detalle — campos extra del embudo, al lado de oportunidades_venta
--    (acordado con ERP y WEB: tabla aparte, sin tocar oportunidades_venta).
--    etapa_crm guarda la etapa fina del CRM; oportunidades_venta.etapa sigue siendo
--    la oficial del ERP (prospecto, calificado, propuesta, cierre_ganado, cierre_perdido).
--    Equivalencia sugerida:
--      consulta -> prospecto | cotizacion -> propuesta | anticipo, produccion, listo,
--      entregado, posventa -> cierre_ganado | perdida -> cierre_perdido
-- ----------------------------------------------------------------------------
create table public.crm_oportunidades_detalle (
  oportunidad_id         uuid primary key references public.oportunidades_venta (id),
  etapa_crm              text check (etapa_crm in
                           ('consulta', 'cotizacion', 'anticipo', 'produccion', 'listo', 'entregado', 'posventa', 'perdida')),
  etapa_desde            timestamptz not null default now(),
  fecha_entrega_deseada  date,
  motivo_perdida         text,
  pedido_id              uuid references public.pedidos_canal_venta (id),
  posventa_hecha         boolean not null default false,
  created_by             uuid default auth.uid(),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
comment on table public.crm_oportunidades_detalle is
  'CRM: detalle de una oportunidad_venta (etapa fina, motivo de pérdida, fecha deseada, pedido ligado).';

create index crm_oport_detalle_pedido_idx on public.crm_oportunidades_detalle (pedido_id) where pedido_id is not null;

create trigger trg_crm_oport_detalle_updated
  before update on public.crm_oportunidades_detalle
  for each row execute function public.fn_crm_set_updated_at();


-- ----------------------------------------------------------------------------
-- 7. Permisos y RLS (todas las tablas crm_*): solo administrador
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'crm_contactos', 'crm_interacciones', 'crm_tareas',
    'crm_fechas_especiales', 'crm_plantillas_mensaje', 'crm_oportunidades_detalle'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from public, anon, authenticated', t);
    execute format('grant select, insert, update, delete on table public.%I to authenticated', t);
    execute format(
      'create policy %I on public.%I for all to authenticated
         using (coalesce(public.fn_rol_actual()::text, '''') = ''administrador'')
         with check (coalesce(public.fn_rol_actual()::text, '''') = ''administrador'')',
      t || '_admin', t);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 8. Lectura del historial de compras (SOLO LECTURA sobre tablas del ERP)
--    Una compra es: pedido de canal (WhatsApp, Instagram, tienda virtual) que ya no
--    está esperando pago, venta de punto de venta completada, o venta de academia.
--    Las compras de la web aparecen como pedidos_canal_venta (canal tienda_virtual)
--    cuando el ERP las registra. Las tablas de la web NO se leen ni se cruzan por correo
--    (Ley 1581: los datos de la web no se usan en el CRM hasta que la abogada apruebe
--    esa finalidad).
-- ----------------------------------------------------------------------------
create or replace function public.fn_crm_historial_compras(p_tercero_id uuid)
returns table (
  origen       text,
  id           uuid,
  fecha        timestamptz,
  descripcion  text,
  valor        numeric,
  estado       text,
  canal        text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'Solo administradoras' using errcode = '42501';
  end if;

  return query
    select 'pedido'::text, p.id, p.created_at, p.descripcion_producto, p.total_pedido,
           p.estado::text, p.canal::text
      from public.pedidos_canal_venta p
     where p.tercero_id = p_tercero_id and p.estado::text <> 'esperando_pago'
    union all
    select 'punto_de_venta'::text, v.id, v.fecha, 'Venta ' || v.consecutivo, v.total,
           v.estado, v.canal
      from public.ventas_pos v
     where v.tercero_id = p_tercero_id and v.estado = 'completada'
    union all
    select 'academia'::text, a.id, a.fecha::timestamptz, a.descripcion, a.monto,
           'completada'::text, a.area_formacion
      from public.ventas_academia a
     where a.tercero_id = p_tercero_id
    order by 3 desc;
end
$$;

revoke all on function public.fn_crm_historial_compras(uuid) from public, anon;
grant execute on function public.fn_crm_historial_compras(uuid) to authenticated;


-- Resumen por cliente para la pantalla Clientes (solo clientes con autorización de datos)
create or replace function public.fn_crm_clientes_resumen(p_buscar text default null)
returns table (
  tercero_id      uuid,
  nombre          text,
  telefono        text,
  email           text,
  ciudad          text,
  n_compras       bigint,
  total_comprado  numeric,
  primera_compra  date,
  ultima_compra   date,
  puntos          integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'Solo administradoras' using errcode = '42501';
  end if;

  return query
    with compras as (
      select p.tercero_id as tid, p.created_at::date as f, p.total_pedido as v
        from public.pedidos_canal_venta p
       where p.tercero_id is not null and p.estado::text <> 'esperando_pago'
      union all
      select v.tercero_id, v.fecha::date, v.total
        from public.ventas_pos v
       where v.tercero_id is not null and v.estado = 'completada'
      union all
      select a.tercero_id, a.fecha, a.monto
        from public.ventas_academia a
       where a.tercero_id is not null
    ), agg as (
      select tid, count(*) n, sum(v) total, min(f) primera, max(f) ultima
        from compras group by tid
    )
    select t.id, t.nombre_completo, t.telefono, t.email, t.ciudad,
           coalesce(g.n, 0), coalesce(g.total, 0), g.primera, g.ultima, t.puntos_fidelizacion
      from public.terceros t
      left join agg g on g.tid = t.id
     where t.activo
       and t.acepta_tratamiento_datos
       and t.tipo::text in ('cliente', 'mixto')
       and (p_buscar is null or p_buscar = ''
            or t.nombre_completo ilike '%' || p_buscar || '%'
            or t.telefono ilike '%' || p_buscar || '%')
     order by g.ultima desc nulls last, t.nombre_completo;
end
$$;

revoke all on function public.fn_crm_clientes_resumen(text) from public, anon;
grant execute on function public.fn_crm_clientes_resumen(text) to authenticated;


-- Embudo: oportunidades_venta (ERP) + detalle del CRM
create or replace function public.fn_crm_embudo()
returns table (
  oportunidad_id         uuid,
  consecutivo            text,
  tercero_id             uuid,
  cliente                text,
  telefono               text,
  descripcion            text,
  monto_estimado         numeric,
  etapa                  text,
  etapa_crm              text,
  etapa_desde            timestamptz,
  fecha_entrega_deseada  date,
  motivo_perdida         text,
  pedido_id              uuid,
  origen                 text,
  created_at             timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'Solo administradoras' using errcode = '42501';
  end if;

  return query
    select o.id, o.consecutivo, o.tercero_id,
           coalesce(t.nombre_completo, o.cliente_nombre_libre),
           coalesce(t.telefono, o.cliente_telefono_libre),
           o.descripcion, o.monto_estimado, o.etapa, d.etapa_crm,
           coalesce(d.etapa_desde, o.updated_at), d.fecha_entrega_deseada, d.motivo_perdida,
           d.pedido_id, o.origen, o.created_at
      from public.oportunidades_venta o
      left join public.terceros t on t.id = o.tercero_id
      left join public.crm_oportunidades_detalle d on d.oportunidad_id = o.id
     order by o.created_at desc;
end
$$;

revoke all on function public.fn_crm_embudo() from public, anon;
grant execute on function public.fn_crm_embudo() to authenticated;


-- ----------------------------------------------------------------------------
-- 8b. Casas de un cliente (Crochet / Mercería / Academy), deducidas de lo que compró.
--     Reemplaza a la tabla clientes_casas de la base vieja. SOLO LECTURA.
--     centro_costo_id de la venta no sirve para esto (todo canal y punto de venta está en
--     01 Tienda/Mercería), así que se deduce por el contenido. REGLA CONFIRMADA por el
--     Orquestador ERP y el Orquestador WEB (13-nov):
--       ACADEMY  = cualquier fila de ventas_academia, o una venta con centro de costo
--                  04, 05 o 06.
--       MERCERÍA = líneas cuyo ítem es inventario_items.tipo = 'merceria' Y del centro de
--                  costo 01 Tienda (ventas_pos_detalle, pedidos_canal_lineas,
--                  pedidos_canal_venta.inventario_item_id).
--                  Un ítem de mercería de otro centro (p. ej. insumos del Taller) no
--                  define casa: no se mezcla el inventario de Taller y Tienda.
--       CROCHET  = pedidos de canal sin ítem de inventario (personalizados) y líneas con
--                  tipo 'producto_terminado'.
--       AGENDA   = casa propia (la cuarta). PENDIENTE de la abogada: hoy solo se reconoce
--                  desde los pedidos de la web (ver más abajo).
--     El centro 03 Taller nunca define casa; el 01 tampoco, porque todo se factura desde la
--     Tienda. Un cliente puede tener varias casas.
--
--     AGENDA y los pedidos de la web: ESTA VERSIÓN NO LEE NADA DE LA WEB (ni los pedidos
--     web, ni sus ítems, ni las cuentas de clientes web, ni hay bandera para encenderlo).
--     Así el SQL aplicado no puede usar datos de la web ni por error. Ley 1581: esa
--     finalidad debe aprobarla primero la abogada. Hasta entonces la casa AGENDA no se puede
--     reconocer (hoy solo se reconoce desde los pedidos de la web). El tramo de la web
--     está listo en docs/fase1/propuesta-web-pendiente.sql, NO para aplicar todavía.
--
--     Detalles de la deducción (confirmados por el Orquestador ERP, 13-nov):
--       * Un pedido de canal CON líneas se clasifica por sus líneas (una línea sin ítem es
--         un personalizado = Crochet); sin líneas, por su propio ítem (sin ítem = Crochet).
--         Así un pedido solo de mercería no cuenta como Crochet por tener la cabecera sin
--         ítem. Hoy, en los datos reales, el resultado es el mismo que con la regla simple.
--       * "Centro 01" de la Mercería = centro de costo del ÍTEM (inventario_items), no el
--         de la venta.
--       * Un ítem que no esté en inventario no define casa.
--       * Venta de punto de venta fuera de 04/05/06: se clasifica por línea con ítem; una
--         línea sin ítem no define casa y se omite.
--       * Compras que cuentan: pedido de canal que ya no espera pago, venta POS completada,
--         venta de academia (igual que fn_crm_clientes_resumen).
--       * Las compras de la web que el ERP ya registró salen como pedidos_canal_venta.
--     p_tercero_id = null devuelve todos los clientes (para la lista de Clientes).
-- ----------------------------------------------------------------------------
create or replace function public.fn_crm_casas_cliente(
  p_tercero_id  uuid default null
)
returns table (
  tercero_id      uuid,
  casa            text,
  n_compras       bigint,
  total_comprado  numeric,
  primera_compra  date,
  ultima_compra   date
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'Solo administradoras' using errcode = '42501';
  end if;

  return query
    with filas as (
      -- 1) Pedidos de canal SIN líneas: por su propio ítem (o centro 04/05/06)
      select p.tercero_id as tid, p.id as doc, p.created_at::date as f, p.total_pedido as v,
             case when cc.codigo in ('04', '05', '06') then 'Academy'
                  when i.tipo::text = 'merceria'        then (case when ic.codigo = '01' then 'Mercería' end)
                  else 'Crochet' end as casa
        from public.pedidos_canal_venta p
        join public.centros_costo cc on cc.id = p.centro_costo_id
        left join public.inventario_items i on i.id = p.inventario_item_id
        left join public.centros_costo ic on ic.id = i.centro_costo_id
       where p.tercero_id is not null
         and p.estado::text <> 'esperando_pago'
         and (p_tercero_id is null or p.tercero_id = p_tercero_id)
         and not exists (select 1 from public.pedidos_canal_lineas l where l.pedido_id = p.id)

      union all
      -- 2) Pedidos de canal CON líneas: por cada línea (sin ítem = personalizado = Crochet)
      select p.tercero_id, p.id, p.created_at::date, l.cantidad * l.valor_unitario,
             case when cc.codigo in ('04', '05', '06') then 'Academy'
                  when i.tipo::text = 'merceria'        then (case when ic.codigo = '01' then 'Mercería' end)
                  else 'Crochet' end
        from public.pedidos_canal_lineas l
        join public.pedidos_canal_venta p on p.id = l.pedido_id
        join public.centros_costo cc on cc.id = p.centro_costo_id
        left join public.inventario_items i on i.id = l.inventario_item_id
        left join public.centros_costo ic on ic.id = i.centro_costo_id
       where p.tercero_id is not null
         and p.estado::text <> 'esperando_pago'
         and (p_tercero_id is null or p.tercero_id = p_tercero_id)

      union all
      -- 3) Punto de venta en centro 04/05/06: toda la venta es Academy
      select v.tercero_id, v.id, v.fecha::date, v.total, 'Academy'
        from public.ventas_pos v
        join public.centros_costo cc on cc.id = v.centro_costo_id
       where v.tercero_id is not null
         and v.estado = 'completada'
         and cc.codigo in ('04', '05', '06')
         and (p_tercero_id is null or v.tercero_id = p_tercero_id)

      union all
      -- 4) Punto de venta en otros centros: por línea con ítem de inventario
      select v.tercero_id, v.id, v.fecha::date, d.subtotal_linea,
             case i.tipo::text when 'merceria' then (case when ic.codigo = '01' then 'Mercería' end)
                               when 'producto_terminado' then 'Crochet' end
        from public.ventas_pos v
        join public.centros_costo cc on cc.id = v.centro_costo_id
        join public.ventas_pos_detalle d on d.venta_id = v.id
        join public.inventario_items i on i.id = d.inventario_item_id
        left join public.centros_costo ic on ic.id = i.centro_costo_id
       where v.tercero_id is not null
         and v.estado = 'completada'
         and cc.codigo not in ('04', '05', '06')
         and (p_tercero_id is null or v.tercero_id = p_tercero_id)

      union all
      -- 5) Academia: cualquier fila
      select a.tercero_id, a.id, a.fecha, a.monto, 'Academy'
        from public.ventas_academia a
       where a.tercero_id is not null
         and (p_tercero_id is null or a.tercero_id = p_tercero_id)

    )
    select f.tid, f.casa, count(distinct f.doc), coalesce(sum(f.v), 0), min(f.f), max(f.f)
      from filas f
     where f.casa is not null
     group by f.tid, f.casa
     order by f.tid, max(f.f) desc;
end
$$;

revoke all on function public.fn_crm_casas_cliente(uuid) from public, anon;
grant execute on function public.fn_crm_casas_cliente(uuid) to authenticated;


-- 9. Plantillas actuales del CRM (5 filas). es_comercial: solo 'cotizacion' es
--    seguimiento de algo que la persona pidió; las demás son publicidad.
-- ----------------------------------------------------------------------------
insert into public.crm_plantillas_mensaje (clave, titulo, texto, es_comercial, orden) values
 ('cotizacion', 'Seguimiento de cotización',
  E'Hola {nombre} 🌸 Te escribo de Lana Rosa Crochet para saber si pudiste revisar la cotización de {producto}. Si quieres ajustar algo o tienes dudas, con gusto te ayudo.\n\nCordialmente,\nLana Rosa Crochet', false, 1),
 ('recompra', 'Te extrañamos (cliente inactivo)',
  E'Hola {nombre} 🌸 ¡Esperamos que estés muy bien! Hace un tiempo que no nos visitas y queríamos contarte que tenemos nuevos diseños. Si quieres algo especial, cuéntame y lo tejemos para ti.\n\nCordialmente,\nLana Rosa Crochet', true, 2),
 ('fecha_especial', 'Fecha especial próxima',
  E'Hola {nombre} 🌸 Vimos que se acerca una fecha especial ({fecha}). Si quieres sorprender con un detalle tejido a mano, hoy es un buen momento para encargarlo y que llegue a tiempo.\n\nCordialmente,\nLana Rosa Crochet', true, 3),
 ('posventa', 'Posventa: ¿cómo te fue?',
  E'Hola {nombre} 🌸 Queremos saber cómo te fue con tu {producto}. ¿Llegó bien y te gustó? Tu opinión nos ayuda mucho. Si te encantó, nos haría muy felices que nos compartieras una foto o nos recomendaras.\n\nCordialmente,\nLana Rosa Crochet', true, 4),
 ('bienvenida', 'Bienvenida a nuevo cliente',
  E'Hola {nombre} 🌸 ¡Gracias por elegir Lana Rosa Crochet! Estamos felices de tejer para ti. Cualquier duda que tengas, aquí estamos.\n\nCordialmente,\nLana Rosa Crochet', true, 5)
on conflict (clave) do nothing;


-- ----------------------------------------------------------------------------
-- 10. BORRADOR — NO APLICAR sin acuerdo explícito con el Orquestador ERP
--     Promover un contacto a cliente (escribe en terceros). Es la única función que
--     escribiría en una tabla del ERP, y según el acuerdo del 13-nov esa escritura va
--     por una RPC acordada con el ERP (dueño de terceros: ERP Chat 1 Ventas).
--     Exige autorización de datos explícita (Ley 1581) y deja la evidencia.
--     Lo que falta definir con el ERP: valores de tipo_tercero/tipo_documento para
--     un cliente nuevo, qué hacer si ya existe el documento, y el texto exacto de
--     medio_autorizacion / version_politica. Por eso va comentada.
-- ----------------------------------------------------------------------------
/*
create or replace function public.fn_crm_promover_contacto(
  p_contacto_id         uuid,
  p_tipo_documento      text,
  p_numero_documento    text,
  p_medio_autorizacion  text,
  p_version_politica    text
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  c public.crm_contactos;
  v_tercero uuid;
begin
  if auth.uid() is null or coalesce(public.fn_rol_actual()::text, '') <> 'administrador' then
    raise exception 'Solo administradoras' using errcode = '42501';
  end if;
  if coalesce(p_medio_autorizacion, '') = '' or coalesce(p_version_politica, '') = '' then
    raise exception 'Falta la evidencia de la autorización de datos (medio y versión de la política)';
  end if;

  select * into c from public.crm_contactos where id = p_contacto_id and estado = 'contacto' for update;
  if not found then raise exception 'Contacto no encontrado o ya promovido'; end if;

  insert into public.terceros (tipo, tipo_documento, numero_documento, nombre_completo, telefono, ciudad,
                               acepta_tratamiento_datos, fecha_aceptacion_datos, medio_autorizacion, version_politica,
                               codigo_pais, activo)
  values ('cliente', p_tipo_documento::public.tipo_documento, p_numero_documento, c.nombre, c.telefono, c.ciudad,
          true, now(), p_medio_autorizacion, p_version_politica, 'CO', true)
  returning id into v_tercero;

  update public.crm_contactos set estado = 'promovido', tercero_id = v_tercero where id = c.id;
  return v_tercero;
end
$$;
revoke all on function public.fn_crm_promover_contacto(uuid, text, text, text, text) from public, anon;
grant execute on function public.fn_crm_promover_contacto(uuid, text, text, text, text) to authenticated;
*/
