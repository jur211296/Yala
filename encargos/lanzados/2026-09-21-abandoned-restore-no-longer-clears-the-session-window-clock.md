# El restore abandonado ya no libera el reloj de la ventana de sesión

## Contexto
Cola A autónoma (serial) tras merge de PR #199 (`reverse-before-mount-has-no-way-to-abandon-the-return`) a 2.1. Cierre limpio; device-QA del #199 queda en el ticket y NO frena esta cola de código.

Ticket: `tickets/backlog/abandoned-restore-no-longer-clears-the-session-window-clock.md` (medium). Residual de `force-fetch-and-wait-ignores-cancellation` (#198): al cancelar la espera al salir de Restaurar, el flujo abandonado ya no llama `noteRestoreFinished`, así que el ancla `restoreStartedAt` sobrevive. Quien vuelve a entrar hereda el reloj viejo; si el import tarda, el tope duro caduca a medias y el dueño legítimo ve «estos datos son de otra persona».

Relacionados (no los implementes de paso): `force-fetch-and-wait-ignores-cancellation` (cerrado), `restore-back-and-reenter-closes-the-live-session-window` (FlowToken). Residual low del #199 `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` queda fuera: pide decisión de producto antes de código.

## Que se pide
Cierra el ticket según sus criterios de aceptación:
1. Volver a entrar a Restaurar tras abandonar un intento estrena la ventana, sin que el botón de reintentar DENTRO de un restore vivo pueda extender el tope duro a voluntad.
2. El flujo abandonado sigue sin apagar la ventana mientras el import baja (no reabrir el bug de force-fetch).
3. El invariante que sustituya `restoreStartedAt == nil ⇔ currentFlow == nil` queda escrito y con test.

Diseño orientativo del ticket: separar reloj (`restoreStartedAt`) de dueño (`currentFlow`) — un cancelado suelta titularidad sin apagar ventana; una entrada nueva sin dueño estrena reloj. Verifica midiendo; no asumas este diseño si encuentras uno mejor que cumpla los AC.

Al empezar: mueve el ticket a `in-progress` y actualiza `docs/TICKETS.md`. Al cerrar: board al día (qa si hace falta device-QA; done si no), índice al día. Bugs/decisiones nuevas de camino → ticket propio (`--solo-crear`) antes de `/cerrar-total`.

## Que NO hay que tocar
- marketing/, Web/
- El residual low del techo reverse (necesita decisión de producto)
- No reiniciar el reloj a ciegas en cada entrada (el docblock lo prohíbe por el reintentar)
- No reabrir el apagado de ventana al cancelar la espera con import vivo

## Como se sabe que esta bien
Gate del repo (build, unit del área, XCUITest con centinela, mutantes del cambio, review adversarial). Criterios del ticket en verde. PR a 2.1, merge, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Solo parar ante decisión/acceso real de Jürgen. Board de Yala = `tickets/` + `docs/TICKETS.md` (create/move en disco).

## Día (AskUserQuestion)
Son las ~14:20 Lima (diurno 6:00–21:00): si necesitas una decisión de producto o de acceso de Jürgen, usa AskUserQuestion. Si no hace falta, sigue.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

---

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Árbol levantado antes de escribir código. Todo lo de abajo se decidió midiendo el árbol, no leyendo
el ticket: la premisa del encargo también se mide.

### D1 · ¿Qué invariante sustituye a `restoreStartedAt == nil ⇔ currentFlow == nil`?

**Decidido: `currentFlow != nil ⇒ restoreStartedAt != nil`, y el converso NO vale.** El estado
`restoreStartedAt != nil && currentFlow == nil` pasa a ser legítimo y tiene nombre: **la ventana
huérfana** — un intento se fue con el import bajando, nadie la vigila, y la cierran el asentamiento o
la caducidad. Es exactamente lo que el AC 2 pide preservar.

Descartado el converso porque es lo que hoy obliga a elegir entre apagar la ventana de un import vivo
(el bug de `force-fetch-and-wait-ignores-cancellation`) y heredar su reloj (este ticket).

### D2 · ¿Cuándo estrena reloj `noteRestoreStarted`?

**Decidido: cuando no hay dueño vigente (`currentFlow == nil`); si lo hay, conserva.**

Medido antes de decidir, y esto **refuta la premisa del docblock actual** («el botón de reintentar
vuelve a llamar aquí, y reiniciar el reloj lo haría extensible a voluntad»): los cinco botones de
«volver a buscar» de `WelcomeRestoreView` solo existen en `showRefreshToolbar`, o sea en
`.notFound`, `.importIncomplete`, `.cloudPaused`, `.cloudUnverified`, `.iCloudDisabled` y `.error` —
**ninguno sale en `.searching`**. Los cuatro primeros se alcanzan desde `onSettled`, que corre
DESPUÉS de `noteRestoreFinished(flowToken)`, así que en el instante del reintento
`restoreStartedAt` ya es `nil` y **el reloj se estrena igual hoy**. La protección que el docblock
dice tener no protege de lo que dice; lo único que produce es este bug.

Con la condición nueva la protección pasa a ser real y al mismo tiempo comprobable: conserva
**mientras el intento anterior siga siendo dueño**, que es lo que de verdad significa «dentro de un
restore vivo». Hoy la UI no puede llegar ahí; el guard es de la API y su test unitario
(`restartingTheSearchDoesNotExtendTheWindow`) lo mata.

Descartado «reiniciar siempre» (tumba ese test y con él el invariante que el repo considera vivo) y
«reiniciar solo si la ventana caducó» (el propio ticket lo mide: a t=400 la ventana sigue viva).

### D3 · ¿Quién declara el abandono, y dónde?

**Decidido: `RestoreProgressView.onDisappear`, junto a los dos `cancel()`.** El abandono ES «esta
pantalla se fue», y ahí ya vive esa declaración.

Descartado el `else` del `guard !Task.isCancelled` dentro de `runTask`: es más tarde (hasta 1 s de
poll de quiescencia) y depende de que la espera resuelva. `onDisappear` es incondicional.

**Residual declarado (no se apuntala):** si SwiftUI llegara a correr el `.task` de una entrada nueva
ANTES del `onDisappear` de la anterior, el reloj se heredaría — o sea, el comportamiento de HOY. Es
fail-soft hacia el status quo, no una regresión nueva, y el guard por token impide cualquier daño al
intento vivo. No se añade una segunda vía por ello: el mecanismo que falla se retira o se arregla, no
se apuntala con un cinturón que además cegaría al vigilante.

### D4 · ¿El abandono puede apagar la ventana en algún caso?

**Decidido: NO, nunca.** `noteRestoreAbandoned` no toca `restoreStartedAt`. Es el AC 2 literal y la
línea que separa este ticket de reabrir el anterior.

### D5 · ¿Se arregla de paso que `.importIncomplete` apague la ventana con el import bajando?

**Decidido: NO — ticket propio.** `noteRestoreFinished` apaga igual cuando `settled == false`, o sea
cuando el tope de 90 s se agotó **con el import en marcha**: ahí la ventana se cierra sobre una
descarga viva. Es el mismo bug-class pero otro eje (el desenlace del flujo, no su abandono), toca la
semántica de `noteRestoreFinished` y merece su propio ciclo. Se crea con `--solo-crear`.

### D6 · ¿Alcance del source-scan nuevo?

**Decidido: pinnear `noteRestoreAbandoned(` a UN solo call-site de producción**, igual que
`noteRestoreStarted(`. Soltar la titularidad desde un segundo sitio permite estrenar reloj a
voluntad, que es justo lo que D2 cierra, y no pondría roja ninguna tabla.

### D7 · ¿Re-anclar sin más, o con una condición? (añadida tras la review, 2026-09-21)

**Decidido: re-anclar una ventana huérfana solo si `hasObservedImportActivity`.** El término lo pide
el call-site, sin default.

Lo cazó la lente de frontera de cuenta y lo medí: con «estrena si no hay dueño» a secas, el ciclo
**entrar a Restaurar → tocar atrás → repetir** re-ancla el reloj en cada vuelta, y como
`ICloudRestoreInProgressLogic` mide TODOS sus plazos desde `restoreStartedAt` —la gracia de 60 s
incluida—, quien navegue más rápido que esa gracia mantiene la ventana abierta indefinidamente. En un
teléfono con el corpus de otra persona eso es exactamente la adopción que `CrossAccountEntryGuardLogic`
existe para impedir. **Antes del ticket no era posible**: el reloj no se reiniciaba en reentradas, así
que en un teléfono sin import la ventana moría a los 60 s de la primera entrada y no volvía.

Descartadas dos salidas antes de llegar aquí:

- **Aceptarlo como residual** — el daño marginal es discutible (con UNA sola entrada ya hay 60 s, de
  sobra para tres taps), pero rompe la promesa escrita de que el tope duro es «la red que no depende
  de NADA», y eso es lo que el yo-futuro lee.
- **Un techo absoluto de sesión** (un segundo ancla que no se re-ancla nunca) — cierra el vector pero
  **exige un número nuevo**, o sea una decisión de producto de Jürgen, y no hace falta: el testigo del
  import contesta la pregunta de verdad, que no es «cuántas veces» sino «¿hay una descarga que
  justifique una ventana nueva?».

El testigo es el mismo con el que `ICloudRestoreInProgressLogic` separa «el import va lento» de «no
hay nada que importar», y su modo de fallo es conservar el reloj viejo, o sea **cerrar antes**.
