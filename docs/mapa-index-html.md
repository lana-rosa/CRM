# Mapa de index.html

Líneas aproximadas al 13-nov-2026. Si mueves algo, actualiza este mapa.

| Líneas | Qué hay |
|---|---|
| 1–17 | `<head>`, manifest, scripts de Supabase y Chart.js |
| 18–1433 | CSS |
| ~1434–1578 | Pantallas de configuración (URL y clave de Supabase), inicio de sesión, menú lateral |
| 1579 | Sección **Inicio** (`section-dashboard`) |
| 1642 | Sección **Pedidos** |
| 1697 | Sección **Clientes** |
| 1748 | Sección **Seguimiento** |
| 1753 | Sección **Embudo** (oportunidades) |
| 1765 | Sección **Indicadores CRM** (`section-crmind`) |
| 1774 | Sección **Calendario** (próximas entregas) |
| 1795 | Sección **Finanzas** |
| 1853 | Sección **Informes** (gráficas + exportar a Excel) |
| 1970 | Sección **Equipo** (usuarios, optimizar fotos) |
| 1992–2045 | Secciones **Envíos**, **Stock**, **Producción**: sobrantes, ya viven en el ERP |
| 2046–2560 | Modales: pedido, pedido de stock, vender stock, registrar pago, usuario, cliente, ficha del cliente, oportunidad, detalle del pedido |
| 2565–2592 | Barra inferior (celular) |
| 2594 | Inicio del `<script>` |
| 2595–2645 | Configuración de Supabase (`localStorage` sb_url / sb_key) |
| 2646–2748 | Arranque, inicio de sesión, perfil, `showApp` (permisos admin/tejedora) |
| 2749–2792 | Navegación: objeto `sections` y `showSection` |
| 2793–2836 | CRM: segmentos RFM, utilidades, plantillas de WhatsApp (`contactarWhatsApp`) |
| 2837–2976 | Ficha completa del cliente (`abrirFicha`, `renderFicha`, interacciones, fechas, tareas) |
| 2977–3032 | Seguimiento: alertas (`fn_crm_alertas`) y tareas |
| 3033–3170 | Embudo: etapas, tablero, oportunidad → pedido (hoy solo avisa que va al ERP) |
| 3171–3213 | Indicadores CRM (`fn_crm_indicadores`) |
| 3218–3267 | Utilidades: `formatCOP`, `formatDate`, `showToast`, modales |
| 3268–3324 | Inicio (dashboard) |
| 3325–3602 | Pedidos y modal de pedido |
| 3603–3710 | Compresión y subida de imágenes |
| 3711–3814 | Pedidos de stock (sobrante) |
| 3815–3970 | Clientes (lista, crear, editar, borrar) |
| 3971–3994 | Tejedoras |
| 3995–4028 | Calendario |
| 4029–4113 | Finanzas |
| 4114–4257 | Informes (lee `produccion_progreso` y `stock_items`, sobrantes) |
| 4258–4368 | Catálogo de stock (sobrante) |
| 4369–4557 | Exportar a Excel |
| 4558–4736 | Equipo y optimizar fotos |
| 4754–4930 | Detalle del pedido, pagos, nota de tejedora |
