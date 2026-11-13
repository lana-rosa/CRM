# Mensajes para abrir los chats del CRM

Abre cada chat nuevo en claude.ai/code con el repo `lana-rosa/CRM`, rama `main`, ponle el título indicado y pega su mensaje. Orden recomendado: 1 → 5 → 3 → 2 → 4 (los dos primeros hacen la Fase 0; 2 y 4 dependen de la unificación).

## CRM - Chat 1. Datos e integración ERP

```
TEMA: Datos e integración con el ERP   (archivo: docs/temas/datos-integracion-erp.md)

Trabajas en el CRM de Lana Rosa (repo lana-rosa/CRM). Antes de hacer nada:
1. Lee CLAUDE.md, docs/temas/datos-integracion-erp.md y las líneas de este tema en docs/PENDIENTES.md.
2. NO leas index.html completo: usa docs/mapa-index-html.md y lee solo el tramo necesario.
3. No releas ni resumas chats anteriores; lo que importa está en esos archivos.

Reglas:
- Responde en español, claro y sin tecnicismos (soy Sara, no programadora).
- Trabaja solo en este tema. Si ves algo de otro tema, anótalo en docs/PENDIENTES.md bajo "Para otro chat" y sigue.
- Las tareas que te mande el "Chat 0. Orquestador CRM" se ejecutan; lo delicado me lo consultas antes de publicar.
- Cada cambio: rama → PR → squash merge a main.
- No toques nada del ERP ni de la Web (tablas, funciones, pantallas, textos de marca). Si hace falta, anótalo en docs/PENDIENTES.md bajo "Para coordinar" y avísale al Orquestador CRM: solo él habla con los Orquestadores ERP y WEB. Leer la base del ERP sí puedes.
- Antes de decir "listo", pruébalo (Playwright o SQL con rollback) y dime qué probaste.
- Al terminar: actualiza tu archivo de docs/temas/, marca en PENDIENTES.md lo cerrado y corrige docs/mapa-index-html.md si cambió lo que tocaste.
- Pregúntame solo si la decisión es mía (negocio, plata, datos personales). Lo técnico decídelo tú.

Contexto de este tema: el CRM tiene su propia base en Supabase (wcqdkccvtywiutzknskr) casi vacía, mientras los clientes y ventas reales están en el ERP (terceros, pedidos_canal_venta, pedidos_web, ventas_pos, ventas_academia). Este chat se encarga de la seguridad de la base del CRM y de unificar los datos con el ERP. Es el que desbloquea a los demás chats.

Mi pedido de hoy: [aquí escribes lo que necesitas; por ejemplo "haz la Fase 0 de seguridad: cierra las funciones expuestas y revisa que una tejedora no pueda leer clientes ni pagos"]
```

## CRM - Chat 2. Clientes y ficha

```
TEMA: Clientes y ficha completa   (archivo: docs/temas/clientes-ficha.md)

Trabajas en el CRM de Lana Rosa (repo lana-rosa/CRM). Antes de hacer nada:
1. Lee CLAUDE.md, docs/temas/clientes-ficha.md y las líneas de este tema en docs/PENDIENTES.md.
2. NO leas index.html completo: usa docs/mapa-index-html.md y lee solo el tramo necesario.
3. No releas ni resumas chats anteriores; lo que importa está en esos archivos.

Reglas:
- Responde en español, claro y sin tecnicismos (soy Sara, no programadora).
- Trabaja solo en este tema. Si ves algo de otro tema, anótalo en docs/PENDIENTES.md bajo "Para otro chat" y sigue.
- Las tareas que te mande el "Chat 0. Orquestador CRM" se ejecutan; lo delicado me lo consultas antes de publicar.
- Cada cambio: rama → PR → squash merge a main.
- No toques nada del ERP ni de la Web (tablas, funciones, pantallas, textos de marca). Si hace falta, anótalo en docs/PENDIENTES.md bajo "Para coordinar" y avísale al Orquestador CRM: solo él habla con los Orquestadores ERP y WEB. Leer la base del ERP sí puedes.
- Antes de decir "listo", pruébalo (Playwright o SQL con rollback) y dime qué probaste.
- Al terminar: actualiza tu archivo de docs/temas/, marca en PENDIENTES.md lo cerrado y corrige docs/mapa-index-html.md si cambió lo que tocaste.
- Pregúntame solo si la decisión es mía (negocio, plata, datos personales). Lo técnico decídelo tú.

Contexto de este tema: lista de clientes, clientes por casa (Crochet, Mercería, Academy), ficha del cliente con interacciones, fechas especiales, referidos y segmentos. El objetivo es que la ficha muestre todo lo que una clienta ha hecho con Lana Rosa en cualquier canal (redes, web, tienda, Academy). Depende de la unificación de datos del Chat 1.

Mi pedido de hoy: [aquí escribes lo que necesitas; por ejemplo "propón cómo debería verse la ficha completa cuando tengamos los datos del ERP"]
```

## CRM - Chat 3. Embudo y seguimiento

```
TEMA: Embudo de ventas y seguimiento   (archivo: docs/temas/embudo-seguimiento.md)

Trabajas en el CRM de Lana Rosa (repo lana-rosa/CRM). Antes de hacer nada:
1. Lee CLAUDE.md, docs/temas/embudo-seguimiento.md y las líneas de este tema en docs/PENDIENTES.md.
2. NO leas index.html completo: usa docs/mapa-index-html.md y lee solo el tramo necesario.
3. No releas ni resumas chats anteriores; lo que importa está en esos archivos.

Reglas:
- Responde en español, claro y sin tecnicismos (soy Sara, no programadora).
- Trabaja solo en este tema. Si ves algo de otro tema, anótalo en docs/PENDIENTES.md bajo "Para otro chat" y sigue.
- Las tareas que te mande el "Chat 0. Orquestador CRM" se ejecutan; lo delicado me lo consultas antes de publicar.
- Cada cambio: rama → PR → squash merge a main.
- No toques nada del ERP ni de la Web (tablas, funciones, pantallas, textos de marca). Si hace falta, anótalo en docs/PENDIENTES.md bajo "Para coordinar" y avísale al Orquestador CRM: solo él habla con los Orquestadores ERP y WEB. Leer la base del ERP sí puedes.
- Antes de decir "listo", pruébalo (Playwright o SQL con rollback) y dime qué probaste.
- Al terminar: actualiza tu archivo de docs/temas/, marca en PENDIENTES.md lo cerrado y corrige docs/mapa-index-html.md si cambió lo que tocaste.
- Pregúntame solo si la decisión es mía (negocio, plata, datos personales). Lo técnico decídelo tú.

Contexto de este tema: oportunidades por etapas, tareas, alertas de Seguimiento y plantillas de WhatsApp. Hoy hay dos embudos (oportunidades en el CRM y oportunidades_venta en el ERP) y hay que dejar uno solo. Los pedidos nuevos se crean en el ERP.

Mi pedido de hoy: [aquí escribes lo que necesitas; por ejemplo "quita el código que ya no se usa en Crear pedido desde oportunidad y propón cómo juntar los dos embudos"]
```

## CRM - Chat 4. Fidelización

```
TEMA: Fidelización y comunicación   (archivo: docs/temas/fidelizacion.md)

Trabajas en el CRM de Lana Rosa (repo lana-rosa/CRM). Antes de hacer nada:
1. Lee CLAUDE.md, docs/temas/fidelizacion.md y las líneas de este tema en docs/PENDIENTES.md.
2. NO leas index.html completo: usa docs/mapa-index-html.md y lee solo el tramo necesario.
3. No releas ni resumas chats anteriores; lo que importa está en esos archivos.

Reglas:
- Responde en español, claro y sin tecnicismos (soy Sara, no programadora).
- Trabaja solo en este tema. Si ves algo de otro tema, anótalo en docs/PENDIENTES.md bajo "Para otro chat" y sigue.
- Las tareas que te mande el "Chat 0. Orquestador CRM" se ejecutan; lo delicado me lo consultas antes de publicar.
- Cada cambio: rama → PR → squash merge a main.
- No toques nada del ERP ni de la Web (tablas, funciones, pantallas, textos de marca). Si hace falta, anótalo en docs/PENDIENTES.md bajo "Para coordinar" y avísale al Orquestador CRM: solo él habla con los Orquestadores ERP y WEB. Leer la base del ERP sí puedes.
- Antes de decir "listo", pruébalo (Playwright o SQL con rollback) y dime qué probaste.
- Al terminar: actualiza tu archivo de docs/temas/, marca en PENDIENTES.md lo cerrado y corrige docs/mapa-index-html.md si cambió lo que tocaste.
- Pregúntame solo si la decisión es mía (negocio, plata, datos personales). Lo técnico decídelo tú.

Contexto de este tema: recompra, cumpleaños, posventa, reactivación de clientes dormidos, puntos de fidelización y mensajes por WhatsApp y correo. Los textos respetan la voz de marca de Lana Rosa. Depende de la unificación de datos del Chat 1.

Mi pedido de hoy: [aquí escribes lo que necesitas; por ejemplo "propón los flujos de mensajes (bienvenida, posventa, recompra, cumpleaños, reactivación) con su texto y cuándo se envía cada uno"]
```

## CRM - Chat 5. Indicadores e interfaz

```
TEMA: Indicadores, informes e interfaz   (archivo: docs/temas/indicadores-interfaz.md)

Trabajas en el CRM de Lana Rosa (repo lana-rosa/CRM). Antes de hacer nada:
1. Lee CLAUDE.md, docs/temas/indicadores-interfaz.md y las líneas de este tema en docs/PENDIENTES.md.
2. NO leas index.html completo: usa docs/mapa-index-html.md y lee solo el tramo necesario.
3. No releas ni resumas chats anteriores; lo que importa está en esos archivos.

Reglas:
- Responde en español, claro y sin tecnicismos (soy Sara, no programadora).
- Trabaja solo en este tema. Si ves algo de otro tema, anótalo en docs/PENDIENTES.md bajo "Para otro chat" y sigue.
- Las tareas que te mande el "Chat 0. Orquestador CRM" se ejecutan; lo delicado me lo consultas antes de publicar.
- Cada cambio: rama → PR → squash merge a main.
- No toques nada del ERP ni de la Web (tablas, funciones, pantallas, textos de marca). Si hace falta, anótalo en docs/PENDIENTES.md bajo "Para coordinar" y avísale al Orquestador CRM: solo él habla con los Orquestadores ERP y WEB. Leer la base del ERP sí puedes.
- Antes de decir "listo", pruébalo (Playwright o SQL con rollback) y dime qué probaste.
- Al terminar: actualiza tu archivo de docs/temas/, marca en PENDIENTES.md lo cerrado y corrige docs/mapa-index-html.md si cambió lo que tocaste.
- Pregúntame solo si la decisión es mía (negocio, plata, datos personales). Lo técnico decídelo tú.

Contexto de este tema: Inicio, Indicadores CRM, Informes y Excel, Calendario, Finanzas, menú y uso en celular. Quedan secciones sobrantes de Stock, Producción y Envíos (ya viven en el ERP) y la pantalla que pide la URL y la clave de Supabase en cada dispositivo. Cuando pruebes algo visual, hazlo en computador y en tamaño de celular.

Mi pedido de hoy: [aquí escribes lo que necesitas; por ejemplo "quita las secciones de Stock, Producción y Envíos y arregla Informes y Excel para que no lean esas tablas"]
```
