# Si el dispositivo que procesa tarde el vaciado no tiene Grupos, los gastos de grupo no vuelven

## Contexto
Ticket: `tickets/backlog/late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows.md` (medium, area groups/sync). Residual explícito del merge #284 (`late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`): el receptor de la señal de «Vaciar datos» solo pide convergencia si su borrado se lleva filas puenteadas posteriores a la señal, y esa convergencia re-puentea desde el store local de Grupos. Si el iPad (u otro dispositivo del mismo Apple ID) nunca tuvo sesión de Grupos —o el canal está parado—, no hay `SplitExpense`/`SplitSettlement` locales: la petición se retira sin reponer, el borrado viaja por el espejo personal y en el iPhone los gastos de grupo desaparecen otra vez y ya no vuelven.

Cola A real-risk (pérdida silenciosa permanente de filas de grupo tras wipe remoto tardío en un receptor sin Grupos). Serial A: una sola sesión Yala a la vez. Device-QA pendiente de otros tickets no frena este código. Horario diurno Lima (~19:30–21:00): AskUserQuestion OK solo para acceso/secreto/dispositivo o algo demasiado grave para asumir; para producto/tech elige la opción robusta/recomendada y sigue (norma Frank).

## Decisión de producto (Frank, robusta — no preguntes)
La promesa de #283/#284 debe cumplirse también cuando el receptor tardío no puede converger: tras su wipe, los gastos y liquidaciones de grupo vuelven a lo personal en el parque (una vez; no duplicar dinero).

No basta con que el receptor «pida convergencia» si no tiene filas de Grupos. Quien SÍ puede reponer (origen u otro dispositivo con Grupos / canal vivo) debe hacerlo **después** de que el borrado tardío ya haya quitado las filas — no antes, o el wipe llega encima otra vez.

La opción de una petición ciega por iCloud-KV para que el origen converja ya se midió y descartó en el ticket padre por carrera de orden (origen converge mientras aún tiene las filas; el borrado llega después). Prefiere un diseño en el que el origen (o el capaz) reconverge cuando las filas ya faltan (p. ej. el receptor declara qué ids puenteados se llevó, o el origen detecta la ausencia tras la señal). Mide, elige la receta robusta mínima, documenta la carrera que dejas fuera. No abras `late-remote-wipe-signal-also-wipes-rows-created-after-it` (antigüedad de la señal / lo personal creado después) ni el rediseño completo de `wipe-data-group-rows-return-only-on-the-next-cold-launch` salvo que quede inseparable.

## Qué se pide
Cierra el ticket `tickets/backlog/late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows.md`:
1. Paso 0: mide el camino actual (`wipeLocallyForRemoteWipeSignal`, convergencia, espejo, KV) y fija la receta mínima que cumple el contrato de arriba.
2. Implementa ese camino; tests (unit + mutantes según norma) que fallen sin el arreglo — idealmente el orden «origen ya convergido → receptor sin Grupos procesa la señal tarde → filas de grupo vuelven en el parque una vez».
3. Gate + review adversarial (sync + dinero); PR a `2.1`; merge; ticket a `qa` o `done` según norma; `docs/TICKETS.md` e índice al día.
4. Cierra con `/cerrar-total` (worktree propio). Hallazgos inseparables → backlog; no abras Cola C post-2.1 ni Cola B.

## Qué NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- Cola B UI/UX redesign
- prod Supabase; solo local/staging si toca nube
- No relances otros encargos
- No abras de lleno `late-remote-wipe-signal-also-wipes-rows-created-after-it`, `late-remote-wipe-infers-the-origin-converged-from-row-dates`, ni `wipe-data-group-rows-return-only-on-the-next-cold-launch` salvo inseparables
- No reabras el alcance completo de `groups-detach-ledger-has-no-exit`

## Cómo se sabe que está bien
- Con Grupos solo en el origen: tras «Vaciar datos» + convergencia, un segundo dispositivo sin Grupos que procesa tarde la señal no deja al parque sin los gastos/liquidaciones de grupo en lo personal — vuelven una vez, sin duplicados permanentes de dinero.
- Gate verde; mutantes; PR mergeado a 2.1; ticket movido; `docs/TICKETS.md` al día; `/cerrar-total` hecho.

## MODO AUTÓNOMO (override)
La regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA para este encargo. Implementa de punta a punta hasta gate/PR/merge y cierra con `/cerrar-total` sin preguntar si sigues. Solo AskUserQuestion real de acceso/dispositivo/secreto (horario diurno Lima 6:00–21:00); para producto/tech elige Recommended/robusta tú mismo y sigue. La decisión de producto de arriba ya está tomada.

## Paso 0 (Frank, 2026-09-27)

### Lo medido

- El receptor (`DataWipeService.wipeLocallyForRemoteWipeSignal`) decide por la fecha de sus `TransactionItem`
  puenteadas; en la rama «posterior a la señal» pide la convergencia y borra con `wipeAllUserData`, sin predicado.
- `GroupsBridgeRestoreConvergence.convergeIfPending` re-puentea los `SplitExpense` LOCALES y las liquidaciones
  confirmadas sin pata. Sin grupos locales retira la petición sin crear nada. Confirmado leyendo el código.
- `bridgeExpense` limpia los borradores no opt-in y re-crea; conserva la transacción real (preserve+update).
  `bridgeSettlement` borra TODAS sus transacciones, reales incluidas. El bridge es idempotente sobre filas intactas;
  el único riesgo de dinero es que dos dispositivos re-puenteen el mismo id antes de cruzarse por el espejo.
- El iCloud-KV solo se toca por `OwnerKeyValueStore.shared` (puerta abierta con sesión privada, que es la condición
  para obedecer la señal y para converger). `wipeAllUserData` no borra nada del KV. `OwnerKeyValueWiringTests` fija
  la lista de ficheros que usan la puerta.

### Decisiones

1. **Un solo reponedor por borrado.** El receptor repone él mismo solo si puede con TODO lo que se lleva: bridge
   abierto y un `SplitExpense`/`SplitSettlement` local por cada id que borra. Si le falta uno, no pide su
   convergencia: lo declara al parque. Repartir (él lo suyo, otro lo que le falta) abría el duplicado si su canal
   baja después el gasto que declaró.
2. **La declaración viaja por el iCloud-KV** (key `groupsRowsToReturnAfterRemoteWipe`, JSON): id, fecha, y los ids de
   gasto y de liquidación que se lleva. Se escribe ANTES del borrado (un corte después la perdería); es segura antes
   porque quien repone espera a que falten. Si ya hay una viva, se unen los ids. El receptor la apunta como suya en
   local y no la atiende nunca.
3. **Quien tiene grupos repone cuando las filas ya faltan.** En el arranque, en `retryPendingBridges` detrás de la
   convergencia (mismos gates: import quieto, dominio abierto) y con sesión privada: por cada id declarado que tenga en
   local, que no haya repuesto ya para esa declaración y **sin ninguna `TransactionItem` suya aquí**, re-puentea ESE id.
   Con una fila aún presente espera: el borrado no ha llegado por el espejo. Es la carrera que descartó el ticket
   padre, cerrada por id. Liquidaciones: solo confirmadas y fuera de grupos ocultos, como la convergencia. Lo no
   atendido va a `GroupsPendingBridgeIntent` con canal `.backend`, igual que la convergencia.
4. **Una vez.** Lo repuesto se apunta por declaración en local (`fullModeActivation.remoteWipeReturn.*`, fuera de las
   listas del reset). La declaración caduca a los 30 días; nadie la borra del KV, porque otro dispositivo puede
   necesitarla.
5. **Se reusa `bridgeRemoteExpenses`/`bridgeRemoteSettlements`**, no la convergencia entera: la convergencia es
   de todo el histórico y aquí se repone un delta.

### Asumido, con la carrera que queda fuera

- **Dos dispositivos con grupos más el receptor sin grupos**: los dos atienden la declaración. Duplican solo si los
  dos re-puentean el mismo id en arranques en frío dentro de la ventana del espejo. Residual documentado.
- **Cuota del KV** (1 MB para todo el Apple ID): una declaración de miles de ids puede no escribirse. Se queda como
  hoy (no vuelve), sin techo que recorte en silencio.
- Dos receptores tardíos que declaran a la vez: el KV es último-gana y se pierde una unión. Raro; documentado.
- Sigue siendo en el arranque en frío (`wipe-data-group-rows-return-only-on-the-next-cold-launch`, no se abre).

### Enmienda tras la review adversarial (tres lentes)

La primera versión cayó y se rehízo. Tres decisiones del Paso 0 cambian:

- **Decisión 1 (un solo reponedor) → el receptor converge lo suyo y declara solo lo que le falta.** «Un solo reponedor»
  era falso: el canal de grupos del receptor puentea igual lo que baje después. Y un receptor con grupos que declaraba por
  una fila huérfana dejaba de reponer lo suyo.
- **Decisión 3 (esperar a que no quede ninguna fila del id) → esperar a que falten las filas DECLARADAS.** Un receptor
  que solo había importado parte de las filas del gasto, o un origen que había rehecho la virtual, dejaba el gasto a
  medias para siempre. La huella es `createdAt` más si la fila es de la cuenta de grupos: la hora sola no separa la real
  de la virtual de un mismo gesto.
- **Decisión 2 (unir en una declaración) → una lista de declaraciones, cada una con su id.** Unirlas bajo un id nuevo
  quitaba al primer receptor su marca de «es mía».
- Nuevo: solo atiende una sesión que obedece la señal (privada y en iCloud).
- Queda fuera, con ticket: una liquidación ya aprobada vuelve a preguntar, porque D7 no deja rastro
  (`settlement-approval-leaves-no-trace-so-a-rebridge-asks-again`).
- Re-review del rediseño: el receptor da por suya solo la liquidación que su convergencia repondrá (confirmada, fuera de
  grupos ocultos) y declara solo filas posteriores a la señal. Dos residuales más, documentados: la liquidación de dos
  patas importada a medias y la fila con la cuenta sin hidratar en el receptor.
