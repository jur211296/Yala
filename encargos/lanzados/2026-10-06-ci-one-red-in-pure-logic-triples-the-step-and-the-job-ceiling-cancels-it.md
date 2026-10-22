# Que un solo rojo en pure-logic no triplique el paso ni deje que el tope del job lo cancele

## Contexto
Ticket `tickets/backlog/ci-one-red-in-pure-logic-triples-the-step-and-the-job-ceiling-cancels-it.md` (tarjeta del tablero `tablero-ci-un-solo-rojo-en-pure-logic-triplica-e-6qi7`, prioridad alta). Léelo entero: trae las medidas.

Resumen: el paso `Unit tests (YalaTests pure-logic)` de `.github/workflows/qa.yml` corre con `-retry-tests-on-failure`. Con Swift Testing, xcodebuild repite la suite ENTERA hasta 3 veces, no solo el test rojo. El paso pasa de ~13 a 27-30 min y el tope de 45 min del job `tests` lo cancela. Como `continue-on-error` no rescata una cancelación, un rojo advisory acaba poniendo `tests` en rojo, el ruleset de `2.1` lo exige y el auto-merge se queda bloqueado. Pasó el 10-03, el 10-05 y el 10-06 (PR #369). Parece un cuelgue y no lo es.

## Que se pide
1. Medir primero, con lo que haya en los logs o una corrida corta, si el reintento repite la suite entera también con XCTest o solo con Swift Testing. Apúntalo en el ticket.
2. Implementar la opción 1 del ticket (la recomendada en la tarjeta): correr pure-logic una vez sin reintento y, si hay rojos, sacar sus identificadores del `.xcresult` (`xcresulttool get test-results tests` o equivalente) y repetirlos solos con `-only-testing`, como mucho las veces que hoy da el reintento. Así se conserva el rescate del flaky conocido (`SpikeR3ContainerReleaseTests`) y el paso dura lo de una vuelta más segundos.
3. Que el paso siga siendo advisory: un rojo que no se rescata sale como `outcome: failure` y el aviso de rojos advisory lo cuenta con el nombre del test; el job no se cancela por tiempo. Si en el camino ves que el aviso lee `cancelled` sin decir el test, deja que nombre el test cuando lo haya.
4. Si la extracción de identificadores falla (formato inesperado del xcresult), el paso cae a un comportamiento seguro y explícito (un rojo es un rojo, sin reintento), nunca a repetir la suite entera.
5. Pruébalo de verdad en el CI del propio PR: una corrida con un rojo provocado (en un commit que luego quitas) que muestre que solo se repite ese test y el job termina a tiempo, y la corrida final sana. Deja los números (minutos del paso, tests ejecutados) en el cuerpo del PR.

## Que NO hay que tocar
- No subas el tope del job ni el del paso como arreglo (opción 4 descartada).
- No quites tests ni los marques como skip para que pase.
- No toques el código de la app ni el resto de jobs del workflow salvo lo imprescindible para este paso.
- El PR #372 (puerta privada tras un adopt) está en la cola de merge: no lo toques.

## GATE DESPUÉS DEL CI DEL PR ANTERIOR
La sesión arranca ya, sobre `origin/2.1`. No se espera a que el PR anterior entre, y no se parte de la rama en auto-merge. Justo antes del gate, mirar si el PR anterior sigue en CI. Si sigue, esperar a que entre y rebasar una sola vez, con el simulador apagado. Si `2.1` no se movió, seguir de frente. Si ese CI falla, no esperar: rebasar con lo que haya y seguir. El build y el simulador van después de ese rebase, una sola vez.

## Mini limpia y pipeline serial
Si compilas o corres tests en la Mini: pipeline serial (limpiar → build con `xcodebuild -jobs 2` sin sim booteado → boot 1 sim → tests → apagar y borrar ese sim). Máximo 1 simulador. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Con un rojo, el paso pure-logic repite solo los tests rojos y el job `tests` termina dentro del tope; el rojo no rescatado sale advisory con su nombre.
- La corrida sana dura lo mismo que hoy (~13 min el paso).
- Ticket actualizado con la medida XCTest/Swift Testing y movido según quede; PR a `2.1` con auto-merge.
- Al terminar, `/cerrar-total` autónomo (sin esperar a nadie): Mini limpia, worktree retirado si el PR ya entró.

## Trabajo previo que puedes reutilizar
Una primera sesión con este mismo encargo se detuvo a los ~7 min por una pausa de Jürgen, sin commits ni PR. Dejó en `~/Claude/worktrees/_rescate/2026-10-06-6qi7-detenida/` dos borradores sin probar (`ci-reintentar-rojos.sh` y `ci-reintentar-rojos-test.sh`) y su encargo con un «Paso 0» de medidas y decisiones. Léelo: dice que XCTest repite solo el test rojo y Swift Testing la suite entera (YalaTests es Swift Testing entero), describe el formato del `.xcresult` en Xcode 27 y avisa de que un `-only-testing` que no casa con nada sale exit 0 con cero tests (por eso el rescate se mide como `Passed` en la repetición, no por el exit code). Revisa esas medidas y decisiones antes de adoptarlas; si alguna no se sostiene, decide lo más robusto y apúntalo en el ticket. Al terminar, borra esa carpeta de rescate.

## Autonomía
Sesión autónoma de punta a punta: la regla del repo de esperar aprobación con más de 3 ficheros o preguntar «¿Sigo?» tras el plan queda suspendida para este encargo. Implementa hasta gate, PR, auto-merge y `/cerrar-total` sin pedir permiso para continuar. Si aparece una decisión técnica, elige la opción más robusta y de buena práctica y documéntala en el ticket.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

*Frank, 2026-10-06. Las medidas de la sesión detenida se re-midieron antes de adoptarlas.*

**Medido.**
- **XCTest repite solo el rojo; Swift Testing, la suite entera.** Nocturna 37346159546 (UI = XCTest, mismo
  `-retry-tests-on-failure`): 171 líneas de caso para 165 casos únicos; los 3 rojos salen ×3 y ningún verde se repite.
  En pure-logic (Swift Testing) la 37325431444 corrió 26 511 tests = 3 vueltas.
- **Formato del `.xcresult`** (sonda Swift Testing, Xcode 27): `Test Case` con `nodeIdentifier` `Suite/test()`, también
  para un `@Test("nombre visible")`; `<bundle>/<id>` funciona tal cual en `-only-testing`.
- **Un crash no deja casos sin correr**: xcodebuild relanza el proceso y sigue con los de detrás; solo el que corría
  queda `Failed`. Repetir los rojos basta.
- **Un `-only-testing` que no casa sale exit 0 con cero casos.** El rescate se mide como `Passed` en la repetición.

**Decisiones.**
1. Opción 1 del ticket, en `qa/scripts/ci-reintentar-rojos.sh` con banco (`ci-reintentar-rojos-test.sh`) en
   `coverage-index`, como `ci-simulador.sh`. El YAML solo lo llama.
2. Hasta 3 vueltas en total, como hoy; cada una repite solo lo que sigue rojo.
3. Caída segura: `.xcresult` ilegible, formato raro, exit ≠ 0 sin ningún caso rojo, o más de 100 rojos ⇒ no se repite
   nada y sale con el código de la primera vuelta.
4. Los rojos se publican en `outputs.rojos` ya tras la primera vuelta (si algo corta la repetición, el nombre queda) y
   el aviso los cita. Los rescatados, como anotación `warning`.
5. Solo pure-logic. Context-based (2-3 min, tope de paso 10) y UI (XCTest) no cancelan el job: no se tocan.
6. Gate: el diff toca `qa/scripts/*.sh`, que según `/gate` pide los pasos 1-3. Se corren.
7. Prueba en CI: un commit con un rojo provocado en un test pure-logic, que luego se revierte.
