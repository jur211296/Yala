---
id: late-icloud-wipe-stays-frozen-after-a-settled-failed-migration
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-10-06
updated: 2026-10-06
source: "review adversarial de `apple-id-change-check-stays-off-after-a-failed-migration` (2026-10-06), lente de consumidores"
---

# Tras una migración fallida, un borrado de iCloud pendiente se queda congelado hasta pulsar «Reintentar»

## El problema, en lenguaje de usuario

Si la persona había pedido borrar lo que tenía en iCloud y ese borrado quedó pendiente (o a medias), y después un paso de
sus datos a la nube terminó en fallo, Yala no termina ni vuelve a preguntar por ese borrado mientras no vuelva a
Almacenamiento a pulsar «Reintentar». No se pierde nada: el borrado simplemente no avanza.

## Medido (2026-10-06)

- El arranque congela el borrado pendiente con la migración fuera de reposo: `WelcomePrivateICloudGateLogic.lateWipeLaunch`
  → `.holdForMigration` y `return` en `ContentView` (`case .holdForMigration:`, «Ni reanudar ni preguntar con la ida en
  vuelo»).
- «Fuera de reposo» es `AppleIDChangeCloseLogic.migrationAtRest`, el ESTRICTO, y `failedRollback` no lo es.
- Desde `apple-id-change-check-stays-off-after-a-failed-migration` existe `migrationFailedAndSettled` (ida fallida, sin
  efectos pendientes): con ella la oferta del cambio de Apple ID y el cierre privado se abren, pero este lector se dejó
  estricto a propósito, porque usa el mismo booleano para `waiverLapses`: con «Reintentar» a la vista, la renuncia de
  «Activar la nube sin borrar» todavía puede servir.
- El motivo del congelado («se llevaría lo que la ida está subiendo») no aplica a un fallo asentado: no sube nada.

## Qué hay que decidir (Jürgen)

¿Se separan los dos usos? Por ejemplo: el congelado del borrado acepta el fallo asentado (y entonces termina o pregunta),
mientras la caducidad de la renuncia sigue exigiendo reposo. Hay que mirar qué pasa con el arm y la renuncia puestos a la
vez: la renuncia sigue mandando y el borrado no puede reanudarse a ciegas.

## Relacionado

- `apple-id-change-check-stays-off-after-a-failed-migration`.
- `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud` (el congelado y la renuncia).
