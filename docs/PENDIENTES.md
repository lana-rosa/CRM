# Pendientes del CRM

Cada chat marca aquí lo que cierra y anota lo que ve de otros temas.

## Decisiones de Sara
- [ ] ¿Unificamos el CRM en la base del ERP (opción A) o mantenemos dos bases (opción B)? Ver `docs/temas/datos-integracion-erp.md`.
- [ ] Activar en Supabase (proyecto Lana Rosa CRM) → Authentication → protección de contraseñas filtradas.

## Fase 0: seguridad y limpieza (no depende de la decisión)
- [ ] Chat 1: cerrar funciones SECURITY DEFINER expuestas, fijar `search_path`, revisar RLS por rol (admin/tejedora).
- [ ] Chat 5: quitar Stock, Producción y Envíos sobrantes; arreglar Informes y Excel; fijar versión de supabase-js.
- [ ] Chat 3: quitar código muerto en `crearPedidoDesdeOportunidad`.

## Fases siguientes (después de la decisión)
- [ ] Fase 1 (Chat 1): un solo cliente, enlazado con `terceros`.
- [ ] Fase 2 (Chat 2): ficha completa con todo el historial.
- [ ] Fase 3 (Chat 3): un solo embudo y automatizaciones desde la web y el ERP.
- [ ] Fase 4 (Chat 4): flujos de fidelización.
- [ ] Fase 5 (Chat 5): indicadores nuevos.
- [ ] Fase 6 (opcional): bandeja de WhatsApp/Instagram con la API de Meta.

## Para otro chat
(Anota aquí: fecha · chat que lo vio · para qué chat · qué es.)

## Para coordinar con el Orquestador ERP
- Cualquier cambio en la base del ERP (`terceros`, `oportunidades_venta`, vistas nuevas para el CRM).
