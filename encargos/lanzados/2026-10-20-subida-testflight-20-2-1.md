---
release: no
---
# Subir a TestFlight el build 20 de Yala 2.1 desde lo último de origin/2.1 con ASC CLI, para la tanda corta del QA guiado

## Contexto
Pedido de Jürgen el 2026-10-20, desde la sesión del QA guiado de 2.1 (`encargo/2026-10-16-qa-guiado-2-1-tf17`, Frank). El TestFlight 19 salió el 20-oct desde `ad6781f8a` + el bump (#570). Después entró en `2.1` el **#577**, con las cuatro cards que faltaban del QA guiado: `t2q8` (unirse por enlace sin pedir el teléfono en blanco), `840m` (Rechazar una solicitud en un grupo de la nube), `blqa` (la revisión del iCloud privado se pasaba de 25 s) y `z81w` (pantalla «Abriendo tu invitación…»). El build 20 tiene que llevarlo. Usa el HEAD de `origin/2.1` en el momento de archivar; si entró algo después del #577, va dentro.

La receta exacta está en `encargos/lanzados/2026-10-20-subida-testflight-19-2-1.md` (PR #570), y antes en la del 18 (#559): **léelas enteras, sobre todo Paso 0 y Resultado**. App `Yala`, bundle `com.jurgenschmidt.yala`, app ASC 6758253109, scheme **«Yala»** y nunca «Yala Dev», `MARKETING_VERSION` 2.1 sin bump si el tren sigue abierto, build number creciente en los 20 targets, archive desde el worktree con `-derivedDataPath .deriveddata/`, `.ipa` con copia de `.asc/ExportOptions.plist` y `destination=export`, `scripts/asc-preflight.sh` contra el `.xcarchive`, `asc builds upload`. Credenciales ASC ya en la Mini.

## Qué se pide
1. Medir con `asc builds list --paginate` y `asc versions list` el último build del tren 2.1 y la versión abierta; el siguiente número, mayor que el último (no asumas 20).
2. Bump de `CURRENT_PROJECT_VERSION` en los 20 targets. `MARKETING_VERSION` solo cambia si el tren 2.1 se cerró: entonces para y pregunta.
3. Archive del scheme `Yala` desde el commit del bump (`nice -n 10 xcodebuild -jobs 2`); lee la versión del `.xcarchive` y comprueba en el dSYM que lleva el #577: busca en su diff (`git show --stat` del merge) dos símbolos nuevos o tocados —uno de la unión por enlace o de la pantalla «Abriendo tu invitación…» y uno del rechazo— y confírmalos con `nm`/`strings` sobre el dSYM. Export, preflight y `asc builds upload`.
4. Espera a `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta número y estado y cierra.
5. Asígnalo a la versión 2.1 de App Store con `asc versions attach-build`, sin enviarla a revisión ni tocar textos ni capturas.
6. En el mismo PR: el bump y este encargo con Paso 0 y Resultado. **No** toques `docs/qa/tanda-qa-jurgen-2.1*.md`: los lleva el QA guiado (PR #563).
7. Aviso de cierre: build, versión, commit de `2.1`, estado en TestFlight y qué PRs lleva respecto al 19.

## Si hace falta algo de Jürgen
Firma, certificado, perfil, 2FA, acuerdo pendiente en ASC, tren cerrado o un rechazo que solo él decide: no lo improvises; `AskUserQuestion` de día (hasta las 21:00 Lima). Después de las 21:00 no se pregunta: se deja escrito en el aviso de cierre y se cierra.

## Qué NO hay que tocar
- `marketing/`, `Web/`, ficha, capturas (Lola). Código de producto: si aparece un bug bloqueante al firmar o subir, ticket y card propios y avisa; no lo arregles aquí.
- No borrar builds, no tocar grupos de testers, no beta review externa, no cambiar bundle id ni versionado.
- No instales nada en el iPhone ni en el iPad de Jürgen.
- En `~/Yala`: ni los `.ckdb` sin commitear, ni `Yala.xcscheme`, ni `encargos/pendientes/` ajenos.

## Reglas de Mini
- Sin simulador. Serial, `-jobs 2`, load < 8 antes del archive. Si `/` baja de 10 GB, `bash qa/scripts/disk-report.sh` antes. Borra tu DerivedData al cerrar.
- Rebase al final sin esperar CI de nadie.
- Modo autónomo hasta terminar: gate (bump en `project.pbxproj`: build de `Yala` y `Yala Dev` + `bash qa/validate-coverage.sh`), PR a `2.1` en auto-merge y `/cerrar-total`, salvo lo de «Si hace falta algo de Jürgen».
- Card del tablero: crea «Subir el TestFlight 20 de 2.1 con las cuatro cards del QA guiado» (`--version 2.1`) y muévela a «in qa» asignada a jurgen al cerrar si el build quedó disponible.
- Avisa al cerrar también a la sesión `Yala--qa-guiado-2-1-tf17` (con `decirle`) de que el build está listo.

## Cómo se sabe que está bien
Build nuevo en TestFlight, mayor que el 19, desde el HEAD de `2.1` con el #577 dentro, disponible para pruebas internas, asignado a la versión 2.1; PR en auto-merge; `/cerrar-total` hecho.

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO, arrancada a las 20:57 (Lima): pasadas las 21:00 no se pregunta nada.

- **App y scheme.** `Yala` (bundle `com.jurgenschmidt.yala`, app ASC 6758253109), la receta de los builds 14-19. Nunca «Yala Dev».
- **Build number.** Medido con `asc builds list --paginate` el 2026-10-20 20:58 (Lima): el último del tren 2.1 es el **19** (`cd345850…`, 20-oct, `VALID`). Siguiente: **20**, en los 20 targets (20 apariciones de `CURRENT_PROJECT_VERSION = 20;`).
- **Versión.** `asc versions list`: la 2.1 sigue en `PREPARE_FOR_SUBMISSION` y la última publicada es 2.0.4 ⇒ tren abierto, `MARKETING_VERSION` se queda en **2.1** (20 targets).
- **Base.** `origin/2.1` en `e47b5cca9` (merge del #577) tras `git fetch`; no entró nada después.
- **Prueba del #577 en el dSYM.** `InviteOpeningLogic` y `WelcomeInviteOpeningView` (z81w, «Abriendo tu invitación…») y `GroupMemberRejectLogic` (840m, rechazo), los tres nuevos en `3330551bf`.
- **Widget (§5.1).** `YalaWidgets/Info.plist` lleva `$(CURRENT_PROJECT_VERSION)`; se comprueba en el `.xcarchive`.
- **Tanda de QA.** No se toca (`docs/qa/tanda-qa-jurgen-2.1*.md` es del PR #563).
- **Gate.** El bump toca `project.pbxproj`, no `.swift`: build de `Yala` y `Yala Dev` + `validate-coverage.sh`.
- **Simulador.** Ninguno arrancado; este encargo no lo usa.
- **Disco.** 24 GB libres en `/` al arrancar (por encima del umbral de 10 GB).

## Resultado

- **TestFlight 20**, versión 2.1, desde `2.1` en `e47b5cca9` (merge del #577) + el bump (`206110c8b`).
- Respecto al 19 (`ad6781f8a` + #570) lleva **#577** (t2q8, 840m, blqa, z81w) y #572, #573 y #575 (marketing y docs: no cambian el binario).
- Comprobado en el dSYM del `.xcarchive`: `InviteOpeningLogic` y `WelcomeInviteOpeningView` (z81w) y `GroupMemberRejectLogic` (840m).
- Leído del `.xcarchive`: 2.1 (20) en la app, `YalaShare` y `YalaWidgetsExtension`. Firma del `.ipa`: `aps-environment` y `appattest-environment` en `production`, `get-task-allow` false. Preflight OK. Load al lanzar el archive: 6,0.
- `asc builds upload` → exit 0 (upload `8f86dd14…`). `VALID` en minutos; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió).
- **Versión 2.1 de App Store**: build 20 asignado con `asc versions attach-build` (`asc versions view --include-build` da `buildVersion: 20`). No se tocaron textos ni capturas ni se envió a revisión.
- Gate: build de `Yala` y `Yala Dev` en verde, `validate-coverage.sh` OK.
