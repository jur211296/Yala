---
esfuerzo: medium
---
# «Crear otra cuenta» con un Apple ID que ya tenía cuenta termina diciendo «Ya tenías una cuenta, has entrado en ella»

## Contexto
Card del tablero `tablero-crear-otra-cuenta-con-apple-entra-en-la-ni6g` (lista para lanzar, vence 2026-10-11). Ticket: `tickets/backlog/born-cloud-signup-lands-on-existing-account-silently.md` (review adversarial, lente de producto, de `beacon-routes-only-never-blocks`, 2026-09-10).

Lo que le pasa al usuario: con el faro de Apple puesto y su cuenta viva, «Es mi primera vez» → «Crear otra cuenta» → «Tu cuenta en la nube» → «Registrarse con Apple». Lee «Creando tu cuenta…» y termina en «¡Tu cuenta está lista!», pero está dentro de la cuenta que ya existía, y nada se lo dice. Si el Apple ID es compartido, es la cuenta de otra persona.

**Decisión de Jürgen (2026-10-07), tal cual en el ticket:** «Sí. Se avisa: **«Ya tenías una cuenta, has entrado en ella»**.» Corresponde a la primera pregunta del ticket: la terminal del alta que acaba en `existing_stable` deja de compartir «¡Tu cuenta está lista!» con la re-entrada y dice ese texto. La segunda pregunta (avisar ya en el intro del alta) no se elige. El texto, con las palabras de Jürgen, va a todos los idiomas de la app (los 16 `.lproj`).

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- Un Apple ID tiene una sola identidad de Sign in with Apple, así que el claim del alta contesta `existing_stable` y el flujo va a la variante A de §f.1: `AccountClaimDecision` → `.routeReturningUser` → `continueAsReturningUser` → `runSignInFlow` → adopt → `.reentryReady`.
- Ficheros de hoy en 2.1: `Yala/App/Logic/CloudWelcomeSignInFlow.swift` (`.reentryReady`, `.continueAsReturningUser`), `Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift` (la terminal de `.reentryReady` y la rama de `.continueAsReturningUser`) y `Yala/Services/CloudSync/BornCloudSignUpService.swift`.
- El comportamiento de entrar en la cuenta viva es correcto (no sembrar encima de una cuenta viva) y no se toca: lo que falta es decírselo a la persona.
- Ojo con la decisión del 2026-09-09: no añadir avisos que nadie pidió. Solo cambia la terminal de este camino.

Antes de esta sesión va en la cola `wipe-copy-reads-one-axis-while-the-sheet-reads-two`; no depende de ella.

Para orientarte: `CLAUDE.md`, `.claude/rules/l10n.md`, `.claude/rules/swiftdata-cloudkit.md`, `.claude/rules/testing.md`, `docs/planning/BRAND-VOICE.md` §7 y el ticket.

Antes de tocar UI, mira `~/Claude/referencias-ui/README.md` (referencias de patrones de la flota: inspiración, no copiar pantallas ni marcas) y respeta `.claude/rules/swiftui-ds.md`.

## Que se pide
1. Fijar con test de la lógica del flujo que hoy el alta que acaba en `existing_stable` y la re-entrada desde «Ya tengo cuenta» terminan en la misma fase y el mismo texto.
2. Distinguir la terminal del alta que acaba en `existing_stable` (una fase propia o un origen en la fase, lo más robusto y testeable) y que diga «Ya tenías una cuenta, has entrado en ella». La re-entrada desde «Ya tengo cuenta» sigue con «¡Tu cuenta está lista!».
3. Texto en los 16 idiomas con `qa/scripts/add-l10n-key.sh`: en español, las palabras de Jürgen tal cual; en los demás, la traducción natural con el mismo sentido.
4. Tests: alta + `existing_stable` → texto nuevo; re-entrada → texto de siempre. Controles rojos con el código viejo. Si hay costura de UI test para el claim, un XCUITest; si no, la lógica pura basta.
5. Si el cambio se ve en el simulador, deja `capturas/antes.png` y `capturas/despues.png` en el worktree, con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas y deja un guion de device-QA en `tickets/qa/`. Sign in with Apple en el simulador suele no dejar llegar aquí: en ese caso, guion de device-QA.
6. Anota la decisión en el ticket y muévelo según las convenciones del repo.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-crear-otra-cuenta-con-apple-entra-en-la-ni6g` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.
8. Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).

## Que NO hay que tocar
- El claim, el adopt y el ruteo a la cuenta existente: siguen igual.
- El intro del alta (la segunda pregunta del ticket no se eligió).
- Los textos de la re-entrada normal.
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
- «Crear otra cuenta» con un Apple ID con cuenta viva termina diciendo «Ya tenías una cuenta, has entrado en ella»; la re-entrada normal no cambia.
- Tests con controles rojos con el código viejo; paridad de l10n en verde con el texto en los 16 idiomas.
- Builds `Yala` y `Yala Dev` verdes; capturas antes y después, o guion de device-QA.
- PR a 2.1 en auto-merge, ticket con la decisión anotada, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Sesión abierta a las 21:00 de Lima: decido yo, sin preguntas.

1. **Dónde vive la diferencia.** Fase propia, `CloudWelcomeSignInPhase.signUpEnteredExistingAccount`, no un flag en `.reentryReady`: el compilador obliga a cada `switch` exhaustivo (`canGoBack`, la vista, el poll) a decidir qué hace con ella.
2. **Quién la produce.** `CloudWelcomeSignInFlow.phase(for:…, origin:)` con un `WelcomeAdoptOrigin` (`.reentry` / `.signUpFoundExistingAccount`). Solo cambia la rama `.cloudActive`; el resto de estados ignora el origen.
3. **Quién sabe el origen.** `runSignInFlow(origin:)` con parámetro SIN valor por defecto: cada llamador lo declara. Solo la rama `.continueAsReturningUser` del alta pasa `.signUpFoundExistingAccount`. Se guarda en un `@State` que el poll lee; cada adopt pasa por `runSignInFlow`, que lo reescribe (los reintentos del alta vuelven a reclamar por `runBornCloudFlow`).
4. **Qué cambia en pantalla.** Solo el título: «Ya tenías una cuenta, has entrado en ella». Cuerpo («Ya puedes empezar. Todo lo que registres se guardará en tu cuenta.»), icono y botón siguen, porque siguen siendo ciertos. Salida: `onFinishedToApp`, la misma que la re-entrada (el flag de onboarding ya lo marcó `onAdoptStarted`). Identificador propio para el device-QA.
5. **Fuera de alcance, asumido.** La terminal `.relaunch` («Ya casi está — reinicia Yala») cuando el alta con cuenta existente cae en un teléfono con el espejo de iCloud puesto: no promete crear nada y la decisión habla de «¡Tu cuenta está lista!». Queda como hallazgo.
6. **Verificación.** Sin costura de UI test para el claim y con SIWA no conducible en el simulador: tests de lógica + guion de device-QA, sin capturas.
