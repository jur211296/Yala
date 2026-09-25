---
id: markerless-adopt-without-full-coverage-never-relays-the-marker
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-09-25
source: "residual de `markerless-adopt-stays-blocked-while-another-device-writes-to-the-account` (2026-09-25), review adversarial, lente de reglas"
---

# El primer adoptador sin todas las filas de la cuenta no releva el marcador, y los siguientes siguen fuera

## El problema, en lenguaje de usuario

El iPhone activó la nube pero nunca dejó su marca en iCloud. El iPad entró en la cuenta, y antes de entrar yo había borrado
en él un movimiento del iPhone. El iPad escribe en la nube a diario. Mi Mac, con el mismo iCloud y algo propio que subir,
nunca entra: cada intento acaba en «espera a iCloud».

## Lo medido (2026-09-25, en el código)

- El relevo (`MigrationWorkExecutor.relayAdoptMarkerIfCovered`) exige cobertura total, `adoptCoverageComplete`: toda fila
  viva del backend tiene que estar aquí con su identidad. Una fila que el iPad borró, o que fundió un deduplicador, sigue
  viva en el backend, porque solo el motor del líder la tombstonearía. Así que el iPad no releva.
- El reconcile del adopt no vuelve a correr tras `.completed` y el espejo del iPad se apaga en el relanzamiento. El iPad
  ya no tiene otra ocasión de relevar.
- Sin marcador, la Mac vuelve al caso del ticket de origen: las filas diarias del iPad faltan y nunca viajan por iCloud.

## Por qué la cobertura total y no algo más laxo

Una fila que falta en el adoptador puede ser una que no llegó aquí, y el siguiente teléfono la tendría sin identidad. El
marcador lo cree el siguiente sin mirar nada, así que no puede certificar lo que el adoptador no vio.

## Ideas, sin decidir

- Que el adoptador tombstonee en el backend las filas que borró durante la espera. Así la cobertura total vuelve a
  cumplirse. Choca con `row-deleted-during-the-relief-wait-comes-back-after-the-relief` y con la asimetría de riesgo del
  diff inverso de `runAdoptOrphanReconcile` (residual (b)).
- Distinguir en el historial de SwiftData «la borré yo» de «no llegó». Los tombstones del historial no guardan el `syncID`
  si el atributo no se preserva al borrar.

## Criterios de aceptación

- [ ] Un adoptador al que solo le faltan filas que él mismo borró releva el marcador sin abrir el duplicado que la
      cobertura total evita.
