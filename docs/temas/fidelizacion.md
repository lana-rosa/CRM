# Tema: Fidelización y comunicación (CRM - Chat 4)

## Alcance
Recompra, cumpleaños y fechas especiales, posventa, reactivación de clientes dormidos, puntos de fidelización, mensajes por WhatsApp (enlaces wa.me con plantillas) y correo.

## Situación al 13-nov-2026
- Los segmentos RFM y las alertas existen, pero calculan sobre la base casi vacía del CRM.
- El ERP ya tiene `parametros_fidelizacion`, `movimientos_puntos_fidelizacion`, `suscriptores_bono`, `configuracion_correo`, `correos_enviados`.
- La voz de marca y el contenido los maneja el chat "Web Chat 8. Marketing y contenido" (otro Orquestador). Para textos de mensajes, respetar la voz de Lana Rosa.

## Flujos objetivo (como Klaviyo/HubSpot)
Bienvenida · posventa (pedir foto/reseña) · recompra según tiempo típico entre compras · cumpleaños · reactivación (más de 120 días) · carrito abandonado.

## Qué falta
- [ ] Esperar la unificación del Chat 1 (opción A decidida el 13-nov). No activar con datos de la web hasta que la abogada apruebe la finalidad.
- [ ] Fecha estimada de próxima compra por cliente.
- [ ] Conectar puntos y reseñas a la ficha y a los flujos.

## Automatización de posventa: agradecimiento + encuesta + reseñas (pedido de Sara, 15-nov-2026)
**Idea:** unos días después de que el pedido queda *entregado*, un mensaje con (1) agradecimiento, (2) encuesta corta de satisfacción con enlace único por pedido, (3) invitación a calificar en la web y en Google.

**Lo que ya existe (respuesta del Orquestador WEB, 15-nov; dueño Web Chat 5):**
- Pedidos **web**: al pasar a «pagado», `trg_pedido_web_pagado` → `fn_correo_compra_web` (uno por pedido, `avisos_compra_web`): confirmación, recibo, aviso de cuenta y **enlace de reseña en Google**. En `cuenta.html` sale «te falta calificar» cuando está entregado (`mis_resenas` → `resenas_web`).
- `fn_correo_calificar` (`avisos_calificar`) ya no envía para pedidos web; sigue para los demás (confirmar con Web Chat 5 si cubre `pedidos_canal_venta` sin cuenta).
- **No duplicar:** la posventa debe reemplazar o integrarse con esos correos, nunca un segundo correo por la misma compra.
- Envío: **Resend** desde `contacto@lanarosacrochet.com` (llave en la bóveda, `resend_api_key`). Un solo remitente. `configuracion_correo`/`correos_enviados`: decidir con el Orquestador ERP.
- Google: hoy la web usa `https://share.google/0JoGMBgdPvaKHMRCu`; falta el enlace directo de la ficha (lo envía Sara). **Pedir reseña a TODOS, sin filtrar por satisfacción y sin dar nada a cambio** (reglas de Google).
- Encuesta: página de la web (Web Chat 4 o 6), enlace único por pedido (token aleatorio con vencimiento), sin iniciar sesión; respuestas en tabla `crm_` con RLS solo administradora; escritura **solo** por una función SECURITY DEFINER que valida el token (anon ejecuta esa función, no la tabla). Datos mínimos. **El diseño se envía al Orquestador WEB antes de construir.**
- Ley 1581: pregunta enviada a la abogada (Web Chat 6): ¿agradecimiento + encuesta = servicio o comercial? **Hasta que responda: tratarlo como comercial** (solo a quien aceptó novedades, con enlace de baja).

**Decisiones de Sara (15/16-nov):**
- Canal: **WhatsApp con un clic** (desde Seguimiento) **+ correo automático**.
- Momento: **5 días después de la entrega**.
- Encuesta (4 preguntas): 1) ¿Qué tan feliz estás con tu amigurumi? (1 a 5 ⭐) · 2) ¿Cómo fue la atención? · 3) ¿Llegó a tiempo? · 4) **¿Algo que podamos mejorar?** (texto libre, opcional; Sara pidió dejarla con ese texto).
- El correo de compra web (`fn_correo_compra_web`) ya pide la reseña de Google: coordinar para que no se pida dos veces (que ese correo deje de pedirla o que la posventa la reemplace).
- La pregunta servicio/comercial está en el punto 17 del documento de la abogada (Web Chat 6).
- **Enlace directo de reseñas de Google (lo dio Sara el 16-nov): https://g.page/r/Cae2iIji5j_XEAI/review** — usar este en la posventa (reemplaza al `share.google/...` que usa hoy la web).
