# El desasociar debe comprobar que la sesión en la nube se cerró de verdad

## Contexto
Cola A autónoma Yala (riesgo real: duplicación silenciosa). Ticket `tickets/backlog/detach-does-not-verify-the-cloud-session-actually-closed.md`. Tras PR #254 (hermano de adopt/ventana iCloud) la cola sigue. Hora Lima ~01:17 → NOCTURNO: elige lo robusto sin AskUserQuestion; si la decisión es demasiado grande para asumirla, aparca el ticket y cierra sin inventar.

Medido: `CloudAuthService.signOut()` envuelve `client.signOut(scope: .local)` en un `do/catch` que solo loguea. Los demás caminos que lo llaman acaban en `armSignOutWipe` + relanzamiento; `detachGroupsAccount` no. Si la sesión sobrevive, en el siguiente foreground `startIfEligible` pasa `sessionCheck()`, arranca el loop, y como el cursor se purgó vuelve a bajar el corpus entero: se re-puentea y aparecen duplicados junto a los movimientos que la persona decidió conservar, sin aviso.

## Que se pide
MODO AUTÓNOMO (norma Jürgen 2026-09-22): implementa de punta a punta hasta gate/PR/merge a 2.1 y `/cerrar-total`. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo: no pares a preguntar si continúas.

Arreglo robusto (opción del ticket): postcondición antes del punto de no retorno del desasociar — `guard !CloudAuthService.shared.hasSession else { phase = .blocked(…); return }` (o equivalente que deje reintentar). Con el sign-out fallido, el desasociar se detiene; no deja el dispositivo a medias.

Mueve el ticket a `in-progress` al empezar y a `done` o `qa` al cerrar; actualiza `docs/TICKETS.md`. Si la review adversarial saca bugs o decisiones nuevas, créalos como tickets propios antes de `/cerrar-total`.

## Que NO hay que tocar
- `marketing/`
- clinicas-dentales-bi / datos de salud
- No relances otros encargos ni toques tickets de Cola B (rediseño UI)
- No aparques por device-QA: si el arreglo es canario/unit-cerrable, `done`; si necesita dos iPhone, `qa` con guion

## Como se sabe que esta bien
- Si `signOut` deja sesión viva, el desasociar NO cruza el punto de no retorno; queda bloqueado y reintentable
- No reaparece el corpus de grupos re-puenteado en silencio tras un detach a medias
- Gate verde (unit + XCUITest del área); mutantes/review según plantilla del repo
- PR mergeado a `2.1` y `/cerrar-total` con board e índice al día

## Paso 0

Decisiones tomadas (nocturno, sin nadie delante; lo asumido va marcado).

1. **Qué cuenta como «la sesión sobrevivió» — medido en supabase-swift 2.50.0.** `signOut(scope: .local)` borra la
   sesión del almacén ANTES de la red y el borrado traga su error: la red caída lanza con la sesión ya fuera. Sobrevive
   si el `SecItemDelete` del llavero falla, o si un refresco del token en vuelo la repone (`LiveSessionManager.remove()`
   no cancela `inFlightRefreshTask`). El testigo es el almacén del SDK releído tras el cierre, y lo devuelve el propio
   `CloudAuthService.signOut()` (`@discardableResult -> Bool`). **No `hasSession`**: lleva el seam
   `-uitest-fake-cloud-session`, y dos XCUITest del desasociar corren con él; el guard del ticket los bloquearía siempre.
2. **Dónde va la postcondición: el cierre de sesión sube por encima del punto de no retorno.** Orden nuevo: push-all →
   teardown → residual → `signOut()` + postcondición → [no retorno] → puente → borrado. Con la sesión viva el gesto se
   para sin haber escrito nada, en el mismo estado que el bloqueo del residual. Dejarlo detrás del puente dejaba el puente
   soltado con la asociación en pie: el reintento volvería a ofrecer las dos salidas y la segunda no se aplicaría.
   *Coste asumido:* si el puente no se deja leer, la sesión ya está cerrada; el teléfono queda asociado sin sesión (la
   celda del segundo móvil) y el reintento funciona sin sesión con el outbox vacío.
3. **Motivo propio, `BlockReason.sessionNotClosed`, con copy nuevo** en los 16 locales (es-AR en voseo). Ninguno de los
   existentes es verdad aquí: `.transient` es «el outbox que drena», `.bridgeUnreadable` habla de movimientos.
   *Asumido:* texto «No pudimos cerrar la sesión de tu cuenta de grupos en este iPhone. No se soltó nada. Vuelve a
   intentarlo.», molde del de `bridgeUnreadable`.
4. **Canario fuera de `#if DEBUG`** (`groupsDetachSessionSurvived`): el ticket dejó sin medir si esto pasa en la flota.
5. **Tests:** XCUITest con seam `-uitest-sign-out-keeps-session` (el aviso sale, con su texto; control: el caso sin seam
   ya existe) + source-scan de orden en `GroupsDetachPurgeFailureTests` + mutantes.
6. **Fuera, con ticket propio:** los cinco cierres de sesión tampoco verifican el cierre, y el boot-wipe no purga el
   llavero de la sesión, así que la premisa «se lo pueden permitir porque relanzan» del ticket no se sostiene; y el
   refresco en vuelo que aterriza DESPUÉS de la postcondición.
