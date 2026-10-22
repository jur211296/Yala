# Subir a TestFlight un build nuevo de Yala 2.1 desde origin/2.1 con ASC CLI, para el QA de Jürgen y el lanzamiento

## Paso 0: base y qué tiene que llevar el build
No esperes el CI de ningún PR para empezar ni para rebasar. `git fetch origin` y trabaja sobre origin/2.1.
Este build es el **TestFlight 17**: tiene que llevar dentro el PR #527 (Novedades de 2.1, tres tarjetas al actualizar) y, si ya entró, el #528 (solo docs: la tanda de QA al día). A las 16:16 del 16-oct los dos estaban en cola de auto-merge a 2.1. Mide primero el último build y prepara el bump; justo antes del archive haz `git fetch` y comprueba con `gh pr view 527` que #527 está en origin/2.1. Si todavía está en cola, no subas un build sin él: es el contenido del build, no un gate de rebase. Si el CI de #527 falla, no lo arregles aquí: para, deja el estado en el cierre y avisa. Di en el cierre qué PRs lleva el build respecto al 16.

## iCloud: el campo nuevo del flujo de caja
El barrido de QA 2.1 (2) (PR #528) dice que antes de probar el 17 hay que desplegar en producción el campo nuevo del flujo de caja en el esquema de iCloud (`docs/cloudkit-schema-diff-2.1.md`). Eso lo hace Jürgen en la consola de CloudKit: **tú no lo despliegues ni toques la consola**. Sí recuérdalo en el cierre como el primer paso de Jürgen antes de instalar el 17.

## Contexto
Pedido de Jürgen (16-oct 16:14): al cerrar el Barrido de QA 2.1 (2), subir un TestFlight nuevo de 2.1 para su QA guiado y el lanzamiento. El último es el build 16 (PR #477, card «Subir 2.1 a TestFlight para el QA de Jürgen y el lanzamiento», ya en done). Ningún arreglo posterior al #514 está en el 16. Esta sesión tiene su propia card nueva en el tablero («Subir el TestFlight 17 de 2.1 con las Novedades»); muévela tú a in qa (asignada a jurgen) al cerrar si el build quedó disponible.
El proceso ya existe y salió bien cuatro veces: PR #116 (build 13), #225 (build 14), PR #477 (build 16) y el encargo `encargos/lanzados/2026-10-04-subir-testflight-para-el-qa-del-lunes.md` (build 15). **Léelo entero, sobre todo su Paso 0 y su Resultado**, y `encargos/lanzados/2026-09-23-subir-testflight-asc-cli.md`. Resumen: app `Yala`, bundle `com.jurgenschmidt.yala`, app ASC 6758253109, scheme **«Yala»** (nunca «Yala Dev»), `MARKETING_VERSION` 2.1 sin bump si el tren sigue abierto, build number global creciente en los 20 targets, archive desde el worktree con `-derivedDataPath .deriveddata/` (ignorado; `.dd` rompe `worktree-stamp.sh`), `.ipa` con copia de `.asc/ExportOptions.plist` y `destination=export`, `scripts/asc-preflight.sh`, `asc builds upload`. Las credenciales ASC ya están en la Mini; no pidas que nadie pegue keys. Revisa también `docs/RELEASE-CHECKLIST-2.1.md` §5.1 (p. ej. el build del widget fijado a mano en `YalaWidgets/Info.plist`).

## Qué se pide
1. Medir con `asc builds list --paginate` / `asc versions list` el último build y la versión abierta; elegir el siguiente build number (mayor que el último que exista; no asumas 16).
2. Bump de `CURRENT_PROJECT_VERSION` en los 20 targets; `MARKETING_VERSION` solo cambia si ASC dice que el tren 2.1 ya no está abierto (entonces para y pregunta).
3. Archive del scheme `Yala`, firmado, desde el commit del bump (`nice -n 10 xcodebuild -jobs 2`); leer `CFBundleVersion`/`CFBundleShortVersionString` del `.xcarchive`; export; preflight; `asc builds upload`.
4. Esperar a un estado útil: `VALID` + `internalBuildState: IN_BETA_TESTING` (disponible para pruebas internas). Si se queda horas en processing, reporta build number y estado y cierra.
5. En el mismo PR: el bump, el encargo con su Paso 0 y Resultado en `encargos/lanzados/`, y `docs/qa/tanda-qa-jurgen-2.1.md` (rehecha en el PR #528) diciendo que el build a usar es el 17.
6. Aviso de cierre: build number, versión, commit de `2.1` del que sale, estado en TestFlight y qué PRs lleva respecto al build anterior.

7. **Versión 2.1 en App Store Connect**: ya existe (se creó con el build 16). Cuando el 17 termine el processing, asígnaselo a la versión 2.1 si la CLI lo permite, sin enviarla a revisión ni tocar textos ni capturas (son de Lola). Si no se puede, dilo en el cierre.

## Si hace falta algo de Jürgen
Firma, certificado o perfil que falte, 2FA, acuerdo o aviso pendiente en App Store Connect, tren 2.1 cerrado, o ASC rechaza el build de una forma que solo él decide: **no lo improvises**. Pregunta con **AskUserQuestion** (de día, hasta las 21:00 Lima; de noche, aplaza y cierra con el estado).

## Qué NO hay que tocar
- marketing/, Web/, ficha de App Store, capturas (Lola). Código de producto: si al firmar o subir aparece un bug bloqueante, ticket y card propios (`tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank`, sin --fecha) y avisa; no lo arregles aquí.
- No borrar builds viejos, no tocar grupos de testers, no someter a beta review externa, no cambiar bundle id ni el versionado.

## Reglas de Mini
- Pipeline serial: limpiar → archive con `xcodebuild -jobs 2` sin simulador booteado; este encargo no necesita simulador. Load < 8 antes del archive.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees retirados: bórralos al lanzar y al cerrar sin preguntar.
- Llavero: si creas cualquier key o secreto, dilo en el cierre con su nombre (no el valor) para que pase a 1Password.
- REBASE AL FINAL, SIN ESPERAR CI: arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR, tampoco el de la sesión anterior. Justo antes de abrir tu PR, `git fetch && git rebase origin/2.1`; si el rebase toca lo tuyo, recompila y corre los tests afectados una vez, con un solo simulador.
- Modo autónomo: gate, PR a 2.1 en auto-merge y `/cerrar-total` sin preguntar, salvo lo de la sección «Si hace falta algo de Jürgen».

## Cómo se sabe que está bien
Build nuevo en TestFlight, mayor que el último, subido con ASC CLI desde el HEAD de `2.1` de hoy, disponible para pruebas internas (o dicho que sigue en processing con su número); PR con bump y docs en auto-merge; `/cerrar-total` hecho (Mini limpia).

## SIMULADORES iOS EN LA MINI (regla nueva, 2026-10-12)
Si usas el simulador o XCUITest: nunca más de un simulador encendido a la vez, y al terminar (y antes de cerrar) ejecuta `xcrun simctl shutdown all`. La Mini se cayó por memoria el 2026-10-12 ~13:30.

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO, de día:

- **Qué app/scheme.** `Yala` (bundle `com.jurgenschmidt.yala`, app ASC 6758253109), el pipeline de los builds 13-16. Nunca «Yala Dev».
- **Build number.** Medido con `asc builds list --paginate` el 2026-10-16 16:20 (Lima): el tren 2.1 lleva 11-16 y el último es el **16** del 12-oct (`VALID`). Siguiente: **17**, en los 20 targets.
- **Versión.** Medido con `asc versions list`: la 2.1 de App Store existe en `PREPARE_FOR_SUBMISSION` y la última publicada es 2.0.4 ⇒ el tren sigue abierto. `MARKETING_VERSION` se queda en **2.1**.
- **Widget (§5.1).** `YalaWidgets/Info.plist` lleva `$(CURRENT_PROJECT_VERSION)`: no hay build fijado a mano. Se comprueba en el `.xcarchive`.
- **#527 y #528.** Al arrancar, los dos en cola de auto-merge con `tests` en curso. El archive espera a que #527 esté en `origin/2.1` (es el contenido del build). La línea del build en `docs/qa/tanda-qa-jurgen-2.1.md` se escribe sobre la versión de #528, para no chocar con su reescritura.
- **Máquina y Xcode.** Mini, Xcode 27.1 (27A9275), SDK iphoneos 27.1: el Xcode cambió respecto al 16 (27.0, 27A266a). Es el único instalado.
- **Aislamiento y export.** Archive desde este worktree en el commit del bump, `-derivedDataPath .deriveddata/` (ignorado), `.ipa` con copia de `.asc/ExportOptions.plist` en el scratchpad con `destination=export`, `scripts/asc-preflight.sh`, `asc builds upload`.
- **Versión 2.1 en ASC.** Ya existe con el build 16. Se le asigna el 17 con `asc versions attach-build` cuando esté `VALID`. No se tocan textos ni capturas, no se envía a revisión.
- **Gate.** El bump toca `project.pbxproj` (no `.swift`): gate = build de `Yala` y `Yala Dev` + `validate-coverage.sh`, como en los builds 14-16.
- **iCloud.** El campo nuevo del flujo de caja (`docs/cloudkit-schema-diff-2.1.md`) lo despliega Jürgen en la consola de CloudKit antes de instalar el 17. Esta sesión no toca la consola.
- **Pase de estrés.** No aplica: este PR no cambia UI, solo el número de build.
- **Grupos de testers.** No se tocan; el externo pide beta review, decisión de Jürgen.
- **Limpieza al lanzar.** Sin DerivedData de worktrees retirados (el único en `/Volumes/ExtDev/DerivedData` es del árbol principal) y sin cachés de XcodeBuildMCP de worktrees Yala retirados. Disco: 16 GB libres en `/`.

## Resultado

- **TestFlight 17**, versión 2.1, desde `2.1` en `55c473e03` (merge de #527) + el bump. El PR se rebasó después sobre `bfb136dcc` (#528, solo docs), que no cambia el binario.
- Respecto al 16 (`7ac7d21a6`) lleva 27 PRs: #427, #477-#480, #484, #486, #487, #490, #501 y #511-#527.
- Leído del `.xcarchive`: 2.1 (17) en la app, `YalaShare` y `YalaWidgets`. Xcode 27A9275, SDK iphoneos27.1. Firma de distribución: `aps-environment` y `appattest-environment` en `production`, `get-task-allow` false. Preflight OK.
- `asc builds upload` → exit 0 (upload `41de397c…`). `VALID` en ~2 min; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió).
- **Versión 2.1 de App Store**: build 17 asignado con `asc versions attach-build` (sustituye al 16). Sigue en `PREPARE_FOR_SUBMISSION`; no se tocaron textos ni capturas ni se envió a revisión.
- Esquema de iCloud: sin desplegar (lo hace Jürgen antes de instalar el 17).
- Trampa: `scripts/asc-preflight.sh` lee el `.xcarchive`, no el `.ipa`; con el `.ipa` sale «No se encontró el Info.plist».
