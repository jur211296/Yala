---
esfuerzo: high
---
# Tras una migración a la nube fallida y asentada, al abrir la app Yala vuelve a preguntar por el borrado pendiente de iCloud en vez de dejarlo congelado

## Contexto
Card del tablero `tablero-decidir-el-borrado-pendiente-de-icloud-s-sqlw` (lista para lanzar, vence 2026-10-10). Ticket: `tickets/backlog/late-icloud-wipe-stays-frozen-after-a-settled-failed-migration.md` (sale de la review adversarial de `apple-id-change-check-stays-off-after-a-failed-migration`, PR #381).

Lo que le pasa al usuario: había pedido borrar lo que tenía en iCloud y ese borrado quedó pendiente (o a medias). Después, un paso de sus datos a la nube terminó en fallo. Desde entonces Yala ni termina ni vuelve a preguntar por ese borrado hasta que la persona vuelve a Almacenamiento y pulsa «Reintentar». No se pierde nada, pero el borrado no avanza.

**Decisión de Jürgen (2026-10-07, 20:26 Lima): opción B.** Tras una migración fallida asentada, al abrir la app Yala vuelve a preguntar por el borrado pendiente. Nunca lo ejecuta a ciegas. Si está puesta la renuncia («Activar la nube sin borrar»), gana la renuncia. No se vuelve a preguntar.

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- El arranque congela el borrado pendiente si la migración no está en reposo: `WelcomePrivateICloudGateLogic.lateWipeLaunch` → `.holdForMigration` y `return` en `ContentView` (`case .holdForMigration:`, «Ni reanudar ni preguntar con la ida en vuelo»).
- «En reposo» es `AppleIDChangeCloseLogic.migrationAtRest`, el estricto, y `failedRollback` no cuenta como reposo.
- Desde el PR #381 existe `migrationFailedAndSettled` (ida fallida, sin efectos pendientes; ver también `Yala/Services/CloudSync/MigrationRestReading.swift`). Con ella ya se abren la oferta del cambio de Apple ID y el cierre privado, pero este lector se dejó estricto a propósito porque usa el mismo booleano para `waiverLapses`: con «Reintentar» a la vista, la renuncia todavía puede servir.
- El motivo del congelado («se llevaría lo que la ida está subiendo») no aplica a un fallo asentado: no sube nada.
- Lo que hay que separar: el congelado del borrado acepta el fallo asentado (y entonces pregunta), mientras la caducidad de la renuncia sigue exigiendo reposo. Con el borrado armado y la renuncia puestos a la vez, manda la renuncia.

Tests que ya cubren esta zona: `YalaTests/CloudSync/PendingICloudWipeCloudTests.swift`, `YalaTests/CloudSync/LateICloudWipeLeftHalfwayTests.swift` y `YalaTests/CloudSync/AppleIDChangeCloseLogicTests.swift`. Relacionados: `apple-id-change-check-stays-off-after-a-failed-migration` y `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`.

Antes de esta sesión van en la cola `presentation-net-desarm-has-no-automated-net`, `upload-order-sorts-by-hlc-test-fails-in-ci`, `widget-period-tests-depend-on-the-runner-timezone` y `hlc01-applied-ddl-snapshots-and-runbook`; ninguna depende de esta.

Para orientarte: `CLAUDE.md`, `.claude/rules/swiftdata-cloudkit.md`, `.claude/rules/testing.md` y `.claude/rules/swiftui-ds.md`, el ticket y los dos relacionados.

## Que se pide
1. Reproducir el congelado: borrado de iCloud pendiente o a medias + migración fallida asentada → al abrir la app no pasa nada hasta «Reintentar».
2. Implementar la opción B con la solución más robusta: separar el uso del congelado del de la caducidad de la renuncia, de modo que con la migración fallida y asentada el arranque vuelva a preguntar por el borrado pendiente (con el mismo aviso y las mismas salidas que ya usa Yala para ese borrado), sin ejecutarlo nunca sin respuesta de la persona. Con la ida en vuelo, se sigue congelando como hoy.
3. Si la renuncia («Activar la nube sin borrar») está puesta, gana la renuncia: ni se pregunta ni se borra. La caducidad de la renuncia sigue exigiendo reposo estricto.
4. Cubrirlo con test: la tabla pura de `lateWipeLaunch` con los casos fallo asentado, ida en vuelo, reposo, y borrado armado con renuncia puesta; y un control que salga rojo con el código viejo. Si el cableado en `ContentView` lo fija un escáner, ajústalo en el mismo movimiento.
5. Si el aviso se puede ver en el simulador, deja `capturas/antes.png` (sin aviso tras el fallo) y `capturas/despues.png` (el aviso al abrir) en el worktree, con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas y deja un guion de device-QA en `tickets/qa/`.
6. Anota la decisión de Jürgen (20:26, opción B) en el ticket y muévelo según las convenciones del repo.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-decidir-el-borrado-pendiente-de-icloud-s-sqlw` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- El flujo de migración a la nube y su rollback: solo cambia qué hace el arranque con el borrado pendiente tras un fallo asentado.
- La renuncia y su caducidad: siguen exigiendo reposo estricto.
- Los textos del aviso del borrado pendiente, salvo que hagan falta para este caso; si cambia alguno, localizado como el resto de la app y en español neutro latinoamericano.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): si aparece una decisión de producto o de riesgo entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion. Lo que toque datos de la persona (borrar sin respuesta suya) es de alto riesgo: no se hace.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~20 GB libres, por debajo del umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `hlc01-applied-ddl-snapshots-and-runbook` sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Con la migración fallida y asentada, al abrir la app Yala pregunta por el borrado pendiente y no borra nada sin respuesta; con la ida en vuelo sigue congelado; con la renuncia puesta, gana la renuncia.
- Tabla pura con los cuatro casos y control rojo con el código viejo; escáner ajustado si lo había.
- Builds `Yala` y `Yala Dev` verdes; capturas antes y después, o guion de device-QA.
- PR a 2.1 en auto-merge, ticket con la decisión anotada, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 05:10 Lima): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Dónde se separan los dos usos del booleano de reposo?** → `lateWipeLaunch` recibe una segunda lectura,
`migrationFailedAndSettled`, del MISMO `MigrationRestReading.live` que el reposo estricto; `waiverLapses` sigue leyendo solo
el estricto. Por qué: el ticket pide separar el congelado de la caducidad sin tocar la segunda. Alternativa descartada:
pasar `migrationAllowsPrivateSessionClose` al arranque, porque haría caducar la renuncia con «Reintentar» a la vista.

**D2 · Con fallo asentado y el borrado ARMADO, ¿qué pregunta Yala?** → No reanuda nunca. Se clasifica como un borrado que
falló (`classifyLateWipeFailure`): si la zona de iCloud ya se fue (o ya estaba «a medias»), pasa a «a medias» y enseña «El
borrado quedó a medias» con «Terminar de borrar» detrás de su «¿seguro?»; si no se tocó nada, se desarma y el aviso del
espejo tardío vuelve a preguntar con el corpus. Por qué: son las dos pantallas y las dos salidas que Yala ya usa para ese
borrado, y su copy es verdad en cada caso. Alternativa descartada: enseñar siempre «a medias» (miente si la zona sigue).

**D3 · Con fallo asentado y solo «a medias»** → `.askLeftHalfway`, igual que en reposo.

**D4 · Renuncia puesta + fallo asentado** → salida propia `.holdForWaiver`: ni pregunta ni borra, el borrado sigue
pendiente y la renuncia no caduca (sigue exigiendo reposo estricto). Por qué: decisión de Jürgen («gana la renuncia») y
una salida distinta de `.holdForMigration` deja la tabla discriminar el motivo.

**D5 · Ida en vuelo (ni reposo ni fallo asentado)** → `.holdForMigration`, como hoy.

**D6 · Capturas** → se intentan en el simulador con el seam existente `-uitest-migration-failed` y la marca «a medias»
escrita en el `UserDefaults` del simulador (estado que un usuario real tiene). Si el aviso no sale sin inventar algo más,
guion de device-QA en `tickets/qa/`.

**D7 · ¿ADR?** → No. Es el desenlace de un ticket; lo durable va a la regla de área (`swiftdata-cloudkit.md`), que hoy dice
que este lector se queda estricto y hay que corregirla.
