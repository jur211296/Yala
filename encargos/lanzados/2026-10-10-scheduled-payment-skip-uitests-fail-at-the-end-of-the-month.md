---
esfuerzo: medium
---
# Los UI tests de saltar un pago programado pasan cualquier día del mes

## Contexto
Card del tablero `tablero-los-ui-tests-de-saltar-un-pago-programad-2lf1` (lista para lanzar, vence 2026-10-10). Ticket: `tickets/backlog/scheduled-payment-skip-uitests-fail-at-the-end-of-the-month.md` (gate de `sheet-size-follows-the-device-not-the-window`, 2026-09-29). El triage de Frank del 2026-10-07 lo confirmó vivo en el código de 2.1.

Lo que pasa: los dos casos de `ScheduledPaymentSkipUITests` (`YalaUITests/Flows/ScheduledPaymentSkipUITests.swift`) caen hacia la línea 30: «No se montó la lista de pagos programados». El test abre Planificación → Pagos planificados y toca la primera fila del período por defecto, «Este mes». La app está bien: el test depende de la fecha. Con `-uitest-seed minimal`, la semilla pone los pagos a días vista (Gimnasio en 4 días, Alquiler en 6, Teléfono en 16, Spotify en 19, Netflix en 21), así que cerca de fin de mes ninguno cae en el mes en curso.

Lo medido según el ticket: 2 de 2 en rojo el 29-sep (en `435bd8eb`) y el 30-sep (en `6e3fdacc2`), mismo mensaje; los otros 182 casos de la suite, en verde. No se midió desde qué día del mes falla. Hoy (8-oct) probablemente pasa: para reproducirlo hay que forzar la fecha, no esperar a fin de mes.

Antes de esta sesión va en la cola `ai-insights-error-card-shows-raw-english-errors`; no depende de ella.

Para orientarte: `CLAUDE.md`, `.claude/rules/testing.md`, `.claude/rules/ci-propio.md` y el ticket.

## Que se pide
1. Reproducir el rojo de forma determinista (por ejemplo, con la costura de reloj o de «ahora» que tenga la semilla de UI tests, o sembrando como si fuera día 28). Si no hay costura, mide desde qué día falla y anótalo.
2. Arreglar con la opción más robusta: que el test no dependa del día. Preferible sembrar un pago que caiga siempre dentro del mes en curso (sin romper los otros tests que leen esa semilla: revísalos) antes que hacer que el test salte a «Próximo mes».
3. Revisar si otros XCUITest de Planificación leen «Este mes» con la misma semilla y corregirlos igual si es el caso.
4. Nada de quitar aserciones, `XCTSkip`/`.disabled` ni lista negra. Corre solo las clases de UI tests afectadas, no la suite entera.
5. Anota lo medido en el ticket y muévelo según las convenciones del repo.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-los-ui-tests-de-saltar-un-pago-programad-2lf1` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.
7. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).

## Que NO hay que tocar
- La app (Planificación y pagos programados): el fallo es del test.
- El resto de la semilla `-uitest-seed`, salvo el pago nuevo.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~32 GB libres el 2026-10-08, justo en el umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- `ScheduledPaymentSkipUITests` pasa con la fecha forzada a fin de mes y a principio de mes, varias corridas seguidas.
- Los demás XCUITest que leen esa semilla siguen verdes.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, ticket movido, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Carga de la Mini (OBLIGATORIO, 2026-10-09)
El puente de Grok Bot se cae con los picos de carga de Xcode (llegó a 17). Por eso:
- Todo `xcodebuild` (build y test) va con `-jobs 2` y precedido de `nice -n 10`: `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca corras dos builds o tests a la vez (ni en paralelo ni en segundo plano); uno termina antes de empezar el siguiente.
- Antes de cada build o test, espera a que la carga de 1 minuto baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- No filtres la salida de xcodebuild con `| head` (corta la tubería y mata el build): escribe a un log y luego busca en él.
- En zsh, los `-only-testing:` van en un array, no en una variable de texto (zsh no la parte).

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Causa (medida en código):** `ScheduledPaymentDateCalculator.applyPostFilters` descarta fechas anteriores a `createdAt` (= momento de la siembra) y los 8 pagos van del día 3 al 28 ⇒ sembrando el 29, 30 o 31 «Este mes» queda vacío. Febrero de 28 días nunca falla.
2. **Arreglo:** pago nuevo «Recibo fin de mes» (mensual, `dayOfMonth: 31` → último día de cada mes), **solo en el perfil `minimal`** para no tocar `realista` (dev seed / capturas). Del 1 al 28 se ordena el último ⇒ no cambia el sujeto de ningún test. Descartado: que el test salte a «Próximo mes».
3. **Reproducción determinista:** costura `-uitest-scheduled-seed-day <N>` que mueve el «hoy» de `DevSeedScheduledPayments` (y su `createdAt`) al día N del mes en curso; la app sigue con el reloj real. Con el `.now` por defecto el comportamiento es idéntico al de hoy.
4. **Pruebas:** dos casos XCUITest nuevos (día forzado al último y al primero) + test unitario que recorre todos los días de 2026 y febrero de 2028. Mutante: sin el pago nuevo, el caso de último día tiene que caer.
5. **Otros XCUITest de Planificación:** ninguno más lee filas de pagos (`AdaptiveNavigation` e `IPhoneLandscape` solo miran el chip) ⇒ nada más que corregir.
6. **Device-QA:** no aplica (solo semilla de test) ⇒ ticket a `done`, card a «done» asignada a frank.
