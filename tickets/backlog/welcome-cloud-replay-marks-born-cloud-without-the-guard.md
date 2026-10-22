---
id: welcome-cloud-replay-marks-born-cloud-without-the-guard
status: backlog
priority: low
area: "modo-nube, onboarding"
created: 2026-09-24
updated: 2026-10-08
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

## Medido en 2.1 (triage 2026-10-08)

- `BornCloudSignUpService.activateBornCloudStorage` sigue llamando a `StorageModePersistence.markBornCloud` sin condición (~382).
- `028c5e3df` (g16_02, 2026-09-24) solo cierra el replay de `created` cuando OTRO teléfono adoptó (`personal_adopted_at`); el caso de este ticket —mismo teléfono, cuenta propia vacía tras migrar un corpus vacío— sigue igual.
- El paso de medir si existe un teléfono con zona previa que llegue aquí sigue sin hacer.

Triage 2026-10-08: abierto · low → low · el camino sigue marcando born-cloud sin la comprobación, pero hace falta una migración de un corpus vacío previa.
