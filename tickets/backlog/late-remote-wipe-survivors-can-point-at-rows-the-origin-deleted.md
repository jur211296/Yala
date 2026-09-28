---
id: late-remote-wipe-survivors-can-point-at-rows-the-origin-deleted
status: backlog
priority: low
area: "sync, settings"
created: 2026-09-28
source: "review adversarial de `late-remote-wipe-signal-also-wipes-rows-created-after-it` (lentes de sync y de tests, 2026-09-28); inferido leyendo código, NO reproducido"
---

# Una fila posterior al vaciado que apunta a algo de antes se queda sin ello

## El síntoma, en lenguaje de usuario

Vacío los datos en el iPhone. El iPad, sin red, sigue usándose: apunto un gasto en una cuenta que ya existía y le pongo
una etiqueta de antes. Cuando el iPad se entera del vaciado, el gasto se queda, pero sin cuenta o sin etiqueta.

## Lo medido (2026-09-28, leyendo código)

El receptor tardío corta por fecha (`RemoteWipeCutLogic`): se queda lo creado después de la señal y lo que eso usa.
Tres huecos quedan fuera, los tres con filas que mezclan las dos épocas:

- **Etiquetas**: tienen fecha, así que se cortan por fecha y no por uso. Una etiqueta vieja se va aunque la lleve un gasto
  nuevo: la M2M la limpia `.nullify` y el espejo CSV del gasto (`tagIDs`) queda apuntando a una etiqueta borrada.
- **Cuentas y categorías viejas usadas por algo nuevo**: el receptor las conserva, pero el origen ya las borró y ese
  borrado llega después por el espejo; el `.nullify` deja la fila nueva sin cuenta o sin categoría. Es inherente: la
  cuenta dejó de existir en el parque al vaciar.
- **Escritura sobre la superviviente**: al borrar una fila vieja que comparte una cuenta con una nueva, la inversa
  (`Account.transactions`) cambia. Por el lado a-muchos no suele haber campo que exportar, pero no está medido.

Quién crea esas filas: un dispositivo sin red que se sigue usando tras el vaciado, el uso del propio receptor antes de
procesar la señal, y el arranque (`ApplePayDraftService.processPending`, con la cuenta de la tarjeta; ese borrador no
protege lo que usa y vuelve a preguntar).

## Qué hay que decidir

Si «Vaciar datos» tiene que ganar a lo que se hizo sin red después —y entonces esas filas se van o se quedan
huérfanas— o conservarlas con lo que usan, resucitando en el origen esas cuentas y etiquetas.

## Relacionados

- [[late-remote-wipe-signal-also-wipes-rows-created-after-it]]
