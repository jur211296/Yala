# Subir a TestFlight el build 2.2 (N) desde origin/2.2 con ASC CLI

## Contexto
Pedido explícito de Jürgen (2026-10-28 ~08:32 Lima): lanzar TestFlight **en paralelo** con la sesión viva `sesion-nube-panel-welcome` (S12k). Frank usó `--permitir-paralelo`.

Receta: `~/Claude/tmp-frank/sesion-S12tf-subida-testflight-2-2-3.md` y `~/Claude/tmp-frank/subida-testflight-2-2-v1.md`. App `Yala`, bundle `com.jurgenschmidt.yala`, ASC **6758253109**, scheme **«Yala»** (nunca «Yala Dev»).

Sube desde **`origin/2.2`** con lo ya mergeado (PR #657–#664 y lo que esté en 2.2). **No esperes** al PR de S12k ni a su CI: este build es para que Jürgen pruebe ya en el iPhone.

## Qué se pide
1. `git fetch origin` y trabajar sobre **`origin/2.2`**. Medir con `asc builds list --paginate` y `asc versions list --app 6758253109`: confirma tren 2.2 y el **siguiente** `CURRENT_PROJECT_VERSION` (el mayor+1 que midas; no asumas «3»).
2. Bump en los **20 targets**: `MARKETING_VERSION` = **2.2**; `CURRENT_PROJECT_VERSION` = el siguiente medido.
3. Archive scheme `Yala` (`nice -n 10 xcodebuild -jobs 2`, `-derivedDataPath .deriveddata/`), export con `.asc/ExportOptions.plist`, `scripts/asc-preflight.sh`, `asc builds upload`.
4. Espera `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta y cierra.
5. `asc versions attach-build` a la versión **2.2** (sin revisión, sin tocar textos/capturas de Lola).
6. Mismo PR a `2.2`: bump + Resultado/Paso 0 en `encargos/lanzados/`. Termina con `/cerrar-total`.

## Si hace falta algo de Jürgen
Firma, certificado, perfil, 2FA, acuerdo ASC, tren cerrado: AskUserQuestion de día. No improvises.

## Qué NO hay que tocar
- `marketing/`, `Web/`, ficha App Store, capturas.
- Código de producto (si bloquea la firma: ticket + card; no arregles aquí).
- No borrar builds, no grupos de testers, no beta review externa.
- No instalar en el iPhone de Jürgen.
- En `~/Yala`: ni scheme ni memoria de Frank ajenos.
- **No lanzar** otras sesiones Yala. Al cerrar → Frank avanza a **S14** solo si S12k ya terminó.

## Reglas de Mini
Pipeline serial: limpiar → build sin sim → apagar sims. `limpiar-mac --apply` al cerrar. No esperes CI de otras sesiones; rebase una vez sobre `origin/2.2` antes del PR.

## Cómo se sabe que está bien
- Build 2.2 (N) en TestFlight VALID / IN_BETA_TESTING, adjunto a la versión 2.2.
- PR del bump mergeable a 2.2.
- Cierre con número de build, commit y estado ASC.

## Paso 0 (decisiones de la sesión)

Auto-contestadas, MODO AUTÓNOMO, de día:

- **Base.** `origin/2.2` en `2f7c9eef0` (#663, «Lo que te falta pagar») tras `git fetch`, sin esperar al PR de S12k.
- **Tren.** `asc versions list` (28-oct): 2.2 en `PREPARE_FOR_SUBMISSION`; 2.1 `READY_FOR_SALE`.
- **Build number.** `asc builds list --version 2.2`: solo el **2** (`VALID`, 26-oct). `asc builds next-build-number --version 2.2` → **3** (cuenta también el 1 rechazado). `CURRENT_PROJECT_VERSION` 2 → **3** en los 20 targets; `MARKETING_VERSION` ya era 2.2.
- **Gate.** El bump solo toca `project.pbxproj`: archive de `Yala` (Release), build de `Yala Dev` y `bash qa/validate-coverage.sh`, como en los builds 14-20 y 2.2 (2). Sin simulador.
- **Pase de estrés.** No aplica: el bump no toca UI; el binario lleva lo ya mergeado, que pasó su propio gate.
- **Disco.** 17 GB libres en `/` al arrancar (por encima de los 10 GB de la receta); load ~3 al lanzar el archive.

## Resultado

- **TestFlight 2.2 (3)** desde `2.2` en `2f7c9eef0` (#663) + el bump de este PR. Lleva todo lo integrado en `2.2` hasta #663 (Panel categorías, barra negra, Empezar de cero, multi-divisa/Aceptar, chips, Welcome, «Lo que te falta pagar»). **No lleva** el trabajo de S12k (sesión/Welcome/Panel), que sigue en su PR.
- Leído del `.xcarchive`: 2.2 (3) en la app, `YalaWidgetsExtension` y `YalaShare`. Firma del `.ipa`: `aps-environment` y `appattest-environment` en `production`, `get-task-allow` false. Preflight OK.
- `asc builds upload` → upload `c3ba322e…`; `uploads list` `COMPLETE` y build `VALID` en ~6 min; `internalBuildState: IN_BETA_TESTING`, `externalBuildState: READY_FOR_BETA_SUBMISSION` (no se sometió a beta review externa).
- **Versión 2.2 de App Store**: build 3 asignado (`asc versions view --include-build` da `buildVersion: 3`). Sigue en `PREPARE_FOR_SUBMISSION`; sin tocar textos ni capturas.
- Gate: archive de `Yala` (Release), build de `Yala Dev` y `validate-coverage.sh` en verde. Sin simulador.
