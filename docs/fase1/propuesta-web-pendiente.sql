-- ============================================================================
-- fn_crm_casas_cliente CON LA WEB — PENDIENTE DE LA ABOGADA. NO APLICAR TODAVÍA.
--
-- Qué es: la versión de la función de docs/fase1/propuesta.sql (sección 8b) con el tramo
-- que lee pedidos_web, pedidos_web_items y cuentas_clientes_web, que es lo único que
-- reconoce la casa AGENDA (ítem de pedido web con producto_id nulo = "Membresía Agenda").
--
-- Por qué está aparte: Ley 1581. El cruce de un pedido web con un cliente usa
-- cuentas_clientes_web (dato de la web) y esa finalidad aún no la aprobó la abogada. Web
-- Chat 5 pidió (13-nov) que el SQL aplicado no pueda leer datos de la web ni por error,
-- ni siquiera con una bandera.
--
-- Cómo se activa (solo cuando la abogada apruebe y el Orquestador ERP dé el go):
--   1. Aplicar este archivo como migración. Usa `create or replace` con la MISMA firma
--      (uuid), así que reemplaza a la versión sin web; los permisos se vuelven a declarar
--      al final, igual que en la propuesta.
--   2. Quitar de prueba-rollback.sql la comprobación "la función no menciona la web".
--   3. Correr prueba-web-pendiente-local.sql (ver su cabecera) y prueba-rollback.sql.
--
-- Reglas del tramo web (confirmadas por ERP y WEB, 13-nov): pedidos_web_items.producto_id
-- es inventario_items.id; NULO = Agenda; mercería solo si el ítem es del centro 01; solo
-- pedidos pagados, que no sean de prueba y que NO estén ya registrados en el ERP
-- (erp_pedidos vacío) para no duplicar lo que ya sale como pedidos_canal_venta; los
-- pedidos digitales SÍ cuentan; un producto_id que no exista en inventario no define casa.
-- ============================================================================

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

      union all
      -- 6) Pedidos web aún no registrados en el ERP (PENDIENTE de la abogada, Ley 1581)
      select c.tercero_id, w.id, w.created_at::date, it.precio * it.cantidad,
             case when it.producto_id is null then 'Agenda'
                  when i.tipo::text = 'merceria' then (case when ic.codigo = '01' then 'Mercería' end)
                  when i.tipo::text = 'producto_terminado' then 'Crochet' end
        from public.pedidos_web w
        join public.cuentas_clientes_web c on c.user_id = w.user_id and c.tercero_id is not null
        join public.pedidos_web_items it on it.pedido_id = w.id
        left join public.inventario_items i on i.id = it.producto_id
        left join public.centros_costo ic on ic.id = i.centro_costo_id
       where w.estado = 'pagado'
         and not w.es_prueba
         and coalesce(cardinality(w.erp_pedidos), 0) = 0
         and (p_tercero_id is null or c.tercero_id = p_tercero_id)
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
