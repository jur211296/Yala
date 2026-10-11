---
id: private-sign-out-proceeds-with-a-migration-in-flight
status: qa
priority: medium
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-09-27
qa-status: needs-testing
source: "review adversarial de `apple-id-change-boot-check-runs-before-the-migration-guard-can-see` (2026-09-26), lentes de fail-open y de cobertura; previo a ese diff"
---

# Cerrar la sesión privada no comprueba si hay un paso de datos a la nube en marcha

## El problema, en lenguaje de usuario

El aviso de «cambiaste de Apple ID» ya no sale a mitad de una migración a la nube. Pero si la persona cierra la sesión
privada por otro camino —la fila de Perfil, o el botón de un aviso que se ofreció antes de que la migración empezara—,
Yala cierra igual. Cerrar ahí puede borrar lo local mientras sube.

## Por qué pasa (medido el 2026-09-26 con grep; el escenario, inferido)

- Ni `CloudSessionSignOut.swift`, ni `CloudSignOutFlowLogic.swift`, ni `ProfileView.swift` leen `uiState`, `isWorking` ni la
  fase del journal para decidir el cierre privado. La única lectura de `uiState` en `ProfileView` decide si se ve la
  fila de Almacenamiento.
- `AppleIDCloseNoticeView.requestClose` elige la celda por `CloudSyncFlags.storageMode`, que sigue en `.icloud` hasta el
  cutover, y no mira la migración. El aviso puede esperar en la cola del router y contestarse más tarde.
- El guard del aviso automático (`AppleIDChangeCloseLogic.migrationAtRest`) solo protege la OFERTA.

## Criterios de aceptación

- [x] El escritor del cierre privado (no cada pantalla) se para con la migración fuera de reposo, con el mismo predicado
  (`migrationAtRest`) y un motivo propio en el aviso.
- [x] Test del escritor con la migración en vuelo + control positivo en reposo.

## Hecho (2026-09-27)

**Qué cambia para quien usa la app.** Si hay un paso de tus datos entre iCloud y la nube a medias —subiendo, parado, fallido
esperando «Reintentar» o pendiente de reabrir Yala—, «Cerrar sesión» ya no borra nada: sale «No pudimos cerrar tu sesión»
con el motivo y dónde terminarlo. En reposo, el cierre sigue igual.

- **El escritor, no las pantallas.** `CloudSessionSignOut.blockIfMigrationNotAtRest` para el cierre en tres sitios: al
  empezar (antes de subir grupos o esperar a iCloud), al entrar en `finalizeSessionExit` (antes de soltar el canal y la
  sesión; ahí entran los que retoman un cierre bloqueado) y pegado al arm del borrado, sin `await` entre medias. Cubre Ajustes,
  la hoja del cambio de Apple ID y la puerta de Grupos del Welcome, que entran todas por el mismo coordinador.
- **El mismo predicado.** `CloudSignOutFlowLogic.migrationBlockReason` devuelve `nil` exactamente cuando
  `AppleIDChangeCloseLogic.migrationAtRest` dice reposo. Las seis lecturas viven en `MigrationRestReading.live`, que la
  oferta del Apple ID también usa ahora (antes estaban dentro de `AppBootstrapper`).
- **Dos motivos.** `.migrationInFlight` manda a «Dónde viven tus datos», en Perfil. `.migrationUnreadable` (el registro
  de la migración no se lee) manda a cerrar y abrir Yala: con ese estado la fila de Almacenamiento puede estar oculta.
  Textos en los 16 idiomas; el Welcome tiene su propio texto porque allí no hay Perfil.
- **Las tres celdas que borran por archivos**, solo-grupos incluida: la review midió que nada impide migrar desde una sesión
  solo-grupos, y su cierre puede borrar un store que espeja.
- **Una migración fallida también para el cierre**, por ser el mismo predicado. La salida es «Reintentar». Si se decide
  abrir la oferta tras un fallo (`apple-id-change-check-stays-off-after-a-failed-migration`), se abren los dos a la vez.

**Verificado.** `PrivateSignOutMigrationGuardTests` (lógica pura con la equivalencia contra `migrationAtRest` sobre una
rejilla, el escritor por `signOut` con la migración en vuelo y con el registro ilegible, la puerta en reposo como control,
y scans del orden) y el XCUITest
`SessionExitsPerCellUITests.test_privateCell_C_signOutWithTheMigrationNotAtRest_stopsBeforeAnythingAndSaysSo` (seam
`-uitest-migration-journal-unreadable`); su control positivo es el test vecino de la sesión superviviente, que en la misma
celda y sin el seam llega a soltar la sesión.

**Por qué `qa`.** Una subida EN MARCHA no se puede montar en el simulador (no hay CloudKit ni App Attest). Guion: bloque
D del `qa/guion-tanda.md`, paso D7 — con la subida parada al 55 % en modo avión, «Cerrar sesión» no borra nada.
