# Tema: Datos, integración con el ERP y seguridad (CRM - Chat 1)

## Alcance
Base de datos del CRM, su relación con la base del ERP, permisos (RLS) y seguridad de Supabase. Es el tema que **desbloquea a los demás**.

## Situación al 13-nov-2026
- El CRM tiene su propia base (`wcqdkccvtywiutzknskr`) casi vacía: 2 clientes, 1 pedido, 0 oportunidades.
- Los clientes y ventas reales están en el ERP (`ngjoognzvehwjtpqwrqe`): `terceros` (49), `pedidos_canal_venta` (36), `pedidos_web` (17), `ventas_pos` (8), `ventas_academia`, `cuentas_clientes_web`, `carritos_abandonados` (12), `oportunidades_venta` (2), `movimientos_puntos_fidelizacion`, `resenas_web`.
- El ERP ya tiene campos pensados para enlazar con el CRM: `terceros.crm_cliente_id`, `pedidos_canal_venta.referencia_crm_id`.
- Hay una sincronización CRM → ERP con `pg_net` (`fn_trg_estado_pedido_a_erp`, `sync_stock_item_to_os`).

## Avisos de seguridad (base del CRM, 13-nov)
- `fn_trg_estado_pedido_a_erp`, `handle_new_user`, `sync_stock_item_to_os`: SECURITY DEFINER ejecutables por `anon` y `authenticated`.
- `crm_es_admin`: SECURITY DEFINER ejecutable por `authenticated` (puede ser intencional: revisar).
- 6 funciones sin `search_path` fijo: `generar_numero_pedido`, `set_updated_at`, `handle_new_user`, `sync_anticipo_pedido`, `fn_pedido_fecha_envio`, `crm_touch_oportunidad`.
- `pg_net` instalado en `public`.
- Protección de contraseñas filtradas apagada (la activa Sara en el panel de Supabase → Auth).
- Pendiente verificar: que las políticas RLS impidan a una tejedora leer `clientes`, `pagos`, `oportunidades` (hoy el bloqueo visible está solo en la pantalla).

## Decisión pendiente de Sara
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

## Qué falta
- [ ] Fase 0: cerrar las funciones expuestas, fijar `search_path`, revisar RLS por rol.
- [ ] Decisión A/B de Sara.
- [ ] Diseño de la unificación (vistas de historial de compras por `tercero_id`, embudo único).
