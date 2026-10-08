---
esfuerzo: medium
---
# Los tests de periodos del widget pasan igual en UTC que en hora de Lima, sin depender de la zona horaria del runner

## Contexto
Card del tablero `tablero-widget-los-periodos-del-widget-y-la-logi-vlf2` («Widget: los periodos del widget y la lógica principal cortan con 5 h de desfase», prioridad alta, vence 2026-10-09). No hay ticket en `tickets/`.

Corrección de Frank del 2026-10-06 (en la card): falsa premisa parcial. No es un bug de la app. Los 4 rojos del run 37479038308 los provocó a propósito la sesión del PR #373 con `TEST_RUNNER_TZ: UTC` (commit `9bd7b9bd6`, revertido en `e4c04112e`) para probar el reintento de solo los rojos. En el CI normal no salen porque `qa.yml` fija `TEST_RUNNER_TZ: America/Lima`. Lo que queda es higiene: esos tests dependen de la zona horaria del runner y en UTC fallan.

Los 4 rojos en UTC (de `YalaTests/WidgetDataServiceIntervalTests.swift`):
- `parity_widgetReplica_matches_ssot_for_all_non_weekly_periods()`
- `lastMonth_ssot_end_is_exactly_one_second_before_this_month_start()`
- `lastYear_ssot_excludes_midnight_of_first_day_of_this_year()`
- `lastMonth_ssot_excludes_midnight_of_first_day_of_this_month()`

Pista (verifícala en este árbol antes de tocar nada): el test arma su calendario con `TimeZone(identifier: "America/Lima")` (`makeCalendar`) y su `now` fijo con ese calendario, pero compara contra el SSOT real `DetailPeriod.dateInterval(now:)`, que usa `userConfiguredCalendar()`, o sea la zona del proceso. En Lima coinciden y en UTC cortan con 5 h de desfase. El propio fichero explica por qué replica la lógica del widget (`WidgetDataService` solo compila en la extensión); `docs/aprendizajes-tecnicos.md` tiene la trampa y el molde (`WidgetAmountSplitter`) por si te sirve.

Medido en `tickets/done/ci-one-red-in-pure-logic-triples-the-step-and-the-job-ceiling-cancels-it.md`: con `TEST_RUNNER_TZ=UTC` salen exactamente esos 4 rojos deterministas.

Antes de esta sesión van en la cola `presentation-net-desarm-has-no-automated-net` y `upload-order-sorts-by-hlc-test-fails-in-ci`; ninguna depende de esta.

Para orientarte: `CLAUDE.md`, `.claude/rules/testing.md` y `.claude/rules/ci-propio.md`, el fichero de test y la card.

## Que se pide
1. Reproducir los 4 rojos en local con la zona del runner en UTC y confirmar que en America/Lima pasan.
2. Hacer que estos tests no dependan de la zona del runner, con la opción más robusta: zona y calendario fijados en el propio test, y que lo que se compara (réplica y SSOT) use el mismo calendario. Si para eso el SSOT necesita aceptar un calendario inyectado, que sea un parámetro con valor por defecto igual al comportamiento de hoy: la app no cambia.
3. Que los tests sigan comprobando lo mismo: la paridad entre widget y SSOT y la exclusión de la medianoche del día 1. Nada de quitar aserciones ni de fijar la zona solo en el entorno del CI.
4. Una corrida de la suite pure-logic completa en UTC para ver si quedan otros tests que dependan de la zona del runner. Esos no se arreglan aquí: van listados en un ticket nuevo en `tickets/backlog/`.
5. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-widget-los-periodos-del-widget-y-la-logi-vlf2` a «done» (es solo de tests, no queda nada para Jürgen), con `tablero mover <id> --a "done" --agente frank`.

## Que NO hay que tocar
- El comportamiento de la app y del widget: no hay bug de producto.
- `TEST_RUNNER_TZ: America/Lima` y el resto de `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Los otros tests que dependan de la zona, si aparecen: solo al ticket.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): si aparece una decisión de producto o de riesgo entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~20 GB libres, por debajo del umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `upload-order-sorts-by-hlc-test-fails-in-ci` sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Los 4 tests pasan en UTC y en America/Lima sin forzar el entorno, y siguen comprobando paridad y exclusión de medianoche.
- Si se inyectó calendario en el SSOT, el comportamiento por defecto es el de hoy.
- Ticket nuevo con los otros tests dependientes de la zona, si los hay.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, card del tablero movida a «done», Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

- **Pista verificada en el árbol:** `DetailPeriod.dateInterval(customRange:now:)` (`Yala/App/Models/SharedModels.swift`) toma `userConfiguredCalendar()`, que parte de `Calendar.current` (zona del proceso); el test arma `now` y límites en America/Lima. Causa confirmada por lectura; la reproducción en UTC va en el paso 1.
- **Decisión:** `dateInterval` gana `calendar: Calendar = userConfiguredCalendar()` como último parámetro. El default se evalúa en cada llamada, igual que la línea que sustituye: los ~60 llamadores de la app no cambian.
- **Tests:** los cuatro rojos y `allTime_starts_ten_years_before_now_in_both_impls` (mismo patrón, pasaba en UTC por casualidad: sin DST) pasan `calendar:` del `makeCalendar()` de Lima. Ninguna aserción se quita.
- **Asumido:** `parity_thisWeek_algorithms_match_with_shared_calendar` se deja como está (réplica vs réplica); solo se corrige su comentario, que decía «no inyectable».
- **Barrido UTC:** la suite pure-logic (los `-only-testing`/`-skip-testing` del paso del CI) con `TEST_RUNNER_TZ=UTC`; lo que salga rojo y no sea de este fichero va a un ticket en `tickets/backlog/`, sin arreglar.
