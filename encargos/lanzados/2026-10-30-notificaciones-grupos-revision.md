---
esfuerzo: medium
release: no
---
# Notificaciones de Grupos: quién las recibe, cuándo y qué dicen

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `notificaciones-grupos-revision` · Sesión cola **S29d** · al cerrar → **S29e** (`grupos-hero-implementar`).

## Contexto
Jürgen (2026-10-30, grave): 1) al cambiar un saldo inicial le llega la notificación también a quien hizo el cambio; 2) esa notificación solo dice «Novedades en tus grupos»; 3) al crear un gasto de grupo también le llega a quien lo creó; 4) el aviso de gasto nuevo también es genérico.

Cards:
- `tablero ver tablero-notificaciones-de-grupos-revision-comple-sztn`

## Qué se pide
1. Audita TODAS las notificaciones de Grupos (gasto nuevo, editado y borrado, saldo inicial, liquidaciones, miembros que entran o salen, roles, invitaciones): quién las dispara (app, trigger o Edge Function de Supabase, APNs/CloudKit), cuándo y a quién. Deja la tabla en `docs/notificaciones/GRUPOS-AUDITORIA-2-2.md`.
2. Quien hace la acción nunca recibe su propia notificación, en ningún dispositivo suyo.
3. Cada tipo tiene título y cuerpo específicos: quién, qué acción, concepto, monto con moneda y grupo (p. ej. «María P. agregó Foppy Pet Store · S/ 40.60 en Jurpi ❤️»). Localizado en todos los idiomas de la app; nada de «Novedades en tus grupos» salvo como agrupado de varias.
4. Tests unitarios de destinatarios y textos; verificación con dos cuentas en staging (o dos simuladores).
Si hay que desplegar Edge Functions o migraciones, hazlo en staging; producción la decide Jürgen en una card.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Lógica de saldos y liquidaciones (solo avisos). Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido antes de decidir: el banner que ve la gente lo pinta el SISTEMA con el push de alerta del Worker (`fanOutGroupPush`), siempre «Novedades en tus grupos». La app solo lo sustituye por su texto rico si ella decide avisar; cuando decide no avisar (autor, saldo inicial, no participa) el genérico se queda. El autor lo recibe porque, con `X-Yala-Device-Token`, el servidor excluye solo el teléfono emisor (los otros del autor sí reciben, por diseño G8-3) y no excluye filas viejas del mismo teléfono registradas con otro usuario.

1. **Quién no recibe**: el teléfono emisor no recibe nada (tampoco por una fila de su token a nombre de otra cuenta); los otros dispositivos del autor reciben solo el eco silencioso (sin banner) para seguir sincronizando al momento. Sin migración SQL. (Primera versión: nada a ningún dispositivo del autor; la review adversarial señaló que su iPad dejaba de bajar el cambio al momento.)
2. **De dónde sale el texto**: el servidor no puede leer nombres ni importes (cifrados at-rest). El cliente que sube adjunta en el body del push una `notice` con lo que ya conoce en claro (nombre del grupo, su nombre de miembro, concepto, importe formateado, si es saldo inicial, quién paga a quién). El Worker la combina con lo que sí sabe del delta aplicado (alta/edición/borrado por `outcome.inserted` y `op`). Nada se guarda: viaja a APNs y muere. Alternativa descartada: descifrar en el Worker (nueva RPC, contradice el motivo del cifrado).
3. **Formato**: título = nombre del grupo; cuerpo con `loc-key` + `loc-args`, localizado por iOS en los 16 `.lproj`. Varios cambios en la misma subida → «X hizo N cambios». Sin `notice` (cliente viejo) → genérico de siempre.
4. **Borrados**: el cliente ya no tiene la fila al subir el borrado → «X borró un gasto/un pago», sin concepto. Conservador.
5. **Ruido**: un cambio que solo marca saldado/pagado no avisa (lo cubre el pago).
6. **Fuera de alcance, anotado**: filtrar en servidor por participación (quien no está en el gasto sigue recibiendo el aviso del servidor, como hoy); membresía (RPC) conserva sus textos, ya específicos por audiencia; roles no emiten push (decisión previa).
7. **Despliegue**: Worker a staging; producción → card a Jürgen.
