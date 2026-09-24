# El teléfono que pierde el relevo DESPUÉS del cutover ya no sube su residual encima de la cuenta

## Contexto
Acaba de mergear a 2.1 el PR #237 (`displaced-migration-leader-keeps-uploading-after-a-takeover`): el teléfono que pierde el relevo de una activación ya no sube nada más a la cuenta y sale enseguida con «otro dispositivo tomó el relevo». Ese arreglo cierra la subida/verificación con una puerta del lease antes de cada página, pero **no cubre lo que va detrás del cutover(.serverConfirmed)**.

Este ticket es el residual hallado en esa review (lente de bypass): el líder desplazado *después* del cutover sigue empujando su residual en el reconcile. Quien arranca aquí empieza en contexto limpio; el detalle vivo está en `tickets/in-progress/leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile.md` (ya movido a in-progress).

Cola A autónoma (callejón nube / migración). Device-QA del ticket hermano en qa corre en paralelo y **no** frena este trabajo de código.

## Que se pide
Cerrar el dead-end de producto: si el teléfono A pierde el relevo **después** del cutover, no debe seguir subiendo lo que escribe encima de lo que B ya está subiendo, ni reintentarlo cada vez que abre la app. Debe parar enseguida y salir con el motivo claro de «otro dispositivo tomó el relevo» (misma familia de salida que #237, en la fase post-cutover / reconcile).

Lee el ticket completo, verifica la hipótesis en código, implementa el arreglo robusto (buena práctica, no el atajo más simple), tests que fijen el bug como contrato, docs/estado/tickets al día, PR a 2.1, gate, merge y `/cerrar-total`.

Si de camino aparecen bugs o decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) **antes** de cerrar; actualizar `docs/TICKETS.md`.

## Que NO hay que tocar
- `marketing/` y Web/ (lane Lola).
- No reabrir el alcance ya cerrado de #237 salvo reutilizar el patrón de puerta/lease de forma limpia.
- No inventar PASS de device-QA ni cerrar tickets de qa ajenos.
- No paralelizar otro encargo de Yala: esta cola es serial.

## Como se sabe que esta bien
- El caso del ticket (líder desplazado post-cutover) ya no empuja residual al reconcile / no ensucia la cuenta del que tomó el relevo.
- Tests fallan antes y pasan después; el bug queda fijado como contrato.
- PR mergeado a 2.1; ticket en el estado correcto (qa si hace falta guion de dos iPhone; done si no-replicable / absorbed con nota).
- `docs/TICKETS.md` e índice del board en disco al día; `/cerrar-total` limpio.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` **sin preguntar** si corre el gate o el commit. La regla del repo «espera aprobación si >3 files» / «¿Sigo?» tras el plan queda **suspendida** en este encargo: implementa hasta el cierre. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real que no puedas resolver.

Horario diurno (Lima): si necesitas acceso/device/secrets de Jürgen, AskUserQuestion vía aviso al bot. Decisiones de producto/copy/techos: elige la opción robusta / buena práctica (Recommended) y sigue; no preguntes por preferencias reversibles.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 (resuelto por la sesión, sin nadie delante)

**Medido antes de decidir** (producción, lectura, 2026-09-24): `claim_account` (md5 `c96106b7…`) da el relevo con
`migration_in_progress` + lease > 60 min y NO mira `migrated_at`. `migration_progress('complete')` mira el líder ANTES que
nada (`other_leader` a quien no lidera, `ok` idempotente al líder aunque la migración ya esté cerrada); `heartbeat` mira
«¿hay migración?» antes que el líder. En el cliente, `done` con `.runLeaderReconcileFromFrozenCloudKit` pendiente deja el
runtime SIN arrancar (`startRuntimeIfStable` exige cero pendientes) y Almacenamiento pinta `.cloudActive`: el teléfono
desplazado se queda sin sincronizar para siempre, empujando su residual en cada intento.

1. **¿Salir o recuperarse?** → **Recuperarse.** Tras el cutover el marcador ya se exportó y el corpus de A está verificado
   en la cuenta: devolver A a iCloud (la salida de #237) contradice «el cutover jamás hace rollback» y mentiría al resto
   del parque. El ticket admite «sale o se recupera». *Asumido: la premisa del encargo («salir con el texto del relevo»)
   no aplica después del cutover.*
2. **La puerta** → el lease se confirma (`confirmMigrationLease`) ANTES de drenar y empujar el residual; el push lleva el
   mismo `continueWhile` de 30 min que la subida. Sin confirmar (red, 5xx, 401 renovable) no se empuja nada y se reintenta.
3. **Con el lease perdido, A resuelve quién cerró la migración sin subir nada:** `complete` → `ok` = fue su propio
   `complete` con la respuesta perdida (antes esto salía «perdido» por el `not_in_progress` del latido); `other_leader` →
   `claim(migration: true)`: `created` = el otro dejó caducar el lease y A vuelve a liderar (mismo relevo que se le dio a
   B); `claiming_in_progress` = B sigue vivo → A espera sin subir; `existing_stable` = B terminó (o volvió a iCloud) → A se
   une como un dispositivo más: el efecto termina, sello `.routeReturningUser`, arranca el runtime y su residual viaja por
   el sync normal de una cuenta ya cerrada. El claim va DIRECTO al cliente, sin `performClaim`: no puede tocar el sello.
4. **Texto** → ninguno nuevo. La espera dura lo que la migración de B (termina, o deja de latir y a los 60 min A recupera
   el relevo) y no hay nada que la persona pueda decidir; «Nube activa» es verdad en cuanto A se une. *Asumido.*
5. **Servidor** (`claim_account` que no dé el relevo con `migrated_at`) → **fuera**: cambia el flujo de B (esperar o
   adoptar en vez de tomar el relevo) y el cliente tiene que resolver el `other_leader` igual — la vuelta a iCloud de
   otro dispositivo también toma el relevo tras el cutover, por diseño. Ticket propio.
6. **Latir en `markerWritten`/`mirrorOff`** → fuera: mitiga, no arregla, y con la app cerrada no late nadie.
7. **Review adversarial** → sí (sync/lease).
