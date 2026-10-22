# Si se pierde la respuesta de la promoción, «Reintentar» ya no bloquea la activación a la nube

## Contexto
Cola A autónoma (noche Lima). Acaba de mergear a `2.1` el PR #231 (`settings-adopt-stalled-before-the-claim-keeps-the-session`): en Almacenamiento, si activar la nube se queda esperando a iCloud antes de empezar, la sesión que abrió se cierra. Ese tramo de adopt/sesión queda cerrado; los residuales low de la review (`adopt-session-close-drops-the-mark-before-the-sign-out-lands`, `welcome-adopt-stalled-session-is-kept-when-settings-reuses-it`) NO entran en este encargo.

Siguiente callejón sin salida de producto para 2.1: ticket `claim-promotion-lost-response-blocks-the-retry` (medium, backlog). Quién arranca lo hace en contexto limpio — lee el ticket en `tickets/backlog/claim-promotion-lost-response-blocks-the-retry.md` y el código citado ahí.

## Que se pide
Arreglar el callejón: si la promoción `POST /account/claim` ya dejó la cuenta completa en el servidor pero la respuesta no llegó al teléfono, «Reintentar» debe terminar la activación (seguir al commit / persistir [P]), no bloquear con «Tu cuenta ya tiene finanzas personales».

Distinguir «la acabo de promocionar yo y no tiene filas personales» de «ya tenía lo personal (otro dispositivo)»: señal en el claim (p. ej. si la cuenta tiene filas personales) o idempotencia por intento — elige la opción más robusta / good-practice (norma Jürgen: nunca la más simple).

Criterios del ticket:
- Promoción confirmada en servidor + respuesta perdida → «Reintentar» termina la activación.
- Una cuenta que de verdad tiene lo personal reclamado desde otro dispositivo sigue bloqueando sin escribir nada.

Al cerrar: mueve el ticket a `done` (sin device-QA si el camino no se monta a voluntad; si hace falta QA de iPhone, a `qa` y dilo), actualiza `docs/TICKETS.md` e índice/board del repo, crea tickets propios de residuales de review antes de `/cerrar-total`, merge a `2.1`.

## Que NO hay que tocar
- marketing/, Web/
- Los residuales low del #231 / #229 (copy de bienvenida, medición de reuse)
- Device-QA de otros tickets en `qa/`
- No paralelizar otro encargo de migración/claim sobre el mismo modelo de estado si chocaría

## Como se sabe que esta bien
Gate verde; mutantes del camino tocado muertos; criterios del ticket cumplidos con tests; PR mergeado a `2.1`; board/TICKETS.md al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (device/secretos). Board de proyectos: create/move directo.

Override Jürgen 2026-09-22: la regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo — implementa hasta el cierre sin pedir continuar.

Noche (21:00–6:00 Lima): elige tú la opción recomendada / más robusta sin AskUserQuestion; si la decisión es demasiado importante para asumirla, aparca en ticket propio y no inventes.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-24)

El detalle, con lo medido, está en el ticket (`tickets/in-progress/claim-promotion-lost-response-blocks-the-retry.md`, § Paso 0). En corto:

1. **Se distingue en el servidor**, no en el cliente: tras una respuesta perdida el cliente solo ve `existing_stable`, y una heurística local sembraría encima del alta en curso de OTRO teléfono.
2. **Señal = mismo dispositivo líder + la cuenta nunca recibió una escritura personal** (sin fila en `sync_seq_counters`, que estampa el trigger de las 17 tablas del canal personal). No un token nuevo: el `device_id` ya es la clave de idempotencia del contrato, y un token exigiría desplegar el Worker (decisión de Jürgen).
3. **Rama nueva en `claim_account`** con cinco términos, cada uno con su escenario; se descartan dos que no protegen nada.
4. **Arregla también el gemelo del Welcome** (alta born-cloud con la respuesta perdida) y el kill entre la promoción y la primera escritura.
5. **Solo SQL** (`qa/cloud/g16_01_…`), staging antes que producción, guarda de md5 y sonda de conducta dentro. Sin Worker, sin cambio de comportamiento en el cliente (solo docblocks).
6. **Tests**: sonda ejecutable con control negativo y mutantes por término + goldens del gateway. El golden 1 pasa a probar la exclusión con dos dispositivos.
7. **Ticket a `done`**, sin device-QA: el camino no se monta a voluntad y el cliente no cambia.
