---
id: late-remote-wipe-signal-also-wipes-rows-created-after-it
status: backlog
priority: medium
area: "sync, settings"
created: 2026-09-27
source: "encargo `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged` (2026-09-27); inferido por lectura, NO reproducido"
---

# Un dispositivo que procesa tarde la señal de «Vaciar datos» también borra lo personal creado DESPUÉS

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPhone y empiezo de nuevo: apunto gastos durante unos días. Abro el iPad, que estaba cerrado desde
antes del vaciado: se vacía (lo esperado), pero su borrado viaja por iCloud y se lleva también los gastos nuevos que
había apuntado en el iPhone.

## Lo medido (2026-09-27, leyendo código)

- La señal es un timestamp en el iCloud-KV del Apple ID (`PreferenceSyncService.signalWipeInitiated`, key
  `lastWipeTimestamp`). El receptor solo compara `remoteWipe > localWipe` para saber si es nueva; no la compara con la
  fecha de lo que va a borrar.
- `ContentView.performLocalWipeForRemoteSync` borra toda `TransactionItem` sin predicado, y en modo iCloud el borrado se
  exporta por el espejo.
- Desde el 2026-09-27 el receptor pide la convergencia de grupos, así que los gastos y liquidaciones de GRUPO vuelven
  (ticket `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`). Lo personal creado tras la señal, no.

## Qué hay que decidir

¿El receptor borra solo lo anterior a la señal (`createdAt` ≤ timestamp), descarta una señal más vieja que un umbral, o
pregunta antes de borrar si encuentra filas posteriores? Cada opción cambia qué promete «Vaciar datos» en los demás
dispositivos.

## Relacionados

- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]
- [[remote-wipe-receiver-has-no-behaviour-test]]
