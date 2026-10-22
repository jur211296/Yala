---
id: late-icloud-wipe-stays-frozen-after-a-settled-failed-migration
status: done
priority: low
area: "sesiones, modo-nube"
created: 2026-10-06
updated: 2026-10-08
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

## Decisión (Jürgen, 2026-10-07 20:26 Lima): opción B

Tras una migración fallida y asentada, al abrir la app Yala vuelve a preguntar por el borrado pendiente. Nunca lo ejecuta a
ciegas. Si está puesta la renuncia («Activar la nube sin borrar»), gana la renuncia: no se vuelve a preguntar.

## Hecho (2026-10-08)

- `lateWipeLaunch` recibe las DOS lecturas del mismo `MigrationRestReading`: `migrationAtRest` (estricto) y
  `migrationFailedAndSettled`. Con la ida en vuelo sigue `.holdForMigration`. Con el fallo asentado: «a medias» →
  `.askLeftHalfway`; arm → `.askAfterFailedMigration`; renuncia puesta → `.holdForWaiver` (ni pregunta ni borra).
- `.askAfterFailedMigration` en `ContentView` clasifica el arm como un borrado que falló (`classifyLateWipeFailure`): con la
  zona de iCloud ya ida pasa a «a medias» y enseña «El borrado quedó a medias»; sin tocar nada el aviso del espejo tardío
  vuelve a preguntar con el corpus y el arm se queda puesto hasta que la persona contesta («Déjalo así» lo retira). Mismas
  pantallas, mismas salidas, sin copy nuevo.
- `waiverLapses` sigue leyendo solo el reposo estricto: tras el fallo la renuncia no caduca.
- Tests: `PendingICloudWipeCloudLogicTests` (tabla de 96 celdas sobre tres estados excluyentes de la migración + los cuatro
  casos del ticket + la renuncia que no caduca) y el source-scan del arranque.
- Review adversarial (tres lentes, 2026-10-08). Cazó que la primera versión desarmaba ANTES de saber si el aviso iba a
  preguntar: sin red, o con la hoja deslizada, el borrado pedido desaparecía y «Migrar» ya no enseñaba el diálogo del
  borrado pendiente (dos lentes). Corregido: el arm espera a la respuesta. También cazó un slice del test que lanzaba
  siempre y un mutante `migrationAtRest || migrationFailedAndSettled` que sobrevivía: el scan ahora trocea los argumentos
  de cada llamada.
- Residual: sin testigo del espejo tardío, o con la sonda en `.standDown`, nadie pregunta y el arm sigue congelado como
  antes.

## Verificado (2026-10-08)

- Gate: builds `Yala` y `Yala Dev` verdes; `YalaTests` entero, 9176 tests en 908 suites, verde; XCUITest de las 30 áreas que
  casan con `ContentView` (126 casos en tres lotes, centinela en 0) verde salvo `TransactionsCrudUITests.test_createTransaction`,
  que falla igual en `2.1` sin este cambio (ticket `new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max`).
- Control rojo con mutantes: el comportamiento viejo (congelar con el fallo asentado), quitar la renuncia y pasar
  `migrationAtRest || migrationFailedAndSettled` al arranque salen rojos.
- Simulador (iPhone 17 Pro, iOS 27.0): con la marca «a medias» puesta y `-uitest-migration-failed`, el build de `2.1` entra al
  Panel sin aviso; el de este cambio abre «El borrado quedó a medias» al arrancar. Capturas en
  `~/Claude/worktrees/_capturas/2026-10-08-late-icloud-wipe-stays-frozen-after-a-settled-failed-migration/`.
- Sin device-QA: la decisión es pura y está en unit; la pantalla es la de siempre. El camino del arm sin zona tocada termina en
  el aviso con el corpus, que necesita CloudKit real y ya tiene su device-QA de siempre.

## Relacionado

- `apple-id-change-check-stays-off-after-a-failed-migration`.
- `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud` (el congelado y la renuncia).
- Hallazgos de la review que no son de este ticket (preexistentes), con ticket propio:
  `retry-after-a-failed-migration-resumes-the-pending-icloud-wipe-blindly` y
  `late-icloud-notice-can-wipe-while-a-migration-is-uploading`.
- Residual bajo anotado por la review: un kill justo después de un borrado que terminó bien y antes de retirar el arm deja
  la marca de la zona; si coincide con una ida fallida asentada, el arranque lo enseña como «a medias» en vez de
  re-ejecutarlo y asentarlo.
