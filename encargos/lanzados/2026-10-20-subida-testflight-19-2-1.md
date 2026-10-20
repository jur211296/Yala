---
release: no
---
# Subir a TestFlight el build 19 de Yala 2.1 desde lo último de origin/2.1 con ASC CLI, para el QA guiado del TestFlight 19

## Contexto
Pedido de Jürgen el 2026-10-20, desde la sesión del QA guiado de 2.1 (`encargo/2026-10-16-qa-guiado-2-1-tf17`, Frank). El TestFlight 18 salió el 19-oct desde `3e59c0689` + el bump (#559). Después entraron en `2.1` los arreglos del QA guiado: **#562** (iCloud Drive apagado, ahora en 2.2 pero mergeado), **#564** (cq2i, 9ttd, ewkw, 8171) y **#566** (axgf, ppxk, t2q8, n2xn; merge `147e5f9e7`, 2026-10-20 03:56 UTC), más docs (#565). El build 19 tiene que llevarlos todos: es el que usa la tanda `docs/qa/tanda-qa-jurgen-2.1-tf19.md` (en el PR #563). Usa el HEAD de `origin/2.1` en el momento de archivar; si entró algo después del #566, va dentro.

La receta exacta está en `encargos/lanzados/2026-10-19-subida-testflight-18-2-1.md` (PR #559) y en `encargos/lanzados/2026-10-16-subida-testflight-17-2-1.md`: **léelas enteras, sobre todo Paso 0 y Resultado**. App `Yala`, bundle `com.jurgenschmidt.yala`, app ASC 6758253109, scheme **«Yala»** y nunca «Yala Dev», `MARKETING_VERSION` 2.1 sin bump si el tren sigue abierto, build number global creciente en los 20 targets, archive desde el worktree con `-derivedDataPath .deriveddata/`, `.ipa` con copia de `.asc/ExportOptions.plist` y `destination=export`, `scripts/asc-preflight.sh` contra el `.xcarchive`, `asc builds upload`. Credenciales ASC ya en la Mini.

## Qué se pide
1. Medir con `asc builds list --paginate` y `asc versions list` el último build y la versión abierta; el siguiente número, mayor que el último (no asumas 19).
2. Bump de `CURRENT_PROJECT_VERSION` en los 20 targets. `MARKETING_VERSION` solo cambia si el tren 2.1 se cerró: entonces para y pregunta.
3. Archive del scheme `Yala` desde el commit del bump (`nice -n 10 xcodebuild -jobs 2`); lee la versión del `.xcarchive` y comprueba en el dSYM que lleva el #566 (p. ej. `AttestSessionTokenLogic` o `MigrationImportWaitLogic`) y el #564 (p. ej. `releaseAudioSession` o `runForeignWipe`). Export, preflight y `asc builds upload`.
4. Espera a `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta número y estado y cierra.
5. Asígnalo a la versión 2.1 de App Store con `asc versions attach-build`, sin enviarla a revisión ni tocar textos ni capturas.
6. En el mismo PR: el bump y este encargo con Paso 0 y Resultado. **No** toques `docs/qa/tanda-qa-jurgen-2.1*.md`: los lleva el QA guiado (PR #563).
7. Aviso de cierre: build, versión, commit de `2.1`, estado en TestFlight y qué PRs lleva respecto al 18.

## Si hace falta algo de Jürgen
Firma, certificado, perfil, 2FA, acuerdo pendiente en ASC, tren cerrado o un rechazo que solo él decide: no lo improvises; `AskUserQuestion` de día (hasta las 21:00 Lima).

## Qué NO hay que tocar
- `marketing/`, `Web/`, ficha, capturas (Lola). Código de producto: si aparece un bug bloqueante al firmar o subir, ticket y card propios y avisa; no lo arregles aquí.
- No borrar builds, no tocar grupos de testers, no beta review externa, no cambiar bundle id ni versionado.
- No instales nada en el iPhone ni en el iPad de Jürgen.
- En `~/Yala`: ni los `.ckdb` sin commitear, ni `Yala.xcscheme`, ni `encargos/pendientes/` ajenos.

## Reglas de Mini
- Sin simulador. Serial, `-jobs 2`, load < 8 antes del archive. Si `/` baja de 10 GB, `bash qa/scripts/disk-report.sh` antes. Borra tu DerivedData al cerrar.
- Rebase al final sin esperar CI de nadie.
- Modo autónomo hasta terminar: gate (bump en `project.pbxproj`: build de `Yala` y `Yala Dev` + `bash qa/validate-coverage.sh`), PR a `2.1` en auto-merge y `/cerrar-total`, salvo lo de «Si hace falta algo de Jürgen».
- Card del tablero: crea «Subir el TestFlight 19 de 2.1 con los arreglos del QA guiado» (`--version 2.1`) y muévela a «in qa» asignada a jurgen al cerrar si el build quedó disponible.
- Avisa al cerrar también a la sesión `Yala--qa-guiado-2-1-tf17` (con `decirle`) de que el build está listo.

## Cómo se sabe que está bien
Build nuevo en TestFlight, mayor que el 18, desde el HEAD de `2.1` de hoy con #562, #564 y #566 dentro, disponible para pruebas internas, asignado a la versión 2.1; PR en auto-merge; `/cerrar-total` hecho.

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO, de día:

- **App y scheme.** `Yala` (bundle `com.jurgenschmidt.yala`, app ASC 6758253109), la receta de los builds 14-18. Nunca «Yala Dev».
- **Build number.** Medido con `asc builds list --paginate` el 2026-10-20 06:47 (Lima): el tren 2.1 lleva 11-18 y el último es el **18** (`4e26afcb…`, 19-oct, `VALID`). Siguiente: **19**, en los 20 targets. El máximo absoluto de la app es 32, pero 19-32 son de los trenes 2.0.x de junio: el número es único por versión, y el 18 ya convivió con otro «18» viejo.
- **Versión.** `asc versions list`: la 2.1 sigue en `PREPARE_FOR_SUBMISSION` y la última publicada es 2.0.4 ⇒ tren abierto, `MARKETING_VERSION` se queda en **2.1** (20 targets).
- **Base.** `origin/2.1` en `ad6781f8a` (#569, solo tests y docs) tras `git fetch`; lleva #562, #564 y #566.
- **Widget (§5.1).** `YalaWidgets/Info.plist` lleva `$(CURRENT_PROJECT_VERSION)`; se comprueba en el `.xcarchive`.
- **Tanda de QA.** No se toca (`docs/qa/tanda-qa-jurgen-2.1*.md` es del PR #563).
- **Gate.** El bump toca `project.pbxproj`, no `.swift`: build de `Yala` y `Yala Dev` + `validate-coverage.sh`, como en los builds 14-18.
- **Simulador.** Hay un iPhone 17 Pro arrancado que no es de esta sesión: no se toca. Este encargo no usa simulador.
- **Disco.** 17 GB libres en `/` al arrancar (por encima del umbral de 10 GB).

## Resultado

- **TestFlight 19**, versión 2.1, desde `2.1` en `ad6781f8a` (#569) + el bump (`fb5d78573`).
- Respecto al 18 (`3e59c0689` + #559) lleva **#562** (iCloud Drive apagado), **#564** (cq2i, 9ttd, ewkw, 8171), **#566** (axgf, ppxk, t2q8, n2xn) y #569 (solo un test y docs). El #565 (roadmap, docs) se mergeó a `2.2`, no a `2.1`: no va, y no cambia el binario.
- Comprobado en el dSYM del `.xcarchive`: `AttestSessionTokenLogic` y `MigrationImportWaitLogic` (#566), `releaseAudioSession` y `runForeignWipe` (#564).
- Leído del `.xcarchive`: 2.1 (19) en la app, `YalaShare` y `YalaWidgets`. Firma del `.ipa`: `aps-environment` y `appattest-environment` en `production`, `get-task-allow` false. Preflight OK. Load al lanzar el archive: 7,5 (medido justo antes, en bucle).
- `asc builds upload` → exit 0 (upload `cd345850…`). `VALID` en minutos; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió).
- **Versión 2.1 de App Store**: build 19 asignado con `asc versions attach-build` (`asc versions view --include-build` da `buildVersion: 19`). Sigue en `PREPARE_FOR_SUBMISSION`; no se tocaron textos ni capturas ni se envió a revisión.
- Gate: build de `Yala` y `Yala Dev` en verde, `validate-coverage.sh` OK.
- Trampa: el hook `commit-msg` de casa rechaza la línea de firma de IA que el arnés pide añadir; manda la regla de casa.
