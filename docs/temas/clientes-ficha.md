# Tema: Clientes y ficha completa (CRM - Chat 2)

## Alcance
Lista de clientes, crear/editar, clientes por casa (Crochet, Mercería, Academy), ficha del cliente (`abrirFicha`/`renderFicha`), interacciones, fechas especiales, referidos, segmentos RFM, calidad de datos.

## Situación al 13-nov-2026
- La ficha y los segmentos leen la base del CRM (`clientes`, `v_clientes_crm`), que tiene 23 clientes (el ERP tiene 49 en `terceros`).
- Depende de la decisión de datos (ver `datos-integracion-erp.md`). Cuando se unifique, la ficha debe mostrar todo el historial: pedidos por redes, web, tienda (POS), Academy, puntos, reseñas, carritos abandonados y cuenta web.

## Qué falta
- [ ] Esperar la unificación del Chat 1 (opción A decidida el 13-nov).
- [ ] Ficha con historial unificado y línea de tiempo.
- [ ] Detección de clientes duplicados (mismo teléfono o correo).
