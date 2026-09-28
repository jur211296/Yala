---
id: activation-start-fresh-drops-group-settlement-legs
status: done
priority: medium
area: "groups, onboarding"
created: 2026-09-27
updated: 2026-09-28
source: "review adversarial de `activation-private-gate-leaves-a-late-notice-that-purges-groups` (2026-09-27, lente «después del borrado»); inferido por lectura, NO reproducido"
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 sin device-QA - pide una liquidacion confirmada por otra persona y un camino compuesto; cubierto por GroupsBridgeRestoreConvergenceTests
---

# «Activar Yala completo → Restaurar → Empezar desde cero» pierde las liquidaciones de grupo en lo personal

## El síntoma, en lenguaje de usuario

Activo Yala completo, entro en Restaurar y elijo «Empezar desde cero». Mis grupos y sus saldos siguen bien, pero en mis
cuentas personales los cobros y pagos de grupo que ya había liquidado desaparecen: la cuenta de grupos cuenta lo que
presté sin descontar lo que ya me devolvieron.

## Lo medido (2026-09-27, leyendo código)

- El borrado es `.importedRows`: `DataWipeService.wipeAllUserData` borra toda `TransactionItem`, también las patas de
  liquidación (`splitSettlementID`).
- Después solo se pide `GroupsBridgeRestoreConvergenceStore.markPending()` (`ContentView`,
  `performICloudZoneAndImportedRowsWipe`), y esa convergencia re-puentea solo GASTOS
  (`GroupsBridgeRestoreConvergence.convergeIfPending`, `settlementIDs: []`). Las patas de liquidación solo vuelven si un
  sync cambia esa liquidación.
- El aviso tardío de quien activó tiene el mismo borrado y ya las re-arma (`armSettlementLegsAfterLateWipe`, ticket
  `activation-private-gate-leaves-a-late-notice-that-purges-groups`). Aquí no se copió porque la sesión todavía es
  solo-grupos: re-puentear una liquidación en esa sesión puede crear la forma de solo-grupos, que la convergencia de
  después no sabe fundir. Hay que decidir cuándo pedirlo (¿tras `completeFullActivation`?).

## Criterios de aceptación

- [x] Tras «Empezar desde cero» dentro de la activación, las liquidaciones confirmadas vuelven a lo personal.
- [x] Ninguna liquidación sale dos veces.

## Relacionados

- [[activation-private-gate-leaves-a-late-notice-that-purges-groups]]

## Decisión (2026-09-27, MODO AUTÓNOMO)

**El «cuándo» es la convergencia, que ya espera a que la sesión sea privada.** El borrado deja pedida, además de la
convergencia de gastos, la de las liquidaciones (`GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending()`), y
`GroupsBridgeRestoreConvergence.convergeIfPending` las re-puentea detrás de su guard de `hasPrivateSession`: en el
arranque siguiente a completar la activación, junto a los gastos.

- **No «tras `completeFullActivation`» a mano**: la activación no converge en su plan de `.freshPrivate`, y un corte entre
  el eje y ese paso dejaría la petición sin nadie que la consuma. La convergencia es durable y ya tiene el guard.
- **No armando `GroupsPendingBridgeIntent` al borrar** (lo que hacía el aviso tardío): su retome del arranque no espera a
  la sesión privada. Tras un corte antes de completar la activación, el bridge crearía la pata virtual SIN el borrador de
  «¿de qué cuenta?» y la daría por atendida.
- **Un solo camino**: el aviso tardío deja de armar la intención (`armSettlementLegsAfterLateWipe` se retira) y pide lo
  mismo. Allí la sesión ya es privada, así que el momento no cambia: el arranque siguiente, en el mismo `retryPendingBridges`.
- **Solo las que se quedaron sin ninguna pata.** Cualquier pata dice que el sync la re-puenteó después del borrado. El
  primer diseño excluía solo las que tenían una pata real, y la review lo tumbó: aprobar un borrador de liquidación crea
  la transacción real SIN `splitSettlementID` (`DraftService`, D7), así que re-puentear esa liquidación sacaba otro
  borrador del mismo pago. Una liquidación re-puenteada en solo-grupos en esa ventana se queda con esa forma, como
  cualquier otra puenteada en solo-grupos antes de activar.
- **El relevo de persona retira las dos peticiones** (`removeGroupsDomainPreferenceKeys`): las pidió un borrado del
  humano anterior.

## Qué cambia para el usuario

Quien activa Yala completo, entra en Restaurar y elige «Empezar desde cero» conserva sus grupos y, desde el arranque
siguiente a terminar la activación, recupera en lo personal sus liquidaciones de grupo: la cuenta de grupos vuelve a
descontar lo ya cobrado o pagado, y en el Inbox le espera la pregunta de a qué cuenta llegó o de cuál salió cada una.
Lo mismo con «Empezar de cero» del aviso «Encontramos datos tuyos en iCloud».

## Verificado

- Unit: `YalaTests/GroupsBridgeRestoreConvergenceTests` contra el bridge real y el `wipeAllUserData` real (borrado →
  un arranque en solo-grupos espera → con sesión privada vuelven, una por liquidación, sin duplicar en una segunda
  convergencia; sin la petición no se re-puentean; un borrador aprobado después del borrado no vuelve a salir; la no
  atendida va a la intención con canal backend), `GroupsPendingBridgeWiringTests.theHandover_sweepsTheConvergenceRequests`
  y los scans de `ActivationRestoreDiscardTests`, `ActivationLateNoticeKeepsGroupsTests` y `FullModeActivationWiringTests`.
- Mutantes: 10/10 muertos en la tanda final (sin la petición, re-puentear todas, no re-puentear, `clear` a medias, la
  activación sin pedirlas, el aviso tardío sin pedirlas, orden invertido, lo no atendido perdido, sin filtro de
  confirmadas, el relevo sin retirar).
- Review adversarial de tres lentes. La de dinero y la de momento cazaron por separado el mismo fallo del primer diseño
  (el borrador aprobado sale otra vez): arreglado aquí con el criterio «sin ninguna pata». La de reglas cazó el borrado
  real ejecutado en un test sin aislamiento (arreglado) y un scan asimétrico (arreglado). Fuera de alcance, a backlog:
  `wipe-data-keeps-groups-but-drops-their-bridged-rows`, `groups-convergence-retries-every-launch-without-a-ceiling`, y
  una nota en `groups-detach-ledger-has-no-exit`.

## Guion de QA en iPhone (opcional; no bloquea)

Hace falta un Apple ID con datos viejos de Yala en iCloud y una sesión solo-grupos con un grupo donde haya al menos una
liquidación confirmada (tú pagas a alguien o alguien te paga).

1. Con Yala en solo-grupos, entra en Grupos → «Activar Yala completo» → privado. La puerta encuentra tus datos de
   iCloud: toca «Traer mis datos».
2. Tras el relanzamiento, en Restaurar toca «Empezar desde cero» y confirma el borrado dos veces.
3. Termina el onboarding personal.
4. Cierra Yala del todo (deslizar hacia arriba en el selector de apps) y ábrela.
5. **Comprueba**: en la cuenta de grupos aparece cada liquidación confirmada una sola vez, y el saldo descuenta lo ya
   cobrado o pagado; en el Inbox hay un borrador por cada liquidación que te pagaron, pidiendo la cuenta.
6. Cierra y abre Yala otra vez: nada se duplica.

## Barrido de `qa` · 2026-09-28 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). Pide una liquidación confirmada, que necesita a otra persona con la app, y el camino compuesto «Activar Yala completo → Restaurar → Empezar desde cero». Lo cubren `GroupsBridgeRestoreConvergenceTests` contra el bridge y el borrado reales (10/10 mutantes).
