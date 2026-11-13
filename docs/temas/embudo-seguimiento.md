# Tema: Embudo de ventas y seguimiento (CRM - Chat 3)

## Alcance
Oportunidades (etapas: consulta → cotización → anticipo → producción → listo → entregado → posventa / perdida), tareas, alertas de Seguimiento (`fn_crm_alertas`), plantillas de WhatsApp.

## Situación al 13-nov-2026
- Hay **dos embudos**: `oportunidades` en el CRM (0 filas) y `oportunidades_venta` en el ERP (2 filas). Hay que dejar uno solo (coordinar con el Orquestador ERP).
- "Crear pedido desde oportunidad" solo avisa que el pedido se crea en el ERP. El código muerto que había después del `return` ya se quitó (13-nov).
- Automatizaciones actuales: al pasar a Cotización crea tarea a 3 días; al pasar a Entregado crea tarea de posventa a 7 días.

## Ideas (de CRM líderes como Kommo/Pipedrive)
- Carrito abandonado de la web → oportunidad automática.
- Formulario de personalizados de la web → oportunidad automática.
- Que la etapa avance sola cuando el ERP registra anticipo, producción, envío y entrega.

## Qué falta
- [ ] Embudo único.
- [x] Limpiar código muerto (13-nov).
- [ ] Automatizaciones desde la web y el ERP.

## Propuesta (13-nov-2026): embudo único sobre `oportunidades_venta` del ERP
*(Solo lectura del ERP. Es una propuesta: no se ha cambiado la pantalla ni ninguna base.)*

### Lo que tiene hoy `oportunidades_venta` (ERP)
- Campos: `id`, `consecutivo`, `tercero_id` (o `cliente_nombre_libre` / `cliente_telefono_libre` / `cliente_correo_libre`), `descripcion`, `monto_estimado`, `etapa`, `notas`, `cotizacion_id`, `origen`, `foto_referencia_url`, `ciudad_envio`, `registrado_por`, fechas.
- **Etapas permitidas (la base las limita): `prospecto`, `calificado`, `propuesta`, `cierre_ganado`, `cierre_perdido`.** Origen: `manual` o `web`. Hoy: 2 filas, ambas `prospecto`/`manual`.
- Al crearse con origen `web` (Personaliza), un disparador avisa por correo; la función `crear_solicitud_personalizada_v2` exige `p_acepta_datos`.
- No tiene: fecha de entrega deseada, motivo de pérdida, vínculo con el pedido, fecha de la etapa, ni posventa.
- Piezas del ERP que sí dicen en qué va la venta: `cotizaciones.estado` (enviada, aprobada, rechazada, vencida, convertida; enlazada por `oportunidades_venta.cotizacion_id`) y `pedidos_canal_venta` (`anticipo_pagado`, `saldo_pagado`, `estado`: esperando_pago → en_preparacion → listo_despacho → entregado; `envio_estado`; `referencia_crm_id`).

### Cómo se cruzan las etapas
Las 8 etapas del CRM no caben en las 5 del ERP, y el ERP no las puede cambiar sin tocar su base. Propuesta: **no guardar la etapa fina, calcularla** a partir de lo que ya registra el ERP; solo lo que el ERP no sabe se guarda en el detalle.

| Etapa CRM | Cómo se sabe | Etapa en `oportunidades_venta` |
|---|---|---|
| Consulta | Oportunidad nueva, sin cotización | `prospecto` |
| Cotización | Tiene `cotizacion_id` con estado `enviada` | `propuesta` (o `calificado` si ya hablaron pero no hay cotización) |
| Anticipo | Cotización `aprobada`/`convertida` y pedido con `anticipo_pagado = true` | `cierre_ganado` |
| Producción | Pedido `en_preparacion` | `cierre_ganado` |
| Listo | Pedido `listo_despacho` | `cierre_ganado` |
| Entregado | Pedido `entregado` | `cierre_ganado` |
| Posventa | Entregado + el CRM marcó posventa (en el detalle) | `cierre_ganado` |
| Perdida | Cotización `rechazada`/`vencida` o el equipo la marca | `cierre_perdido` |

Notas:
- Las etapas de Anticipo a Entregado **las mueve el ERP** (al registrar pago, producción, envío y entrega); en el CRM esas tarjetas no se arrastran a mano.
- Consulta, Cotización, Perdida y Posventa **sí las mueve el equipo en el CRM**.
- El tablero del CRM seguiría mostrando las 8 columnas; por debajo lee la oportunidad + cotización + pedido en una **vista de lectura** (`v_crm_embudo`).
- Duda a confirmar con ERP: si `pedidos_canal_venta.referencia_crm_id` puede apuntar a `oportunidades_venta.id` (hoy se pensó para el CRM viejo). Si no, el vínculo vive en el detalle (`pedido_id`).

### Campos para `crm_oportunidades_detalle` (para pasar al CRM Chat 1)
Una fila por oportunidad; la tabla nace cerrada (sin `anon`/`PUBLIC`), con acceso por rol.

| Campo | Para qué |
|---|---|
| `oportunidad_id` (PK, → `oportunidades_venta.id`) | Enlace 1 a 1 |
| `pedido_id` (→ `pedidos_canal_venta.id`, nullable) | Vínculo con el pedido (reemplaza `pedido_id` del CRM viejo) |
| `etapa_desde` (timestamptz) | Días en la etapa actual (hoy el tablero los cuenta) |
| `fecha_entrega_deseada` (date) | "Lo necesita para…" |
| `motivo_perdida` (text) | Por qué no se concretó (+ opcional `motivo_perdida_tipo`: precio, tiempo, compró en otro lado, sin respuesta, otro, para sacar indicadores) |
| `posventa_iniciada_at` / `posventa_estado` | Posventa (pendiente, opinión pedida, reseña recibida) |
| `casa` (Crochet / Mercería / Academy) | Separar el embudo por casa |
| `canal_origen` (Instagram, WhatsApp, Facebook, Feria, Referido, Web) | El ERP solo tiene `manual`/`web`; el CRM necesita más detalle para saber de dónde llegan |
| `responsable_id` (→ `profiles`) | Quién hace el seguimiento |
| `proximo_contacto` (date) | Alimenta las alertas de Seguimiento |
| `ultimo_contacto_at` | Detectar oportunidades dormidas |
| `created_at` / `updated_at` | Control |

Las tareas (`tareas.oportunidad_id`) apuntarían a `oportunidades_venta.id` en lugar de la tabla `oportunidades` del CRM (que tiene 0 filas y se retiraría al final).

### Automatizaciones que conviene tener
**Ya existen (se conservan):** cotización → tarea a 3 días; entregado → tarea de posventa a 7 días.

**Nuevas (propuesta, en orden de prioridad):**
1. **Solicitud de Personaliza → oportunidad en Consulta + tarea "responder hoy"** (la oportunidad ya la crea la web; el CRM solo agrega el detalle y la tarea).
2. **El ERP avanza la etapa solo:** pago de anticipo → Anticipo; pedido en preparación → Producción; listo para despacho → Listo; entregado → Entregado (por la vista, sin que nadie arrastre tarjetas).
3. **Cotización vencida o sin respuesta** (ej. 7 días) → tarea de recordatorio; a los 15 días → sugerir marcar Perdida con motivo.
4. **Oportunidad dormida** (más de X días sin contacto) → alerta en Seguimiento.
5. **Entrega cercana:** `fecha_entrega_deseada` a menos de 7 días y sin pedido en producción → alerta.
6. **Entregado → posventa** (opinión/reseña) a los 7 días, **solo si la persona marcó recibir novedades** y con enlace de baja; sin Navidad, santos ni Halloween.
7. **Carrito abandonado → oportunidad:** **en espera**. Los datos de la web no se usan en el CRM en producción hasta que la abogada apruebe la finalidad, y el recordatorio de carrito exige autorización. Solo se prepara el diseño.

### Cuidados
- Los datos de la solicitud (nombre, teléfono, fotos) llegan con la autorización de datos de Personaliza; **eso no autoriza mensajes comerciales**. Mensajes solo con la casilla de novedades.
- Fotos de referencia (`foto_referencia_url`): se pueden mostrar en la tarjeta solo si la web confirma el consentimiento de fotos (`p_acepta_fotos`); consultar al Chat de Personaliza vía Orquestador.
- Todo lo del lado ERP (vista `v_crm_embudo`, permisos de lectura del CRM sobre `oportunidades_venta`, si se crea o no la tabla de detalle en la base del ERP) pasa por el Orquestador ERP.

### Decisiones que pide Sara
- ¿Te sirve que las etapas Anticipo → Entregado **se muevan solas desde el ERP** (y no a mano en el CRM)?
- ¿Cuántos días sin respuesta antes de dar una cotización por perdida (propuesta: 15) y cuándo marcar una oportunidad como "dormida" (propuesta: 10 días)?
