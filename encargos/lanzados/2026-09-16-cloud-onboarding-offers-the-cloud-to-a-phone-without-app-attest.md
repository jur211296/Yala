# Conectar la puerta: sin App Attest no ofrecer la nube en el Welcome

## Contexto
Ticket: `tickets/backlog/cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest.md`.

`AttestSyncGate.shouldOfferCloudOnly(isAttestSupported:)` existe desde I7b con la decisión del owner de bloquear por adelantado, y **no tiene ningún llamador** en Yala/. Los docblocks mienten: nada caza el caso antes de elegir. Esa persona entra a nube y nada sube; solo puede salir tras el flujo del #175.

Opciones del ticket: (1) conectar la puerta al Welcome; (2) retirar la función; (3) medir primero.

## NOCHE — decisión recomendada
**Opción 1:** conectar la puerta al Welcome — sin App Attest no se ofrece la nube. Encaja con la decisión DARK original. Sin AskUserQuestion. Si al medir el alcance aparece un choque de producto demasiado gordo, aparca y avisa a Frank.

## Que se pide
1. Enchufar `shouldOfferCloudOnly` (o equivalente) en el flujo Welcome / elección de nube para que un teléfono sin Attest no vea / no pueda elegir «Tu cuenta en la nube».
2. Corregir docblocks mentirosos.
3. Tests / preview según el repo.
4. Gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si gate OK, `/cerrar-total`. Bugs nuevos → ticket. No Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/`/cerrar-total` sin preguntar. Solo parar ante decisión/acceso real (noche: aparca). UI tests CI advisory.

## Que NO
marketing/; no reopen #175–#179 salvo reutilizar patrón.

## Como se sabe que esta bien
Sin Attest: la nube no se ofrece (o no se puede elegir). Con Attest: flujo igual. Board al día + `/cerrar-total`.

## Avisos Frank
Webhook local Mini (URL/key local, no en git): (1) decisión/acceso; (2) PR/preview; (3) `/cerrar-total` + resumen usuario; (4) sin siguiente paso — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión nocturna, 03:49 Lima, bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

### Lo medido antes de decidir

- `AttestSyncGate.shouldOfferCloudOnly` sigue sin llamador en `Yala/`: solo lo llama su test.
- Las cards de «Es mi primera vez» las decide un único gate, `WelcomeNewOptionsGate.live`. Lo leen tres puertas: el
  Welcome, «Crear otra cuenta» y «Activar Yala completo» (paso 8, «mismo gate de visibilidad»).
- El cliente consigue token por dos caminos (`AppAttestClient.performRefresh`): App Attest si `isSupported`, y si no el
  bypass de dev, que solo existe en DEBUG con `YALA_DEV_SHARED_SECRET`. Sin ninguno lanza `.unavailable` en cada intento.
- El simulador no tiene App Attest y ningún scheme compartido define el secreto. Un XCUITest tampoco lo hereda. ⇒ el
  simulador es, de verdad, un teléfono sin App Attest.
- Un iPhone real con build de release dice `isSupported == true`: producción atesta (`POST /v1/attest/register - Ok`
  del 2026-07-31, en `gateway-attest.md`), y sin eso tampoco funcionaría la IA.
- Solo un montaje de QA vivo elige la nube en un simulador sin App Attest: el de
  `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (en `qa`). Los de `beacon-routes-only-never-blocks`
  y `full-mode-activation-must-ask-where-personal-data-lives` van en iPhone real y no cambian.
- «Migrar a la nube» (Ajustes) tampoco mira el attest. Por el orden que documenta `MigrationStateMachine` (el servidor
  confirma antes de persistir el modo), la migración falla sin cambiar de modo. **Inferido, no ejecutado.**
- **Medido a mitad de la implementación: el alta tiene dos puertas más, fuera del chooser.** En la pantalla de entrar,
  «No encontramos una cuenta» ofrece «Crear mi cuenta», y el mismatch del faro ofrece «Crear cuenta con…»
  (`WelcomeCloudSignInView.switchToSignUp`). Ninguna consulta un gate: tampoco el kill del alta
  (`cloudOnboardingChoiceEnabled`), y eso es anterior a este encargo. Las dos existen por decisión de Jürgen: el paso 6
  («el veredicto dejó de ser una pared») y el bloque [I] («No encontramos una cuenta» ofrece crearla).

### Decisiones

**D1 · ¿Conectar, retirar o medir?** → Conectar (opción 1).
Por qué: es la decisión del owner (bloquear por adelantado, 2026-07-06) y la del encargo. Alternativa descartada: retirar,
que deja la trampa abierta con la salida del #175 como única red.

**D2 · ¿Qué es «tener App Attest»?** → Lo que usa el cliente para conseguir token: `isSupported`, o en DEBUG el bypass con
secreto. Vive en un solo sitio, `AppAttestClient.canObtainSessionToken`, junto a `performRefresh`.
Por qué: la puerta no puede prometer una nube que el cliente no puede usar, ni negarla a un simulador que sí sube.
Alternativas descartadas: `isSupported` a secas (esconde la nube al simulador con secreto); eximir al simulador o a DEBUG,
que haría que QA y producción se comporten distinto, la lección con la que abre `gateway-attest.md`.

**D3 · ¿Dónde se engancha?** → Como término de `WelcomeAccountChoiceLogic.visibleNewOptions`, que llama a
`AttestSyncGate.shouldOfferCloudOnly`, alimentado desde `WelcomeNewOptionsGate.live`. Cubre las tres puertas a la vez.
Por qué: la lógica decide qué cards hay (la vista solo las ordena), y las tres puertas comparten gate por decisión de
Jürgen. Alternativa descartada: gatear solo el container del Welcome, que partiría el gate y dejaría a la activación
ofreciendo la nube.

**D4 · ¿Qué ve quien no tiene App Attest?** → Nada nuevo: con una sola card el chooser hace bypass a la rama privada, el
mismo recorrido del kill-switch. Sin copy.
Por qué: aún no hay datos suyos en juego, solo recorrido, y en la puerta de captación no se añade fricción. Alternativa
descartada: la card deshabilitada con explicación, copy en 16 idiomas para una opción que nadie puede elegir.

**D5 · ¿Entran «Ya tengo una cuenta» y el encaminamiento del faro?** → No.
Por qué: es otro objeto, una cuenta que ya existe. Esconder la entrada le quitaría la puerta a su propia cuenta. Lo que le
pasa al entrar (la ruedecita eterna) ya tiene ticket: `cloud-hydration-spinner-never-gives-up-without-attest`.

**D6 · ¿Entra «Migrar a la nube» de Ajustes?** → No: ticket nuevo en backlog.
Por qué: otro objeto con su propia decisión, y por lo inferido no deja a nadie atrapado.

**D7 · ¿Cómo pasan los XCUITest del chooser, si el simulador no tiene App Attest?** → Seam nuevo
`-uitest-fake-attest-support` (parámetro `fakeAttestSupport:`). Finge solo la entrada de la puerta, no al cliente. Sin él
vale la verdad del host. Lo llevan los tests que necesitan ver la card de la nube.
Por qué: `.claude/rules/testing.md` pide que el test de la condición corra sin el seam. Alternativa descartada: que
`-uitest-cloud-chooser` finja también el attest, que dejaría la condición sin ningún XCUITest posible.

**D8 · ¿Cómo se prueba la condición?** → Cinco redes: (a) la tabla unitaria del término; (b) un XCUITest negativo por
puerta —«Es mi primera vez», «Crear otra cuenta» (añadido tras la review) y la activación—, con `-uitest-cloud-chooser` y
sin el seam; (c) el
source-scan del cuerpo entero de `live` y de `canObtainSessionToken`, porque en el host de test el lado `true` es
inalcanzable y un `{ false }` solo lo ve un scan; (d) la paridad del nombre del seam; (e) un mutante por red.

**D9 · ¿Y el montaje del #175, que elige la nube en el simulador?** → Se anota en su ticket, sin reabrirlo: el simulador
sin secreto ya no ofrece «Tu cuenta en la nube». La cuenta se crea por «Ya tengo una cuenta» → Google → «No encontramos una
cuenta» → «Crear mi cuenta», que no mira el attest (D15); si esa puerta se cierra, con el secreto puesto y quitado antes del
paso 1. Inferido, no ejecutado. No encontré el secreto de dev en `~/Secrets/yala-gateway/`, así que la segunda vía puede
pedir volver a ponerlo en staging.

**D10 · ¿Qué docblocks?** → Los tres de `AttestSyncGate` (cabecera, `classify`, `shouldOfferCloudOnly`), la cabecera de
`WelcomeAccountChoiceLogic`, el de `WelcomeNewOptionsGate` y la lista de motivos del bypass en `WelcomeNewChooserView`. La
convención durable va a `.claude/rules/gateway-attest.md`.

**D11 · ¿Canario para contar esos teléfonos?** → No.
Por qué: el encargo elige la opción 1, no la 3, y `live` se evalúa en cada render, así que un canario pide deduplicar.
Queda declarado que la población sigue sin medir.

**D12 · ¿En qué estado cierra el ticket?** → `qa`, con un único paso en iPhone real: «Es mi primera vez» sigue enseñando
«Tu cuenta en la nube».
Por qué: ningún simulador prueba que un iPhone real diga `isSupported == true`, y si no lo dijera la nube desaparecería
para todos. El lado sin App Attest lo cubre el simulador, que es ese teléfono.

**D13 · ¿Review adversarial?** → Sí, acotada: dos lentes y la regla del área contra el diff.
Por qué: no es de las familias obligatorias, pero su fallo caro, esconder la nube a todos en la puerta de captación, es
silencioso.

**D14 · ¿ADR?** → No. La decisión existe desde el 2026-07-06; lo nuevo es cómo se cumple, y eso es convención de área.

**D15 · ¿Entran «Crear mi cuenta» y «Crear cuenta con…» de la pantalla de entrar?** → No: ticket propio
(`cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`).
Por qué: es el mismo objeto —un alta—, pero esconder esos botones vuelve pared dos pantallas que Jürgen decidió que no lo
fueran (paso 6 y bloque [I]), y elegir entre la trampa y la pared es suyo. Alternativa descartada: cerrarlas de noche con la
capacidad, que además dejaría esas puertas obedeciendo al attest y no al kill del alta: medio gate.

### Ficheros

Más de tres; el encargo es autónomo y sigo sin esperar aprobación.

| Fichero | Qué cambia |
|---|---|
| `Yala/App/Services/AppAttestClient.swift` | `canObtainSessionToken`: el espejo en booleano de `performRefresh` |
| `Yala/Services/CloudSync/AttestSyncGate.swift` | `shouldOfferCloudOnly` pasa a `nonisolated` y gana llamador; tres docblocks |
| `Yala/App/Logic/WelcomeAccountChoiceLogic.swift` | término `isAttestSupported` en `visibleNewOptions`; `live` lo alimenta; docblocks |
| `Yala/App/UITestHooks.swift` | seam `fakeAttestSupport` |
| `Yala/App/Views/Onboarding/WelcomeNewChooserView.swift` | solo docblock: un motivo más de bypass |
| `YalaTests/WelcomeAccountChoiceLogicTests.swift` · `WelcomeNewChooserOrderTests.swift` | firma nueva, tabla, scans |
| `YalaUITests/Support/XCUIApplication+Yala.swift` | parámetro `fakeAttestSupport:` |
| `YalaUITests/Flows/WelcomeChooserUITests.swift` · `FullModeActivationChooserUITests.swift` | seam en los positivos; un negativo cada uno |
| `qa/coverage-index.json` · `.claude/rules/gateway-attest.md` · `tickets/` · `docs/TICKETS.md` | cobertura, regla, tablero |
