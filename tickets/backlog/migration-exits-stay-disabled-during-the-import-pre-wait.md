---
id: migration-exits-stay-disabled-during-the-import-pre-wait
status: backlog
priority: low
area: "modo-nube, settings, onboarding"
created: 2026-10-19
updated: 2026-10-19
source: "review adversarial de `cloud-activation-waits-for-icloud-with-no-way-out` (2026-10-19)"
---

# «Dejar de esperar» y el «Cancelar» del adopt en el Welcome siguen apagados mientras se espera a iCloud

## En lenguaje de usuario

Mientras Yala espera a que iCloud se asiente, en Almacenamiento ya puedo cancelar la activación. Pero si estoy esperando a otro de mis dispositivos («Dejar de esperar») o activando la nube desde la bienvenida, el botón de salir sigue apagado durante esa espera.

## Lo medido (leído en el código, 2026-10-19)

- `cloud-activation-waits-for-icloud-with-no-way-out` habilitó «Cancelar la activación» durante la pre-espera del import (`MigrationImportWaitLogic.cancelEnabled`).
- «Dejar de esperar» (`StorageSettingsView`, la espera del seguidor, pre-espera de `pollLeader`) y el «Cancelar» del adopt en la bienvenida (`WelcomeCloudSignInView`) siguen con `isDisabled: isWorking`, que es `true` durante la misma pre-espera.

## Lo que habría que hacer

Llevar el mismo criterio a los dos, con el corte de la pre-espera que ya tiene `cancelMigration`.
