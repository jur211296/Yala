# Un dispositivo que procesa tarde «Vaciar datos» no se lleva lo personal creado después

## Contexto
Acaba de mergearse a 2.1 el PR #288 (`settlement-approval-leaves-no-trace-so-a-rebridge-asks-again`): una liquidación ya aprobada no vuelve a pedir su cuenta ni duplica el pago tras un re-puente / wipe tardío.

La familia del wipe remoto tardío (#284 `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`, #287 receptor sin Grupos) dejó este residual medium en backlog: `tickets/backlog/late-remote-wipe-signal-also-wipes-rows-created-after-it.md` (leído en código, no reproducido).

Síntoma de usuario: vacía datos en el iPhone y empieza de nuevo; apunta gastos varios días. Abre el iPad cerrado desde antes del vaciado: el iPad se vacía (esperado), pero su borrado viaja por iCloud y se lleva también los gastos NUEVOS del iPhone. Desde #284 los gastos/liquidaciones de GRUPO vuelven; lo personal creado tras la señal, no.

Causa medida: la señal es un timestamp en iCloud-KV (`PreferenceSyncService.signalWipeInitiated`, key `lastWipeTimestamp`). El receptor solo compara `remoteWipe > localWipe`; no filtra por fecha lo que borra. `ContentView.performLocalWipeForRemoteSync` borra toda `TransactionItem` sin predicado y en modo iCloud el borrado se exporta por el espejo.

Cola A real-risk (borrado incorrecto / pérdida de datos personales post-vaciado). Carril Swift Cola A: una sesión a la vez. El carril adaptativo iPad/Duo es otro carril; no lo toques.

NOCTURNO (21:00–6:00 Lima): elige la opción recomendada sin AskUserQuestion. Si la decisión fuera demasiado grave para asumirla, aplaza con ticket propio — no inventes producto.

## Que se pide
Cierra el ticket `late-remote-wipe-signal-also-wipes-rows-created-after-it` de punta a punta.

Decisión de producto ya tomada por Frank (opción robusta, buena práctica — la más fiel a «Vaciar datos» en los demás dispositivos):
1. El receptor de una señal de wipe remota borra solo lo anterior o igual a la señal (`createdAt` ≤ timestamp de la señal, o el campo temporal equivalente que midas como SSOT de «existía antes del vaciado»). No se lleva filas personales creadas después.
2. Lo que sea dominio de grupos sigue las reglas ya cerradas en #284/#287 (convergencia / declaración); no reabras ese diseño salvo que midas un choque real con este predicado.
3. Si al medir resulta que `createdAt` no es fiable para alguna superficie (borrador, preferencia, etc.), documenta el hueco con ticket propio y cierra el camino de `TransactionItem` (y gemelos evidentes) con el predicado correcto.

Relacionados a no absorber salvo que midas que son el mismo bug: `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`, `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`, `wipe-data-group-rows-return-only-on-the-next-cold-launch`, `late-remote-wipe-infers-the-origin-converged-from-row-dates`, `remote-wipe-receiver-has-no-behaviour-test`.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- el carril adaptativo iPad/Duo ni sus simuladores `YalaLane-Adapt-*`
- simuladores de otras colas
- prod Supabase; staging solo si el ticket lo exige de verdad
- no reabrir el diseño de la convergencia de grupos del wipe tardío (#284/#287) ni D7 de liquidaciones (#288) más allá de un choque medido

## Como se sabe que esta bien
- Tests que fijen: tras un wipe en el origen y gasto personal nuevo, un receptor que procesa la señal tarde no exporta el borrado de esas filas nuevas (el origen las conserva).
- Gate verde del encargo; PR a 2.1; ticket movido (qa o done según norma del repo) y `docs/TICKETS.md` al día.
- Si salen bugs o decisiones nuevas de camino: ticket propio en `tickets/` antes de `/cerrar-total`.
- Device-QA solo si hace falta; si queda, guion claro en el ticket — no frena el merge de código.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen o secreto que no tengas. No sync al Kanban del panel centro de mando.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 (Frank, 2026-09-28 02:30 Lima — nocturno, autocontestado)

Medido en el árbol antes de decidir:

- `createdAt` (default `Date.now`, solo lo reescribe `DevSeed*`) existe en `TransactionItem`, `InboxDraft`, `Budget`,
  `FavoritePayment`, `ScheduledPayment`, `Tag`, `CashFlowPlan` y `NotificationItem`. `MerchantMemory` tiene
  `lastApprovedAt`, que nace con la fila y solo avanza. **`Account`, `Category`, `Subcategory` y `ExchangeRate` NO
  tienen fecha de creación.** Todas las relaciones hacia ellas son `.nullify`: borrar la cuenta deja la transacción
  nueva viva pero sin cuenta.
- El origen, tras vaciar, re-siembra categorías y crea cuentas nuevas: si el receptor se las lleva, los gastos nuevos
  sobreviven huérfanos y el origen pierde sus categorías sin usar (la semilla no vuelve: centinela puesto).
- El arranque del receptor puede crear borradores de pagos programados VIEJOS antes de procesar la señal
  (`processDuePayments`): nacen después de la señal pero derivan de lo que se borra.
- El mecanismo de #284 (pedir convergencia) y #287 (declarar al parque) existe porque el receptor se llevaba filas
  puenteadas POSTERIORES a la señal. Con el corte por fecha ya no se las lleva. Ninguno de los dos está en un build
  publicado (build 14 = `ba884680`, 23-sep).

Decisiones:

1. **Lo fechado:** el receptor borra solo `createdAt ≤ señal` (`MerchantMemory`: `lastApprovedAt`). Sin hora de señal
   (≤ 0) no hay corte: borrado entero, como hoy.
2. **Lo derivado:** un borrador cuyo `sourceScheduledPaymentID` es un pago programado que se borra, se borra aunque
   sea posterior.
3. **Lo sin fecha** (cuenta, categoría, subcategoría, tipo de cambio): se queda si lo referencia algo que se queda; se
   va si solo lo referencia lo que se borra; y si nadie lo referencia, se queda solo si el parque ya empezó de nuevo
   (`remoteOnboarding > remoteWipe`, el mismo `skipOnboarding` del drenaje). Sin ese inicio nuevo, lo no referenciado
   se borra como hoy — si no, un receptor que vuelve al onboarding conservaría categorías viejas, la semilla no
   correría y el espejo se las llevaría después: cero categorías.
4. **Lo que se queda no se escribe.** Las limpiezas de relaciones solo tocan filas que se borran: cualquier escritura
   en una superviviente viajaría al origen.
5. **Choque medido con #284/#287:** el receptor deja de pedir convergencia y de declarar, porque ya no se lleva nada
   posterior a la señal. Pedirla sobre filas intactas re-puentea las del origen, y declararlas haría que el origen
   repusiera un gasto que la persona borre después a propósito. El atendedor de declaraciones, `toDeclare` y el
   predicado de #284 se quedan sin productor: NO se retiran de paso (memoria «mi arreglo deja el mecanismo sin
   productor»); ticket propio para retirarlos.
6. **Preferencias:** el reset del receptor es local (`removeUserPreferenceKeys` sobre `.standard`, sin observador que
   empuje al KV). No pisa las del origen. Sin ticket.
7. Review adversarial: sí (borrado de datos + sync). Device-QA: guion en el ticket, no frena el merge.

### Enmiendas tras la review adversarial (tres lentes)

- **(3) cambia**: «el parque empezó de nuevo» es la marca del KV **o** una fila personal posterior a la señal en el
  store (la marca se congela al detectar y viaja por otro canal). Borradores, memorias y filas de grupo no cuentan.
- **Nuevo**: borradores y memorias no protegen las cuentas y categorías que usan. Un borrador de Apple Pay creado al
  arrancar sobre una subcategoría vieja impedía la semilla, y el espejo se la llevaba después: cero categorías.
- **(5) se corrige**: el receptor **sigue pidiendo la convergencia** con el predicado de #284. Ya no es para devolver la
  reposición (que ahora se queda), sino lo anterior que el corte sí se lleva y el origen no repone: una real vieja que
  el bridge del origen conservó al reponer, la pata vieja que hizo saltar una liquidación, los grupos que el origen no
  tiene. Solo se retira la declaración al parque. La primera versión (quitar también la petición) era una regresión.
- **Nuevo**: el receptor reprograma los avisos de lo que se queda (el borrado cancela todo lo programado y con
  `skipOnboarding` no hay arranque que los reprograme).
- Tickets nuevos: `late-remote-wipe-return-has-no-producer-left`, `late-remote-wipe-cut-keeps-what-it-cannot-date-until-
  the-mirror-decides`, `late-remote-wipe-survivors-can-point-at-rows-the-origin-deleted`,
  `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`.
