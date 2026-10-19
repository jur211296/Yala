---
release: no
---
# Subir a TestFlight el build 18 de Yala 2.1 desde lo último de origin/2.1 con ASC CLI, para el QA guiado en curso

## Contexto
Pedido de Jürgen el 2026-10-19, en medio del QA guiado de 2.1 (sesión `encargo/2026-10-16-qa-guiado-2-1-tf17`, Frank). El TestFlight 17 salió el 16-oct desde `55c473e03` (#527). Después entraron en `2.1` los PRs #529 (el bump del 17), #530 (esquemas de iCloud), **#535** (código: «dos teléfonos con el mismo ajuste de un mes acaban con el mismo», `CashFlowOverrideLineMigration`, `CashFlowLine`, `AppBootstrapper`, `CashFlowProjectionCalculator`, `CashFlowLineConfigSheet`) y #553 (docs). El 17 **no lleva el #535**, y la tanda de QA (`docs/qa/tanda-qa-jurgen-2.1.md`, prueba D · ly22, pasos 1b y 4 «mes Y») lo prueba en TestFlight. Por eso hace falta un build nuevo con lo último. A las 2026-10-19 el HEAD de `origin/2.1` era `3e59c0689` (#553); si al archivar hay algo más nuevo, entra también.

El esquema de iCloud ya está en Producción (campo `CD_cashFlowLine`, Lola, 16-oct 16:24; #530 lo dejó en el repo). No hay nada que desplegar antes.

El proceso ya salió bien cinco veces. **Lee entero `encargos/lanzados/2026-10-16-subida-testflight-17-2-1.md`, sobre todo su Paso 0 y su Resultado**: es la receta exacta (app `Yala`, bundle `com.jurgenschmidt.yala`, app ASC 6758253109, scheme **«Yala»** y nunca «Yala Dev», `MARKETING_VERSION` 2.1 sin bump si el tren sigue abierto, build number global creciente en los 20 targets, archive desde el worktree con `-derivedDataPath .deriveddata/`, `.ipa` con copia de `.asc/ExportOptions.plist` y `destination=export`, `scripts/asc-preflight.sh` contra el `.xcarchive` y no el `.ipa`, `asc builds upload`). Las credenciales ASC ya están en la Mini; no pidas que nadie pegue keys. Revisa `docs/RELEASE-CHECKLIST-2.1.md` §5.1.

## Qué se pide
1. Medir con `asc builds list --paginate` y `asc versions list` el último build y la versión abierta. Elegir el siguiente build number, mayor que el último que exista (no asumas 18).
2. Bump de `CURRENT_PROJECT_VERSION` en los 20 targets. `MARKETING_VERSION` solo cambia si ASC dice que el tren 2.1 ya no está abierto: entonces para y pregunta.
3. Archive del scheme `Yala`, firmado, desde el commit del bump (`nice -n 10 xcodebuild -jobs 2`). Lee `CFBundleVersion` y `CFBundleShortVersionString` del `.xcarchive`, y comprueba que el binario lleva el #535. Luego export, preflight y `asc builds upload`.
4. Espera a un estado útil: `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta número y estado y cierra.
5. Asigna el build nuevo a la versión 2.1 de App Store con `asc versions attach-build`, sin enviarla a revisión ni tocar textos ni capturas (son de Lola).
6. En el mismo PR: el bump, este encargo con su Paso 0 y su Resultado en `encargos/lanzados/`, y en `docs/qa/tanda-qa-jurgen-2.1.md` **solo** el punto 2 de «Antes de empezar» y la frase de los bloques B, C y D, diciendo que el build a usar es el nuevo y qué lleva respecto al 17. No reescribas la tanda: la está usando el QA guiado en vivo.
7. Aviso de cierre: build number, versión, commit de `2.1` del que sale, estado en TestFlight y qué PRs lleva respecto al 17.

## Si hace falta algo de Jürgen
Firma, certificado o perfil que falte, 2FA, acuerdo pendiente en App Store Connect, tren 2.1 cerrado, o un rechazo de ASC que solo él decide: no lo improvises. Pregunta con `AskUserQuestion` (de día, hasta las 21:00 Lima).

## Qué NO hay que tocar
- `marketing/`, `Web/`, la ficha de App Store y las capturas (Lola).
- Código de producto. Si al firmar o subir aparece un bug bloqueante: ticket y card propios (`tablero crear --proyecto Yala --version 2.1 --asignado frank ...`), y avisa; no lo arregles aquí.
- No borrar builds viejos, no tocar grupos de testers, no someter a beta review externa, no cambiar bundle id ni versionado.
- No instales nada en los iPhone ni en el iPad de Jürgen: el QA guiado los está usando.
- En el árbol principal `~/Yala`: ni los `.ckdb` sin commitear, ni `Yala.xcscheme`, ni `encargos/pendientes/`.

## Reglas de Mini
- Este encargo no necesita simulador: no arranques ninguno. Pipeline serial, `xcodebuild -jobs 2`, load < 8 antes del archive.
- Disco: el 16-oct quedaban 15 GB libres en `/`. Si baja de 10 GB, `bash qa/scripts/disk-report.sh` antes de archivar. Borra el DerivedData de esta sesión al cerrar.
- Rebase al final, sin esperar el CI de nadie: arranca sobre `origin/2.1` y, justo antes de abrir el PR, `git fetch && git rebase origin/2.1`.
- Modo autónomo hasta terminar: gate (el bump toca `project.pbxproj`, no `.swift`: build de `Yala` y `Yala Dev` + `bash qa/validate-coverage.sh`, como en los builds 14-17), PR a `2.1` en auto-merge y `/cerrar-total` sin preguntar, salvo lo de «Si hace falta algo de Jürgen».
- La card del tablero: crea una («Subir el TestFlight 18 de 2.1 con el arreglo del flujo de caja», `--version 2.1`) y muévela a «in qa» asignada a jurgen al cerrar si el build quedó disponible.

## Cómo se sabe que está bien
Build nuevo en TestFlight, mayor que el 17, subido con ASC CLI desde el HEAD de `2.1` de hoy (con el #535 dentro), disponible para pruebas internas (o dicho que sigue en processing con su número); asignado a la versión 2.1; PR con bump y docs en auto-merge; `/cerrar-total` hecho.

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO, de día:

- **App y scheme.** `Yala` (bundle `com.jurgenschmidt.yala`, app ASC 6758253109), la receta del build 17. Nunca «Yala Dev».
- **Build number.** Medido con `asc builds list --paginate` el 2026-10-19: el último es el **17** (16-oct, `VALID`). Siguiente: **18**, en los 20 targets (20 apariciones de `CURRENT_PROJECT_VERSION = 18;`).
- **Versión.** `asc versions list`: la 2.1 sigue en `PREPARE_FOR_SUBMISSION` y la última publicada es 2.0.4 ⇒ tren abierto, `MARKETING_VERSION` se queda en **2.1**.
- **Base.** `origin/2.1` en `3e59c0689` (#553) tras `git fetch`; lleva el #535 (`d75fc6120`). No había nada más nuevo.
- **Widget (§5.1).** `YalaWidgets/Info.plist` lleva `$(CURRENT_PROJECT_VERSION)`; se comprueba en el `.xcarchive`.
- **Archive.** Desde el worktree con el bump aplicado (mismo contenido que el commit del bump), `-derivedDataPath .deriveddata/`, `-jobs 2`, load 7,5 al lanzar, sin simulador booteado.
- **Tanda de QA.** Solo se toca el punto 2 de «Antes de empezar», que es donde está la frase «Los bloques B, C y D van con…». El resto de menciones al 17 se quedan: la tanda está en uso.
- **Gate.** El bump toca `project.pbxproj`, no `.swift`: build de `Yala` y `Yala Dev` + `validate-coverage.sh`, como en los builds 14-17.
- **Disco.** 19 GB libres en `/` al arrancar (por encima del umbral de 10 GB del encargo).

## Resultado

- **TestFlight 18**, versión 2.1, desde `2.1` en `3e59c0689` (#553) + el bump.
- Respecto al 17 (`55c473e03`) lleva #528, #529, #530, #535 y #553. Solo el **#535** cambia el binario: dos teléfonos con el mismo ajuste de un mes acaban con el mismo. Comprobado en el dSYM del `.xcarchive`: `CashFlowOverrideLineMigration.survivor(among:)`, que entra con `632f7c3f4`.
- Leído del `.xcarchive`: 2.1 (18) en la app, `YalaShare` y `YalaWidgetsExtension`. Xcode 27.1 (27A9275). Firma del `.ipa`: `aps-environment` y `appattest-environment` en `production`, `get-task-allow` false. Preflight OK.
- `asc builds upload` → exit 0 (upload `4e26afcb…`). `VALID` en minutos; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió).
- **Versión 2.1 de App Store**: build 18 asignado con `asc versions attach-build` (sustituye al 17; `asc versions view` da `buildVersion: 18`). Sigue en `PREPARE_FOR_SUBMISSION`; no se tocaron textos ni capturas ni se envió a revisión.
- Gate: build de `Yala` y `Yala Dev` en verde, `validate-coverage.sh` OK.
- Load al lanzar el archive: 13,8 (subió entre la medida de 7,5 y el lanzamiento). El archive salió igual; la próxima vez, medir justo antes.
- Ojo al medir: `asc builds list` devuelve también builds «18» de trenes viejos (abril y junio). El de este tren es el `4e26afcb…` del 19-oct.
