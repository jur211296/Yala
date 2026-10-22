---
id: apple-id-change-boot-check-runs-before-the-migration-guard-can-see
status: done
priority: medium
area: "sesiones, modo-nube"
created: 2026-09-22
updated: 2026-09-27
qa-status: not-replicable
qa-date: 2026-09-27
qa-notes: pide un arranque con una migracion a medias y un Apple ID cambiado a la vez; lo fijan los unit de la logica pura y los scans del orden
source: "review adversarial de `an-unreadable-migration-journal-reads-as-never-started` (2026-09-22), lente de fail-open"
---

# En el arranque, la comprobación del cambio de Apple ID no ve si hay una migración a la nube en marcha

## El problema, en lenguaje de usuario

Si el Apple ID del teléfono cambió, Yala ofrece cerrar la sesión privada. No debe ofrecerlo a mitad de un paso de los
datos a la nube: cerrar ahí puede borrar lo local mientras sube. Esa protección existe, pero en el arranque se consulta
antes de que exista lo que consulta, así que en el arranque no protege nada.

## Por qué pasa (medido el 2026-09-22 en la rama del ticket padre)

- `AppBootstrapper.checkForAppleIDChange(trigger: "boot")` corre en `AppBootstrapper.swift:345`.
- Su guard «no a mitad de una migración» es `(CloudMigrationController.shared?.uiState ?? .idle) == .idle`
  (`AppBootstrapper.swift:1241`).
- `CloudMigrationController.configureShared(context:)` se llama después, en `AppBootstrapper.swift:375`. Hasta entonces
  `shared` es `nil`, el `?? .idle` da `.idle` y el guard deja pasar siempre.
- Los otros disparadores (`identity-notification`) sí ven el controller, y desde el ticket padre un journal ilegible
  cuenta como «no es el momento» (`.journalUnreadable != .idle`).

## Qué habría que decidir

1. Mover el disparador de arranque detrás del paso 14.6, o que el guard lea el journal por su cuenta
   (`MigrationPhaseStore.currentPhaseRead`, que ya distingue la lectura fallida).
2. Qué hace la comprobación cuando no se sabe: el docblock de la función ya dice que el error caro es el falso positivo.

## Criterios de aceptación

- [x] En el arranque, con una fase de migración transitoria journaleada, no se ofrece el cierre.
- [x] Test del orden (el guard ve un controller o el journal) + control positivo sin migración.

## Qué se hizo (2026-09-27)

Se tomaron las dos opciones, no una:

- **El disparo de arranque va detrás del 14.6** (paso 14.65), fuera de su `if`: el controller ya existe y su `init` ha
  pintado `uiState`.
- **El guard lee dos fuentes** (`AppleIDChangeCloseLogic.migrationAtRest`): el controller, si existe (estado `.idle` y
  sin `isWorking`), y el journal (`MigrationPhaseStore.currentPhaseRead`) derivado con la misma función que la pantalla.
  Un journal ilegible no concede.
- **El guard se vuelve a mirar tras el `await` a CloudKit**, antes de decidir: el `resumeIfNeeded` del 14.6 corre
  durante ese viaje. Lo trajo la review.

Tests: `AppleIDChangeMigrationAtRestTests` (24 fases fuera de reposo sin controller, ilegible, relanzamiento pendiente,
controller ocupado, cada fuente por su lado, controles positivos) y dos scans nuevos en `AppleIDChangeWiringTests`
(orden y nivel del disparo; forma del guard, antes del flag «en vuelo» y otra vez tras el `await`).

Hallazgos de la review con ticket propio: `private-sign-out-proceeds-with-a-migration-in-flight`,
`apple-id-change-check-stays-off-after-a-failed-migration` y
`apple-id-change-boot-check-is-lost-when-the-journal-is-unreadable-at-launch`.
