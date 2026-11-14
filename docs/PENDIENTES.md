# Pendientes del CRM

Cada chat marca aquí lo que cierra y anota lo que ve de otros temas.

## Decisiones de Sara
- [x] Unificar el CRM en la base del ERP: **opción A** (13-nov).
- [x] Borrado del Vault del CRM el secreto `os_service_role_key` (13-nov, lo confirmó Sara).
- [ ] Activar en Supabase (proyecto Lana Rosa CRM) → Authentication → protección de contraseñas filtradas.

## Fase 1: llevar el CRM a la base del ERP (Chat 1)
- [x] Diseño: SQL y explicación en `docs/fase1/` (13-nov). Probado en Postgres local con tablas de mentira: 31 comprobaciones, 0 fallas.
- [x] Revisión del Orquestador ERP (confirmó los 4 detalles de `docs/fase1/LEEME.md` 1b y que la parte web quede fuera) y OK de Sara a la Fase 1 (13-nov). Falta el OK del Orquestador WEB / Web Chat 5 si lo requiere.
- [x] **Fase 1 aplicada en el ERP el 14-nov** (migración `20261114004646 fase1_crm_tablas_y_funciones`; `propuesta.sql` de `f25ed54`, sin web). Prueba previa con rollback 31/31; asesor de seguridad 392→396 hallazgos, 0 ERROR (los 4 nuevos son las 4 funciones de lectura ejecutables por `authenticated`, esperado); rendimiento 560→571 (11 `unused_index` INFO en tablas vacías); prueba sobre lo aplicado 31/31. Detalle en `docs/fase1/LEEME.md`, sección 9.
- [x] Reglas que se siguieron en el paso 1 (OK técnico del ERP, 13-nov): un solo bloque `do $$ … $$` que termina en `raise exception`, `lock_timeout` corto, horarios prohibidos (sábados 9 a. m.–7 p. m. y 12–13 de diciembre), resultado al ERP antes de aplicar. Siguen valiendo para cualquier cambio futuro en el ERP.
- [ ] Decisión de Sara: los 3 clientes sin vínculo y el corte propuesto (11-ene-2027). Ver `docs/fase1/LEEME.md`.
- [ ] Preguntas a la abogada (Ley 1581): `docs/fase1/LEEME.md`, sección 6.
- [ ] **Llenar `tercero_id` en el ERP** (lo hace el ERP): 16 de los 26 `pedidos_canal_venta` ligados al CRM no lo tienen; el historial por cliente sale incompleto. Chat 1 puede preparar la propuesta de `UPDATE` si el Orquestador ERP la pide (`docs/fase1/LEEME.md`, sección 9).
- [ ] Cambiar las pantallas del CRM para usar `fn_crm_clientes_resumen`, `fn_crm_historial_compras`, `fn_crm_embudo` y `fn_crm_casas_cliente` (temas de los otros chats; el CRM actual sigue siendo el oficial hasta el corte propuesto del 11-ene-2027).

## Fase 0: seguridad y limpieza (no depende de la decisión)
- [x] Orquestador: cerrar funciones expuestas y apagar la copia de stock al ERP (13-nov).
- [x] Chat 1: `search_path` fijado en las 6 funciones y RLS por rol (13-nov, migración `fase0_search_path_y_rls_por_rol`). Probado con rollback.
- [ ] Para otro chat (Chat 5, pantallas): la tejedora ya no puede leer `clientes`; en su lista de pedidos el nombre del cliente sale vacío. Revisar que la pantalla lo muestre bien (ej. «—») y que no dé error.
- [x] Chat 5: quitar Stock, Producción y Envíos sobrantes; arreglar Informes y Excel; fijar versión de supabase-js (13-nov, `supabase-js@2.118.0`).
- [x] Chat 3: quitar código muerto en `crearPedidoDesdeOportunidad` (13-nov).

## Mudanza del ERP a Cloudflare Pages (aviso del Orquestador ERP)
- [ ] Chat 5: cuando el Orquestador CRM confirme la dirección nueva, cambiar el enlace `https://lana-rosa.github.io/ERP/` en `avisarPedidoEnERP` (index.html ~3446). Es el único enlace fijo al ERP.

## Fases siguientes (opción A decidida)
- [ ] Fase 1 (Chat 1): un solo cliente, enlazado con `terceros`.
- [ ] Fase 2 (Chat 2): ficha completa con todo el historial.
- [ ] Fase 3 (Chat 3): un solo embudo y automatizaciones desde la web y el ERP.
- [ ] Fase 4 (Chat 4): flujos de fidelización.
- [ ] Fase 5 (Chat 5): indicadores nuevos.
- [ ] Fase 6 (opcional): bandeja de WhatsApp/Instagram con la API de Meta.

## Para otro chat
(Anota aquí: fecha · chat que lo vio · para qué chat · qué es.)

## Para coordinar (lo hace solo el Orquestador CRM)
### Con el Orquestador ERP
- **`tercero_id` faltante (14-nov, Chat 1, lectura):** solo 18 de 36 `pedidos_canal_venta` lo tienen (16 de los 26 ligados al CRM no), 1 de 8 `ventas_pos` y 0 de 1 `ventas_academia`. Sin eso, `fn_crm_historial_compras`, `fn_crm_clientes_resumen` y `fn_crm_casas_cliente` muestran historial incompleto. Hay que llenarlo (dueño: ERP Chat 2 Pedidos); Chat 1 prepara la propuesta si se la piden.
- Fase 1 propuesta lista para revisión: `docs/fase1/propuesta.sql` + `LEEME.md` (13-nov). No se aplicó nada.
- **Revisar `oportunidades_venta`:** su política "Acceso total via service role" está puesta para `authenticated` con `true` (no para `service_role`). Por lectura, cualquier usuario con sesión podría ver/modificar todas las oportunidades. No probado.
- `anon` tiene permisos de tabla (leer/insertar) sobre `terceros`, `pedidos_canal_*`, `pedidos_web`, `ventas_*`, `oportunidades_venta`; hoy los frena la RLS.
- 10 de los 20 `terceros` vinculados al CRM tienen `acepta_tratamiento_datos = true` sin `medio_autorizacion` ni `version_politica`.
- Decidir: ¿se importan al ERP los 38 pagos del CRM (desglose anticipo/saldo)? Propuesta de Chat 1: no (toca caja y contabilidad).
- Cualquier cambio en la base del ERP (`terceros`, `oportunidades_venta`, vistas nuevas para el CRM).
- Embudo único: `oportunidades` (CRM) vs `oportunidades_venta` (ERP). Propuesta de etapas, vista `v_crm_embudo` y tabla `crm_oportunidades_detalle` en `docs/temas/embudo-seguimiento.md`; falta confirmar con ERP si `pedidos_canal_venta.referencia_crm_id` puede apuntar a `oportunidades_venta`.
### Con el Orquestador WEB
- `fn_crm_casas_cliente` (Fase 1): la función aplicada **no lee nada de la web** (Web Chat 5, 13-nov). La versión con web (la única que reconoce la casa **Agenda**) está lista y probada en `docs/fase1/propuesta-web-pendiente.sql`; se activa solo cuando la abogada apruebe esa finalidad (Ley 1581) y el Orquestador ERP dé el go.
- Carritos abandonados y formulario de personalizados → oportunidades del CRM.
- Reseñas, cuentas web y puntos en la ficha del cliente.
- Textos de los mensajes de fidelización (voz de marca, Web Chat 8).
