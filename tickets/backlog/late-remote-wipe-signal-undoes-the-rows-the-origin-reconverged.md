---
id: late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged
status: backlog
priority: medium
area: "groups, sync"
created: 2026-09-27
source: "review adversarial de `wipe-data-keeps-groups-but-drops-their-bridged-rows` (2026-09-27, lente de dinero); inferido por lectura, NO reproducido"
---

# Un dispositivo que procesa tarde la señal de «Vaciar datos» borra lo que el de origen ya repuso

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPhone. Días después abro el iPad, que estaba cerrado: se vacía también (lo esperado), pero en el
iPhone desaparecen otra vez los gastos de grupo que habían vuelto, y ya no vuelven.

## Lo medido (2026-09-27, leyendo código)

- La convergencia solo la pide el dispositivo que pulsó «Vaciar datos» (`DataWipeService.wipePersonalDataKeepingGroups`)
  y la consume en su siguiente arranque. El otro dispositivo, en `ContentView.performLocalWipeForRemoteSync`, borra toda
  `TransactionItem` sin pedir nada, por diseño: la señal solo sale en modo iCloud y las filas repuestas le llegan por el
  espejo.
- Si el otro dispositivo procesa la señal DESPUÉS de que el de origen haya convergido, su borrado se lleva las filas
  repuestas, viaja por el espejo al de origen, y nadie vuelve a pedir la convergencia.
- Que el borrado tardío se lleve datos nuevos ya pasaba antes (no hay comprobación de antigüedad de la señal). Lo nuevo
  es que la promesa del ticket padre no sobrevive a ese orden.

## Qué hay que decidir

¿La señal de vaciado lleva fecha y el receptor la descarta si es vieja, o el receptor también pide la convergencia?

## Relacionados

- [[wipe-data-keeps-groups-but-drops-their-bridged-rows]]
