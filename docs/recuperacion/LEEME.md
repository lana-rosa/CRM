# Recuperar contraseña solo para colaboradores (CRM)

Pedido de Jennifer (18-nov-2026) vía Orquestador General; Sara aprobó la base el 18-nov con «máximo 3 intentos».

## Piezas
| Pieza | Dónde | Qué hace |
|---|---|---|
| `crm_recuperacion_intentos` | base del CRM | Intentos de recuperación. Correo y dirección de red cifrados (sha256 con sal). RLS activada **sin políticas** (el asesor lo marca como aviso informativo: es a propósito, nadie la lee por la API). Se borran los de más de 1 día. |
| `crm_intentar_recuperacion(correo, ip)` | base del CRM (`docs/recuperacion/migracion.sql`) | Devuelve `ok` (hay fila en `profiles` con rol `admin` o `tejedora`), `no_existe` o `limite`. **Cerrada**: solo `service_role`. |
| `recuperar-contrasena` | función de borde (`supabase/functions/recuperar-contrasena/index.ts`), sin exigir sesión | Llama a la función de la base y, solo si es `ok`, envía el correo de recuperación de Supabase al correo registrado. |
| Pantalla de ingreso | `index.html` (`enviarEnlaceRecuperacion`) | Solo llama a la función de borde y muestra el resultado. Ya no llama a Supabase Auth directo. |

## Límites (3 por hora)
- Por aparato: 3 intentos por hora (cuenta todos, existan o no los correos).
- Por correo: 3 envíos reales por hora (los correos inexistentes no gastan el cupo de nadie).

## Textos (iguales en el ERP)
- Colaborador: «Te enviamos un enlace a tu correo registrado. Revisa también la carpeta de spam.»
- No colaborador: «Ese usuario no existe en el sistema».
- Límite: «Llegaste al máximo de 3 intentos por hora. Inténtalo más tarde.»

## Riesgos conocidos (decididos por Jennifer, aceptados por Sara)
1. **Se puede saber qué correos son de colaboradores** (el aviso explícito lo permite). El límite de 3 intentos por hora por aparato lo frena, pero no lo elimina: alguien con muchos aparatos o direcciones puede ir probando.
2. **El punto de envío propio de Supabase** (`/auth/v1/recover`) sigue abierto a cualquier cuenta de acceso registrada. Hoy toda cuenta de acceso tiene perfil (0 sin perfil), así que no hay quien reciba el enlace sin ser colaborador. Cerrarlo del todo exige un «Send Email hook» de Auth.
3. «Activo» = tener perfil con rol. Quitar a alguien de Equipo le quita el permiso. No existe una marca `activo` separada.
4. Quien abusa de un aparato con la dirección de red de otra persona (red compartida) puede dejarla sin cupo una hora.

## Pruebas hechas (18-nov)
- SQL con rollback (`prueba-rollback.sql`): todo bien, 0 filas quedan.
- Lógica de la función de borde con piezas simuladas (`prueba-funcion-borde.mjs`).
- Pantalla con Playwright a 1280 y 390 px.
- **Pendiente:** llamada en vivo a la función y correo real (este entorno no tiene red hacia Supabase).
