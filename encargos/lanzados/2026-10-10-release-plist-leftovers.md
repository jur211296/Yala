---
esfuerzo: medium
---
# Restos en los plist de release: build del widget, Face ID y App Attest

**Card:** tablero-restos-en-los-plist-de-release-build-del-j2kj · **Prioridad:** según la card · **Versión:** 2.1 · **Ticket:** `tickets/backlog/release-plist-leftovers-widget-build-faceid-appattest.md` (del PR #443, checklist de envío)

## Qué se pide
1. **Build del widget:** `YalaWidgets/Info.plist` fija CFBundleVersion en 3 (y quizá la versión). Que siga al de la app: `$(CURRENT_PROJECT_VERSION)` y `$(MARKETING_VERSION)`, igual en la share extension y en cualquier otro target embebido. Verifica con un build de Release que los Info.plist resultantes de app, widget y extensión tienen la misma versión y build.
2. **Face ID:** quita `NSFaceIDUsageDescription` si no queda ningún uso de LocalAuthentication (compruébalo) y sus traducciones en InfoPlist.strings.
3. **App Attest:** declara `com.apple.developer.devicecheck.appattest-environment` = production en el entitlement de Release (y development en Debug) sin romper el flujo actual; compila y comprueba que el perfil lo admite. Si el App ID no tiene la capacidad y no se puede verificar desde la Mini, déjalo anotado como paso de Jürgen en el portal y no lo fuerces.
4. Un test o script en `qa/` que falle si un target embebido vuelve a fijar su build a mano.

## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0

Medido sobre `origin/2.1` 349f3145c, en la Mini.

- **Widget:** `YalaWidgets/Info.plist` fija `CFBundleVersion = 3`; la versión ya es `$(MARKETING_VERSION)`. Se cambia a `$(CURRENT_PROJECT_VERSION)`. La share extension **no** fija nada: su plist no lleva las claves y el target tiene `GENERATE_INFOPLIST_FILE = YES`, que las rellena desde los build settings. Solo hay dos targets embebidos (widget y share). Las 20 configuraciones del proyecto ya dicen 15 / 2.1.
- **Face ID:** ningún `import LocalAuthentication` ni `LAContext` en el código (la única mención es un comentario de `FaceIDProtectionGuideView`, que es educativa). Se quita la clave de `Info.plist` y de los 16 `InfoPlist.strings`.
- **App Attest:** ninguno de los perfiles instalados en la Mini (incluido el de App Store de `com.jurgenschmidt.yala`) lleva `com.apple.developer.devicecheck.appattest-environment`, así que el App ID no tiene la capacidad. Declararlo rompería la firma de Release en el archive. **No se fuerza:** queda como paso de Jürgen en el portal, con el cambio exacto anotado en el PR. Sin el entitlement, una app distribuida atesta en producción igualmente.
- **Red:** `qa/scripts/versiones-embebidas.py` (estático, corre en Linux) + su banco `versiones-embebidas-test.sh`, enganchado en el job `coverage-index`. Modo `--app` para comparar un `.app` compilado con sus `.appex`.
- **Ticket:** vive en el PR #443, aún abierto. No lo toco aquí para no chocar al mergear; en el PR se anota que se cierra con éste.
- **Pase de estrés:** no aplica, el cambio no toca UI.
