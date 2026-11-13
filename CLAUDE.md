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

**El ERP (`lana-rosa/ERP`) y la Web tienen cada uno su propio Orquestador.** Si un cambio toca algo de sus funciones (tablas, funciones, permisos o pantallas del ERP; tienda web, carritos, cuentas web, reseñas, formulario de personalizados, Rosina, textos de marca), **no lo hagas tú**: anótalo en `docs/PENDIENTES.md` bajo "Para coordinar" y avísale al Orquestador CRM, que es el único que habla con ellos. Leer (SELECT) sí puedes.

| Orquestador | Sesión |
|---|---|
| Chat 0. Orquestador CRM | `session_01H2X8gbEkPKtZwG74rfVzkM` |
| Chat 0. Orquestador ERP | `session_01H2X8gbHYKGsVHH1dKbt8dt` |
| Chat 0. Orquestador WEB | `session_01H2X8gaahfucSR9WM7L1zXM` |

Decisiones vigentes:
- Producción, Envíos y la creación de pedidos nuevos **ya viven en el ERP**. El CRM no los vuelve a crear.
- Medios de pago del CRM: sin Nequi; el predeterminado es Efectivo.
- `terceros` del ERP exige `acepta_tratamiento_datos` (Ley 1581 de 2012, Habeas Data): un prospecto sin autorización no se puede guardar ahí.

## Reglas acordadas con la Web (13-nov-2026)
- **Ley 1581:** los datos de la web (cuentas, carritos, reseñas, Personaliza) no se usan en el CRM en producción hasta que la abogada apruebe esa finalidad en la política de datos.
- **Mensajes comerciales** (bienvenida, posventa, recompra, cumpleaños, reactivación) solo a quien marcó la casilla opcional de novedades (`cuentas_novedades` / `registrar_novedades`), siempre con enlace de baja. Recordatorio de carrito solo con autorización. La autorización del bono **no** vale como autorización de publicidad.
- **Reseñas:** solo nombre de pila o seudónimo.
- **Cumpleaños:** la web no pide fecha de nacimiento; pedirla es un dato nuevo con finalidad propia (consultar).
- **Funciones nuevas nacen cerradas** (sin `anon`/`PUBLIC`), lectura con guarda de rol, asesor de seguridad después de cada migración.
- **Marca:** nada de Navidad, santos ni Halloween en ningún mensaje.
- Campos de dirección (E22) y consentimientos del bono (E28) están cambiando: consultar antes de usarlos.
- Dueños en la Web: datos y Supabase de la web = Web Chat 5; Personaliza = Web Chat 4; textos de marca = Web Chat 8; textos legales = Web Chat 6.

## Forma de trabajo (igual que en el ERP)
- Hay un **Orquestador CRM** ("Chat 0. Orquestador CRM") y chats por tema ("CRM - Chat N. …"). Las tareas que manda el Orquestador se ejecutan; lo delicado se consulta con Sara antes de publicar.
- Trabaja solo en tu tema. Si ves algo de otro tema, anótalo en `docs/PENDIENTES.md` bajo "Para otro chat" y sigue.
- Cada cambio: rama → PR → squash merge a `main`.
- Antes de decir "listo", pruébalo (Playwright sobre `index.html`, o SQL con `begin … rollback`) y di qué probaste.
- Cambios de base de datos: con migración (`apply_migration`), revisando antes la estructura y después los avisos de seguridad (`get_advisors`).
- Al terminar: actualiza tu archivo de `docs/temas/` (qué se decidió, por qué, qué objetos de Supabase usa, qué falta), marca en `docs/PENDIENTES.md` lo cerrado y corrige `docs/mapa-index-html.md` si lo que tocaste cambió de lugar.
- Pregúntale a Sara solo si la decisión es de ella (negocio, plata, datos personales). Lo técnico decídelo tú.
