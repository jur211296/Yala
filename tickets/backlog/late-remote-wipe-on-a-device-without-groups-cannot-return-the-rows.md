---
id: late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows
status: backlog
priority: medium
area: "groups, sync"
created: 2026-09-27
source: "review adversarial de `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged` (2026-09-27, lente de sync); inferido por lectura, NO reproducido"
---

# Si el dispositivo que procesa tarde el vaciado no tiene Grupos, los gastos de grupo no vuelven

## El síntoma, en lenguaje de usuario

Uso Grupos en el iPhone; en el iPad nunca entré en mi cuenta de grupos. Vacío mis datos en el iPhone y los gastos de
grupo vuelven al abrirlo. Días después abro el iPad: se vacía, y en el iPhone los gastos de grupo desaparecen otra vez y
ya no vuelven.

## Lo medido (2026-09-27, leyendo código)

- Desde el ticket `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`, el receptor que se lleva filas
  puenteadas posteriores a la señal pide la convergencia (`DataWipeService.wipeLocallyForRemoteWipeSignal`).
- El store de Grupos es local de cada dispositivo (`cloudKitDatabase: .none`) y lo llena el canal backend, que necesita
  sesión de la cuenta Yala en ese dispositivo (`GroupsSyncClient.startIfEligible`). Las `TransactionItem` puenteadas sí
  viajan por el espejo personal.
- `GroupsBridgeRestoreConvergence.convergeIfPending` re-puentea solo los `SplitExpense`/`SplitSettlement` locales. Sin
  ninguno, retira la petición igual. `GroupsPendingBridgeIntent` tampoco sirve: da por abandonado un id sin fila local.
- Lo mismo, en parte, con el canal parado (sesión caducada, kill-switch): lo que el receptor aún no conoce no vuelve.

## Qué hay que decidir

Quién repone cuando el receptor no puede. Opción medida y descartada en el ticket padre: una petición por el iCloud-KV
para que la atienda el dispositivo con Grupos. Su orden con el espejo no está garantizado: si el origen converge antes de
recibir el borrado, converge sobre filas que todavía tiene y el borrado llega después. Haría falta que el origen converja
cuando las filas ya faltan (p.ej. comparando contra los ids que le mande el receptor).

## Relacionados

- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]
- [[late-remote-wipe-signal-also-wipes-rows-created-after-it]]
