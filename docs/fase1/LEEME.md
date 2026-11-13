# Fase 1 — El CRM pasa a la base del ERP (propuesta, 13-nov-2026)

**Estado: aprobada por Sara el 13-nov-2026; todavía NO se aplicó nada en el ERP.** Antes de aplicar: prueba con rollback contra la base real (o rama de Supabase) y el go del Orquestador ERP.

Archivos:
- `propuesta.sql`: el SQL completo. Solo **crea** objetos nuevos; no cambia ni borra nada del ERP.
- `prueba-rollback.sql`: la prueba con usuarios simulados. No deja nada guardado.

## 1. Qué crea y por qué

| Objeto (en la base del ERP) | Para qué | Por qué así |
|---|---|---|
| `crm_contactos` | Prospectos que **aún no** autorizaron el tratamiento de datos | `terceros` exige `acepta_tratamiento_datos` (Ley 1581). Datos mínimos: sin cédula, fecha de nacimiento, dirección ni correo |
| `crm_interacciones` | Historial de contacto con un cliente o contacto | Cuelga de `terceros.id` **o** de `crm_contactos.id` (exactamente uno) |
| `crm_tareas` | Pendientes de seguimiento | Puede apuntar a `oportunidades_venta` |
| `crm_fechas_especiales` | Fechas de un cliente (con autorización) | Solo de `terceros`. Ver "Pendiente de la abogada" |
| `crm_plantillas_mensaje` | Textos de WhatsApp (se cargan las 5 actuales) | Columna `es_comercial`: solo "cotización" es seguimiento; las otras 4 son publicidad y solo van a quien marcó novedades |
| `crm_oportunidades_detalle` | Campos extra del embudo (etapa fina, motivo de pérdida, fecha deseada, pedido ligado) | Tabla aparte `oportunidad_id → oportunidades_venta.id`; **no se toca** `oportunidades_venta` (acordado con ERP y WEB) |
| `fn_crm_clientes_resumen(buscar)` | Lista de clientes con nº de compras, total y última compra | Lee `terceros` + pedidos + POS + academia. Solo clientes con autorización de datos |
| `fn_crm_historial_compras(tercero_id)` | Compras de un cliente | Une `pedidos_canal_venta`, `ventas_pos` (completadas) y `ventas_academia` |
| `fn_crm_embudo()` | Oportunidades del ERP + detalle del CRM | Solo lectura |
| `fn_crm_casas_cliente(tercero_id, incluir_web)` | Qué casas (Crochet, Mercería, Academy) tiene un cliente según lo que compró: nº de compras, total, primera y última. Con `tercero_id` vacío devuelve todos los clientes | Reemplaza a `clientes_casas` de la base vieja. `centro_costo_id` no sirve (todo está en 01 Tienda/Mercería), así que se deduce por el contenido de lo vendido. Ver sección 1b |
| `fn_crm_set_updated_at()` | Pone `updated_at` | Sin permisos para nadie; solo la usan los triggers |

Reglas que cumple (de las "Pautas para la Fase 1"):
- **RLS encendida** en las 6 tablas; una sola política por tabla: solo `administrador` (con `fn_rol_actual()`). Cajero, contador, taller y tejedora no ven ni escriben nada del CRM.
- **Nada para `anon` ni `PUBLIC`**: Supabase da permisos por defecto en objetos nuevos y el SQL los revoca expresamente.
- Funciones `security definer`, `search_path = public, pg_temp`, `execute` solo para `authenticated`, y adentro se vuelve a revisar el rol (error `42501` si no es administradora).
- El CRM **no escribe** en `terceros`, `pedidos_*` ni `ventas_*`. La única función que lo haría (`fn_crm_promover_contacto`) va **comentada** al final del SQL: necesita acuerdo con ERP Chat 1 Ventas (dueño de `terceros`).
- Sin `DROP FUNCTION` ni `DROP COLUMN`. No se toca el puente `fn_trg_estado_pedido_a_erp`.
- Las compras de la web se ven como `pedidos_canal_venta` (canal `tienda_virtual`) cuando el ERP las registra. **No se cruza `pedidos_web` por correo** (Ley 1581: los datos de la web no se usan en el CRM hasta que la abogada apruebe esa finalidad).

### 1b. Cómo se deducen las casas (`fn_crm_casas_cliente`)

Un cliente puede tener varias casas. **Regla confirmada por el Orquestador ERP y el Orquestador WEB (13-nov):**

| Casa | Cuándo |
|---|---|
| **Academy** | Cualquier fila de `ventas_academia` del cliente, o una venta con centro de costo 04, 05 o 06 |
| **Mercería** | Ítem con `inventario_items.tipo = 'merceria'` **y** del centro 01 Tienda (en `ventas_pos_detalle`, `pedidos_canal_lineas`, `pedidos_canal_venta.inventario_item_id` o `pedidos_web_items.producto_id`). Un ítem de mercería de otro centro (insumos del Taller) no define casa |
| **Crochet** | Pedidos de canal sin ítem de inventario (personalizados) y líneas con tipo `producto_terminado` |
| **Agenda** | Casa propia: ítem de un pedido web con `producto_id` vacío (el nombre "Membresía Agenda" solo es apoyo) |
| (ninguna) | El centro 03 Taller nunca define casa; el 01 tampoco, porque todo se factura desde la Tienda |

Detalles (**confirmados por el Orquestador ERP el 13-nov**, junto con dejar la parte web apagada):
1. **"Centro 01" de la Mercería:** lo leí como el centro de costo **del ítem** (`inventario_items.centro_costo_id`), que es lo que separa el inventario del Taller del de la Tienda. Si la regla era el centro de la **venta**, no serviría: todas las ventas están en 01.
2. **Pedidos con líneas:** se clasifican por sus líneas (una línea sin ítem es un personalizado, o sea Crochet). Solo los pedidos sin líneas se clasifican por su cabecera. Así, un pedido hecho solo de lanas no cuenta como Crochet por tener la cabecera sin ítem. Con los datos de hoy el resultado es idéntico al de la regla simple.
3. **Web:** `pedidos_web_items.producto_id` es `inventario_items.id`. Entran pedidos **pagados**, que no sean de prueba y que **no estén ya registrados en el ERP** (si lo están, ya salen como `pedidos_canal_venta` y no se cuentan dos veces). Los pedidos digitales **sí** cuentan (la membresía es Agenda). Un `producto_id` que no exista en inventario no define casa y se omite.
4. **Ley 1581:** el pedido web se liga al cliente por `cuentas_clientes_web`, que es dato de la web. Por eso la parte web viene **apagada** (`incluir_web = false`) hasta que la abogada apruebe esa finalidad. Hoy no cambia el resultado: los 2 pedidos web pagados ya están registrados en el ERP y salen como pedidos de canal.

Dato de hoy: ninguna compra registrada es de Mercería (todo lo vendido es `producto_terminado`, personalizado o academia) y Agenda solo aparecerá cuando se encienda la parte web.

## 2. Cómo se probó

No se corrió nada en el ERP (ni siquiera con rollback: sus disparadores de eventos pueden colgarse con DDL). Se probó en un Postgres 16 local con tablas de mentira que imitan al ERP (`terceros`, `pedidos_canal_venta`, `ventas_pos`, `ventas_academia`, `oportunidades_venta`, `fn_rol_actual`, `fn_es_tejedora`) y los permisos por defecto de Supabase:

1. `propuesta.sql` se aplica limpio en **una sola transacción**.
2. `prueba-rollback.sql`: **30 comprobaciones, 0 fallas**. Administradora: lee, crea y usa las 3 funciones (una interacción con dos dueños es rechazada). Cajero y tejedora: ven 0 filas, no crean nada y las 3 funciones les dan error. Visitante sin sesión: sin acceso. Catálogo: 0 funciones `fn_crm_*` ejecutables por `anon`/`PUBLIC`, 0 tablas `crm_*` sin RLS.
3. Números: un cliente con pedido entregado (50.000), pedido esperando pago (excluido), venta POS completada (20.000), venta POS anulada (excluida) y curso (100.000) da 3 compras y 170.000. El cliente sin autorización no sale en el resumen.

4. **Casas** (`prueba-casas-local.sql`, sobre `stub-erp-local.sql`): un cliente por cada regla (academia, personalizado, ítem terminado, mercería en POS, venta en centro 04, pedido con líneas mixtas, cabecera sin ítem con línea de mercería, centro 05) y los que **no** deben dar casa (esperando pago, venta anulada, taller, línea sin ítem, mercería de un ítem del Taller), más la web apagada y encendida (Agenda, Crochet y Mercería; no cuenta lo ya registrado en el ERP, lo de prueba, lo pendiente ni lo anulado; un id desconocido se omite), el filtro por cliente y la seguridad por rol. **0 fallas.** Para comprobar que la prueba sirve, introduje a propósito errores en copias (contar pedidos que esperan pago, contar web ya registrada, ignorar el centro 01 de la mercería y mandar Agenda a Crochet) y la prueba los detectó.

**Cómo repetirla en el ERP, ya con OK** (idealmente en una rama de Supabase): aplicar `propuesta.sql` como migración y correr `prueba-rollback.sql`; el resultado sale como mensaje de error con `FALLAS: 0`. Usa un administrador, un cajero y una tejedora reales y simula la sesión con `set_config('request.jwt.claims', …)`. Luego, asesor de seguridad: 0 errores nuevos.

## 3. Informe de lo que no tiene vínculo (solo lectura de ambas bases, 13-nov)

**Clientes: 23 en el CRM, 20 ya vinculados** (`terceros.crm_cliente_id`). Los 3 sin vínculo (ninguno tiene pedidos en el CRM):

| id CRM | Creado | Qué es | Propuesta (decide Sara) |
|---|---|---|---|
| `69a5a935` | 02-jul | Su correo es el **del propio negocio**; en el ERP ese correo ya está en un registro de "proveedor" | Parece un registro interno o de prueba. **No migrar**; dejar en el CRM viejo |
| `d1cea353` | 17-jul | **Vacío**: sin cédula, teléfono ni correo | **No migrar**; dejar en el CRM viejo |
| `83e0fdbc` | 12-nov | Clienta real, con cédula y teléfono; no está en el ERP por documento, teléfono ni correo | Si hay constancia del aviso de datos (como los 9 de "WhatsApp/Redes — aviso en confirmación"): pasarla a `terceros`. Si no: `crm_contactos` hasta que autorice |

Ojo: en el CRM `acepta_contacto` está en "sí" para los 23, pero **eso no es la autorización de tratamiento de datos** que exige `terceros`.

**Pedidos: 33 en el CRM, 26 ya vinculados** (`pedidos_canal_venta.referencia_crm_id`). Los 7 sin vínculo:

| Pedido CRM | Qué es | Propuesta |
|---|---|---|
| LR-2026-004 | Prueba de **$1** (cliente ya vinculado) | No migrar |
| LR-2026-008, 009, 010, 011, 012, 016 | Piezas de stock ya archivadas, sin cliente y sin pagos; el stock real son los 8 `stock_items`, ya vinculados con `inventario_items` | No migrar; quedan como historia en el CRM viejo |

**Pagos: 39 en el CRM.** 1 es el de $1 de LR-004. Los otros **38 corresponden a los 26 pedidos vinculados y los montos cuadran exactamente**: en los 26, lo pagado en el CRM es igual al total del pedido en el ERP, y el ERP los tiene como anticipo y saldo pagados. La diferencia es de detalle: en el ERP, `pedidos_canal_pagos` tiene **una sola fila por el total en 14 pedidos y ninguna en los otros 12** (ahí solo están las marcas "pagado"). El desglose anticipo/saldo, las fechas y los medios de pago solo existen en el CRM.
- **Propuesta:** no importar esos pagos al ERP. Meterlos tocaría caja, turnos y contabilidad (`asiento_id`), y eso lo decide el Orquestador ERP. El CRM viejo queda como archivo de ese detalle.
- Dato menor: LR-2026-036 está "listo" en el CRM y "en preparación" en el ERP. Es normal: Producción y Envíos ya viven en el ERP.

Otros datos del CRM viejo: 5 plantillas (se cargan en el SQL; ninguna menciona Navidad, santos ni Halloween), y 0 tareas, 0 interacciones, 0 fechas especiales y 0 oportunidades: no hay nada más que migrar. Nadie tiene fecha de nacimiento guardada.

## 4. Plan de transición (fechas propuestas; las decide Sara)

Principio: **el CRM actual sigue funcionando igual hasta el día del corte**, incluido el puente de estados `fn_trg_estado_pedido_a_erp`. Los pedidos nuevos ya se crean en el ERP.

| Cuándo | Qué pasa |
|---|---|
| 16–20 nov | Revisión del SQL por Orquestador ERP, WEB (Web Chat 5) y Sara. La abogada recibe las preguntas de la sección 5 |
| 23 nov | Con OK: aplicar `propuesta.sql` en el ERP (rama de Supabase primero), correr `prueba-rollback.sql`, asesor de seguridad. No cambia nada visible |
| 24 nov – 11 dic | Pantallas del CRM conectadas al ERP **en modo prueba**, solo lectura; el CRM actual sigue siendo el oficial. Decidir con Sara los 3 clientes de la sección 3 |
| 12–13 dic | **No tocar nada**: apertura del ERP el 13-dic |
| **Corte propuesto: lunes 11-ene-2027** | Pasada la temporada y la apertura. Ese día: el CRM viejo queda en **solo lectura**, la app apunta al ERP y se mueven a `crm_contactos` o `terceros` los clientes acordados |
| Después | El CRM viejo se **conserva** (nada se borra sin que Sara lo confirme). El puente de estados se retira solo cuando el Orquestador ERP lo diga |

## 5. Plan de vuelta atrás

- Todo lo nuevo es **aditivo** y vive al lado de lo existente: volver atrás no exige deshacer nada en el ERP. Siguiendo la regla del ERP no se hace `DROP`: se **revoca `execute`** de las funciones y se deja de usar lo demás.
- **Antes del corte:** no hay nada que revertir; el CRM viejo nunca dejó de ser el oficial.
- **Después del corte:** la app se vuelve a apuntar al CRM viejo (que sigue completo, en solo lectura, y se reactiva en escritura). El puente nunca se apagó. Los datos creados en `crm_*` desde el corte se exportan antes a CSV y se pasan a mano al CRM viejo. La app guarda la dirección de la base en cada dispositivo (`sb_url`/`sb_key`); el cambio de vuelta debe poder hacerse sin tocar código.
- Condición del Orquestador ERP: **no se borra nada de la base del CRM** sin confirmación de Sara.

## 6. Pendiente de la abogada (Ley 1581)

1. ¿Puede el CRM guardar **prospectos sin autorización** (nombre, teléfono, red social) y **por cuánto tiempo**? Hay una columna `conservar_hasta` esperando ese plazo.
2. Finalidad "gestión de relación con clientes y mensajes comerciales" en la política de datos. Hasta que la apruebe, los datos de la web (cuentas, carritos, reseñas, Personaliza) no entran al CRM.
3. **Fechas especiales y cumpleaños:** la web no pide fecha de nacimiento; pedirla o guardarla es un dato nuevo con finalidad propia.
4. **Evidencia de autorización:** de los 20 clientes ya vinculados, 10 tienen `acepta_tratamiento_datos = true` pero **sin `medio_autorizacion` ni `version_politica`** (9 dicen "WhatsApp/Redes — aviso en confirmación de pedido, v1.0" y 1 "Compra en la web, v1.0"). Hay que decidir si esa constancia basta.
5. Mensajes comerciales solo a quien marcó novedades y con enlace de baja; la autorización del bono no vale como publicidad.

## 7. Lo que NO incluye esta propuesta (siguientes pasos)

- Cambiar las pantallas de `index.html` para usar estas funciones (tema de cada chat, después del OK).
- Equivalentes en el ERP de `fn_crm_alertas` y `fn_crm_indicadores`.
- ~~Sustituir `clientes_casas`~~ → hecho en la propuesta con `fn_crm_casas_cliente` (sección 1b). Falta: que el ERP confirme los 4 detalles de la sección 1b y la aprobación de la abogada para encender la parte web.
- Editar datos de un cliente (`terceros`): irá por la RPC acordada con el ERP (el borrador comentado `fn_crm_promover_contacto` es el primer caso).
- Ver pedidos del ERP desde la pantalla Pedidos del CRM (`fn_crm_pedidos`).

## 8. Lo que vi en el ERP (para el Orquestador ERP; no lo toqué)

- **`oportunidades_venta`**: su única política se llama "Acceso total via service role", pero está puesta para el rol **`authenticated`** con condición `true`. Según su lectura, cualquier usuario con sesión podría ver y modificar todas las oportunidades (nombre, teléfono, correo, fotos de referencia). **No lo probé**; es lectura de la política. Si las cuentas de clientes de la web usan sesión de Supabase en la misma base, el alcance sería mayor.
- **Permisos de tabla**: `anon` tiene permiso de leer e insertar (lo comprobé) en `terceros`, `pedidos_canal_venta`, `pedidos_canal_pagos`, `pedidos_web`, `ventas_pos`, `ventas_academia` y `oportunidades_venta`; en `terceros` figuran además actualizar, borrar y vaciar. Las políticas RLS los frenan hoy, pero un fallo de política quedaría expuesto.
- La autorización de 10 de los 20 clientes vinculados no tiene constancia (punto 4 de la sección 6).
