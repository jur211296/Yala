# Subir a TestFlight un build nuevo de Yala desde origin/2.1 con ASC CLI, para el QA del lunes

## Contexto
Jürgen dejó la cola de 2.1 de este fin de semana así: rediseños (tendencias, capturas de onboarding, hero, dictado, registro por voz, registro por imagen, vistas del registro en grupos), barrido QA y, al final, **subida a TestFlight con asc-cli como siempre**. Todo eso ya está hecho o en cola de merge:
- PR #354 (gasto de grupo: dice qué te toca y se edita con una frase) ya está mergeado en `2.1`.
- PR #355 (barrido QA: 36 tickets para el iPhone y `qa/guion-tanda.md` con el bloque R de rediseños) está en cola de auto-merge; es solo docs.
- El guion del lunes dice que **R11 (gasto de grupo, #354) se prueba en el TestFlight que sale después**, con los grupos reales de Jürgen, porque Yala Dev no tiene grupos de 3 personas. Este build es ese TestFlight.

El proceso ya existe y salió bien dos veces: PR #116 (build 13, 9-sep) y PR #225 (build 14, 23-sep). Lee `encargos/lanzados/2026-09-23-subir-testflight-asc-cli.md` (su Paso 0 tiene las decisiones: app `Yala`, bundle `com.jurgenschmidt.yala`, app ASC 6758253109, `MARKETING_VERSION` 2.1 sin bump si el tren sigue abierto, build number global creciente en los 20 targets, archive desde el worktree con `-derivedDataPath` dentro, `.ipa` con `destination=export` y `asc builds upload`, `scripts/asc-preflight.sh`). Las credenciales ya están en la Mini; no pidas que nadie pegue keys.

Base: `origin/2.1` al día. Worktree propio.

## Que se pide
1. Medir con `asc builds list` / `asc versions list` el último build y la versión abierta; elegir el siguiente build number (mayor que el último que exista, no asumas 15).
2. Bump de `CURRENT_PROJECT_VERSION` en los 20 targets según la convención; `MARKETING_VERSION` solo cambia si ASC dice que el tren 2.1 ya no está abierto (entonces para y pregunta).
3. Archive del scheme de distribución `Yala`, firmado, desde el commit del bump; preflight; `asc builds upload`.
4. Esperar a un estado útil (VALID / IN_BETA_TESTING en el grupo interno). Si se queda horas en processing, reporta build number y estado y cierra.
5. Actualizar en el mismo PR lo mínimo: el guion `qa/guion-tanda.md` y el ticket de R11 (gasto de grupo) diciendo qué build de TestFlight usar, y el encargo con su Paso 0 en `encargos/lanzados/`. Si `#355` aún no entró cuando toques el guion, espera a que entre y rebasa (ver gate abajo).
6. Aviso de cierre con: build number, versión, commit de `2.1` del que sale, estado en TestFlight (interno ya lo ve o processing) y qué bloques del guion del lunes van en este build.

GATE DESPUÉS DEL CI DEL PR ANTERIOR: la sesión arranca ya, sobre `origin/2.1`. No esperes a que el PR anterior (#355) entre y no partas de su rama. Justo antes del gate (y antes del archive), mira si #355 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build/archive va después de ese rebase, una sola vez.

PIPELINE SERIAL EN LA MINI: limpiar → build/archive con `xcodebuild -jobs 2` sin simulador booteado → solo si hace falta, 1 simulador → apagarlo y borrarlo. No solapar compilación con simulador ni tests. Este encargo no necesita simulador.

DERIVEDDATA Y CACHÉS DE XCODEBUILDMCP: al lanzar y al cerrar, borra sin pedir aprobación el DerivedData de esta sesión (el de tu worktree) y las cachés de XcodeBuildMCP de worktrees que ya no existen o cuyo PR ya se mergeó. No toques DerivedData ni cachés de un worktree vivo. Si el borrado falla, dilo en el cierre; no despiertes a Jürgen para autorizarlo. Disco al lanzar: ~36 GB libres.

LLAVERO: si creas cualquier key o secreto en el Llavero de la Mini, dilo en el cierre con su nombre (no el valor) para que pase a 1Password.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR, docs/board del repo, `docs/TICKETS.md` si tocaste tickets, merge a `2.1` (auto-merge) y `/cerrar-total` sin preguntar. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en este encargo. Solo parar ante un acceso real que falte (secreto ASC, firma, cuenta) o si ASC rechaza el build de una forma que solo Jürgen decide. Diurno hasta las 21:00 Lima: si eso pasa, pregunta con AskUserQuestion; de noche, aplaza.

/cerrar-total al terminar, dejando la Mini limpia (sin simuladores encendidos, DerivedData de la sesión borrado, worktree retirado si el PR ya entró).

## Que NO hay que tocar
- No marketing/, no Web/, no ficha de App Store ni capturas (eso es Lola).
- No código de producto: si al firmar o subir aparece un bug bloqueante, ticket propio y avisa; no lo arregles aquí.
- No borrar builds viejos de TestFlight.
- No tocar los grupos de testers ni someter a beta review externa (decisión de Jürgen).
- No cambiar bundle id ni el esquema de versionado.

## Como se sabe que esta bien
- Hay un build nuevo en TestFlight, mayor que el último existente, subido vía ASC CLI desde el HEAD de `2.1` de hoy (con #354 dentro).
- El grupo interno lo ve (o queda dicho que está en processing con su número).
- PR con el bump y los docs en cola de merge / mergeado a `2.1`; `/cerrar-total` hecho.

## Paso 0

Decisiones resueltas antes de tocar nada (auto-contestadas, MODO AUTÓNOMO):

- **Qué app/scheme.** `Yala` (bundle `com.jurgenschmidt.yala`, app ASC 6758253109), el mismo pipeline que los builds 13 (#116) y 14 (#225).
- **Build number.** Medido con `asc builds list --paginate`: el tren 2.1 (pre-release `839f5044…`) lleva 11-14, el último es el **14** del 23-sep (`VALID`). Siguiente: **15**, en los 20 targets. Los números hasta 32 son de trenes viejos (junio) y no cuentan: la convención reinició en 2.0.x y 2.1 sigue la cuenta desde ahí.
- **Versión.** Medido con `asc versions list`: la última publicada es 2.0.4 (`READY_FOR_SALE`) y no hay 2.1 publicada ⇒ el tren 2.1 sigue abierto. `MARKETING_VERSION` se queda en **2.1**.
- **Base y #355.** Al arrancar, #355 (solo docs) estaba en cola de auto-merge con `tests` en curso. Se espera a que entre y se rebasa una vez antes del archive, como pide el encargo; si su CI falla, se rebasa con lo que haya.
- **Máquina y Xcode.** Mini, Xcode 27.0 GA (27A266a), el mismo que subió el 14.
- **Aislamiento y export.** Archive desde este worktree, en el commit del bump, con `-derivedDataPath` dentro del worktree; `.ipa` con una copia de `.asc/ExportOptions.plist` en el scratchpad con `destination=export`; `scripts/asc-preflight.sh`; `asc builds upload`.
- **Gate.** El bump toca `project.pbxproj` (no `.swift`): gate = build de `Yala` y `Yala Dev` + `validate-coverage.sh`, como en #225.
- **Pase de estrés.** No aplica: el build no cambia UI, solo el número de build.
- **Grupos de testers.** No se tocan: llega al grupo interno; el externo pide beta review, que es decisión de Jürgen.
- **Limpieza al lanzar.** DerivedData global vacío (0 B). Caché de XcodeBuildMCP de `Yala-2026-10-03-trends-insight-card-v2-bullets` borrada (su PR #345 ya entró). Las demás cachés son de worktrees vivos y no se tocan.

## Resultado

- **TestFlight 15**, versión 2.1, desde `2.1` en `b216f5f11` (con #354 y #355 dentro) + el bump `270173de2`.
- Leído del `.xcarchive`: `CFBundleVersion` 15, `CFBundleShortVersionString` 2.1, `com.jurgenschmidt.yala`, Xcode 27A266a, SDK iphoneos27.0. Preflight OK.
- `asc builds upload` → exit 0 (upload `3acd4f04…`). `VALID` en ~4 min; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió).
- Trampa de proceso: un `-derivedDataPath` fuera de `.gitignore` (`.dd`) hace que `worktree-stamp.sh` hashee gigas de untracked y el sello no termina. Se usa `.deriveddata/`, que sí está ignorado.
