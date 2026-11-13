# CRM de Lana Rosa — guía para los chats

Lana Rosa Crochet (amigurumis personalizados, Manizales/Villamaría, Colombia). Casas: **Crochet**, **Mercería**, **Academy**.
La dueña es **Sara**: no es programadora. Responde siempre en español, claro y sin tecnicismos.

## Qué es este repositorio
- `index.html`: toda la app del CRM (HTML + CSS + JS en un solo archivo, ~4.900 líneas). Se publica con GitHub Pages desde `main`.
- **No leas `index.html` completo.** Usa `docs/mapa-index-html.md` y lee solo el tramo que necesitas.
- Librerías: `@supabase/supabase-js@2` y `chart.js@4.4.0` desde jsDelivr.

## Bases de datos (Supabase)
| Proyecto | id | Qué guarda |
|---|---|---|
| **Lana Rosa CRM** | `wcqdkccvtywiutzknskr` | Tablas del CRM: `clientes`, `clientes_casas`, `pedidos`, `pagos`, `oportunidades`, `tareas`, `interacciones`, `fechas_especiales`, `plantillas_mensaje`, `profiles`, vista `v_clientes_crm`, funciones `fn_crm_alertas`, `fn_crm_indicadores`. Casi vacío (2 clientes, 1 pedido). |
| **Lana Rosa ERP + SO** | `ngjoognzvehwjtpqwrqe` | El negocio real: `terceros` (clientes), `pedidos_canal_venta`, `pedidos_web`, `ventas_pos`, `ventas_academia`, `oportunidades_venta`, `carritos_abandonados`, puntos, reseñas… |

**El ERP es de otro repositorio (`lana-rosa/ERP`) y tiene su propio Orquestador.** No cambies tablas, funciones ni permisos de la base del ERP sin que el Orquestador CRM lo haya acordado con el Orquestador ERP. Leer (SELECT) sí puedes.

Decisiones vigentes:
- Producción, Envíos y la creación de pedidos nuevos **ya viven en el ERP**. El CRM no los vuelve a crear.
- Medios de pago del CRM: sin Nequi; el predeterminado es Efectivo.
- `terceros` del ERP exige `acepta_tratamiento_datos` (Ley 1581 de 2012, Habeas Data): un prospecto sin autorización no se puede guardar ahí.

## Forma de trabajo (igual que en el ERP)
- Hay un **Orquestador CRM** ("Chat 0. Orquestador CRM") y chats por tema ("CRM - Chat N. …"). Las tareas que manda el Orquestador se ejecutan; lo delicado se consulta con Sara antes de publicar.
- Trabaja solo en tu tema. Si ves algo de otro tema, anótalo en `docs/PENDIENTES.md` bajo "Para otro chat" y sigue.
- Cada cambio: rama → PR → squash merge a `main`.
- Antes de decir "listo", pruébalo (Playwright sobre `index.html`, o SQL con `begin … rollback`) y di qué probaste.
- Cambios de base de datos: con migración (`apply_migration`), revisando antes la estructura y después los avisos de seguridad (`get_advisors`).
- Al terminar: actualiza tu archivo de `docs/temas/` (qué se decidió, por qué, qué objetos de Supabase usa, qué falta), marca en `docs/PENDIENTES.md` lo cerrado y corrige `docs/mapa-index-html.md` si lo que tocaste cambió de lugar.
- Pregúntale a Sara solo si la decisión es de ella (negocio, plata, datos personales). Lo técnico decídelo tú.
