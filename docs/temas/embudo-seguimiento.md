# Tema: Embudo de ventas y seguimiento (CRM - Chat 3)

## Alcance
Oportunidades (etapas: consulta → cotización → anticipo → producción → listo → entregado → posventa / perdida), tareas, alertas de Seguimiento (`fn_crm_alertas`), plantillas de WhatsApp.

## Situación al 13-nov-2026
- Hay **dos embudos**: `oportunidades` en el CRM (0 filas) y `oportunidades_venta` en el ERP (2 filas). Hay que dejar uno solo (coordinar con el Orquestador ERP).
- "Crear pedido desde oportunidad" ahora solo avisa que el pedido se crea en el ERP; `crearPedidoDesdeOportunidad` tiene código muerto después del `return`.
- Automatizaciones actuales: al pasar a Cotización crea tarea a 3 días; al pasar a Entregado crea tarea de posventa a 7 días.

## Ideas (de CRM líderes como Kommo/Pipedrive)
- Carrito abandonado de la web → oportunidad automática.
- Formulario de personalizados de la web → oportunidad automática.
- Que la etapa avance sola cuando el ERP registra anticipo, producción, envío y entrega.

## Qué falta
- [ ] Embudo único.
- [ ] Limpiar código muerto.
- [ ] Automatizaciones desde la web y el ERP.
