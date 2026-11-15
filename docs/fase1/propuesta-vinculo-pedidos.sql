-- ============================================================================
-- VÍNCULO DE PEDIDOS CON SU CLIENTE (pedidos_canal_venta.tercero_id)
-- Base destino: ngjoognzvehwjtpqwrqe (Lana Rosa ERP + SO)
--
-- ESTADO: PROPUESTA PARA REVISAR. NO SE HA APLICADO. No aplicar sin el go del Orquestador
-- ERP (que lo revisa con ERP Chat 2 Pedidos, dueño de pedidos_canal_venta) ni sin el OK
-- de Sara. Preparada por CRM Chat 1 el 15-nov-2026.
--
-- PARA QUÉ: 16 de los 26 pedidos del ERP que vienen del CRM (referencia_crm_id) tienen
-- tercero_id vacío. Por eso el historial de compras por cliente (fn_crm_historial_compras,
-- fn_crm_clientes_resumen, fn_crm_casas_cliente) sale incompleto.
--
-- QUÉ HACE (y solo eso): pone tercero_id en esos 16 pedidos, tomando el cliente del pedido
-- en el CRM (clientes.id) y buscando al tercero del ERP que tiene terceros.crm_cliente_id
-- igual a ese cliente. El mismo método reproduce exactamente los 10 pedidos del CRM que
-- ya tenían tercero_id en el ERP (10 de 10 coinciden).
--
-- QUÉ NO HACE: no cambia estado, totales, anticipos ni ninguna otra columna; no toca otros
-- pedidos; no toca terceros, ventas_pos ni ventas_academia; no crea ni borra nada.
-- Ningún disparador de pedidos_canal_venta se activa: los 8 que tiene son de tipo
-- "UPDATE OF estado" y aquí solo cambia tercero_id (no hay disparadores de updated_at).
--
-- SEGURIDAD DE LA FILA (guardas; si UNA falla no se cambia NADA):
--   * la lista tiene exactamente 16 pedidos;
--   * cada pedido existe con el mismo consecutivo y el mismo referencia_crm_id;
--   * cada pedido tiene tercero_id VACÍO (nunca se pisa un cliente ya asignado);
--   * cada tercero existe, está activo, autorizó el tratamiento de datos (Ley 1581) y su
--     crm_cliente_id es el del cliente del CRM.
-- Después de actualizar se verifica: +16 pedidos con cliente, -16 sin cliente, el total de
-- pedidos igual, y que una huella de (id, estado, total, referencia_crm_id) de TODA la
-- tabla es idéntica antes y después.
--
-- CÓMO SE USA: el bloque trae v_aplicar := false = PRUEBA: hace todo, muestra los conteos
-- y termina con un error a propósito que DESHACE todo ("RESULTADO DE LA PRUEBA"). Para
-- aplicar de verdad (solo con el go) se cambia v_aplicar a true y se corre como migración.
-- Reglas del ERP: un solo bloque do $$, lock_timeout corto, sin DROP.
--
-- LISTA (consecutivo, pedido del ERP → tercero del ERP):
--   PED-2026-00469  pedido cfa38dc4-8d57-46cb-b8f1-7c4c88c55f47  →  tercero 2ae126ba-0def-4cf7-aa6f-ad0f9bfb2371
--   PED-2026-00470  pedido df70efae-9d5c-48fe-8830-de045c7cba30  →  tercero 71ce6aa5-a8dd-478e-9c93-79fd2e1b392e
--   PED-2026-00471  pedido 77d133bd-2683-453e-b681-78c299bd67a5  →  tercero 24a84e7e-162e-401b-9587-c79546efdd8e
--   PED-2026-00472  pedido 53e284a8-bf3c-4830-a95d-5edcb8973a59  →  tercero 24a84e7e-162e-401b-9587-c79546efdd8e
--   PED-2026-00490  pedido ad57faf4-25dd-4ae2-8eb3-d2720c35e7cc  →  tercero 71ce6aa5-a8dd-478e-9c93-79fd2e1b392e
--   PED-2026-00506  pedido 0686f242-e10e-45d3-a659-e79a0e0d6d46  →  tercero 812d22d6-a5da-4c4e-91ac-08ce1256dfe5
--   PED-2026-00507  pedido 553c0dc7-93e3-4f9b-98c5-0eb3025f2b1a  →  tercero 1971d945-7239-4c7f-a764-44047fbe5058
--   PED-2026-00508  pedido dda278e0-9236-474d-9dd5-375084f06465  →  tercero c7cd739a-f894-4c75-b7b0-e695869c07af
--   PED-2026-00510  pedido f9053e26-0f79-47f6-b405-7b60f49abbc9  →  tercero b90646ef-8c1e-41d1-9a05-69ec97228091
--   PED-2026-00511  pedido 79842bf8-2106-49f1-a467-6e5a6ef241b8  →  tercero 6070bab2-3af3-4d6b-a376-f366dadbcaf7
--   PED-2026-00512  pedido f0234937-1fec-4d0c-9776-5967d4ee7c79  →  tercero 8c7984b1-01f1-404f-ab49-7c313642b831
--   PED-2026-00513  pedido 1c8b02bf-489f-4585-accc-714b6b34db9b  →  tercero 6070bab2-3af3-4d6b-a376-f366dadbcaf7
--   PED-2026-00514  pedido 2791b08a-6567-4dc7-b30e-2b04e13e1423  →  tercero b90646ef-8c1e-41d1-9a05-69ec97228091
--   PED-2026-00515  pedido 70df37de-558b-4acb-a101-4c6b623988ce  →  tercero b90646ef-8c1e-41d1-9a05-69ec97228091
--   PED-2026-00516  pedido 55e9a870-bfe9-4c50-9567-6a25155af577  →  tercero df6a96be-c9df-4f61-804f-3886113140f9
--   PED-2026-00517  pedido 5306b29f-67a2-4879-b457-ed2d1aaa0158  →  tercero b90646ef-8c1e-41d1-9a05-69ec97228091
--
-- VUELTA ATRÁS: al final del archivo, comentada. Deja tercero_id vacío SOLO en estos 16
-- pedidos y SOLO donde sigue valiendo lo asignado. No borra nada.
-- ============================================================================
do $vinculo$
declare
  v_aplicar constant boolean := false;   -- false = PRUEBA (deshace todo); true = APLICAR
  v_lista   constant jsonb := '[
 {
  "pedido_id": "cfa38dc4-8d57-46cb-b8f1-7c4c88c55f47",
  "consecutivo": "PED-2026-00469",
  "crm_pedido_id": "47d2b2ed-a0ec-4f28-b46f-8ab1748831aa",
  "crm_cliente_id": "cf2d9204-2efc-4523-a22b-7c216e3e680e",
  "tercero_id": "2ae126ba-0def-4cf7-aa6f-ad0f9bfb2371"
 },
 {
  "pedido_id": "df70efae-9d5c-48fe-8830-de045c7cba30",
  "consecutivo": "PED-2026-00470",
  "crm_pedido_id": "29a673af-b857-4974-b43c-14f21d6ea9a7",
  "crm_cliente_id": "9136fbb0-9b43-4e02-ae48-62c42a266273",
  "tercero_id": "71ce6aa5-a8dd-478e-9c93-79fd2e1b392e"
 },
 {
  "pedido_id": "77d133bd-2683-453e-b681-78c299bd67a5",
  "consecutivo": "PED-2026-00471",
  "crm_pedido_id": "1bc4e56c-7f77-4e61-aabc-40f23f54a336",
  "crm_cliente_id": "a7f7ef15-1b68-4d4d-9814-794792a41f9c",
  "tercero_id": "24a84e7e-162e-401b-9587-c79546efdd8e"
 },
 {
  "pedido_id": "53e284a8-bf3c-4830-a95d-5edcb8973a59",
  "consecutivo": "PED-2026-00472",
  "crm_pedido_id": "a3dfb6fe-dff7-43b7-aa71-81835b2a0514",
  "crm_cliente_id": "a7f7ef15-1b68-4d4d-9814-794792a41f9c",
  "tercero_id": "24a84e7e-162e-401b-9587-c79546efdd8e"
 },
 {
  "pedido_id": "ad57faf4-25dd-4ae2-8eb3-d2720c35e7cc",
  "consecutivo": "PED-2026-00490",
  "crm_pedido_id": "1057629d-01fd-45f3-a466-9685345d19ea",
  "crm_cliente_id": "9136fbb0-9b43-4e02-ae48-62c42a266273",
  "tercero_id": "71ce6aa5-a8dd-478e-9c93-79fd2e1b392e"
 },
 {
  "pedido_id": "0686f242-e10e-45d3-a659-e79a0e0d6d46",
  "consecutivo": "PED-2026-00506",
  "crm_pedido_id": "fb366c5d-80c4-4808-87ea-e1523383fb76",
  "crm_cliente_id": "88934652-5d7a-4d06-ac72-4ffa3735ae8a",
  "tercero_id": "812d22d6-a5da-4c4e-91ac-08ce1256dfe5"
 },
 {
  "pedido_id": "553c0dc7-93e3-4f9b-98c5-0eb3025f2b1a",
  "consecutivo": "PED-2026-00507",
  "crm_pedido_id": "89586a9b-c9b0-40d7-8401-56938e95fb18",
  "crm_cliente_id": "6131dd72-438c-4985-83fe-c56b08b5a62f",
  "tercero_id": "1971d945-7239-4c7f-a764-44047fbe5058"
 },
 {
  "pedido_id": "dda278e0-9236-474d-9dd5-375084f06465",
  "consecutivo": "PED-2026-00508",
  "crm_pedido_id": "930f3b70-c03a-435f-86ac-2e03ab04da52",
  "crm_cliente_id": "9aaca1d8-2cee-4ad1-8c44-8ebad990b804",
  "tercero_id": "c7cd739a-f894-4c75-b7b0-e695869c07af"
 },
 {
  "pedido_id": "f9053e26-0f79-47f6-b405-7b60f49abbc9",
  "consecutivo": "PED-2026-00510",
  "crm_pedido_id": "13c88c5f-7be7-4fd7-8353-6d39369f58b9",
  "crm_cliente_id": "6cf316e6-fe95-4c31-802f-f4b32e2e9aff",
  "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"
 },
 {
  "pedido_id": "79842bf8-2106-49f1-a467-6e5a6ef241b8",
  "consecutivo": "PED-2026-00511",
  "crm_pedido_id": "15a544e6-4dfb-4e85-a59d-ff1a8251187a",
  "crm_cliente_id": "cf184697-0c5a-444b-a10c-c91c3d902a17",
  "tercero_id": "6070bab2-3af3-4d6b-a376-f366dadbcaf7"
 },
 {
  "pedido_id": "f0234937-1fec-4d0c-9776-5967d4ee7c79",
  "consecutivo": "PED-2026-00512",
  "crm_pedido_id": "7d6d0cca-9c8b-4324-94a8-9e19ad27a6a6",
  "crm_cliente_id": "af497eda-0b07-40f1-9565-425d351c7f19",
  "tercero_id": "8c7984b1-01f1-404f-ab49-7c313642b831"
 },
 {
  "pedido_id": "1c8b02bf-489f-4585-accc-714b6b34db9b",
  "consecutivo": "PED-2026-00513",
  "crm_pedido_id": "d32af191-19fa-4add-bc81-83f7126f85c2",
  "crm_cliente_id": "cf184697-0c5a-444b-a10c-c91c3d902a17",
  "tercero_id": "6070bab2-3af3-4d6b-a376-f366dadbcaf7"
 },
 {
  "pedido_id": "2791b08a-6567-4dc7-b30e-2b04e13e1423",
  "consecutivo": "PED-2026-00514",
  "crm_pedido_id": "9d8e103c-a9ae-48ed-815e-8df633e1966e",
  "crm_cliente_id": "6cf316e6-fe95-4c31-802f-f4b32e2e9aff",
  "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"
 },
 {
  "pedido_id": "70df37de-558b-4acb-a101-4c6b623988ce",
  "consecutivo": "PED-2026-00515",
  "crm_pedido_id": "ec30461e-c9f3-46ed-a046-5efdb0c91c67",
  "crm_cliente_id": "6cf316e6-fe95-4c31-802f-f4b32e2e9aff",
  "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"
 },
 {
  "pedido_id": "55e9a870-bfe9-4c50-9567-6a25155af577",
  "consecutivo": "PED-2026-00516",
  "crm_pedido_id": "42341a3a-548b-4a55-a8ee-4a2d0aa18be9",
  "crm_cliente_id": "d1a1b721-f00a-4e41-98a3-1cf949ad0ddb",
  "tercero_id": "df6a96be-c9df-4f61-804f-3886113140f9"
 },
 {
  "pedido_id": "5306b29f-67a2-4879-b457-ed2d1aaa0158",
  "consecutivo": "PED-2026-00517",
  "crm_pedido_id": "920b1c51-0c08-4acb-96e1-fe4870c30752",
  "crm_cliente_id": "6cf316e6-fe95-4c31-802f-f4b32e2e9aff",
  "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"
 }
]'::jsonb;

  n_lista int; n_ok int; n_tocadas int; n_correctas int;
  antes_con int; antes_sin int; antes_total int; hash_antes text;
  desp_con int;  desp_sin int;  desp_total int;  hash_desp text;
  fallas int := 0; r text := '';
begin
  set local lock_timeout = '3s';
  set local statement_timeout = '60s';

  select count(*) into n_lista
    from jsonb_to_recordset(v_lista) as v(pedido_id uuid, consecutivo text, crm_pedido_id uuid, crm_cliente_id uuid, tercero_id uuid);
  if n_lista <> 16 then raise exception 'La lista debe tener 16 pedidos y tiene %', n_lista; end if;

  -- Conteos y huella ANTES (la huella no incluye tercero_id, que es lo único que cambia)
  select count(*) filter (where tercero_id is not null), count(*) filter (where tercero_id is null), count(*),
         md5(string_agg(id::text || '|' || estado::text || '|' || total_pedido::text || '|' || coalesce(referencia_crm_id::text, ''), ',' order by id))
    into antes_con, antes_sin, antes_total, hash_antes
    from public.pedidos_canal_venta;

  -- Guardas: TODAS o ninguna
  select count(*) into n_ok
    from jsonb_to_recordset(v_lista) as v(pedido_id uuid, consecutivo text, crm_pedido_id uuid, crm_cliente_id uuid, tercero_id uuid)
    join public.pedidos_canal_venta p
      on p.id = v.pedido_id and p.consecutivo = v.consecutivo
     and p.referencia_crm_id = v.crm_pedido_id and p.tercero_id is null
    join public.terceros t
      on t.id = v.tercero_id and t.crm_cliente_id = v.crm_cliente_id
     and t.activo and t.acepta_tratamiento_datos;
  if n_ok <> n_lista then
    raise exception 'Guarda: solo % de % pedidos cumplen todas las condiciones (el pedido ya tiene cliente, cambió su vínculo con el CRM, o el tercero no coincide o no autorizó datos). No se cambió nada.', n_ok, n_lista;
  end if;

  -- Actualización: solo tercero_id, solo donde está vacío
  update public.pedidos_canal_venta p
     set tercero_id = v.tercero_id
    from jsonb_to_recordset(v_lista) as v(pedido_id uuid, consecutivo text, crm_pedido_id uuid, crm_cliente_id uuid, tercero_id uuid)
   where p.id = v.pedido_id and p.tercero_id is null and p.referencia_crm_id = v.crm_pedido_id;
  get diagnostics n_tocadas = row_count;

  -- Conteos y huella DESPUÉS
  select count(*) filter (where tercero_id is not null), count(*) filter (where tercero_id is null), count(*),
         md5(string_agg(id::text || '|' || estado::text || '|' || total_pedido::text || '|' || coalesce(referencia_crm_id::text, ''), ',' order by id))
    into desp_con, desp_sin, desp_total, hash_desp
    from public.pedidos_canal_venta;

  select count(*) into n_correctas
    from jsonb_to_recordset(v_lista) as v(pedido_id uuid, consecutivo text, crm_pedido_id uuid, crm_cliente_id uuid, tercero_id uuid)
    join public.pedidos_canal_venta p on p.id = v.pedido_id and p.tercero_id = v.tercero_id;

  r := r || 'Pedidos con cliente:  antes ' || antes_con || '  →  después ' || desp_con || '  (esperado +16)' || E'\n';
  r := r || 'Pedidos sin cliente:  antes ' || antes_sin || '  →  después ' || desp_sin || '  (esperado -16)' || E'\n';
  r := r || 'Pedidos en total:     antes ' || antes_total || '  →  después ' || desp_total || '  (esperado igual)' || E'\n';
  r := r || 'Filas actualizadas: ' || n_tocadas || ' (esperado 16); con el cliente esperado: ' || n_correctas || ' (esperado 16)' || E'\n';
  r := r || 'Huella de la tabla (sin tercero_id) igual antes y después: ' || (hash_antes = hash_desp) || ' (esperado true)' || E'\n';
  if n_tocadas <> 16 or n_correctas <> 16 then fallas := fallas + 1; end if;
  if desp_con <> antes_con + 16 or desp_sin <> antes_sin - 16 or desp_total <> antes_total then fallas := fallas + 1; end if;
  if hash_antes <> hash_desp then fallas := fallas + 1; end if;

  if fallas > 0 then raise exception E'FALLÓ la verificación (se deshace todo):\n%', r; end if;

  if v_aplicar then
    raise notice E'APLICADO:\n%', r;
  else
    raise exception E'RESULTADO DE LA PRUEBA (se deshizo todo; v_aplicar = false)\n%FALLAS: %', r, fallas;
  end if;
end
$vinculo$;


-- ============================================================================
-- VUELTA ATRÁS (comentada; solo si hace falta después de aplicar).
-- Deja tercero_id vacío SOLO en los 16 pedidos de la lista y SOLO donde todavía vale el
-- tercero asignado por esta propuesta (si alguien lo cambió a mano, no se toca).
-- No borra nada. Esperado: 16 filas.
-- ============================================================================
-- do $vuelta$
-- declare n int;
-- begin
--   set local lock_timeout = '3s';
--   update public.pedidos_canal_venta p
--      set tercero_id = null
--     from jsonb_to_recordset('[{"pedido_id": "cfa38dc4-8d57-46cb-b8f1-7c4c88c55f47", "tercero_id": "2ae126ba-0def-4cf7-aa6f-ad0f9bfb2371"}, {"pedido_id": "df70efae-9d5c-48fe-8830-de045c7cba30", "tercero_id": "71ce6aa5-a8dd-478e-9c93-79fd2e1b392e"}, {"pedido_id": "77d133bd-2683-453e-b681-78c299bd67a5", "tercero_id": "24a84e7e-162e-401b-9587-c79546efdd8e"}, {"pedido_id": "53e284a8-bf3c-4830-a95d-5edcb8973a59", "tercero_id": "24a84e7e-162e-401b-9587-c79546efdd8e"}, {"pedido_id": "ad57faf4-25dd-4ae2-8eb3-d2720c35e7cc", "tercero_id": "71ce6aa5-a8dd-478e-9c93-79fd2e1b392e"}, {"pedido_id": "0686f242-e10e-45d3-a659-e79a0e0d6d46", "tercero_id": "812d22d6-a5da-4c4e-91ac-08ce1256dfe5"}, {"pedido_id": "553c0dc7-93e3-4f9b-98c5-0eb3025f2b1a", "tercero_id": "1971d945-7239-4c7f-a764-44047fbe5058"}, {"pedido_id": "dda278e0-9236-474d-9dd5-375084f06465", "tercero_id": "c7cd739a-f894-4c75-b7b0-e695869c07af"}, {"pedido_id": "f9053e26-0f79-47f6-b405-7b60f49abbc9", "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"}, {"pedido_id": "79842bf8-2106-49f1-a467-6e5a6ef241b8", "tercero_id": "6070bab2-3af3-4d6b-a376-f366dadbcaf7"}, {"pedido_id": "f0234937-1fec-4d0c-9776-5967d4ee7c79", "tercero_id": "8c7984b1-01f1-404f-ab49-7c313642b831"}, {"pedido_id": "1c8b02bf-489f-4585-accc-714b6b34db9b", "tercero_id": "6070bab2-3af3-4d6b-a376-f366dadbcaf7"}, {"pedido_id": "2791b08a-6567-4dc7-b30e-2b04e13e1423", "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"}, {"pedido_id": "70df37de-558b-4acb-a101-4c6b623988ce", "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"}, {"pedido_id": "55e9a870-bfe9-4c50-9567-6a25155af577", "tercero_id": "df6a96be-c9df-4f61-804f-3886113140f9"}, {"pedido_id": "5306b29f-67a2-4879-b457-ed2d1aaa0158", "tercero_id": "b90646ef-8c1e-41d1-9a05-69ec97228091"}]'::jsonb) as v(pedido_id uuid, tercero_id uuid)
--    where p.id = v.pedido_id and p.tercero_id = v.tercero_id;
--   get diagnostics n = row_count;
--   raise notice 'Pedidos devueltos a "sin cliente": % (esperado 16)', n;
-- end
-- $vuelta$;
