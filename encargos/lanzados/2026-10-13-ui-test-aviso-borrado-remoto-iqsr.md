# UI test del aviso de borrado remoto: keepWaiting falla 3 de 3

Card: tablero-ui-test-del-aviso-de-borrado-remoto-keep-iqsr (Yala, 2.1). Base y PR: **2.1** (fetch + rebase sobre origin/2.1 antes del PR).

## Contexto
En la QA de 2.1 (run 38426514839, HEAD f82b458), `RemoteWipeNoticeRoutingUITests.test_notice_keepWaiting_leavesTheAppWhereItWas` falla 3 de 3 (tanda 2 UI, advisory) y `test_noticeThatNeverMounts_netExhausts_andReleasesTheRouter` falló 1 vez. Mira los logs del run con `gh run view 38426514839 -R jur211296/Yala --log-failed`.

## Qué hacer
1. Reproduce ambos tests en local con `-only-testing` (`nice -n 10 xcodebuild -jobs 2`, un simulador).
2. Decide si el fallo está en la app o en el test, con evidencia (logs, capturas, xcresult).
3. Arréglalo donde toque, sin debilitar el test; si el test era incorrecto, explica por qué.
4. PR a 2.1 que explique la causa raíz, qué cambiaste y cómo lo probaste (repeticiones en verde, p. ej. 5/5). /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar. Hay otra sesión Yala viva pero ociosa (Yala--auditoria-ux-2-2-lote-1-variantes, esperando a Jürgen, sin simulador): no la toques. Sin deploy. Cierra con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: en local (iOS 27.0) la suite pasa 12/12 y 10/10 con 9 núcleos cargados. En el CI
(iOS 26.5), una rama de diagnóstico desechable con `NSLog` en el drenaje reprodujo los dos rojos (1/12 cada uno) y el
de su control `PaywallInboxAlertRoutingUITests` (3/12). En 8 de ~60 arranques la oferta se drenó con la matriz ya
tapada por el aviso recién drenado: el `onChange(of: revision)` corría antes que el observador que publica el bloqueo.

**D1 · ¿El fallo está en la app o en el test?** → En la app.
Por qué: los DIAG muestran `drainedCV trialOffer` con `blocker=remoteWipeAlert` ya puesto; los tres síntomas (aviso
que no sale, oferta que no vuelve, paywall a destiempo) son las dos caras de dos presentaciones del mismo anchor.
Alternativa descartada: alargar esperas o anclar la ventana del test, que taparía un bug que le pasa a una persona.

**D2 · ¿Dónde se cierra la ventana?** → En `drainContentViewIntents`, `defer { updateContentViewReadiness() }` tras
el manejador.
Por qué: es el único sitio por el que entra todo lo que un drenaje enciende, y `update…` ya bloquea en el acto y
libera aplazado, así que no añade drenajes. Alternativas descartadas: un guard al principio del drenaje (no publica
`shellModalBlocker` a tiempo para Panel y MainTab) y tocar los 28 observadores (mismo efecto, más superficie).

**D3 · ¿Se tocan los tests?** → No.
Por qué: afirman justo lo que el bug rompe; el arreglo tiene que ponerlos verdes sin aflojarlos.

**D4 · ¿Cómo se fija?** → Source-scan en `ContentViewReadinessReleaseWiringTests` del `defer` en su sitio, con
mutante (quitarlo debe dar rojo). La red de comportamiento sigue siendo la suite en 26.5.

**D5 · ¿Cómo se prueba?** → La misma rama de diagnóstico con el arreglo, en el CI 26.5: cero drenajes con la matriz
tapada en ~60 arranques y las dos suites en verde; y la suite en local 27.0.

**D6 · Los manejadores que encienden su bloqueo en un `Task` (invitación confirmada) siguen por el observador.** →
Fuera de alcance, se anota en el PR. Por qué: no es lo medido y no tiene rojo.

**D7 · La rama `diag/iqsr-remote-wipe-ci`** → desechable: se borra al cerrar, nunca se mergea. Lleva un commit con
`--no-verify` porque su Swift es instrumentación que no pasa el gate a propósito.
