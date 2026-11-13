-- ============================================================================
-- Prueba LOCAL de fn_crm_casas_cliente (ver stub-erp-local.sql para montar la base).
-- Arma un escenario con un cliente por cada regla, llama a la función como administradora
-- y compara con lo esperado. Todo se deshace al final (rollback). Si algo no coincide,
-- falla con un mensaje claro; si todo está bien, imprime "TODO BIEN".
-- No se corre contra el ERP real: insertaría en tablas con consecutivos.
-- ============================================================================
begin;

do $$
declare
  c_merc uuid := gen_random_uuid(); c_prod uuid := gen_random_uuid();
  cc01 uuid; cc03 uuid; cc04 uuid; cc05 uuid;
  adm  uuid := gen_random_uuid(); caj uuid := gen_random_uuid(); tej uuid := gen_random_uuid();
  t_acad uuid := gen_random_uuid(); t_croc uuid := gen_random_uuid(); t_merc uuid := gen_random_uuid();
  t_mixto uuid := gen_random_uuid(); t_espera uuid := gen_random_uuid(); t_anulada uuid := gen_random_uuid();
  t_cc05 uuid := gen_random_uuid(); t_pcv_item uuid := gen_random_uuid(); t_pos_prod uuid := gen_random_uuid();
  t_pos_sin uuid := gen_random_uuid(); t_taller uuid := gen_random_uuid(); t_web uuid := gen_random_uuid();
  t_multi uuid := gen_random_uuid();
  ped uuid; vta uuid; wid uuid; u_web uuid := gen_random_uuid();
  r text; n int; fallas int := 0;
begin
  select id into cc01 from centros_costo where codigo = '01';
  select id into cc03 from centros_costo where codigo = '03';
  select id into cc04 from centros_costo where codigo = '04';
  select id into cc05 from centros_costo where codigo = '05';

  insert into inventario_items (id, tipo, nombre) values (c_merc, 'merceria', 'Lana'), (c_prod, 'producto_terminado', 'Oso');
  insert into usuarios_roles values (adm, 'administrador', true), (caj, 'cajero', true);
  insert into tejedoras_usuarios values (tej);
  insert into terceros (id, numero_documento, nombre_completo, acepta_tratamiento_datos)
    select x, x::text, 'T', true from unnest(array[t_acad, t_croc, t_merc, t_mixto, t_espera, t_anulada, t_cc05,
      t_pcv_item, t_pos_prod, t_pos_sin, t_taller, t_web, t_multi]) x;

  -- ACADEMY: fila de ventas_academia
  insert into ventas_academia (fecha, area_formacion, descripcion, monto, tercero_id) values (current_date, 'curso_virtual', 'Curso', 100000, t_acad);
  -- CROCHET: pedido de canal sin ítem y sin líneas (personalizado)
  insert into pedidos_canal_venta (canal, centro_costo_id, tercero_id, descripcion_producto, total_pedido, estado)
    values ('whatsapp', cc01, t_croc, 'Oso a pedido', 50000, 'entregado');
  -- CROCHET: pedido de canal cuyo ítem es producto_terminado
  insert into pedidos_canal_venta (canal, centro_costo_id, tercero_id, inventario_item_id, descripcion_producto, total_pedido, estado)
    values ('tienda_virtual', cc01, t_pcv_item, c_prod, 'Oso', 40000, 'entregado');
  -- MERCERÍA: venta POS en 01 con línea de mercería
  insert into ventas_pos (consecutivo, tercero_id, centro_costo_id, total, estado, canal) values ('V1', t_merc, cc01, 15000, 'completada', 'tienda') returning id into vta;
  insert into ventas_pos_detalle (venta_id, inventario_item_id, subtotal_linea) values (vta, c_merc, 15000);
  -- CROCHET: venta POS en 01 con línea de producto terminado
  insert into ventas_pos (consecutivo, tercero_id, centro_costo_id, total, estado, canal) values ('V2', t_pos_prod, cc01, 30000, 'completada', 'tienda') returning id into vta;
  insert into ventas_pos_detalle (venta_id, inventario_item_id, subtotal_linea) values (vta, c_prod, 30000);
  -- SIN CASA: venta POS en 01 con línea sin ítem
  insert into ventas_pos (consecutivo, tercero_id, centro_costo_id, total, estado, canal) values ('V3', t_pos_sin, cc01, 8000, 'completada', 'tienda') returning id into vta;
  insert into ventas_pos_detalle (venta_id, inventario_item_id, subtotal_linea) values (vta, null, 8000);
  -- ACADEMY: venta POS en centro 04 (aunque no tenga líneas con ítem)
  insert into ventas_pos (consecutivo, tercero_id, centro_costo_id, total, estado, canal) values ('V4', t_mixto, cc04, 60000, 'completada', 'tienda');
  -- MIXTO: además de Academy (arriba), pedido de canal con una línea de mercería y una sin ítem
  insert into pedidos_canal_venta (canal, centro_costo_id, tercero_id, descripcion_producto, total_pedido, estado)
    values ('whatsapp', cc01, t_mixto, 'Kit', 90000, 'entregado') returning id into ped;
  insert into pedidos_canal_lineas (pedido_id, inventario_item_id, cantidad, valor_unitario) values (ped, c_merc, 2, 10000), (ped, null, 1, 70000);
  -- CABECERA SIN ÍTEM pero con línea solo de mercería: NO debe contar como Crochet
  insert into pedidos_canal_venta (canal, centro_costo_id, tercero_id, descripcion_producto, total_pedido, estado)
    values ('whatsapp', cc01, t_multi, 'Solo lanas', 20000, 'en_preparacion') returning id into ped;
  insert into pedidos_canal_lineas (pedido_id, inventario_item_id, cantidad, valor_unitario) values (ped, c_merc, 2, 10000);
  -- ACADEMY: pedido de canal en centro 05
  insert into pedidos_canal_venta (canal, centro_costo_id, tercero_id, descripcion_producto, total_pedido, estado)
    values ('whatsapp', cc05, t_cc05, 'Curso Hotmart', 120000, 'entregado');
  -- NO CUENTAN: esperando pago, venta anulada, venta en 03 Taller sin ítem
  insert into pedidos_canal_venta (canal, centro_costo_id, tercero_id, descripcion_producto, total_pedido, estado)
    values ('whatsapp', cc01, t_espera, 'Sin pagar', 10000, 'esperando_pago');
  insert into ventas_pos (consecutivo, tercero_id, centro_costo_id, total, estado, canal) values ('V5', t_anulada, cc01, 5000, 'anulada', 'tienda') returning id into vta;
  insert into ventas_pos_detalle (venta_id, inventario_item_id, subtotal_linea) values (vta, c_merc, 5000);
  insert into ventas_pos (consecutivo, tercero_id, centro_costo_id, total, estado, canal) values ('V6', t_taller, cc03, 7000, 'completada', 'tienda') returning id into vta;
  insert into ventas_pos_detalle (venta_id, inventario_item_id, subtotal_linea) values (vta, null, 7000);

  -- WEB: pagada, sin registrar en el ERP, con un ítem de mercería y uno desconocido
  insert into cuentas_clientes_web values (u_web, t_web);
  insert into pedidos_web (id, user_id, estado) values (gen_random_uuid(), u_web, 'pagado') returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_merc, 10000, 3), (wid, gen_random_uuid(), 25000, 1);
  -- WEB que NO cuentan: ya registrada en el ERP, de prueba, digital, pendiente de pago, anulada
  insert into pedidos_web (user_id, estado, erp_pedidos) values (u_web, 'pagado', array[gen_random_uuid()]) returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  insert into pedidos_web (user_id, estado, es_prueba) values (u_web, 'pagado', true) returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  insert into pedidos_web (user_id, estado, es_digital) values (u_web, 'pagado', true) returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  insert into pedidos_web (user_id, estado) values (u_web, 'pendiente_pago') returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  insert into pedidos_web (user_id, estado) values (u_web, 'anulado') returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);

  -- ======================= COMPROBACIONES (como administradora) =======================
  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- Cada caso: (descripción, cliente, casas esperadas "Casa:compras:total" ordenadas por casa; web apagada)
  declare
    esperado text; obtenido text; nombre text;
    caso record;
  begin
    for caso in
      select * from (values
        ('academia',        t_acad,    'Academy:1:100000'),
        ('personalizado',   t_croc,    'Crochet:1:50000'),
        ('pedido con ítem producto_terminado', t_pcv_item, 'Crochet:1:40000'),
        ('pos mercería',    t_merc,    'Mercería:1:15000'),
        ('pos producto',    t_pos_prod,'Crochet:1:30000'),
        ('pos línea sin ítem (sin casa)', t_pos_sin, ''),
        ('pos centro 04 + pedido con líneas mixtas', t_mixto, 'Academy:1:60000,Crochet:1:70000,Mercería:1:20000'),
        ('cabecera sin ítem, línea solo mercería', t_multi, 'Mercería:1:20000'),
        ('pedido centro 05', t_cc05,   'Academy:1:120000'),
        ('esperando pago',  t_espera,  ''),
        ('venta anulada',   t_anulada, ''),
        ('taller sin ítem', t_taller,  ''),
        ('web apagada (por defecto)', t_web, '')
      ) v(nombre, tid, esperado)
    loop
      select coalesce(string_agg(x.casa || ':' || x.n_compras || ':' || trunc(x.total_comprado), ',' order by x.casa), '')
        into obtenido from public.fn_crm_casas_cliente(caso.tid) x;
      if obtenido <> caso.esperado then
        fallas := fallas + 1;
        raise warning 'FALLA en "%": esperado [%] obtenido [%]', caso.nombre, caso.esperado, obtenido;
      end if;
    end loop;

    -- web encendida: mercería 30.000 + Crochet 25.000, y NO cuentan las otras 5 compras web
    select coalesce(string_agg(x.casa || ':' || x.n_compras || ':' || trunc(x.total_comprado), ',' order by x.casa), '')
      into obtenido from public.fn_crm_casas_cliente(t_web, true) x;
    if obtenido <> 'Crochet:1:25000,Mercería:1:30000' then fallas := fallas + 1; raise warning 'FALLA web encendida: obtenido [%]', obtenido; end if;

    -- sin filtro (null) devuelve a todos: al menos las 6 casas-cliente esperadas del escenario
    select count(*) into n from public.fn_crm_casas_cliente(null);
    if n <> 10 then fallas := fallas + 1; raise warning 'FALLA todos los clientes: % filas (esperado 10)', n; end if;
  end;
  reset role;

  -- ======================= SEGURIDAD =======================
  foreach r in array array['cajero', 'tejedora', 'anon'] loop
    perform set_config('request.jwt.claims',
      case r when 'cajero' then json_build_object('sub', caj, 'role', 'authenticated')::text
             when 'tejedora' then json_build_object('sub', tej, 'role', 'authenticated')::text
             else '{"role":"anon"}' end, true);
    execute case r when 'anon' then 'set local role anon' else 'set local role authenticated' end;
    begin
      perform * from public.fn_crm_casas_cliente(t_acad);
      fallas := fallas + 1; raise warning 'FALLA: % pudo usar fn_crm_casas_cliente', r;
    exception when insufficient_privilege then null;   -- no es administrador / sin permiso: correcto
    end;
    reset role;
  end loop;

  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname = 'public' and p.proname = 'fn_crm_casas_cliente'
     and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'));
  if n <> 0 then fallas := fallas + 1; raise warning 'FALLA: fn_crm_casas_cliente ejecutable por anon/PUBLIC'; end if;

  if fallas = 0 then raise notice 'TODO BIEN: casas por cliente, apagado de web, seguridad por rol'; else raise exception '% FALLAS', fallas; end if;
end $$;

rollback;
