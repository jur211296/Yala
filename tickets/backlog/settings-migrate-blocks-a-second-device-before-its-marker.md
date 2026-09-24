---
id: settings-migrate-blocks-a-second-device-before-its-marker
status: backlog
priority: medium
area: "modo-nube, settings"
created: 2026-09-16
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (Paso 0 · D14: Jürgen, ticket aparte), 2026-09-16"
---

# El segundo iPhone del mismo iCloud no puede activar la nube hasta que le llega la marca del primero

## El problema, en lenguaje de usuario

Tengo dos iPhones con el mismo iCloud. Activo la nube en el primero. En el segundo, antes de que iCloud le haya traído
la señal de que el primero ya migró, toco «Activar la nube» y entro con la misma cuenta. Yala me para con «Esa cuenta
ya tiene finanzas personales», aunque son mis mismos datos. Hasta hoy seguía y adoptaba la cuenta, que en este caso era
lo correcto.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- La cuenta es `complete` desde el claim del primer iPhone: el `created` del INSERT o de la promoción ya escribe
  `kind = 'complete'` (`qa/cloud/g15_01_account_kind.sql`, `claim_account`), no al terminar la migración.
- La comprobación de «Migrar a la nube» bloquea toda cuenta `complete` que este dispositivo no reclamó
  (`StorageMigrationIdentityGateLogic.check`, `claimedForMigrationHere`), y el claim con la intención de migrar
  devuelve al inicio cualquier `existing_stable` o `claiming_in_progress` (`ForwardClaimIntent.migrateOnly`).
- La tarjeta pasa sola a «Activar en este dispositivo» cuando el espejo de CloudKit trae el `CloudMigrationMarker`
  (`StorageSettingsView.markerDecision()`), y ese camino es el adopt, que no pasa por la comprobación.
- El aviso ya da una salida que funciona: «Para usar los de esa cuenta aquí, cierra sesión y entra con ella».
- **El claim tampoco sigue al líder** (decisión de Jürgen del mismo día, D18): si la comprobación pasó antes de que el
  primer iPhone reclamara la cuenta, el claim del segundo contesta `claiming_in_progress` y «Migrar» vuelve al inicio con
  el mismo aviso, en vez de esperar al líder y adoptar.

## La ventana que no se cierra (segunda pasada de la review, 2026-09-16)

La marca llega solo si el primer dispositivo TERMINA. Dos casos en que no termina nunca, medidos en el código:

- **El líder falla y no reintenta.** Su claim dejó la cuenta `complete` con `migration_in_progress` y él de líder; un
  rollback (iCloud lleno, un fallo antes del cutover) es solo local y no deja marca. El segundo dispositivo se para en la
  comprobación para siempre. En `2.1` su claim le seguía y a los 60 min sin latido le quitaba el turno
  (`claim_account`, rama del relevo). La salida que queda es reintentar en el dispositivo que empezó, y **ningún texto lo
  dice**.
- **El mismo iPhone reinstala Yala a medias.** El sello `.proceedMigration` vive en `UserDefaults` y se va con la app, y el
  `device_id` cambia, así que el servidor ya no le devuelve `created` al líder: se para igual. Guardar el sello donde
  sobreviva a reinstalar (el Keychain, por `sub`) es una de las opciones.

Jürgen eligió parar y avisar también aquí (D18): con iCloud distintos, esperar y relevar mezcla dos corpus, y el teléfono
no puede distinguir los dos casos.

## Por qué no se arregló en el ticket que lo abrió

Distinguir «es mi otro iPhone» de «es la cuenta de otra persona» necesita una prueba de linaje que hoy no existe. **El
faro (`CloudBeacon`) no vale**: dice que la cuenta es de este Apple ID, no que el corpus de este teléfono sea el de esa
cuenta, y también lo escribe el alta born-cloud, que no tiene corpus en CloudKit. Es la misma pregunta que
`adopt-uploads-a-foreign-corpus-without-a-lineage-check`.

## Opciones, sin decidir

- **Decir la verdad sobre la migración en curso**: si la cuenta tiene `migration_in_progress` y el faro nombra esta cuenta,
  decir «Otro de tus dispositivos está llevando tus datos a la nube: termina allí, o reintenta en ese dispositivo» en vez
  de «ya tiene finanzas personales». `/account/exists` no expone `migration_in_progress`: hace falta el gateway. Y «aquí se
  activará cuando termine» sería falso con un líder abandonado.
- **Resolverlo con la guarda de linaje del ticket hermano**, si se diseña una.

## Criterios de aceptación

- [ ] Un segundo dispositivo del mismo iCloud, antes de que llegue la marca, no recibe el aviso de «ya tiene finanzas
      personales», o el caso se decide y se documenta como aceptado.
- [ ] Una cuenta con finanzas de otra persona sigue sin poder recibir la migración.
- [ ] Una migración abandonada por su líder, o por el mismo iPhone tras reinstalar, tiene una salida que el aviso nombra.

## Nota (2026-09-24)

La «guarda de linaje del ticket hermano» existe ya, con dos pruebas: el marcador de la cuenta o una fila viva de la cuenta
en el store local (`MigrationWorkExecutor.lineageSharedLiveRows`, la de la ida y la del adopt desde
`adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`). Es candidata para distinguir aquí «es mi otro iPhone»
de «es la cuenta de otra persona»; no se ha tocado esta puerta. Ojo al reusarla: sin marcador, una fila compartida sola no
basta —`adoptSharedRowsProof` exige además que en cada tabla que sube estén ya todas las filas de la cuenta, o se
duplicarían—. Y este es ahora el hueco que queda del escenario de ese ticket: el segundo teléfono que YA tenía Yala, con
el líder parado tras el cutover del servidor, no llega al adopt desde Ajustes.

