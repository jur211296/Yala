---
id: retry-after-a-failed-migration-resumes-the-pending-icloud-wipe-blindly
status: qa
priority: low
area: "sesiones, modo-nube"
created: 2026-10-08
updated: 2026-10-12
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

## Resuelto (2026-10-12, opción A de Jürgen)

- «Reintentar» (`MigrationRunner.resetAfterRollback`, rama `.failedRollback`) apunta la marca durable
  `cloudSync.icloudCorpusWipeCrossedFailedMigration` sobre el arm, antes del save. Con ella, el arranque en reposo da
  `.askAfterFailedMigration` (pregunta) en vez de `.resume`. Se retira con el arm y al volver a confirmar el borrado.
- Probado: §9d de `MigrationRunnerTests` (de punta a punta: arm + fallo → «Reintentar» → la decisión del arranque
  pregunta; con el sello quitado sale `.resume` — mutante verificado), `RetryAfterFailedMigrationWipeMarkTests` y la tabla
  de 192 celdas de `PendingICloudWipeCloudLogicTests`. Review adversarial de dos lentes: sin hallazgos altos.
- Residual escrito en `swiftdata-cloudkit.md`: sin testigo del espejo tardío, o con la sonda en `.standDown`, el arm se
  queda quieto también tras «Reintentar» (antes lo «desatascaba» el borrado a ciegas).

## Device-QA (Jürgen, cuando pueda)

No se puede montar en simulador (pide una ida a la nube real que falle). En un teléfono con iCloud: pedir «Borrar» en el
aviso de iCloud, cortar con un kill antes de que termine, activar la nube y forzar el fallo (sin red durante la subida),
pulsar «Reintentar» en Almacenamiento y relanzar Yala. Esperado: Yala pregunta (aviso de iCloud o «quedó a medias") y no
borra nada sin pantalla.
