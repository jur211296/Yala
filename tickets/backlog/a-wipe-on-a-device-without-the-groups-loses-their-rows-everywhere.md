---
id: a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere
status: backlog
priority: medium
area: "groups, sync"
created: 2026-09-28
source: "review adversarial de `late-remote-wipe-signal-also-wipes-rows-created-after-it` (lentes de grupos y de sync, 2026-09-28); inferido leyendo código, NO reproducido"
---

# «Vaciar datos» en un dispositivo sin los grupos deja al resto sin los gastos de grupo

## El síntoma, en lenguaje de usuario

Uso los grupos en el iPhone. En el iPad, que nunca entró en Grupos, pulso «Vaciar datos» para empezar de nuevo. En el
iPhone desaparecen de mis cuentas los gastos y las liquidaciones de grupo, y no vuelven.

## Lo medido (2026-09-28, leyendo código)

- «Vaciar datos» borra toda `TransactionItem`, también las que el bridge puso en lo personal, y pide la convergencia
  para reponerlas (`DataWipeService.wipePersonalDataKeepingGroups`). La convergencia re-puentea desde el store LOCAL de
  Grupos (`GroupsBridgeRestoreConvergence.convergeIfPending`), que no viaja por iCloud (`cloudKitDatabase: .none`).
- Un origen que no tiene esos grupos —nunca entró, o tiene el canal parado— converge sobre nada. Su borrado viaja por
  el espejo al iPhone.
- El iPhone recibe la señal. Si la procesa ANTES de que haya nada de grupo posterior a la señal (el orden normal), no
  pide la convergencia (`remoteWipeTakesRowsTheOriginReconverged` sale `false`): lo que se lleva lo da por repuesto por
  el origen, que no lo va a reponer.
- En el orden tardío sí lo cubre: con una fila de grupo posterior, el receptor pide su convergencia y re-puentea sus
  grupos (desde el 2026-09-27, mantenido el 2026-09-28).

Es el espejo de `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows` (el RECEPTOR sin grupos).

## Qué hay que decidir

Quién sabe que el origen no tiene esos grupos. Una salida: el origen escribe en la señal si su convergencia puede
reponer (tiene grupos y el canal vivo), y el receptor con grupos pide la suya cuando el origen dice que no. Pedir
siempre ya se descartó el 27-sep: dos convergencias que se cruzan antes que el espejo duplican.

## Relacionados

- [[late-remote-wipe-signal-also-wipes-rows-created-after-it]]
- [[late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows]]
- [[wipe-data-keeps-groups-but-drops-their-bridged-rows]]
