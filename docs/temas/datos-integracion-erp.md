# Tema: Datos, integración con el ERP y seguridad (CRM - Chat 1)

## Alcance
Base de datos del CRM, su relación con la base del ERP, permisos (RLS) y seguridad de Supabase. Es el tema que **desbloquea a los demás**.

## Situación al 13-nov-2026
- El CRM tiene su propia base (`wcqdkccvtywiutzknskr`) casi vacía: 2 clientes, 1 pedido, 0 oportunidades.
- Los clientes y ventas reales están en el ERP (`ngjoognzvehwjtpqwrqe`): `terceros` (49), `pedidos_canal_venta` (36), `pedidos_web` (17), `ventas_pos` (8), `ventas_academia`, `cuentas_clientes_web`, `carritos_abandonados` (12), `oportunidades_venta` (2), `movimientos_puntos_fidelizacion`, `resenas_web`.
- El ERP ya tiene campos pensados para enlazar con el CRM: `terceros.crm_cliente_id`, `pedidos_canal_venta.referencia_crm_id`.
- Hay una sincronización CRM → ERP con `pg_net` (`fn_trg_estado_pedido_a_erp`, `sync_stock_item_to_os`).

## Avisos de seguridad (base del CRM, 13-nov)
- ~~`fn_trg_estado_pedido_a_erp`, `handle_new_user`, `sync_stock_item_to_os` ejecutables por `anon`/`authenticated`~~ → cerrado el 13-nov.
- `crm_es_admin`: SECURITY DEFINER ejecutable por `authenticated` (puede ser intencional: revisar).
- 6 funciones sin `search_path` fijo: `generar_numero_pedido`, `set_updated_at`, `handle_new_user`, `sync_anticipo_pedido`, `fn_pedido_fecha_envio`, `crm_touch_oportunidad`.
- `pg_net` instalado en `public`.
- Protección de contraseñas filtradas apagada (la activa Sara en el panel de Supabase → Auth).
- Pendiente verificar: que las políticas RLS impidan a una tejedora leer `clientes`, `pagos`, `oportunidades` (hoy el bloqueo visible está solo en la pantalla).

## Decisión de Sara (13-nov-2026): OPCIÓN A ✅
(Texto original de las opciones:)
**Opción A (recomendada):** mover el CRM a la base del ERP; el cliente es `terceros` y el CRM agrega encima sus tablas (interacciones, tareas, fechas, plantillas). Prospectos sin autorización de datos quedan como "contacto" hasta aceptar.
**Opción B:** mantener dos bases y sincronizarlas.
Cualquier cambio en la base del ERP se coordina antes con el Orquestador ERP.

## Acuerdos con el Orquestador ERP (13-nov-2026)
La opción A le parece bien al Orquestador ERP, con estas condiciones:
- El CRM **no escribe** en tablas del ERP (`terceros`, `pedidos_*`, `ventas_*`): solo lee, por vistas o RPC.
- Las tablas propias del CRM referencian `terceros.id`.
- Lo que el CRM necesite escribir en `terceros` va por una función RPC acordada con el ERP.
- Reglas del ERP: la lógica va en funciones RPC plpgsql `security definer` con RLS; **nunca** `DROP FUNCTION` ni `ALTER … DROP COLUMN` (se cuelgan por event triggers): se deja lo viejo y se revoca `execute`; probar con rollback (`do $$ … raise exception $$`) simulando el usuario con `set_config('request.jwt.claims', …)`; el Worker de Cloudflare no se puede editar; solo la administradora ve lo sensible; respetar `acepta_tratamiento_datos`.
- **Antes de cualquier cambio en la base del ERP, el SQL propuesto se le manda al Orquestador ERP**, que lo revisa con Sara. La misma base la usa la Web: también se avisa al Orquestador WEB.
- Dueños en el ERP: `terceros` de punto de venta = ERP Chat 1 Ventas; de pedidos = ERP Chat 2 Pedidos; `oportunidades_venta` sin dueño. Los cambios los asigna el Orquestador ERP.

## Puentes CRM → ERP (no tocar sin OK del Orquestador ERP)
- `fn_trg_estado_pedido_a_erp` (triggers `trg_estado_pedido_a_erp` y `trg_envio_pedido_a_erp` sobre `pedidos`): pg_net a la Edge Function del ERP `actualizar-pedido-desde-crm` con `x-puente-clave`. **Se deja como está** por ahora (13-nov).
- `sync_stock_item_to_os` (trigger sobre `stock_items`): usa la **service role del ERP** guardada en el Vault del CRM (`os_service_role_key`) para escribir `inventario_items`. 13-nov: **trigger desactivado** (la función se conserva). **Secreto `os_service_role_key` borrado del Vault del CRM el 13-nov** (lo confirmó Sara). Queda solo `erp_puente_secreto` (puente de estados). Rotar la clave: NO por ahora (lo planea el Orquestador ERP; podría romper el Worker de ventas antes de la apertura del 13-dic).
- 13-nov, migración `fase0_cerrar_funciones_trigger_y_apagar_sync_stock`: revocado `execute` a `public`, `anon` y `authenticated` en `fn_trg_estado_pedido_a_erp`, `handle_new_user` y `sync_stock_item_to_os`. Probado con rollback: el puente de estados sigue poniendo la solicitud en la cola de pg_net.

## Embudo único (acordado con el Orquestador WEB, 13-nov)
- Personaliza escribe en `oportunidades_venta` (ERP) con `crear_solicitud_personalizada_v2(...)` (abierta a anon a propósito). `depurar-fotos-referencia` borra las fotos de referencia a los 90 días.
- El embudo único será `oportunidades_venta`. **No cambiar su firma ni la tabla sin acordarlo con el Orquestador WEB** (y el ERP: tablero de Oportunidades).
- Puntos de fidelización: son del ERP.

## Qué falta
- [x] Cerrar las funciones expuestas (13-nov).
- [ ] Fijar `search_path` en las 6 funciones; revisar RLS por rol.
- [x] Decisión A/B de Sara: **opción A** (13-nov).
- [ ] Fase 1, diseño: proponer el SQL (tablas del CRM en la base del ERP referenciando `terceros.id`, vistas/RPC de solo lectura para historial de compras, RPC acordada para escribir en `terceros`, "contactos" sin autorización de datos). **El SQL se le entrega al Orquestador CRM**, que lo manda al Orquestador ERP (y avisa al WEB) para revisarlo con Sara antes de aplicarlo.
- [ ] Migrar los 2 clientes y el pedido del CRM (o confirmar que ya existen en el ERP).
- [ ] Cambiar el CRM para que se conecte a la base del ERP (después del OK).
- [ ] Diseño de la unificación (vistas de historial de compras por `tercero_id`, embudo único).
