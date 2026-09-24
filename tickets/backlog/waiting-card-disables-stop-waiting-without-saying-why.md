---
id: waiting-card-disables-stop-waiting-without-saying-why
status: backlog
priority: low
area: "modo-nube, migración, ajustes"
created: 2026-09-23
source: "review adversarial de `adopt-follower-waits-for-the-leader-with-no-ceiling` (2026-09-23), lente de consumidores"
---

# «Dejar de esperar» puede quedarse gris hasta cinco minutos sin que la tarjeta diga por qué

## El problema, en lenguaje de usuario

En Ajustes → Almacenamiento, esperando a que otro teléfono termine de activar la nube, el botón «Dejar de esperar» se
queda deshabilitado mientras iCloud termina de importar, y la tarjeta no lo explica.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

Cada re-kick de 30 s llama a `CloudMigrationController.pollLeader`, que pone `isWorking` y espera la quiescencia del
import hasta 300 s (`awaitImportQuiescenceForResume`). El botón se deshabilita con `isWorking`. La tarjeta de progreso pinta
`resumeWaitingForImport` («esperando a que iCloud termine…»); la de espera (`StorageSettingsView.waitingCard`) no.

## Arreglo propuesto

Pintar el mismo caption en la tarjeta de espera.

## Criterios de aceptación

- [ ] Con el import sin asentar, la tarjeta de espera dice por qué el botón no responde.
