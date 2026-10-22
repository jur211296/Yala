# Subir a TestFlight un build nuevo de Yala 2.1 desde origin/2.1 con ASC CLI, para el QA de Jürgen y el lanzamiento

## AUTONOMÍA (léelo primero)
Jürgen está dormido. **Nunca uses AskUserQuestion y nunca esperes respuesta**: decide tú, apunta la decisión en el PR y cierra de forma autónoma hasta `/cerrar-total`. Esto sustituye a la sección «Si hace falta algo de Jürgen»: si algo solo lo puede resolver él (firma, 2FA, acuerdo en ASC, tren cerrado), para, deja el estado exacto y el paso pendiente en el cierre, y cierra.

## Paso 0: esperar a que entren los PRs abiertos
Antes de compilar, espera a que #472, #473, #474, #475 y #476 estén MERGED en 2.1 (sondea con `gh pr view N --json state,mergeStateStatus,statusCheckRollup` cada pocos minutos, sin bucles de shell de más de 10 min). Si uno sale rojo, intenta arreglarlo en esta sesión (rama del PR, rebase, push) o exclúyelo con una nota en el cierre. Luego `git fetch origin` y construye desde el HEAD de origin/2.1. Di en el cierre qué PRs lleva el build.

## Contexto
Card del tablero `tablero-subir-2-1-a-testflight-para-el-qa-de-jur-c59v` (Yala 2.1, very-high). Pedido de Jürgen (12-oct 06:36): después del barrido de QA (card bapd), subir 2.1 a TestFlight. Jürgen hace hoy todo el QA y quiere lanzar 2.1 lo antes posible. Desde el último TestFlight (build 15, 4-oct) entraron muchos arreglos (#451 a #467 y lo que venga).
El proceso ya existe y salió bien tres veces: PR #116 (build 13), #225 (build 14) y el encargo `encargos/lanzados/2026-10-04-subir-testflight-para-el-qa-del-lunes.md` (build 15). **Léelo entero, sobre todo su Paso 0 y su Resultado**, y `encargos/lanzados/2026-09-23-subir-testflight-asc-cli.md`. Resumen: app `Yala`, bundle `com.jurgenschmidt.yala`, app ASC 6758253109, scheme **«Yala»** (nunca «Yala Dev»), `MARKETING_VERSION` 2.1 sin bump si el tren sigue abierto, build number global creciente en los 20 targets, archive desde el worktree con `-derivedDataPath .deriveddata/` (ignorado; `.dd` rompe `worktree-stamp.sh`), `.ipa` con copia de `.asc/ExportOptions.plist` y `destination=export`, `scripts/asc-preflight.sh`, `asc builds upload`. Las credenciales ASC ya están en la Mini; no pidas que nadie pegue keys. Revisa también `docs/RELEASE-CHECKLIST-2.1.md` §5.1 (p. ej. el build del widget fijado a mano en `YalaWidgets/Info.plist`).

## Qué se pide
1. Medir con `asc builds list --paginate` / `asc versions list` el último build y la versión abierta; elegir el siguiente build number (mayor que el último que exista; no asumas 16).
2. Bump de `CURRENT_PROJECT_VERSION` en los 20 targets; `MARKETING_VERSION` solo cambia si ASC dice que el tren 2.1 ya no está abierto (entonces para y pregunta).
3. Archive del scheme `Yala`, firmado, desde el commit del bump (`nice -n 10 xcodebuild -jobs 2`); leer `CFBundleVersion`/`CFBundleShortVersionString` del `.xcarchive`; export; preflight; `asc builds upload`.
4. Esperar a un estado útil: `VALID` + `internalBuildState: IN_BETA_TESTING` (disponible para pruebas internas). Si se queda horas en processing, reporta build number y estado y cierra.
5. En el mismo PR: el bump, el encargo con su Paso 0 y Resultado en `encargos/lanzados/`, y `docs/qa/tanda-qa-jurgen-2.1.md` (del barrido bapd) diciendo qué build de TestFlight usar.
6. Aviso de cierre: build number, versión, commit de `2.1` del que sale, estado en TestFlight y qué PRs lleva respecto al build anterior.

7. **Versión 2.1 en App Store Connect** (pedido de Lola, 2026-10-12): comprueba con `asc versions list` si existe la versión de App Store «2.1» de la app 6758253109. Si no existe, créala con la ASC CLI (`asc versions create` o el subcomando equivalente que tenga; mira `asc --help`), plataforma iOS, versión 2.1, sin enviarla a revisión. Asígnale el build recién subido cuando termine el processing si la CLI lo permite. Objetivo: que Lola pueda editar descripción, Novedades y capturas. No toques textos ni capturas tú, ni envíes a revisión. Si la CLI no puede crearla, dilo en el cierre con el paso manual (App Store Connect → app → «+ Versión»).

## Si hace falta algo de Jürgen
Firma, certificado o perfil que falte, 2FA, acuerdo o aviso pendiente en App Store Connect, tren 2.1 cerrado, o ASC rechaza el build de una forma que solo él decide: **no lo improvises**. Pregunta con **AskUserQuestion** (de día, hasta las 21:00 Lima; de noche, aplaza y cierra con el estado).

## Qué NO hay que tocar
- marketing/, Web/, ficha de App Store, capturas (Lola). Código de producto: si al firmar o subir aparece un bug bloqueante, ticket y card propios (`tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank`, sin --fecha) y avisa; no lo arregles aquí.
- No borrar builds viejos, no tocar grupos de testers, no someter a beta review externa, no cambiar bundle id ni el versionado.

## Reglas de Mini
- Pipeline serial: limpiar → archive con `xcodebuild -jobs 2` sin simulador booteado; este encargo no necesita simulador. Load < 8 antes del archive.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees retirados: bórralos al lanzar y al cerrar sin preguntar.
- Llavero: si creas cualquier key o secreto, dilo en el cierre con su nombre (no el valor) para que pase a 1Password.
- Gate: arranca sobre `origin/2.1`. Justo antes del archive, `git fetch`; si el PR anterior (bapd) sigue en CI, espera a que entre y rebasa una sola vez; si su CI falla, rebasa con lo que haya. Archive después de ese rebase, una sola vez.
- Modo autónomo: gate, PR a 2.1 en auto-merge y `/cerrar-total` sin preguntar, salvo lo de la sección «Si hace falta algo de Jürgen».

## Cómo se sabe que está bien
Build nuevo en TestFlight, mayor que el último, subido con ASC CLI desde el HEAD de `2.1` de hoy, disponible para pruebas internas (o dicho que sigue en processing con su número); PR con bump y docs en auto-merge; `/cerrar-total` hecho (Mini limpia).

## SIMULADORES iOS EN LA MINI (regla nueva, 2026-10-12)
Si usas el simulador o XCUITest: nunca más de un simulador encendido a la vez, y al terminar (y antes de cerrar) ejecuta `xcrun simctl shutdown all`. La Mini se cayó por memoria el 2026-10-12 ~13:30.

## Paso 0

Decisiones resueltas antes de tocar nada (auto-contestadas, MODO AUTÓNOMO, de noche):

- **Qué app/scheme.** `Yala` (bundle `com.jurgenschmidt.yala`, app ASC 6758253109), el pipeline de los builds 13, 14 y 15. Nunca «Yala Dev».
- **Build number.** Medido con `asc builds list --paginate` el 2026-10-12 23:45 (Lima): el tren 2.1 (pre-release `839f5044…`) lleva 11-15 y el último es el **15** del 4-oct (`VALID`). Siguiente: **16**, en los 20 targets.
- **Versión.** Medido con `asc versions list`: la última publicada es 2.0.4 (`READY_FOR_SALE`) y no hay ninguna 2.1 ⇒ el tren sigue abierto. `MARKETING_VERSION` se queda en **2.1**.
- **Widget (§5.1 del checklist).** `YalaWidgets/Info.plist` ya lleva `$(CURRENT_PROJECT_VERSION)` en `origin/2.1`: el aviso de build fijado a `3` ya no aplica. Se comprueba en el `.xcarchive`.
- **PRs que esperar.** #472-#475 ya `MERGED` al arrancar. #476 (App Attest, toca `project.pbxproj` y entitlements) en cola de auto-merge con `tests` en curso: se espera a que entre y el bump se rebasa encima, una vez. Si su CI falla, se construye sin él y se dice.
- **Versión 2.1 de App Store (pedido de Lola).** No existe. Se crea con `asc versions create --version 2.1 --platform IOS`, **sin copiar metadatos con la CLI**: lo mínimo; si ASC la crea vacía, Lola la rellena. Sin `--release-type` (lo decide Jürgen al enviar). Se le asigna el build 16 con `asc versions attach-build` cuando esté `VALID`. No se envía a revisión.
- **Máquina y Xcode.** Mini, Xcode 27.0 GA (27A266a), el mismo del 15.
- **Aislamiento y export.** Archive desde este worktree en el commit del bump, `-derivedDataPath .deriveddata/` (ignorado), `.ipa` con copia de `.asc/ExportOptions.plist` en el scratchpad con `destination=export`, `scripts/asc-preflight.sh`, `asc builds upload`.
- **Gate.** El bump toca `project.pbxproj` (no `.swift`): gate = build de `Yala` y `Yala Dev` + `validate-coverage.sh`, como en #225 y en el 15.
- **Pase de estrés.** No aplica: este PR no cambia UI, solo el número de build.
- **Grupos de testers.** No se tocan: llega al grupo interno; el externo pide beta review, decisión de Jürgen.
- **Limpieza al lanzar.** Borrados dos DerivedData huérfanos de `fixes-migracion-y-aviso-dispositivo` (6,4 GB, worktree ya retirado) y diez cachés de XcodeBuildMCP de worktrees Yala retirados. Disco: 24 GB libres en `/`.

## Resultado

- **TestFlight 16**, versión 2.1, desde `2.1` en `7ac7d21a6` (merge de #476) + el bump `359102183`. Respecto al 15 (`b216f5f11`) lleva 119 PRs: #356 a #476, más #319, #321 y #402, que entraron en ese tramo.
- Leído del `.xcarchive`: `CFBundleVersion` 16 y `CFBundleShortVersionString` 2.1 en la app, `YalaShare` y `YalaWidgets` (el widget ya no fija su build). Xcode 27A266a, SDK iphoneos27.0. Firma de distribución: `aps-environment` y `appattest-environment` en `production`, `get-task-allow` false. Preflight OK.
- `asc builds upload` → exit 0 (upload `ffe52a6f…`). `VALID` en ~2 min; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió).
- **Versión 2.1 de App Store creada** con `asc versions create` (id `7bf0521c…`, `PREPARE_FOR_SUBMISSION`), build 16 asignado con `asc versions attach-build`. ASC copió sola la ficha de 2.0.4 en los 13 idiomas (descripción y palabras clave); «Novedades» está vacío. No se tocaron textos ni capturas ni se envió a revisión.
- Trampa: `asc builds list` filtrado por `version == "16"` devuelve también un build 16 de **abril** (otro tren, `expired`), con estado `VALID`. Al sondear un número que ya existió en trenes viejos, filtra por `uploadedDate` o por el id de la subida.
