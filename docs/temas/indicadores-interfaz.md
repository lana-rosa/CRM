# Tema: Indicadores, informes e interfaz (CRM - Chat 5)

## Alcance
Inicio (dashboard), Indicadores CRM (`fn_crm_indicadores`), Informes y exportar a Excel, Calendario, Finanzas, menú y uso en celular, pantalla de configuración, logo.

## Situación al 13-nov-2026
- **Fase 0 hecha:** se quitaron Stock, Producción y Envíos (secciones, menú, contador de stock, modales de stock, estilos de envíos, botón "Nuevo para stock"). Producción, Envíos y Stock viven en el ERP.
- Informes: se quitaron las lecturas de `stock_items` y `produccion_progreso`. Las tarjetas "Tiempo promedio por pieza" y "Piezas en stock" y la gráfica de tiempos se reemplazaron por "Valor promedio por pedido" y "Clientes que compraron (12 meses)". Excel: se quitaron las descargas de Producción, Envíos y Stock; "Todos los pedidos" ahora trae también tipo de entrega, dirección, transportadora, guía y estado del envío (columnas que ya están en `pedidos`). "Optimizar fotos" ya no lee `stock_items`.
- Los pedidos marcados `es_stock` (6 en la base) siguen apareciendo en la lista de Pedidos pero sin botón de editar (ese formulario se quitó); pendiente decidir con Chat de Pedidos si se archivan.
- `supabase-js` fijado en `2.118.0` (última 2.x publicada hace más de 2 semanas; la 2.119.0 es del 4-nov).
- **No se tocó** (a propósito): la pantalla de URL y clave de Supabase (cambia con la Fase 1) ni el enlace al ERP de `avisarPedidoEnERP` (lo cambia Sara tras la mudanza del ERP).
- Probado con Playwright (computador 1366px y celular 390px, base simulada): menú, barra inferior, Pedidos, Informes, las 4 descargas de Excel, todas las pantallas sin errores nuevos; el CRM ya no consulta `stock_items` ni `produccion_progreso`.

## Indicadores objetivo
Valor de vida del cliente (CLV), tasa de recompra, cohortes por mes de primera compra, conversión por canal y por casa, motivos de pérdida, tiempo de respuesta.

## Qué falta
- [x] Limpieza de sobrantes y versión fija de supabase-js (Fase 0).
- [ ] Quitar la pantalla de configuración (con la Fase 1, cuando el CRM cambie de base).
- [ ] Tablas `stock_items` y `produccion_progreso` del CRM: ya nadie las lee; borrarlas es decisión del Orquestador/Chat de base de datos.
- [ ] Indicadores nuevos después de la unificación.
