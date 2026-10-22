---
id: adopt-effect-ceiling-never-sees-an-import-that-never-settles
status: backlog
priority: low
area: "modo-nube, migración, adopt"
created: 2026-09-23
updated: 2026-10-08
source: "review adversarial de `adopt-effect-retries-forever-with-no-ceiling` (2026-09-23), lente de relojes"
---

# Si iCloud no termina nunca de importar, entrar en tu cuenta de la nube tampoco se rinde nunca

## El problema, en lenguaje de usuario

Con el efecto del adopt pendiente y la importación de iCloud que no se asienta nunca, la tarjeta de progreso se queda
esperando y «Cancelar» tampoco hace nada.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

El runner (`awaitQuiescence`, 120 s) y el controller (pre-espera de 300 s) vuelven sin ejecutar el efecto cuando el
import no está quieto, así que no hay observación que selle el reloj de 72 h. `cancelMigration` pasa por la misma
pre-espera. Es la misma forma que ya tienen las fases de la ida; aquí lo hace visible la tarjeta nueva.

## Relacionado

- `adopt-effect-retries-forever-with-no-ceiling`.

## Medido en 2.1 (triage 2026-10-08)

- `MigrationRunner.cancelMigration` sigue empezando por `guard await awaitQuiescence()` (tope 120 s): sin import quieto el «sí» queda apuntado y no se ejecuta.
- `submit` y `resume` siguen con la misma puerta, así que ninguna pasada observa el efecto y el reloj de 72 h no se sella.
- Caso hermano en otra superficie: `detach-quiescence-timeout-says-group-changes-are-pending`.

Triage 2026-10-08: abierto · low → low · la puerta de quiescencia sigue delante de `cancelMigration` y de cada pasada; requiere un import de iCloud que no se asiente nunca, y el teléfono sigue usable en iCloud.
