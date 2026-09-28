---
id: late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged
status: qa
priority: medium
area: "groups, sync"
created: 2026-09-27
updated: 2026-09-27
qa-status: needs-testing
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

## Decisión (Frank, 2026-09-27, en el encargo)

El receptor de la señal también pide la convergencia. La review adversarial la acotó: **solo cuando su borrado se lleva
filas que el origen ya repuso**, y la prueba es la fecha. Pedir siempre abría un duplicado nuevo de dinero.

## Qué cambia para el usuario

Vacío mis datos en el iPhone y los gastos de grupo vuelven al abrirlo. Si después abro el iPad, que estaba cerrado, se
vacía como antes, y en su siguiente arranque en frío los gastos y las liquidaciones de grupo vuelven a lo personal, una
vez, y llegan también al iPhone. Si el iPad procesa el vaciado enseguida, antes de que el iPhone reponga nada, no pide
nada: lo repone el iPhone y le llega por iCloud, sin copias dobles.

## Qué se hizo

- `DataWipeService.wipeLocallyForRemoteWipeSignal(in:signaledAt:)` es el borrado del receptor
  (`ContentView.performLocalWipeForRemoteSync`), con la hora de la señal que procesa. Mira las `TransactionItem`
  puenteadas (`splitExpenseID` o `splitSettlementID`): si alguna es posterior a la señal, borra por
  `wipePersonalDataKeepingGroups(broadcastSignal: false)`, que pide la convergencia y la de las liquidaciones antes de
  borrar. Si no, borra como antes. Nunca re-emite la señal.
- Por qué la fecha (review, lentes de dinero y sync): la convergencia re-puentea TODOS los gastos de grupo y las
  liquidaciones sin pata, no un delta. Si los dos dispositivos convergen antes de cruzarse por el espejo, cada gasto sale
  dos veces, con dos borradores; aprobados, cuenta doble. Una fila posterior a la señal es casi siempre la reposición
  del origen, que ya consumió su petición: con eso converge solo el receptor. Es un indicio y no una prueba (también la
  crea el sync de grupos nuevo): ver el ticket de abajo. Sin hora de señal no pide.
- El libro de conservados al desasociar ya lo retiraba `wipeAllUserData` en cualquier alcance (#283). La marca de sesión
  privada no se toca, así que la convergencia corre aunque la persona vuelva al Welcome.

## Verificado

- Unit: el orden del ticket (el origen convergió → el receptor borra tarde → vuelven una vez), solo una liquidación
  repuesta, el orden normal (no pide), la petición sobrevive al reset de preferencias en `.standard` y no re-emite la
  señal, el corte estricto con sus dos vecinos, y el scan del cableado en `ContentView` (hora de la señal incluida).
- Gate: builds Yala y Yala Dev, 614 unit en 72 suites, 5 XCUITest (aviso de vaciado remoto y Perfil) con el centinela solo.
- Mutantes 10/10 del diseño final (siempre pide, nunca pide, corte no estricto, sin liquidaciones en la prueba, re-emite la
  señal, el reset se lleva la petición, `ContentView` a pelo, hora ajena, sin la petición de liquidaciones, sin el guard de
  hora 0).
- Review adversarial de tres lentes y una re-review del rediseño. La primera versión (pedir siempre) duplicaba dinero; se
  cambió al criterio de la fecha. Hallazgos no inseparables, a backlog.

## Fuera, con ticket

- Un receptor sin el dominio de Grupos no puede reponer: `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`.
- La señal sin fecha se lleva también lo personal creado después: `late-remote-wipe-signal-also-wipes-rows-created-after-it`.
- La fecha como indicio (sync de grupos nuevo con el origen aún pendiente; borradores que llegan antes que su
  transacción): `late-remote-wipe-infers-the-origin-converged-from-row-dates`.
- La reposición espera al arranque en frío del receptor, y la ventana de la liquidación aprobada en el origen: nota en
  `wipe-data-group-rows-return-only-on-the-next-cold-launch`.

## Guion de device-QA (opcional; hacen falta dos dispositivos con el mismo Apple ID, en modo iCloud y sesión privada)

1. En los dos, entra en tu cuenta de grupos. Crea un grupo con un gasto que pagues tú y una liquidación confirmada.
2. Cierra la app en el iPad (desde el selector de apps) y déjalo sin abrir.
3. En el iPhone: Perfil → Ajustes → «Vaciar datos», conservando los grupos. Cierra la app del todo y vuelve a abrirla:
   el gasto y la liquidación deben estar en Registros, y el Inbox pregunta la cuenta.
4. Espera un par de minutos con el iPhone abierto (que suba a iCloud).
5. Abre el iPad: se vacía. Cierra la app del iPad del todo y vuelve a abrirla.
6. Comprueba en el iPad y, pasado un minuto, en el iPhone: el gasto y la liquidación de grupo están, una sola vez cada
   uno, y el Inbox tiene un borrador por cada uno, no dos.
