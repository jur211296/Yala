---
id: markerless-adopt-stays-blocked-while-another-device-writes-to-the-account
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24), segunda pasada"
---

# El adopt sin marcador no entra mientras otro teléfono siga escribiendo en la cuenta

## El problema, en lenguaje de usuario

Mi iPhone ya usa la nube a diario. Mi iPad, con el mismo iCloud y sin la marca del iPhone, intenta entrar en la cuenta
con algo propio que subir. Nunca termina: cada intento acaba en «espera a iCloud».

## Lo medido y lo inferido (2026-09-24)

- **Medido en código**: sin marcador, el adopt pide la cobertura de `adoptSharedRowsProof`. Lo que el iPhone crea en la
  nube después del cutover no viaja por iCloud (su espejo está apagado), así que falta en el iPad siempre. Ya pasaba
  antes del ticket de origen, que exigía todas las filas.
- **Medido en código**: desde `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` una fila que falta
  deja de bloquear si lo que sube se creó en el iPad después de la última escritura del backend. Con un teléfono que
  escribe a diario (hasta los tipos de cambio suben cada día UTC y cuentan para esa última escritura) eso no llega nunca.
- **Inferido**: el corte global es a propósito (protege de un tercer teléfono que adoptó antes y subió filas del iPad).
  Arreglarlo pide otra señal, no mover el corte.

## Criterios de aceptación

- [ ] Medido cuántos adopts sin marcador llegan con otro teléfono activo (¿existe el marcador en la práctica?).
- [ ] Una salida que no duplique, o la decisión escrita de que la espera es el comportamiento correcto.
