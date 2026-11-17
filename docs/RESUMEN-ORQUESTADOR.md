# Resumen del Orquestador CRM (17-nov-2026) — entregado al Orquestador General

**Chats del CRM** (repo `lana-rosa/CRM`; reglas en `CLAUDE.md`, pendientes en `docs/PENDIENTES.md`):
- **Chat 1. Datos e integración ERP** — Fase 0 (seguridad) cerrada; **Fase 1 aplicada en el ERP el 14-nov** (tablas `crm_*`, funciones `fn_crm_*`, 31/31 pruebas, 0 errores del asesor). Lista sin aplicar: `docs/fase1/propuesta-vinculo-pedidos.sql` (llenar `tercero_id` en 16 pedidos).
- **Chat 5. Indicadores e interfaz** — limpieza hecha (sin Stock/Producción/Envíos, supabase-js fijo). Pendiente: nombre de cliente vacío para tejedoras; enlace al ERP tras la mudanza.
- **Chat 3. Embudo y seguimiento** — propuesta de embudo único sobre `oportunidades_venta` + `crm_oportunidades_detalle` en `docs/temas/embudo-seguimiento.md`.
- **Chat 4. Fidelización** — diseño de posventa hecho (`docs/fidelizacion/posventa.md` y `.sql`, 37 pruebas locales); falta probar contra ERP, Resend, web y Seguimiento, y revisión de la Web antes de construir.
- **Chat 2. Clientes y ficha** — sin abrir; espera pasar las pantallas a la base del ERP.

**Decisiones vigentes de la dueña:**
- Opción A: el CRM vive en la base del ERP; solo lee tablas del ERP; escribe en `terceros` solo por RPC acordada.
- No se importan los pagos del CRM. Las 7 ventas POS sin cliente se quedan así. Tejedoras con rol admin/cajero: a propósito.
- Casas: Crochet, Mercería (ítem `merceria` del centro 01), Academy, **Agenda** (casa propia; solo con datos web, apagada hasta la abogada).
- Posventa: WhatsApp con un clic + correo, **5 días después de la entrega**, encuesta de 4 preguntas (felicidad 1-5 ⭐, atención, ¿llegó a tiempo?, ¿algo que podamos mejorar?), reseña en Google a TODAS con **https://g.page/r/Cae2iIji5j_XEAI/review** (la web ya lo usa). Hasta que responda la abogada: solo a quien aceptó novedades.
- Perfil de Google: textos finales revisados por Web Chat 6 (categoría principal Tienda de regalos); horario solo desde la apertura.

**Pendientes de la dueña:**
- Go a `propuesta-vinculo-pedidos.sql`; decidir PED-2026-00553 y 00562; los 3 clientes sin vínculo; fecha de corte (propuesta 11-ene-2027).
- Copiar los textos en el Perfil de Google y corregir el pin del mapa.
- Activar la protección de contraseñas filtradas en Supabase (proyecto CRM).
- Abogada (Ley 1581): datos web en el CRM, prospectos sin autorización, posventa servicio vs. comercial (punto 17), 10 terceros sin constancia.

**Riesgos para la apertura del 13-dic:**
- Nada de cambios en la base del ERP sábados 9 a. m.–7 p. m. ni el 12–13 dic.
- El CRM viejo sigue siendo el oficial hasta el corte; no se borra nada de su base sin la dueña.
- Historial de clientes incompleto hasta llenar `tercero_id`.
