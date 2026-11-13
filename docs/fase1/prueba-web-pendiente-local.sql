-- ============================================================================
-- Prueba LOCAL de la versión PENDIENTE de fn_crm_casas_cliente (la que sí lee la web:
-- docs/fase1/propuesta-web-pendiente.sql). Sirve para tenerla probada antes de activarla,
-- cuando la abogada apruebe la finalidad (Ley 1581).
--
-- Cómo correrla (base local desechable, ya con stub-erp-local.sql y propuesta.sql
-- aplicados; psql debe correr desde esta carpeta porque usa \i con ruta relativa):
--   cd docs/fase1 && psql -d prueba_fase1 -f prueba-web-pendiente-local.sql
-- Todo ocurre dentro de una transacción que termina en rollback: la base local vuelve a
-- tener la versión SIN web.
-- ============================================================================
begin;

\i propuesta-web-pendiente.sql

do $$
declare
  cc01 uuid; cc03 uuid;
  c_merc uuid := gen_random_uuid(); c_prod uuid := gen_random_uuid(); c_merc_taller uuid := gen_random_uuid();
  adm uuid := gen_random_uuid(); caj uuid := gen_random_uuid();
  t_web uuid := gen_random_uuid(); u_web uuid := gen_random_uuid(); t_taller uuid := gen_random_uuid(); u_taller uuid := gen_random_uuid();
  wid uuid; obtenido text; fallas int := 0; n int;
begin
  select id into cc01 from centros_costo where codigo = '01';
  select id into cc03 from centros_costo where codigo = '03';
  insert into inventario_items (id, tipo, nombre, centro_costo_id) values
    (c_merc, 'merceria', 'Lana', cc01), (c_prod, 'producto_terminado', 'Oso', cc01), (c_merc_taller, 'merceria', 'Insumo del Taller', cc03);
  insert into usuarios_roles values (adm, 'administrador', true), (caj, 'cajero', true);
  insert into terceros (id, numero_documento, nombre_completo, acepta_tratamiento_datos)
    values (t_web, 'w1', 'Cliente web', true), (t_taller, 'w2', 'Cliente web taller', true);
  insert into cuentas_clientes_web values (u_web, t_web), (u_taller, t_taller);

  -- CUENTAN: pagada, sin registrar en el ERP: mercería de Tienda, producto terminado,
  -- un id desconocido (se omite)
  insert into pedidos_web (user_id, estado) values (u_web, 'pagado') returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values
    (wid, c_merc, 10000, 3), (wid, c_prod, 25000, 1), (wid, gen_random_uuid(), 77000, 1);
  -- CUENTA: digital pagada con ítem SIN producto = Agenda
  insert into pedidos_web (user_id, estado, es_digital) values (u_web, 'pagado', true) returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, nombre, precio, cantidad) values (wid, null, 'Membresía Agenda', 45000, 1);
  -- NO CUENTAN: ya registrada en el ERP, de prueba, pendiente de pago, anulada
  insert into pedidos_web (user_id, estado, erp_pedidos) values (u_web, 'pagado', array[gen_random_uuid()]) returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  insert into pedidos_web (user_id, estado, es_prueba) values (u_web, 'pagado', true) returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  insert into pedidos_web (user_id, estado) values (u_web, 'pendiente_pago') returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  insert into pedidos_web (user_id, estado) values (u_web, 'anulado') returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_prod, 99000, 1);
  -- NO CUENTA: mercería del Taller en un pedido web
  insert into pedidos_web (user_id, estado) values (u_taller, 'pagado') returning id into wid;
  insert into pedidos_web_items (pedido_id, producto_id, precio, cantidad) values (wid, c_merc_taller, 5000, 1);

  perform set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select coalesce(string_agg(x.casa || ':' || x.n_compras || ':' || trunc(x.total_comprado), ',' order by x.casa), '')
    into obtenido from public.fn_crm_casas_cliente(t_web) x;
  if obtenido <> 'Agenda:1:45000,Crochet:1:25000,Mercería:1:30000' then
    fallas := fallas + 1; raise warning 'FALLA web: obtenido [%]', obtenido; end if;

  select coalesce(string_agg(x.casa, ','), '') into obtenido from public.fn_crm_casas_cliente(t_taller) x;
  if obtenido <> '' then fallas := fallas + 1; raise warning 'FALLA mercería del Taller en web: [%]', obtenido; end if;
  reset role;

  -- seguridad: el cajero y el visitante siguen sin poder usarla
  perform set_config('request.jwt.claims', json_build_object('sub', caj, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin perform * from public.fn_crm_casas_cliente(t_web); fallas := fallas + 1; raise warning 'FALLA: el cajero pudo usarla';
  exception when insufficient_privilege then null; end;
  reset role;
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
  begin perform * from public.fn_crm_casas_cliente(t_web); fallas := fallas + 1; raise warning 'FALLA: anon pudo usarla';
  exception when insufficient_privilege then null; end;
  reset role;

  select count(*) into n from pg_proc p where p.proname = 'fn_crm_casas_cliente'
     and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'));
  if n <> 0 then fallas := fallas + 1; raise warning 'FALLA: ejecutable por anon/PUBLIC'; end if;

  if fallas = 0 then raise notice 'TODO BIEN: versión con web (Agenda, Crochet, Mercería), exclusiones y seguridad';
  else raise exception '% FALLAS', fallas; end if;
end $$;

rollback;
