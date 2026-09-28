---
id: late-remote-wipe-signal-also-wipes-rows-created-after-it
status: done
updated: 2026-09-28
priority: medium
area: "sync, settings"
created: 2026-09-27
source: "encargo `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged` (2026-09-27); inferido por lectura, NO reproducido"
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 sin device-QA - pide dos dispositivos con el mismo Apple ID; cubierto por RemoteWipeCutTests
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

## Lo decidido (2026-09-28, encargo nocturno)

El receptor borra solo lo que existía al vaciar. Es lo más fiel a lo que promete «Vaciar datos» en los demás
dispositivos: vaciar lo que había, no lo que la persona hizo después en otro.

## Lo que cambia para el usuario

- El iPad que se entera tarde del vaciado se vacía igual, pero **ya no se lleva los gastos, cuentas, categorías,
  etiquetas, presupuestos, favoritos, pagos programados, planes ni avisos que el iPhone creó después**, y su borrado no
  viaja al iPhone.
- Una cuenta o categoría vieja se queda solo si la usa algo nuevo; la semilla nueva del origen se queda en cuanto hay
  prueba de que alguien empezó de nuevo (la marca del onboarding o cualquier fila personal nueva en el store).
- Los avisos de lo que se queda se vuelven a programar en el momento, sin esperar al arranque siguiente.
- Lo de grupos sigue como desde el 27-sep: el receptor tardío pide su convergencia. Ya no declara nada al parque.

## Cómo está hecho

`DataWipeService.wipeLocallyForRemoteWipeSignal` pasa un corte (`RemoteWipeCutLogic`) a `wipeAllUserData`, que borra lo
que elige `rowsToWipe`. Detalle y las siete cosas que no se tocan: `.claude/rules/swiftdata-cloudkit.md`, regla «El
receptor tardío de "Vaciar datos" se lleva solo lo que existía al vaciar».

Verificado: tests de comportamiento contra un store real (`RemoteWipeCutTests`, incluido que el History no registra
ninguna escritura en lo que se queda), review adversarial de tres lentes (datos/sync, grupos, tests) y mutantes. La
review cambió tres cosas de la primera versión: la evidencia de vida nueva, que borradores y memorias no protejan, y
mantener la petición de convergencia de #284.

## Guion de device-QA (dos dispositivos con el mismo Apple ID, modo iCloud)

No frena el merge. Hace falta un iPhone y un iPad (o dos iPhone) con la misma cuenta de iCloud y Yala en modo iCloud.

1. En el iPad, abre Yala y comprueba que ves tus gastos. Ciérralo del todo (deslizar hacia arriba en el selector de
   apps) y activa el modo avión en el iPad.
2. En el iPhone: Perfil → «Vaciar datos» (la última fila de la sección de datos) → confirma. Completa el onboarding de nuevo y crea una cuenta
   «Prueba QA».
3. En el iPhone, apunta dos gastos en «Prueba QA» (por ejemplo «Café QA» 5 y «Taxi QA» 12). Espera un minuto con la app
   abierta.
4. En el iPad, quita el modo avión y abre Yala. Debería vaciarse lo viejo y enseñar el aviso de restauración.
5. **Pasa si**: en el iPad ves «Prueba QA» con «Café QA» y «Taxi QA», y NO ves los gastos de antes del vaciado.
6. Vuelve al iPhone y espera un minuto. **Pasa si** «Café QA», «Taxi QA» y la cuenta «Prueba QA» siguen ahí. Antes de
   este cambio desaparecían.

## Tickets que salieron de aquí

- [[late-remote-wipe-return-has-no-producer-left]]
- [[late-remote-wipe-cut-keeps-what-it-cannot-date-until-the-mirror-decides]]
- [[late-remote-wipe-survivors-can-point-at-rows-the-origin-deleted]]
- [[a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere]]

## Relacionados

- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]
- [[remote-wipe-receiver-has-no-behaviour-test]]

## Barrido de `qa` · 2026-09-28 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). El guion pide dos dispositivos con el mismo Apple ID, uno de ellos en modo avión mientras el otro vacía. Lo cubre `RemoteWipeCutTests`.
