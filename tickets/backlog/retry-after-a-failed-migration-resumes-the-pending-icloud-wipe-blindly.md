---
id: retry-after-a-failed-migration-resumes-the-pending-icloud-wipe-blindly
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-10-08
updated: 2026-10-08
source: "review adversarial de `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration` (2026-10-08), lente de reglas de área — hallazgo 2"
---

# Tras pulsar «Reintentar» en una migración fallida, el borrado de iCloud pendiente se termina sin volver a preguntar

## El problema, en lenguaje de usuario

Si la persona había pedido borrar lo que tenía en iCloud, un paso a la nube falló y luego pulsa «Reintentar» en
Almacenamiento, la siguiente vez que abre Yala el borrado se termina solo, sin preguntarle. Si además había elegido
«Activar la nube sin borrar», esa elección caduca en ese mismo arranque y el borrado se termina igual.

## Medido (por lectura, 2026-10-08)

- Desde `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration`, con la ida fallida y asentada el arranque PREGUNTA
  y nunca reanuda (decisión B de Jürgen del 2026-10-07: «nunca lo ejecuta a ciegas»).
- «Reintentar» (`CloudMigrationController.resetAfterRollback`) devuelve el journal a `notStarted` (reposo). El arranque
  siguiente lee reposo estricto y `lateWipeLaunch` devuelve `.resume` con el arm puesto: el borrado se termina sin pantalla.
- Con la renuncia: `.holdForWaiver` mientras dura el fallo → «Reintentar» → reposo → `waiverLapses` la retira → `.resume`.
- Ya pasaba antes de ese ticket (el congelado también acababa en «Reintentar» → `.resume`). Lo nuevo es que la decisión B
  dice «nunca a ciegas» y este camino lo contradice.
- Sin reproducir en simulador: inferido de `resetAfterRollback` y de la derivación de la tarjeta.

## Qué hay que decidir (Jürgen)

¿Un arm que sobrevivió a una ida fallida debe preguntar también después de «Reintentar»? Opciones:
- **A (recomendada):** al entrar en `failedRollback` asentado se apunta una marca durable «este borrado pasó por una ida»
  y, con ella, el arranque en reposo pregunta en vez de reanudar.
- **B:** se acepta: «Reintentar» es un gesto de la persona y el arm sigue siendo su petición.

## Relacionado

- `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration`.
- `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud` (la renuncia y su caducidad).
