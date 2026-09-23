---
id: apple-id-change-boot-check-runs-before-the-migration-guard-can-see
status: backlog
priority: medium
area: "sesiones, modo-nube"
created: 2026-09-22
updated: 2026-09-22
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

- [ ] En el arranque, con una fase de migración transitoria journaleada, no se ofrece el cierre.
- [ ] Test del orden (el guard ve un controller o el journal) + control positivo sin migración.
