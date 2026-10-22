---
esfuerzo: high
---
# El desarme que salva la sesión (red de presentación del aviso de borrado remoto y de la hoja de cambio de Apple ID) queda cubierto por un test automatizado

## Contexto
Card del tablero `presentation-net-desarm-has-no-automated-net` (lista para lanzar, venció el 2026-09-29). Hallazgo del PR #164. Ticket ya escrito: `tickets/backlog/presentation-net-desarm-has-no-automated-net.md` (sale de la review adversarial de `remote-wipe-alert-skips-the-router`, lente de tests).

Lo que protege, en lenguaje de usuario: si el aviso «tus datos fueron eliminados de iCloud» no llega a presentarse, la app no puede quedarse muda para siempre. La cura es una red que verifica la presentación contra UIKit (`ModalPresentationProbe`) y, al agotar el cap, suelta la condición viva para que el siguiente aviso retenido sí salga. Hoy esa cura está medida con control positivo y negativo, pero a mano (ediciones temporales del código y dos lanzamientos en el simulador). En el repo solo queda un source-scan que fija la FORMA del desarme (`RemoteWipeSignalWiringTests`), no su comportamiento.

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- La receta medida el 2026-09-14: `isPresented: .constant(false)` en el alert del vaciado remoto en `ShellDataAlertsModifier`, lanzar con `-uitest -uitest-reset -uitest-skip-onboarding -uitest-remote-wipe-notice -uitest-trial-offer` y leer el log de readiness. Con la red: `blocked by: remoteWipeAlert` → a los ~10 s `blocked by: proTrialOffer`. Sin la red (`armRemoteWipeNoticePresentationNet()` comentado): se queda en `remoteWipeAlert` y el paywall no presenta nunca.
- Vías descartadas y por qué: seam en el `isPresented` del alert (es el binding con setter no-op que prohíbe la regla (1) de `.claude/rules/swiftui-ds.md`, aunque sea bajo `#if DEBUG`) y seam en la sonda (ejercita «la sonda miente», que es otro escenario con otro desenlace).
- La vía que el ticket ve como buena: un seam en el DRENAJE que encienda la condición viva sin encender la red visual, simulando exactamente «la presentación no montó». Cuesta un `#if DEBUG` dentro del tramo que hoy fija un escáner por literal, así que hay que ajustar ese escáner en el mismo movimiento.
- Segunda red con el mismo hueco: la hoja «Cambiaste de cuenta de iCloud» en `AppleIDCloseNoticeModifier` (prueba de presentación por `onAppear`; al agotar el cap suelta `appleIDCloseNotice`, reconoce el bloqueo del cierre y emite `appleIDCloseNoticeNotPresented`). La cubren `AppleIDCloseNoticeLogicTests` y `AppleIDCloseNoticeWiringTests` (en `YalaTests/AppleIDCloseNoticeTests.swift`), sin XCUITest del desarme. La misma vía vale: encender `appleIDCloseNotice` en el drenaje sin encender `showSheet`.

Tests de UI que ya existen cerca: `YalaUITests/Flows/RemoteWipeNoticeRoutingUITests.swift` y `YalaUITests/Flows/AppleIDCloseNoticeUITests.swift`; los argumentos de lanzamiento viven en `Yala/App/UITestHooks.swift` y `YalaUITests/Support/XCUIApplication+Yala.swift`. Ojo: `RemoteWipeNoticeRouting` keepWaiting está anotado como flaky 1/3 en la suite advisory; no lo empeores.

Hoy se mergeó el PR #389 (sesión 2 del gateway) y siguen en cola el #390 (índice de docs debajo del frontmatter, auto-merge a 2.1) y el PR de la sesión anterior de esta cola (`insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language`). Ninguno depende de este encargo.

Para orientarte: `CLAUDE.md`, `.claude/rules/testing.md` (en especial la regla `L103`) y `.claude/rules/swiftui-ds.md`, y el ticket.

## Que se pide
1. Reproducir en local la receta del ticket para las dos redes (aviso de borrado remoto y hoja de cambio de Apple ID) y confirmar que el comportamiento medido sigue igual en este árbol.
2. Cablear un seam de test, solo en DEBUG y por argumento de lanzamiento, con la opción más robusta (el ticket recomienda el del drenaje; si encuentras una mejor, justifícala en el PR), que simule «la presentación no montó» sin tocar el binding de presentación ni la sonda.
3. Un XCUITest por red que ejercite el camino `.retry` → `.exhausted` y afirme las dos consecuencias: la condición viva se suelta y el aviso retenido detrás presenta. Con un control que salga rojo sin la red (por ejemplo, con el desarme anulado).
4. Ajustar los escáneres que fijan el tramo del drenaje para que sigan fijando el orden con el seam dentro.
5. Mover el ticket a donde toque según las convenciones del repo.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `presentation-net-desarm-has-no-automated-net` a «done» (no hay cambio visible para Jürgen), con `tablero mover <id> --a "done" --agente frank`.

## Que NO hay que tocar
- El comportamiento de producción de las dos redes ni sus textos: esto es solo cobertura.
- El test de la presentación NORMAL tiene que seguir corriendo sin el seam.
- Que la suite UI siga siendo advisory: no la conviertas en bloqueante ni cambies los reintentos en `qa.yml`.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): si aparece una decisión de producto o de riesgo entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~20 GB libres, por debajo del umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language` y el #390 siguen en CI. Si siguen, espera a que entren y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Hay un XCUITest por red que recorre `.retry` → `.exhausted`, afirma que la condición viva se suelta y que el aviso retenido presenta, y pasa varias veces seguidas en local (por ejemplo 3 corridas).
- El control sin la red sale rojo; el test de la presentación normal sigue corriendo sin el seam; los escáneres fijan el orden con el seam dentro.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, card del tablero movida a «done», Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones (resueltas en autónomo, bypass; 23:40 Lima)

1. **Dónde va el seam: en el ÚNICO sitio que enciende la red visual de cada aviso, no solo en el drenaje.**
   Un seam solo en el drenaje no llega a `.exhausted`: el `.retry` de la red vuelve a escribir
   `showRemoteWipeAlert = true` (y `showSheet = true` en la hoja de Apple ID) sin condición, así que el
   primer reintento monta el aviso y la red acaba en `.satisfied`. Inferido del código, no medido. Por eso
   cada red pasa a encender su flag visual por un helper (`mountRemoteWipeAlert()` en `ContentView`,
   `mountSheet()` en `AppleIDCloseNoticeModifier`) con el `#if DEBUG` dentro. Ni binding ni sonda se tocan.
2. **Un arg por red** (`-uitest-remote-wipe-notice-never-mounts`, `-uitest-apple-id-close-never-mounts`),
   nombrados en `launchForUITest`, como sus vecinos.
3. **«La condición viva se suelta» se observa por su consecuencia**: el paywall retenido detrás presenta. Y
   el `.retry` previo, porque el paywall NO aparece en los primeros segundos y el aviso no aparece nunca.
4. **Control rojo**: mutante que anula el desarme (no suelta la condición viva en `.exhausted`) en las dos
   redes, una corrida; documentado en el PR, sin dejar código.
5. **Escáneres**: el tramo del drenaje fija `… = true mountRemoteWipeAlert() arm…()`, el cuerpo del helper se
   fija entero (con el `#if DEBUG`), y los conteos de escritores se ajustan (7 → 6 en el aviso).
6. **Ticket** a `tickets/done/` (no hay device-QA: es cobertura). Card a «done».
7. Los tests nuevos van en las suites existentes de cada red (`RemoteWipeNoticeRoutingUITests`,
   `AppleIDCloseNoticeUITests`), para que el `codeGlobs` del área los recoja sin tocar el índice más que
   `lastVerified`.
