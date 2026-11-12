---
release: no
---
> **Cola automática 2026-10-26:** sesión **S1**. Al cerrar → avanzar a **S2** (propuestas completa↔solo grupos), **no** a Segmento. Frank lee `siguiente-activo.txt` + `cola-2-2-orden-activo.txt`.

# Subir a TestFlight el build v1 (UX) de Yala 2.2 desde origin/2.2 con ASC CLI

## Contexto
Pedido de Jürgen (2026-10-26 ~07:00 Lima, vía Frank): primer TestFlight de la rama **2.2** para mirar UX mientras avanza la cola ready. Cola **S1** tras Sentry (viva); **antes del bloque propuestas S2–S5 y de Segmento (S6)**. FAB ya done (PR #636). No es el build de lanzamiento App Store: es el TF v1 de UX.

Receta base: `encargos/lanzados/2026-10-20-subida-testflight-19-2-1.md` y `~/Claude/tmp-frank/subida-testflight-2-1.md` (y Resultado/Paso 0 del 18 y 19). App `Yala`, bundle `com.jurgenschmidt.yala`, app ASC **6758253109**, scheme **«Yala»** (nunca «Yala Dev»), archive con `-derivedDataPath .deriveddata/`, `.ipa` con copia de `.asc/ExportOptions.plist` y `destination=export`, `scripts/asc-preflight.sh`, `asc builds upload`. Credenciales ASC ya en la Mini.

Medido 2026-10-26 (worker Frank, Mini):
- `asc versions list`: tren **2.2** ya existe en ASC (`PREPARE_FOR_SUBMISSION`, creado 2026-10-22). Tren 2.1 sigue abierto.
- `asc builds list`: último build subido = **20** (versión marketing 2.1, VALID). **Ningún build de 2.2** aún.
- `origin/2.2` HEAD (~`c11a53cce`): `MARKETING_VERSION = 2.1` y `CURRENT_PROJECT_VERSION = 20` en los 20 targets → hay que subir marketing a **2.2** y elegir el siguiente build number del tren 2.2.

## Qué se pide
1. `git fetch origin` y trabajar sobre **`origin/2.2`**. No esperes CI de nadie. Medir otra vez con `asc builds list --paginate` y `asc versions list --app 6758253109`: confirmar tren 2.2 abierto y el último build; **no asumas el número**.
2. Bump en los **20 targets**:
   - `MARKETING_VERSION` → **2.2** (primer TF de este tren; el tren ASC ya está creado).
   - `CURRENT_PROJECT_VERSION` → el siguiente para el tren 2.2. Si no hay builds 2.2, el primero suele ser **1** (el número es por versión marketing; 2.1 ya usó 11–20 y convive con números viejos de 2.0.x). Si ASC o el repo exigen otro, usa el mayor+1 que midas y dilo en el cierre. Widget: `YalaWidgets/Info.plist` ya usa `$(CURRENT_PROJECT_VERSION)` / `$(MARKETING_VERSION)`.
3. Archive del scheme `Yala` desde el commit del bump (`nice -n 10 xcodebuild -jobs 2`); lee `CFBundleVersion` / `CFBundleShortVersionString` del `.xcarchive` (app, share, widgets = 2.2 / N). Export, preflight, `asc builds upload`.
4. Espera `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta número y estado y cierra.
5. Asígnarlo a la versión **2.2** de App Store con `asc versions attach-build` (sin enviar a revisión, sin tocar textos ni capturas — son de Lola).
6. En el mismo PR a `2.2`: el bump y este encargo con Paso 0 y Resultado en `encargos/lanzados/` (p. ej. `2026-10-26-subida-testflight-v1-2-2.md`). **No** inventes tanda de QA ni toques `docs/qa/*` salvo que ya exista una de 2.2 pedida en otra card.
7. Aviso de cierre: build, versión 2.2, commit de `2.2`, estado TestFlight, PRs relevantes respecto al HEAD previo.

## Si hace falta algo de Jürgen
Firma, certificado, perfil, 2FA, acuerdo pendiente en ASC, tren 2.2 cerrado o rechazo que solo él decide: **no lo improvises**. `AskUserQuestion` de día (hasta las 21:00 Lima); de noche, aplaza y cierra con el estado. Para solo por eso.

## Qué NO hay que tocar
- `marketing/`, `Web/`, ficha App Store, capturas (Lola).
- Código de producto: si al firmar/subir aparece un bug bloqueante, ticket + card propios (`tablero crear --proyecto Yala --titulo "..." --version 2.2 --agente frank`) y avisa; no lo arregles aquí.
- No borrar builds, no tocar grupos de testers, no beta review externa, no cambiar bundle id.
- No instalar en el iPhone/iPad de Jürgen.
- En `~/Yala`: ni `.ckdb` sin commit, ni `Yala.xcscheme`, ni `encargos/pendientes/` ajenos.
- **No lanzar** otras sesiones Yala. Al cerrar → Frank avanza a S2 (propuestas), no a Segmento.

## Reglas de Mini
- Sin simulador. Serial, `-jobs 2`, load < 8 antes del archive. Si `/` < 10 GB, `bash qa/scripts/disk-report.sh` antes. Borra tu DerivedData al cerrar.
- Rebase al final sobre `origin/2.2` sin esperar CI.
- Gate típico del bump: build de `Yala` y `Yala Dev` + `bash qa/validate-coverage.sh` (como builds 14–20).
- Modo autónomo: gate, PR a `2.2` en auto-merge y **`/cerrar-total`** sin preguntar si el upload quedó OK (o en processing con número reportado). Para solo ante 2FA / firma / ASC / tren cerrado.
- Card del tablero: «Subir el TestFlight v1 de 2.2 (UX)» — muévela a **in qa** asignada a jurgen al cerrar si el build quedó disponible.

## Cómo se sabe que está bien
Build nuevo de marketing **2.2** en TestFlight (primer build del tren), disponible para pruebas internas (o processing reportado), asignado a la versión 2.2; PR del bump en auto-merge; `/cerrar-total` hecho (Mini limpia).

## SIMULADORES
Si por error se usa simulador: nunca más de uno; al terminar `xcrun simctl shutdown all`.

## Cola al cerrar
Al cerrar con `/cerrar-total`, Frank avanza `siguiente-activo` a **S2** (`propuestas-completa-solo-grupos`). No Segmento.

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO, de día:

- **Base.** `origin/2.2` en `aab0a0760` (#636, el FAB) tras `git fetch`, sin esperar CI de nadie.
- **Tren.** `asc versions list` (26-oct): 2.2 en `PREPARE_FOR_SUBMISSION` (creada el 22-oct); 2.1 ya `READY_FOR_SALE`.
- **Build number.** `asc builds list --paginate`: último el **20** (2.1, `VALID`, 20-oct); `--version 2.2` vacío ⇒ ningún build en el tren 2.2. El número es único por versión marketing: **2.2 (1)** en los 20 targets.
- **Versión.** `MARKETING_VERSION` 2.1 → **2.2** en los 20 targets. Widget y share heredan `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)`; se comprueba en el `.xcarchive`.
- **Gate.** El bump solo toca `project.pbxproj`: archive de `Yala` (Release), build de `Yala Dev` y `bash qa/validate-coverage.sh`, como en los builds 14-20. Sin simulador.
- **Tanda de QA.** No hay una de 2.2 pedida: no se crea ni se toca `docs/qa/`.
- **Disco.** 24 GB libres en `/` al arrancar (por encima del umbral de 10 GB); load 1,9 al lanzar el archive.
- **Rechazo del build 1 (asumido, autorizado por Jürgen en vivo).** ASC rechazó 2.2 (1) con 23 ITMS-90626: una traducción de frase de Siri no puede contener «apple» ni «siri». Se arregla en esta misma sesión: traducciones sin la marca y build **2** (`asc builds next-build-number` cuenta el 1 rechazado como usado).

## Resultado

- **TestFlight 2.2 (2)**, primer build del tren 2.2, desde `2.2` en `aab0a0760` (#636) + bump (`5cc2c5553`) + arreglo de Siri (`3936738bc`).
- **El build 1 no existe en TestFlight**: el upload `d1798c18…` quedó `FAILED` con 23 × ITMS-90626 (Apple Pay en las frases traducidas de de/fr/it/ja/nl/pl/pt/pt-BR/pt-PT/zh-Hans, y «com a Siri» en el portugués de «Log an expense»). `altool --validate-app` dio OK sobre ese mismo `.ipa`: la validación local no ve este error.
- **Arreglo:** en `AppShortcuts.xcstrings`, «Registra Apple Pay en …» → «registrar un pago» y «Pago Apple Pay en …» → «pago con el móvil» en los diez idiomas; «Apple Pay en …» sin traducción (los idiomas conservan dos frases para Apple Pay); portugués «Registre/Regista uma despesa». La frase que enseña Ajustes › Siri y Atajos (`siriShortcuts.phrase.applePay`) cambia igual en esos diez idiomas. Español e inglés no cambian: ASC no valida las frases del código.
- **Red nueva:** `SiriPhrasesPortugueseTests.ningunaTraduccion_llevaMarcasQueAppStoreRechaza` (los diez idiomas, contra el `AppShortcuts.strings` compilado). 7 suites de Siri y l10n: 27 tests en verde.
- Leído del `.xcarchive`: 2.2 (2) en la app, `YalaShare` y `YalaWidgets`; ningún `AppShortcuts.strings` del binario contiene «apple» ni «siri». Firma del `.ipa`: `aps-environment` y `appattest-environment` en `production`, `get-task-allow` false. Preflight OK.
- `asc builds upload` → upload `446ca180…`, `VALID` en ~5 min; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió).
- **Versión 2.2 de App Store**: build 2 asignado (`asc versions view --include-build` da `buildVersion: 2`). Sigue en `PREPARE_FOR_SUBMISSION`; sin tocar textos ni capturas.
- Gate: archive de `Yala`, build de `Yala Dev`, tests de Siri/l10n y `validate-coverage.sh` en verde. El simulador se usó solo para esos tests, con cola, y se apagó.
- Respecto al build 20 (2.1), el binario lleva todo lo integrado en `2.2` hasta #636. **No lleva #637 (Sentry)**: se mergeó mientras el build procesaba; el PR se rebasó sobre él (gate re-pasado: `Yala Dev` + índice), pero el binario subido salió de `aab0a0760`.
