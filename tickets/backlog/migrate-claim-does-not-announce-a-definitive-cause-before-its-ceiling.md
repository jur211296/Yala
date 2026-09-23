---
id: migrate-claim-does-not-announce-a-definitive-cause-before-its-ceiling
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-23
updated: 2026-09-23
source: "Paso 0 de `adopt-claim-stays-parked-with-no-ceiling` (2026-09-23), D4"
---

# Al migrar a la nube, si tu sesión se borra en el paso del 22 %, no te lo dice hasta pasados 15 minutos

## El problema, en lenguaje de usuario

Toco «Migrar a la nube» y la barra se para al 22 %. Si el motivo es que mi sesión se borró o que la cuenta no me deja
entrar, la tarjeta solo dice «Activando la nube…» con «Retomar» y «Cancelar la activación». A los 15 minutos sale la
tarjeta de fallo con el motivo. Hasta entonces no sé que esperar no sirve.

## Por qué pasa

`adopt-claim-stays-parked-with-no-ceiling` añadió el aviso del motivo definitivo en la tarjeta de progreso, pero **solo
para el claim de un adopt** (`AdoptClaimScope.notice`), porque el ticket era del adopt. El claim de «Migrar» mide la
misma causa en el mismo reloj (`MigrationState.forwardStepStallCauseRaw`), así que el dato ya está.

## Qué habría que decidir

1. ¿El mismo aviso en «Migrar»? Los textos del adopt dicen «vuelve a entrar con tu cuenta» y «tu cuenta no permite
   entrar»; para «Migrar» valdrían casi igual, pero conviene leerlos contra `docs/planning/BRAND-VOICE.md`.

## Criterios de aceptación

- [ ] Decisión de Jürgen.
- [ ] Si se hace: el predicado sale de `AdoptClaimScope.notice` a uno de la fase, con su test.
