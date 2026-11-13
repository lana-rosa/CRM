# Tema: Indicadores, informes e interfaz (CRM - Chat 5)

## Alcance
Inicio (dashboard), Indicadores CRM (`fn_crm_indicadores`), Informes y exportar a Excel, Calendario, Finanzas, menú y uso en celular, pantalla de configuración, logo.

## Situación al 13-nov-2026
- Quedan secciones sobrantes: Stock, Producción, Envíos (`section-stock`, `section-produccion`, `section-envios`), el contador `actualizarBadgeStock`, y en Informes/Excel lecturas de `stock_items` y `produccion_progreso` (vacías porque eso vive en el ERP).
- Cada dispositivo debe escribir a mano la URL y la clave de Supabase la primera vez (`localStorage`). La clave publicable puede ir fija en el código.
- `supabase-js@2` sin versión exacta: fijarla.

## Indicadores objetivo
Valor de vida del cliente (CLV), tasa de recompra, cohortes por mes de primera compra, conversión por canal y por casa, motivos de pérdida, tiempo de respuesta.

## Qué falta
- [ ] Limpieza de sobrantes (Fase 0).
- [ ] Fijar versión de supabase-js y quitar la pantalla de configuración.
- [ ] Indicadores nuevos después de la unificación.
