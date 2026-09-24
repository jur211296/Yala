---
id: welcome-cloud-replay-marks-born-cloud-without-the-guard
status: backlog
priority: low
area: "modo-nube, onboarding"
created: 2026-09-24
source: "review adversarial de `claim-promotion-lost-response-blocks-the-retry` (2026-09-24), lente de consumidores"
---

# El alta en la nube que ahora siembra en una cuenta vacía propia se salta la comprobación de «cuenta distinta»

## Qué cambia, en lenguaje de usuario

Desde el 2026-09-24, si el mismo teléfono ya tenía una cuenta en la nube vacía (creada o migrada sin datos) y
vuelve a «Es mi primera vez → Tu cuenta en la nube», Yala la da de alta como nueva en vez de «entrar en ella».
No hay nada que mezclar —la cuenta está vacía—, pero ese camino no pasa por la comprobación de cuenta
distinta de la re-entrada y marca la cuenta como nacida en la nube.

## Por qué importa (inferido, no medido)

- Con `existing_stable`, el Welcome iba por `runSignInFlow` (guard cross-cuenta, restauración en curso). Con
  `created` va directo a `activateBornCloudStorage` y `StorageModePersistence.markBornCloud`.
- `markBornCloud` abre «Volver a iCloud» sin exigir el mapa de coordenadas de CloudKit. Si ese teléfono SÍ tuvo
  zona en iCloud (una migración de un corpus vacío), la vuelta se ofrecería sin el mapa. Dura hasta la primera
  subida; no se ha medido si el consentimiento o las preferencias suben antes.

## Criterios de aceptación

- [ ] Medido si existe un teléfono con zona previa que llegue a este camino.
- [ ] Si existe: el alta repetida no marca born-cloud, o la vuelta sigue exigiendo el mapa.
