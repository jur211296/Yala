---
id: adopt-effect-after-the-cloud-mode-retries-silently
status: backlog
priority: low
area: "modo-nube, migración, adopt"
created: 2026-09-23
updated: 2026-10-08
source: "review adversarial de `adopt-effect-retries-forever-with-no-ceiling` (2026-09-23), lente de relojes"
---

# Si la app muere justo al terminar de entrar en tu cuenta, puede quedarse sin sincronizar diciendo que todo va bien

## El problema, en lenguaje de usuario

Un cierre de la app en una ventana de milisegundos al final de la activación deja el teléfono ya en la nube, pero con el
último paso pendiente. Almacenamiento dice que todo está sincronizado y la sincronización no arranca hasta que ese paso
termine, que se reintenta sin techo y sin aviso.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

Un kill entre `writeCloudArmed` (paso 5 de `runAdoptFlow`) y el save que retira `.adoptBackendAccount` relanza con
`.cloud` + el pendiente. `AdoptEffectScope` lo excluye del techo y de «Cancelar» a propósito —salir a `failedRollback`
dejaría `.cloud` en un terminal de fallo— y `CloudMigrationUIStateDeriver` pinta `.cloudActive`, mientras
`startRuntimeIfStable` no arranca el motor con un pendiente. Existía antes de `adopt-effect-retries-forever-with-no-ceiling`.

## Qué habría que decidir

¿Qué ve la persona en ese estado, y hay que darle techo con otra salida que no sea `failedRollback`?

## Medido en 2.1 (triage 2026-10-08)

- `AdoptEffectScope.isPending` (`MigrationRunner.swift`) sigue exigiendo `!persistedCloudMode`: con `.cloud` + `.adoptBackendAccount` pendiente no hay techo ni «Cancelar».
- `CloudMigrationUIStateDeriver.derive` (`CloudMigrationController.swift`) sigue devolviendo `.cloudActive` para `.cloud` + `notStarted`, y `startRuntimeIfStable` sigue sin arrancar el motor con un efecto pendiente.
- Decisión pendiente. A) pintar «terminando de entrar en tu cuenta» en vez de `.cloudActive` mientras quede el efecto, sin techo; B) además un techo con aviso y «Reintentar» que no salga a `failedRollback`; C) dejarlo. Recomendada: A, que quita la mentira de la UI sin inventar otra salida; con ella sigue `low` por la ventana de milisegundos.

Triage 2026-10-08: abierto · low → low · la exclusión con modo `.cloud` y el `.cloudActive` del deriver siguen igual; solo se alcanza con un kill en una ventana de milisegundos.
