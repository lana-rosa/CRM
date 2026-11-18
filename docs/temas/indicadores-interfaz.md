# Tema: Indicadores, informes e interfaz (CRM - Chat 5)

## Alcance
Inicio (dashboard), Indicadores CRM (`fn_crm_indicadores`), Informes y exportar a Excel, Calendario, Finanzas, menú y uso en celular, pantalla de ingreso, logo.

## Situación al 13-nov-2026
- **Fase 0 hecha:** se quitaron Stock, Producción y Envíos (secciones, menú, contador de stock, modales de stock, estilos de envíos, botón "Nuevo para stock"). Producción, Envíos y Stock viven en el ERP.
- Informes: se quitaron las lecturas de `stock_items` y `produccion_progreso`. Las tarjetas "Tiempo promedio por pieza" y "Piezas en stock" y la gráfica de tiempos se reemplazaron por "Valor promedio por pedido" y "Clientes que compraron (12 meses)". Excel: se quitaron las descargas de Producción, Envíos y Stock; "Todos los pedidos" ahora trae también tipo de entrega, dirección, transportadora, guía y estado del envío (columnas que ya están en `pedidos`). "Optimizar fotos" ya no lee `stock_items`.
- Los 6 pedidos `es_stock` (LR-2026-008, 009, 010, 011, 012 y 016) se **archivaron** el 13-nov: migración `pedidos_archivado` agrega `pedidos.archivado boolean default false` y los marca `true`. Inicio (conteos y recientes) y la lista de Pedidos ya filtran `archivado = false`; no se borraron. Calendario, Finanzas, Informes y Excel ya excluían `es_stock`.
- `supabase-js` fijado en `2.118.0` (última 2.x publicada hace más de 2 semanas; la 2.119.0 es del 4-nov).
- **No se tocó** (a propósito): el enlace al ERP de `avisarPedidoEnERP` (lo cambia Sara tras la mudanza del ERP).
- **Ingreso sin configuración (17-nov, opción A, decidida por Sara):** pedido de Jennifer vía Orquestador General. Se borró la pantalla "Configuración inicial" (pedía URL y clave de Supabase). La URL y la clave pública (anon) de la **base del CRM** quedan fijas en `CONEXION` (`index.html`, ~línea 2248): es el único lugar a cambiar cuando las plataformas pasen a una dirección con un solo ingreso. La pantalla de ingreso: correo + contraseña con ojo; recuerda **solo el correo** en el aparato (`localStorage` `lr_crm_correo`; la próxima vez enfoca la contraseña); se limpian `sb_url`/`sb_key` viejos. Sin sesión no se pide ningún dato (verificado: el rol anónimo no tiene permiso de lectura en ninguna tabla). Solo entra quien tiene fila en `profiles` con rol `admin` o `tejedora`; sin perfil se cierra la sesión con aviso.
- **Pantalla completa en computador y emojis que no se ven (18-nov, pedido de Jennifer vía Orquestador General; preparado, pendiente de que Sara diga "sí"):** el contenido quedaba en una columna angosta (414–946 px) porque `.main-content` no tenía `flex: 1`; ahora ocupa todo el ancho que deja el menú lateral fijo (1020 px en pantalla de 1280, 1660 px en 1920) y las tarjetas se reacomodan solas (6 por fila en 1920). Celular (390 px) sin cambios y sin desplazamiento horizontal. Emojis de Unicode 11–12 que Windows antiguo no dibuja (cuadrito vacío) cambiados por otros antiguos: 🧵 (En proceso / En producción) → 🔄 / 🛠️; casas 🧸 Crochet → 🎀 y 🧶 Mercería → ✂️; 🧾 → 🏷️ y 💳; 🧭 → 🔎; 🧹 → ✨; 🧶 de "sin pedidos" → 🐑; 🟣 Anticipo → 🔶. Ya no queda ningún emoji posterior a Emoji 5 en `index.html`; al agregar íconos nuevos, usar solo emojis antiguos.
- **Opción B (pendiente, con la Fase 1):** apuntar `CONEXION` a la base del ERP y usar los roles del ERP; necesita que el Orquestador General confirme permisos y que los datos del CRM ya estén allá.
- Probado con Playwright (computador 1366px y celular 390px, base simulada): menú, barra inferior, Pedidos, Informes, las 4 descargas de Excel, todas las pantallas sin errores nuevos; el CRM ya no consulta `stock_items` ni `produccion_progreso`.

## Indicadores objetivo
Valor de vida del cliente (CLV), tasa de recompra, cohortes por mes de primera compra, conversión por canal y por casa, motivos de pérdida, tiempo de respuesta.

## Qué falta
- [x] Limpieza de sobrantes y versión fija de supabase-js (Fase 0).
- [x] Quitar la pantalla de configuración (opción A, 17-nov).
- [ ] Opción B: apuntar `CONEXION` a la base del ERP con los roles del ERP (con la Fase 1).
- [ ] Tablas `stock_items` y `produccion_progreso` del CRM: ya nadie las lee; borrarlas es decisión del Orquestador/Chat de base de datos.
- [ ] Indicadores nuevos después de la unificación.
