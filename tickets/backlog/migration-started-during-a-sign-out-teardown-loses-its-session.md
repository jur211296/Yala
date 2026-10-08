---
id: migration-started-during-a-sign-out-teardown-loses-its-session
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-10-08
source: "review adversarial de `private-sign-out-proceeds-with-a-migration-in-flight` (2026-09-27)"
---

# Una migración que arranca mientras se cierra la sesión se queda sin la sesión que usa

## El problema, en lenguaje de usuario

El cierre de la sesión mira la migración al empezar, al entrar en su tramo final y pegado al borrado. Entre el segundo y el
tercero desmonta el canal y suelta la sesión en la nube. Si justo ahí arranca una migración (o un adopt con la sesión de
Grupos), el cierre se para sin borrar nada, pero la migración ya no tiene sesión y se queda pidiendo volver a entrar.
INFERIDO: no se midió si la interfaz deja llegar a «Migrar» con el cierre en `.working`.

## Medido (2026-09-27)

- `CloudMigrationController.startMigration` (`CloudMigrationController.swift:667`) no mira `CloudSessionSignOut.shared.phase`.
- `finalizeSessionExit` suelta canal y sesión entre la puerta de entrada y la del arm (`CloudSessionSignOut.swift`).

## Criterios de aceptación

- [ ] Medido si «Migrar», «Activar la nube» o el adopt son alcanzables con el cierre trabajando. Si lo son, la entrada de la
  migración espera o se niega mientras `phase != .idle`.

## Medido en 2.1 (triage 2026-10-08)

- `CloudMigrationController.startMigration(consentPath:signIn:)` no lee la fase del cierre: las dos menciones a `CloudSessionSignOut` en ese fichero son de otros caminos. `StorageSettingsView` tampoco la lee.

Triage 2026-10-08: abierto · low → low · `CloudMigrationController.startMigration` sigue sin mirar `CloudSessionSignOut.shared.phase`; sigue sin medir si la interfaz deja llegar a «Migrar» con el cierre trabajando.
