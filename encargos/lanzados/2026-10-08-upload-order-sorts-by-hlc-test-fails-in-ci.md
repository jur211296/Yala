---
esfuerzo: high
---
# El test de orden de subida por HLC (`UploadOrderTests`) deja de salir rojo en 2.1, arreglando la causa raíz y sin silenciarlo

## Contexto
En 2.1 sale rojo, en todas las vueltas, `YalaTests/UploadOrderTests/pure_sortsByHLC_notByCreatedAt_andMalformedLast()` (suite «Orden de subida · por HLC, no por la hora de drenado», en `YalaTests/CloudSync/ClockAheadServerCapTests.swift`). Llegó con el PR #382 (tope del servidor a un HLC del futuro), que hizo que los outbox suban en orden de HLC (`HLC.uploadOrder` en `Yala/Services/CloudSync/HLC.swift`, usado por `SyncPushClient.push` y `GroupsSyncClient.pushPending`). Es el único rojo de 9 029 tests.

Dónde se vio (QA de GitHub, repo `jur211296/Yala`):
- Run 37644787793 (QA programada sobre `beed3a2`, merge del PR #384): rojo 3 de 3 vueltas. El mensaje, igual en las tres:
  `ClockAheadServerCapTests.swift:192:9: Expectation failed: (ordered → ["nuevo", "viejo", "malformado-a", "malformado-b"]) == ["viejo", "nuevo", "malformado-a", "malformado-b"]`
- Run 37615876262 (push de `beed3a2`) y run 37657178403 (push de `806dd7b`, merge del PR #385): el mismo test, «sigue en rojo tras 3 vuelta(s)». En el run 37648007282 (`fd52c0479`) no aparece en las anotaciones.
- En el mismo run 37644787793, además, el paso «UI tests (YalaUITests) — solo nocturna · advisory» agotó sus 110 min y el job `tests` pasó el tope de 2 h 30. Por el log, no parece un cuelgue: iba por `StatisticsNavigationUITests` con ~179 casos pasados, a ~45-60 s cada uno.

Una pista, sin verificar: en el test, «nuevo» y «viejo» se construyen con `remoteHLC(offset:counter:)`, que llama a `Date()` en cada llamada (física = ahora + 1 día). Si entre las dos llamadas cambia el milisegundo, «viejo» (contador 0) sale con más física que «nuevo» (contador 1) y el orden por HLC esperado se invierte. Eso explicaría un rojo que depende de la velocidad de la máquina. Pero también puede ser un fallo real de `HLC.uploadOrder`. Decídelo con evidencia, no por la pista.

Hoy se mergeó el PR #389 y sigue en cola el #390 (auto-merge a 2.1). Antes de esta sesión va en la cola `presentation-net-desarm-has-no-automated-net`; no depende de este encargo.

Para orientarte: `CLAUDE.md`, `.claude/rules/testing.md`, `.claude/rules/ci-propio.md`, los tickets `tickets/qa/personal-clock-ahead-wins-every-conflict-until-real-time-catches-up.md` y `tickets/qa/groups-clock-ahead-wins-every-conflict-until-real-time-catches-up.md`, y los logs con `gh run view <id> -R jur211296/Yala --log-failed`.

## Que se pide
1. Escribe el ticket en `tickets/` del repo con lo de arriba (si no existe ya).
2. Reproducir el rojo en local (si en la Mini no sale, fuérzalo de forma determinista: por ejemplo, con dos instantes que caen en milisegundos distintos) y encontrar la causa raíz: si falla el producto (`HLC.uploadOrder` o quienes lo usan no ordenan como promete el PR #382) o si falla el test (datos de arranque que dependen del reloj).
3. Arreglar con la opción más robusta: si es el producto, arregla el producto y deja el test como guardián con un control que salga rojo con el código viejo; si es el test, hazlo determinista sin debilitar lo que comprueba. Nada de quitar aserciones, `XCTSkip`/`.disabled`, ni meterlo en la lista negra.
4. Revisa los otros tests de la misma suite y del mismo fichero (`personalPush_uploadsInHLCOrder` y los de Grupos) por si comparten el mismo patrón de construcción, y corrígelos igual si es el caso.
5. El timeout de 110 min de los UI tests de la nocturna: confirma con el log si tiene relación con este rojo. Si no la tiene, anótalo en un ticket aparte en `tickets/backlog/` con lo medido y no lo arregles aquí.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). No hay card en el tablero para esto.

## Que NO hay que tocar
- La migración `qa/cloud/hlc01_cap_future_hlc.sql`, los `.ddl` ni nada del servidor.
- `qa.yml` (reintentos, topes, lista negra), `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
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

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `presentation-net-desarm-has-no-automated-net` sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- La causa raíz queda escrita en el ticket y en el PR, con la prueba que la confirma.
- `pure_sortsByHLC_notByCreatedAt_andMalformedLast` pasa de forma estable en local (varias corridas seguidas) y en el CI del PR, sin aserciones quitadas ni test desactivado; si era producto, hay control rojo con el código viejo.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, timeout de UI anotado en su ticket si no es lo mismo, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿Producto o test?** Test. Medido en el log del run 37644787793: el caso tarda 13-75 ms en el runner y «nuevo»
   (contador 1) se construye antes que «viejo» (contador 0), cada uno con su `Date()`. El mensaje es justo el orden
   inverso de esos dos. `HLC.uploadOrder` ordena bien; no se toca producto.
2. **Cómo hacerlo determinista sin debilitarlo:** un único `now` por prueba en `UploadOrderTests`; `remoteHLC` gana un
   parámetro `base` con default `Date()` (los demás tests no cambian). Ninguna aserción se toca. Se prueba con un
   mutante del producto (orden por `createdAt` y comparar solo la física) que el test tiene que cazar.
3. **Los otros dos tests de la suite:** mismo constructor, pasaban por el orden de las líneas. Se pasan a la misma
   base. El resto del fichero compara con márgenes de segundos o días: se deja.
4. **Timeout de 110 min de UI:** no es este rojo (paso aparte, mismo tope todas las noches). Ya existe
   `tickets/backlog/nightly-ui-suite-hits-its-110-minute-cap-every-night.md`: se le añade lo medido el 7-oct en vez de
   abrir un duplicado. Lo único que sí suma este rojo: sus vueltas 2 y 3 (~5,5 min) empujaron el job por encima de su
   tope de 150 min y lo cancelaron.
5. **Ticket:** `tickets/done/upload-order-sorts-by-hlc-test-fails-in-ci.md` + fila en `docs/TICKETS.md`. Sin
   `coverage-index`: no se toca nada bajo `Yala/`.
6. **Disco:** no se borran simuladores de otros carriles (Lola captura de ellos); solo el de esta sesión al cerrar.
