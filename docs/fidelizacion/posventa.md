# Posventa automática: agradecimiento + encuesta + reseñas

**Estado:** DISEÑO (16-nov-2026, CRM - Chat 4 Fidelización). No se aplicó nada en ninguna base ni se tocó `index.html`.
**Para:** Orquestador General (desde el 17-nov, único; el Orquestador CRM quedó archivado), que lo pasa a Web Chat 5 y al ERP antes de construir.
**SQL propuesto:** `docs/fidelizacion/posventa.sql` · **Prueba local:** `prueba-posventa-local.sh` (37 comprobaciones, 0 fallas, Postgres con tablas de mentira; falta probarlo contra el ERP real con `begin … rollback`).
**Origen del pedido:** `docs/temas/fidelizacion.md`, sección «Automatización de posventa».

---

## 1. En palabras simples (para Sara)

Cinco días después de que un pedido queda **entregado**, la clienta recibe:

1. **Un correo automático** (por Resend, el mismo envío de la web) que le da las gracias, le pide contestar una encuesta de 4 preguntas y la invita a calificar en la web y en Google.
2. **Un WhatsApp con un clic**: en **Seguimiento** te sale la lista «Posventa para enviar» con un botón por clienta; el mensaje ya viene escrito y con su enlace. Tú solo das clic y envías.

Las dos cosas llevan **el mismo enlace único por pedido**, sin iniciar sesión. Una clienta solo puede contestar una vez por pedido y el enlace se vence a los 30 días.

**Lo que NO hace:** no manda recordatorios insistentes (un solo correo), no escribe a los pedidos viejos que ya se entregaron, no ofrece regalos ni descuentos por calificar, y no esconde la invitación a Google a quien puso una nota baja.

**Lo más importante que encontré (leer antes de decidir):** hoy, con la regla prudente (solo a quien aceptó novedades), **solo 1 de los 33 pedidos entregados** tiene una clienta que aceptó novedades. Casi nadie lo recibiría. Se explica en el punto 3; no es un error del diseño sino de dónde vive hoy esa autorización.

---

## 2. Línea de tiempo de un pedido

| Día | Qué pasa | Quién |
|---|---|---|
| 0 | El pedido pasa a **entregado** en el ERP (queda en `pedidos_canal_historial`) | ERP, como hoy |
| 5, 10:00 a. m. (Colombia) | Una tarea diaria revisa quién cumple las reglas y crea el seguimiento con su enlace (`crm_posventa`) | Base (pg_cron) |
| 5, mismo momento | Sale el **correo** por Resend | Base (pg_net, igual que `fn_correo_compra_web`) |
| 5 en adelante | Aparece en **Seguimiento** para WhatsApp con un clic; al enviarla se marca y desaparece de la lista | Sara |
| 5 a 35 | La clienta abre el enlace y contesta (una vez) | Clienta, página de la web |
| al contestar | Ve el agradecimiento y las invitaciones a calificar (web y Google). Si marcó algo por mejorar, se crea una **tarea interna** «escribirle personalmente» | Función de la encuesta |
| 35 | El enlace vence | — |

Parámetros (editables en `crm_posventa_config`, sin tocar código): días de espera = 5, vigencia = 30, enfriamiento por clienta = 30 días.

---

## 3. A quién se le envía

Todas estas condiciones juntas (vista `v_crm_posventa_candidatas`):

- Pedido en estado `entregado`, con fecha de entrega **de hace 5 días o más y no más de 30** (la fecha sale de `pedidos_canal_historial`, porque `pedidos_canal_venta` no guarda cuándo se entregó).
- Entregado **después del corte** `desde_entregados` (obligatorio para encender). Así no se le escribe de golpe a los 33 pedidos ya entregados.
- Clienta activa en `terceros`, con correo válido **o** teléfono.
- **Mientras la abogada no responda** (`requiere_novedades = true`): la clienta tiene cuenta web (`cuentas_clientes_web`) y `cuentas_novedades.acepta = true`.
- Un pedido = un seguimiento, y una clienta = un seguimiento cada 30 días (si le entregan dos pedidos seguidos, se pregunta por el primero).

### Hallazgo: casi nadie cumple la regla de novedades
Consultado en el ERP (solo SELECT, 16-nov):
- 33 pedidos de canal están `entregado`; **1** pertenece a una clienta con cuenta web y novedades aceptadas.
- La autorización de novedades vive solo en `cuentas_novedades`, que se llena desde la **cuenta web**. Las clientas de WhatsApp, Instagram o mostrador no tienen cuenta y por eso no tienen esa autorización registrada. `terceros.acepta_tratamiento_datos` es otra cosa (datos), **no** autoriza publicidad.

Opciones (decide Sara con la abogada; no las construyo):
- **A. Esperar la respuesta de la abogada.** Si agradecimiento + encuesta es *servicio* (algo que se derivó de la compra), se apaga `requiere_novedades` y le llega a todas. Es un solo cambio en `crm_posventa_config`.
- **B. Mientras tanto, solo WhatsApp manual** a las clientas que *tú* sabes que aceptaron (hablar con ellas ya es un acto tuyo, fuera de la automatización). El correo automático espera.
- **C. Pedir la casilla de novedades al comprar** también por WhatsApp/mostrador y guardarla (dato nuevo con finalidad propia: dueño ERP/WEB, no se hace aquí).

Tampoco se debe olvidar esto: **la propia lectura de `cuentas_novedades` desde el CRM es «dato de la web usado en el CRM»**, que según el acuerdo del 13-nov espera la aprobación de la abogada. Por eso el diseño nace **apagado** (`activo = false`) y primero se hace un **simulacro** (contar candidatas sin enviar nada).

---

## 4. Correo (automático)

- **Cómo:** `fn_crm_posventa_enviar_correos()` usa `resend_api_key` de la bóveda y `net.http_post`, igual que `fn_correo_compra_web`. Un solo remitente.
- **Remitente:** el doc de fidelización dice `contacto@lanarosacrochet.com`; `fn_correo_calificar` hoy usa `ventas@lanarosacrochet.com`. Queda en `crm_posventa_config.remitente`: **decidir con WEB/ERP cuál es el oficial.**
- **Una sola vez por pedido:** `crm_posventa.pedido_id` es único y se envía con `Idempotency-Key: posventa-<id>`, así que un reintento no duplica el correo.
- **Enlace de baja** visible y también en el encabezado `List-Unsubscribe`.
- **Registro:** queda en `crm_posventa.correo_estado`. Si el ERP quiere además registrar en `correos_enviados` o seguir rebotes (webhook de Resend), se agrega después; `pg_net` es asíncrono, así que «enviado» significa «entregado a Resend».
- Sin correo válido: el canal queda `omitido`; si tampoco hay teléfono, no se crea el seguimiento.

## 5. WhatsApp (un clic desde Seguimiento)

- No hay envío automático: la API de Meta es la Fase 6 opcional. Se mantiene `wa.me` con plantilla, como hoy en `index.html` (~2475–2492).
- **Alerta nueva en Seguimiento** «Posventa para enviar»: lee `fn_crm_posventa_pendientes()` (nombre, teléfono, producto, enlace ya armado). Botón → abre `wa.me` con la plantilla `posventa` con `{nombre}`, `{producto}` y `{enlace}`; al enviar llama `fn_crm_posventa_marcar_whatsapp(id)`.
- La plantilla `posventa` que ya existe en `crm_plantillas_mensaje` se actualiza para incluir el `{enlace}` (borrador abajo, comentado en el SQL).
- Si ya contestó la encuesta, o venció, deja de salir en la lista.
- **Choque con una automatización existente (Chat 3):** «entregado → tarea de posventa a 7 días». Se propone **reemplazarla** por esta alerta a los 5 días, para que Sara no reciba dos recordatorios por el mismo pedido. Lo decide el Chat 3 / Orquestador CRM.

## 6. La encuesta (4 preguntas)

| # | Pregunta (borrador) | Tipo | Campo |
|---|---|---|---|
| 1 | ¿Qué tan feliz estás con tu pedido? | 1 a 5 estrellas, obligatoria | `felicidad` |
| 2 | ¿Cómo fue la atención que recibiste? | 1 a 5 estrellas, obligatoria | `atencion` |
| 3 | ¿Tu pedido llegó a tiempo? | Sí / Más o menos / No | `a_tiempo` |
| 4 | ¿Quieres contarnos algo más? | Texto, **opcional**, máx. 1.000 caracteres | `comentario` |

Sara solo dio el nombre de las preguntas; el **formato** de la 2 y la 3 es propuesta mía (ver decisiones). Se podría precargar si «llegó a tiempo» comparando `fecha_estimada_entrega` con la fecha de entrega, pero no se hace: la percepción de la clienta es el dato.

**Página (la construye la WEB; Web Chat 4 o 6 según el Orquestador WEB):** `encuesta.html?t=<token>`, sin iniciar sesión, con la misma estética de la web. Usa solo dos funciones:

- `encuesta_posventa_ver(p_token)` → `{estado: abierta | respondida | vencida | invalida, nombre, producto}`. Nada más: ni teléfono, ni correo, ni precio.
- `encuesta_posventa_responder(p_token, p_felicidad, p_atencion, p_a_tiempo, p_comentario)` → `{ok, estado, resena_web, resena_google}`. Valida el token, que no haya vencido ni respondido, y los rangos; guarda; marca respondida; si hay nota ≤ 3 o «No llegó a tiempo» crea `crm_tareas` «escribirle personalmente».

**Seguridad (el diseño sigue lo pedido por el Orquestador WEB):**
- Token de 64 caracteres (dos UUID v4 sin guiones), único, con vencimiento a 30 días y un solo uso.
- Las tablas (`crm_posventa`, `crm_posventa_respuestas`, `crm_posventa_config`) están cerradas: RLS solo `administrador`, sin permisos para `anon`/`PUBLIC`. `anon` no puede leer ninguna tabla ni la vista.
- **Excepción consciente** a «funciones nuevas nacen cerradas»: las dos funciones de la encuesta son `SECURITY DEFINER` y ejecutables por `anon`, porque la clienta no inicia sesión. Es lo que pidió el Orquestador WEB; el asesor de seguridad mostrará 2 avisos esperados.
- El token va en el enlace, así que se guarda tal cual (no con hash) para poder rearmar el enlace en Seguimiento; la tabla solo la lee la administradora. Si WEB prefiere hash, hay que cambiar la forma en que Seguimiento arma el enlace (por ejemplo, guardar el enlace cifrado). Lo dejo como pregunta.
- Datos mínimos: la respuesta no guarda nombre, teléfono ni correo; el nombre se ve solo uniendo con `crm_posventa` (solo administradora).

## 7. Invitación a calificar (a TODAS)

- Está en el **correo** (siempre) y en la **página de gracias** (siempre, para todas las respuestas). No depende de las notas.
- No se ofrece nada a cambio (ni descuento, ni puntos, ni bono). Reglas de Google contra reseñas con incentivo y contra filtrar a quién se le pide según su satisfacción.
- **Enlace de Google:** `https://g.page/r/Cae2iIji5j_XEAI/review` (lo dio Sara el 16-nov; queda en `crm_posventa_config.url_google`). La web ya lo usa en su correo de compra: por eso se propone pedir la reseña **solo** en la posventa y no dos veces.
- **Reseña en la web:** hoy apunta a `cuenta.html`, que exige iniciar sesión por enlace al correo. Pregunta a WEB: ¿la página de reseña puede aceptar el mismo token (sin sesión)? Si no, se deja `cuenta.html`.
- Reseñas en la web: solo nombre de pila o seudónimo (regla vigente).

## 8. Cómo no duplicar los correos de la web

| Correo existente | Cuándo sale | Propuesta |
|---|---|---|
| `fn_correo_compra_web` (`avisos_compra_web`) | Al pasar a «pagado»: confirmación, recibo, aviso de cuenta **y enlace de reseña en Google** | Se queda (es el recibo). **Pedir a WEB que quite el enlace de reseña de Google de ese correo:** pedir reseña antes de recibir el producto es prematuro y repetiría la petición 5 días después de la entrega. La posventa es el único lugar donde se pide. |
| `fn_correo_calificar` (`avisos_calificar`) | Disparador `trg_correo_calificar` sobre `pedidos_canal_venta` (no verifiqué en qué estado sale), para pedidos **no** web con cuenta | Reemplazarlo por la posventa (o excluir lo que ya tenga `crm_posventa`). Decide Web Chat 5. |
| `cuenta.html` «te falta calificar» | Dentro de la cuenta | Se queda; no es un correo. |

Dos cosas que vi leyendo `fn_correo_calificar` y que dejo anotadas, sin tocar:
- Usa `v_t.nombre`, pero `terceros` no tiene columna `nombre` (tiene `nombre_completo`/`primer_nombre`): parece que **falla para pedidos no web con cuenta**. Comprobar con Web Chat 5.
- Envía desde `ventas@…`, no `contacto@…` (ver punto 4).

## 9. Borradores de texto (voz de marca: los aprueba Web Chat 8)

Sin Navidad, santos ni Halloween. Firma como las plantillas actuales.

**Correo** — asunto: `💗 Gracias por tu pedido: ¿cómo te fue?`
> Hola Ana, esperamos que tu pedido ya esté contigo y que te haya encantado. Gracias por confiar en nosotras: cada pieza la teje una persona pensando en ti.
> ¿Nos cuentas cómo te fue? Son 4 preguntas rápidas (menos de un minuto). **[Contar mi experiencia]**
> Y si quieres, tu opinión también ayuda a otras personas a conocernos: Calificar en nuestra web · Calificar en Google.
> Con cariño, Lana Rosa Crochet.
> *Recibes este correo porque aceptaste recibir novedades. Dejar de recibirlos.*

**WhatsApp** (plantilla `posventa`)
> Hola {nombre} 🌸 Gracias por elegir Lana Rosa Crochet. Esperamos que tu {producto} ya esté contigo y te haya encantado.
> ¿Nos cuentas cómo te fue? Son 4 preguntas rápidas: {enlace}
> Si quieres, también puedes dejar tu opinión en Google y en nuestra web; nos ayuda muchísimo.
> Cordialmente, Lana Rosa Crochet

**Página de gracias:** «¡Gracias por contarnos! 💗 Tu opinión nos ayuda a tejer mejor.» + botones «Calificar en nuestra web» y «Calificar en Google» para todas.

Nota: la plantilla `posventa` es `es_comercial = true`: no se envía a quien no aceptó novedades mientras rija la regla prudente. El WhatsApp manual de Sara sigue esa misma regla.

## 10. Qué le toca a cada quien

| Pieza | Dueño | Notas |
|---|---|---|
| Tablas `crm_posventa*`, vista, funciones de programar/enviar, funciones de Seguimiento, plantilla | **ERP** (base donde viven, por el acuerdo del SQL del ERP) con diseño de CRM Chat 4 | Pasa por el Orquestador ERP con las reglas ya acordadas: un bloque `do $$ … $$` que termina en `raise exception` para el ensayo, `lock_timeout` corto, nada en sábados 9 a. m.–7 p. m. ni 12–13 dic; asesor de seguridad después. |
| Página `encuesta.html`, página de baja `baja.html`, enlace de reseña con token (opcional), quitar el enlace de Google de `fn_correo_compra_web`, decidir `fn_correo_calificar` | **WEB** (Web Chat 5 datos; Web Chat 4 o 6 página) | `baja.html`: falta una función pública de baja de novedades por token, que escribe en `cuentas_novedades` (tabla de la web) y por eso la hace WEB. Hoy `registrar_novedades` pide sesión. |
| Alerta «Posventa para enviar», botón WhatsApp, pantalla de resultados | **CRM Chat 5** (`index.html`, sección Seguimiento ~1625; plantillas ~2475) | Solo lee/llama funciones; no escribe tablas del ERP. |
| Textos | **Web Chat 8** | Punto 9. |
| Pregunta Ley 1581 | **Web Chat 6** / abogada | Punto 3. |

## 11. Cómo se enciende sin riesgo

1. Aplicar el SQL (nace **apagado**). Asesor de seguridad: 0 errores nuevos.
2. **Simulacro:** `select fn_crm_posventa_programar(true)` solo cuenta candidatas; no escribe nada.
3. WEB publica `encuesta.html` y `baja.html`; se prueba con un pedido de prueba y un token propio.
4. Sara aprueba textos (Web Chat 8) y el enlace de Google.
5. Abogada responde → se decide `requiere_novedades`.
6. Encender: poner `desde_entregados = hoy` y `activo = true`, y programar la tarea (`cron.schedule` comentado al final del SQL).
7. Primera semana: Sara revisa uno por uno. **Para apagar de inmediato:** `update crm_posventa_config set activo = false`.

## 12. Qué probé y qué no

Probado (Postgres 16 local, tablas de mentira, **no** el ERP real): 37 comprobaciones, 0 fallas.
- Apagado no programa ni envía; no se enciende sin fecha de corte.
- Candidatas: entra A (con novedades y 6 días) y E (dos pedidos, se toma el primero); quedan fuera B (sin novedades), C (2 días), D (sin correo ni teléfono), F (entregado hace 90 días).
- Un correo por pedido, con `Idempotency-Key`, enlace de baja, encuesta + web + Google; sin Navidad/santos/Halloween; segunda corrida no reenvía.
- `anon` no lee ninguna tabla ni la vista, no ejecuta programar ni las funciones de Seguimiento; sí ejecuta las dos de la encuesta.
- Encuesta: token falso/ya usado/vencido, estrellas fuera de rango rechazadas, notas bajas crean tarea y igual reciben la invitación a Google y web.
- Un `cajero` no puede ver la lista de Seguimiento; la administradora sí, y marcar como enviado la saca de la lista.

**No probado:** contra el ERP real (falta el ensayo con `begin … rollback`), el envío real por Resend (`net.http_post` y `vault` son de mentira), la página de la web, ni la pantalla de Seguimiento.

## 13. Decisiones que pide Sara

1. **Sobre el punto 3:** ¿esperamos a la abogada (A), mandamos solo WhatsApp manual a quien tú sepas que aceptó (B), o pedimos la casilla de novedades también por WhatsApp/mostrador (C)?
2. **Pregunta 2 y 3 de la encuesta:** ¿atención con 1–5 estrellas y «¿a tiempo?» con Sí / Más o menos / No? ¿O prefieres otras opciones?
3. **Cuando alguien marque algo por mejorar,** ¿te parece bien que te salga una tarea «escribirle personalmente»? (Es interno; no cambia lo que ve la clienta.)
4. **Un solo correo, sin recordatorio:** ¿de acuerdo, o prefieres un recordatorio a los 10 días a quien no contestó?
5. Reemplazar la tarea de posventa a 7 días del embudo por esta alerta a los 5.

## 14. Preguntas para otros Orquestadores

**WEB:** ¿quitan el enlace de Google del correo de compra? ¿qué pasa con `fn_correo_calificar` (y el posible fallo por `v_t.nombre`)? ¿quién y cuándo construye `encuesta.html` y `baja.html` (función pública de baja por token)? ¿la reseña en web puede aceptar el token? ¿remitente oficial `contacto@` o `ventas@`? ¿token en claro o con hash?
**ERP:** ¿van aquí las tablas `crm_posventa*` y los dos `fn_*` con `pg_cron`/`pg_net`? ¿registran también en `correos_enviados`? ¿hay un correo de «pedido entregado» propio del ERP que haya que integrar? ¿prefieren que la fecha de entrega se guarde en una columna en vez de leerla de `pedidos_canal_historial`?
