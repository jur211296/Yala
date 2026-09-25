---
id: adopt-with-existing-session-skips-the-unreadable-journal-guard
status: backlog
priority: low
area: "modo-nube, bienvenida, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial de `an-undecodable-migration-phase-reads-as-never-started` (2026-09-25)"
---

# «Activar la nube» desde la bienvenida no comprueba antes que el registro de la migración se deja leer

## El problema, en lenguaje de usuario

«Migrar» y «Volver a iCloud» vuelven a leer el registro de la migración antes de empezar, y si no se deja leer no
empiezan. El adopt de la bienvenida (entrar en una cuenta que ya existe) no lo hace: empieza, el motor de la migración
no hace nada porque el registro no se lee, y la pantalla se queda en la barra al 0 % sin «Cancelar» (que se esconde con
el registro ilegible). Solo sale matando la app.

## Por qué pasa (medido leyendo el código; que sea alcanzable es INFERIDO)

`CloudMigrationController.startMigration` y `startReverse` cortan con `readJournalDecisionInputs() != nil`;
`startAdoptWithExistingSession` no. Antes de `an-undecodable-migration-phase-reads-as-never-started` el runner reseteaba
el registro y «Retomar» volvía a lanzar el adopt; ahora el runner para. En la práctica no se alcanza: una fila escrita
por un build más nuevo implica el onboarding ya completo, y un fetch que lanza es pasajero. Es una asimetría de guards.

## Criterios de aceptación

- [ ] Con el registro ilegible, el adopt de la bienvenida no empieza y la pantalla lo dice o se queda como estaba.
