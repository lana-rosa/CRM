# Mapa de index.html

Líneas aproximadas al 13-nov-2026. Si mueves algo, actualiza este mapa.

| Líneas | Qué hay |
|---|---|
| 1–17 | `<head>`, manifest, scripts de Supabase (`supabase-js@2.118.0`, versión exacta) y Chart.js |
| 18–~1300 | CSS |
| 1311 | Pantalla de **ingreso** (`auth-screen`: correo, contraseña con ojo), luego menú lateral |
| 1419 | Sección **Inicio** (`section-dashboard`) |
| 1482 | Sección **Pedidos** |
| 1536 | Sección **Clientes** |
| 1587 | Sección **Seguimiento** |
| 1592 | Sección **Embudo** (oportunidades) |
| 1604 | Sección **Indicadores CRM** (`section-crmind`) |
| 1613 | Sección **Calendario** (próximas entregas) |
| 1634 | Sección **Finanzas** |
| 1692 | Sección **Informes** (gráficas + exportar a Excel) |
| 1777 | Sección **Equipo** (usuarios, optimizar fotos) |
| 1802–2202 | Modales: pedido, registrar pago, usuario, cliente, ficha del cliente, oportunidad, detalle del pedido |
| 2203 | Barra inferior (celular) |
| 2231 | Inicio del `<script>` |
| 2232–2296 | `CONEXION` (URL y clave pública fijas, un solo lugar), `mostrarIngreso`, correo recordado |
| 2297–2400 | Arranque, inicio de sesión, perfil, `showApp` (permisos admin/tejedora) |
| 2401–2440 | Navegación: objeto `sections` y `showSection` |
| 2441–2829 | CRM: segmentos, ficha del cliente, seguimiento, embudo, Indicadores CRM (`loadCrmIndicadores` ~2783) |
| 2830–2879 | Utilidades: `formatCOP`, `formatDate`, `showToast`, modales |
| 2880–2936 | Inicio (dashboard) |
| 2937–3284 | Pedidos, modal de pedido, compresión y subida de imágenes |
| 3285–3440 | Clientes |
| 3441–3461 | Tejedoras |
| 3462–3495 | Calendario |
| 3496–3575 | Finanzas |
| 3576–3666 | Informes (estadísticas: ventas por mes, valor promedio, clientes que compraron) |
| 3667–~3850 | Exportar a Excel (clientes, ventas mensuales, pedidos con datos de envío, saldos) |
| ~3850–3991 | Equipo, optimizar fotos, `playBeep` |
| 3992–fin | Detalle del pedido, pagos, nota de tejedora |

Stock, Producción y Envíos ya no están en el CRM: viven en el ERP.
