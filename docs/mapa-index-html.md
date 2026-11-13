# Mapa de index.html

Líneas aproximadas al 13-nov-2026. Si mueves algo, actualiza este mapa.

| Líneas | Qué hay |
|---|---|
| 1–17 | `<head>`, manifest, scripts de Supabase (`supabase-js@2.118.0`, versión exacta) y Chart.js |
| 18–~1060 | CSS |
| ~1060–1450 | CSS (resto), pantallas de configuración (URL y clave de Supabase), inicio de sesión, menú lateral |
| 1457 | Sección **Inicio** (`section-dashboard`) |
| 1520 | Sección **Pedidos** |
| 1574 | Sección **Clientes** |
| 1625 | Sección **Seguimiento** |
| 1630 | Sección **Embudo** (oportunidades) |
| 1642 | Sección **Indicadores CRM** (`section-crmind`) |
| 1651 | Sección **Calendario** (próximas entregas) |
| 1672 | Sección **Finanzas** |
| 1730 | Sección **Informes** (gráficas + exportar a Excel) |
| 1815 | Sección **Equipo** (usuarios, optimizar fotos) |
| 1840–2240 | Modales: pedido, registrar pago, usuario, cliente, ficha del cliente, oportunidad, detalle del pedido |
| 2241 | Barra inferior (celular) |
| 2269 | Inicio del `<script>` |
| 2270–2320 | Configuración de Supabase (`localStorage` sb_url / sb_key) |
| 2321–2413 | Arranque, inicio de sesión, perfil, `showApp` (permisos admin/tejedora) |
| 2414–2455 | Navegación: objeto `sections` y `showSection` |
| 2456–2880 | CRM: segmentos, ficha del cliente, seguimiento, embudo, Indicadores CRM (`loadCrmIndicadores` ~2834) |
| 2881–2930 | Utilidades: `formatCOP`, `formatDate`, `showToast`, modales |
| 2931–2987 | Inicio (dashboard) |
| 2988–3337 | Pedidos, modal de pedido, compresión y subida de imágenes |
| 3338–3493 | Clientes |
| 3494–3514 | Tejedoras |
| 3515–3548 | Calendario |
| 3549–3628 | Finanzas |
| 3629–3719 | Informes (estadísticas: ventas por mes, valor promedio, clientes que compraron) |
| 3720–~3900 | Exportar a Excel (clientes, ventas mensuales, pedidos con datos de envío, saldos) |
| ~3900–4046 | Equipo, optimizar fotos, `playBeep` |
| 4047–fin | Detalle del pedido, pagos, nota de tejedora |

Stock, Producción y Envíos ya no están en el CRM: viven en el ERP.
