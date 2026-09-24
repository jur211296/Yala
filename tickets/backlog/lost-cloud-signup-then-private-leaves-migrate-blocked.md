---
id: lost-cloud-signup-then-private-leaves-migrate-blocked
status: backlog
priority: low
area: "modo-nube, onboarding"
created: 2026-09-24
source: "review adversarial de `claim-promotion-lost-response-blocks-the-retry` (2026-09-24), lente de consumidores"
---

# Si pierdes la respuesta del alta en la nube y eliges iCloud, luego «Migrar a la nube» te bloquea

## El síntoma, en lenguaje de usuario

Empiezo con «Tu cuenta en la nube», se corta la red al crearla y cambio de idea: vuelvo y elijo «Tu iCloud
privado». Semanas después, en Almacenamiento, toco «Migrar a la nube» con la misma cuenta: «Esa cuenta ya tiene
finanzas personales». No las tiene.

## Por qué pasa (medido en código, no reproducido)

- El alta perdida dejó la cuenta `complete` y vacía en el servidor.
- «Migrar» pasa por `StorageMigrationIdentityGateLogic`, que bloquea una cuenta `complete` sin el sello
  `.proceedMigration` de este teléfono; y su claim va con `migration: true`, que la rama de `qa/cloud/g16_01_…`
  excluye a propósito (una migración con `created` conduciría una máquina sin lease).
- No es una regresión de g16_01: ya pasaba antes.

## Alcance

- Decidir si una cuenta `complete` SIN ninguna escritura personal y con este teléfono de líder puede tratarse
  como propia en la puerta de «Migrar» (la misma señal del contador, por `/account/exists` o por el claim).

## Criterios de aceptación

- [ ] Alta en la nube perdida + iCloud privado + «Migrar a la nube» con la misma cuenta → migra.
- [ ] Una cuenta `complete` con datos sigue bloqueando «Migrar».
