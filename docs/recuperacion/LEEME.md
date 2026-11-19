# Recuperar contraseña solo para colaboradores (CRM)

Pedido de Jennifer (18-nov-2026) vía Orquestador General; Sara aprobó la base el 18-nov con «máximo 3 intentos».

## Piezas
| Pieza | Dónde | Qué hace |
|---|---|---|
| `crm_recuperacion_intentos` | base del CRM | Intentos de recuperación. Correo y dirección de red cifrados (sha256 con sal). RLS activada **sin políticas** (el asesor lo marca como aviso informativo: es a propósito, nadie la lee por la API). Se borran los de más de 1 día. |
| `crm_intentar_recuperacion(correo, ip)` | base del CRM (`docs/recuperacion/migracion.sql` + `migracion-2-neutral.sql`) | Devuelve `ok` (hay fila en `profiles` con rol `admin` o `tejedora`), `no_existe` o `limite`. **Cerrada**: solo `service_role`. |
| `recuperar-contrasena` | función de borde (`supabase/functions/recuperar-contrasena/index.ts`), sin exigir sesión | Llama a la función de la base y, solo si es `ok`, envía el correo de recuperación de Supabase al correo registrado. |
| Pantalla de ingreso | `index.html` (`enviarEnlaceRecuperacion`) | Solo llama a la función de borde y muestra el resultado. Ya no llama a Supabase Auth directo. |

## Límites (3 por hora)
- Por aparato: 3 intentos por hora (cuenta todos, existan o no los correos).
- Por correo: 3 envíos reales por hora (los correos inexistentes no gastan el cupo de nadie). Al llegar a 3 no se envía otro y se responde igual que a un correo no registrado.

## Textos (iguales en el ERP)
- **Cualquier correo, sea colaborador o no:** «Si el correo está registrado, te enviamos un enlace.» Solo se envía el correo si es colaborador.
- Límite: «Llegaste al máximo de intentos.»
- Botón en pausa 10 s tras cada envío (igual al ERP). La vista de recuperación no lleva línea de ayuda: título, correo, botón y «Volver a ingresar».

**Historia:** el 18-nov se aprobó un aviso explícito («Ese usuario no existe en el sistema»). El 19-nov se cambió a aviso neutro, **para que no se descubran los correos de los colaboradores**. Para que el aviso neutro sirva de algo, el servidor también responde igual (`enviado`) a colaboradores y no colaboradores, con una pausa aleatoria de 0,7–1,3 s cuando no envía (imita lo que tarda el envío real), y el tope de 3 envíos por correo ya no responde `limite` sino igual que un correo no registrado.

## Riesgos conocidos
1. ~~Se puede saber qué correos son de colaboradores~~ → **cerrado con el aviso neutro** (pantalla, respuesta del servidor y tope por correo). Queda un rastro mínimo: el tiempo de respuesta se imita pero no es idéntico.
2. **El punto de envío propio de Supabase** (`/auth/v1/recover`) sigue abierto a cualquier cuenta de acceso registrada. Hoy toda cuenta de acceso tiene perfil (0 sin perfil), así que no hay quien reciba el enlace sin ser colaborador. Cerrarlo del todo exige un «Send Email hook» de Auth.
3. «Activo» = tener perfil con rol. Quitar a alguien de Equipo le quita el permiso. No existe una marca `activo` separada.
4. Quien abusa de un aparato con la dirección de red de otra persona (red compartida) puede dejarla sin cupo una hora.

## Pruebas hechas (18-nov)
- SQL con rollback (`prueba-rollback.sql`): todo bien, 0 filas quedan.
- Lógica de la función de borde con piezas simuladas (`prueba-funcion-borde.mjs`).
- Pantalla con Playwright a 1280 y 390 px.
- **Pendiente:** llamada en vivo a la función y correo real (este entorno no tiene red hacia Supabase).
