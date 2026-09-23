---
id: a-malformed-ref-leaves-a-stale-dangler
status: backlog
priority: very-low
area: "modo-nube, sync"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `dangling-ref-repair-is-lost-when-its-row-cannot-be-read` (2026-09-23), lente de instancias gemelas — fuera de lente"
---

# Una referencia mal formada desde la nube deja viva la nota vieja de «esto va con tal categoría»

## El problema, en lenguaje de usuario

Si la nube mandara la categoría o la cuenta de un movimiento en un formato que no es un identificador, la app la
dejaría vacía pero conservaría la nota anterior de a qué apuntaba; cuando esa categoría llegara, la volvería a
poner. Nuestro servidor no manda ese formato: es una defensa, no un bug que se vea hoy.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

`EntityApplyMap.resolveRef`: un `.string` que no es UUID (`guard let id = UUID(uuidString:) else { return nil }`) y el
caso `default` devuelven `nil` —pisan la ref— SIN `clearDangler`. El `.null` sí lo borra. Un dangler previo de esa
(fila, columna) sobrevive y el pase final re-adjunta su destino.

## Qué habría que decidir

- Tratarlo como el `.null` (vínculo a nil y dangler borrado) o como un delta inaplicable (tirar la página con canario).

## Criterios de aceptación

- [ ] Un valor de ref mal formado no deja un dangler que luego pise la ref.
