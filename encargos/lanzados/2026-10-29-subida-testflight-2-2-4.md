---
release: no
depende: import-columnas-cuenta-excel-montos (PR 692)
---
# Subir TestFlight 2.2 (4) con lo mergeado hasta la puerta de Grupos (opción A)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Slug: `subida-testflight-2-2-4` · Sesión cola **S27tf** · al cerrar → **S27c** (barrido animaciones iOS 27).

## Contexto
Pedido de Jürgen (2026-10-29 05:31 Lima): subida a TestFlight **antes** del barrido de animaciones iOS 27, con todo lo mergeado a 2.2 hasta ese momento. No es App Store. Receta: `~/Claude/tmp-frank/subida-testflight-2-2-v1.md` y el encargo de 2.2 (3) (`sesion-S12tf-subida-testflight-2-2-3.md`, PR #665). App `Yala`, bundle `com.jurgenschmidt.yala`, ASC **6758253109**, scheme **«Yala»** (nunca «Yala Dev»). Último medido: 2.2 (3) VALID, subido 2026-10-28.
Card: `tablero ver tablero-subir-testflight-2-2-4-con-lo-mergeado-h-ikbw`.

Debe ir en este build: todo desde #665 hasta lo último, en especial #681 (pagos planificados), #682 (Observaciones), S27 (Yala IA sin categoría), S27b (este teléfono en iPad) y la opción A de Grupos (grupos-borrar-era-cloudkit) el arreglo del crash de la Bandeja (bandeja-crash-borrar-dos-seguidos) y Vaciar datos / Eliminar cuenta (vaciar-datos-mantiene-cuenta), los arreglos de UI tests (S27k, ui-tests-2-2-tres-tandas-rojo) y el import 2.2: transferencias por idioma y rollback (S27l, import-transferencias-rollback) e import por nombre de columna, cuenta, Excel, montos y puente de Grupos (S27m, import-columnas-cuenta-excel-montos). Jürgen (2026-10-29 13:45) pidió el TestFlight después del import para probar su Excel en este build.

## Qué se pide
0. **Espera de merges (acotada):** antes de archivar, mira con `gh pr list -R jur211296/Yala --base 2.2 --state open` (y `--state merged`) qué PR de la lista de arriba siguen sin mergear. Si alguno sigue en CI/cola, espera como máximo 45 min en total. Si tras esa espera un PR sigue sin mergear pero su CI no está en rojo, sube con lo que ya está en origin/2.2 y anota en el cierre y en la card qué quedó fuera. Si hay CI en rojo real (no flaky, no cancelado) en un PR que debía entrar, no subas: dilo en el cierre, crea card cierra-sola y cierra con /cerrar-total. Las tres tandas de UI tests de S27k cuentan como CI: rojo real → no subas.
1. `git fetch origin` y trabajar sobre **`origin/2.2`**. Medir con `asc builds list --paginate` y `asc versions list --app 6758253109`: confirma tren 2.2 y el **siguiente** `CURRENT_PROJECT_VERSION` (mayor+1 medido; se espera 4, no lo asumas).
2. Bump en los **20 targets**: `MARKETING_VERSION` = 2.2; `CURRENT_PROJECT_VERSION` = el siguiente medido.
3. Archive scheme `Yala` (`nice -n 10 xcodebuild -jobs 2`, `-derivedDataPath .deriveddata/`), export con `.asc/ExportOptions.plist`, `scripts/asc-preflight.sh`, `asc builds upload`.
4. Espera `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta y cierra.
5. `asc versions attach-build` a la versión 2.2 (sin revisión, sin tocar textos/capturas de Lola).
6. Mismo PR a 2.2: bump + Resultado en `encargos/lanzados/`. Card a in qa (Jürgen instala y prueba).

## Si hace falta algo de Jürgen
Firma, certificado, perfil, 2FA, acuerdo ASC, tren cerrado: de noche NO uses AskUserQuestion ni esperes. No improvises ni toques certificados: crea card cierra-sola asignada a jurgen con el error exacto, deja el bump sin subir en el PR (o sin PR si no hay nada útil) y cierra con /cerrar-total.

## Qué NO hay que tocar
- `marketing/`, `Web/`, ficha App Store, capturas.
- Código de producto (si bloquea la firma: ticket + card).
- No borrar builds, no grupos de testers, no beta review externa. No instalar en el iPhone de Jürgen.
- No lanzar otras sesiones Yala.

## Reglas de Mini
Pipeline serial: limpiar → build sin sim → apagar sims. Borra al lanzar y al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados, sin preguntar. `limpiar-mac --apply` al cerrar.

## Cómo se sabe que está bien
- Build 2.2 (N) VALID / IN_BETA_TESTING, adjunto a la versión 2.2, con los PR de arriba dentro.
- PR del bump mergeable a 2.2. Cierre con número de build, commit y estado ASC.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen: es de noche (21:00–6:00).
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en el ticket/card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total

## Paso 0 (Frank, 2026-10-29 22:40 Lima, Mini)

- **Número de build: 4.** Medido con `asc builds list --paginate`: el último del tren 2.2 es el 3 (VALID, 2026-10-28). `asc versions list`: versión 2.2 en `PREPARE_FOR_SUBMISSION`.
- **`origin/2.2` lleva `CURRENT_PROJECT_VERSION = 2`**, no 3: el bump del (3) vive en #665, que sigue abierto. Este PR sube 2 → 4 y deja #665 obsoleto (choca en las mismas 20 líneas).
- **Por qué #665 no entra:** el banco `qa/scripts/versiones-embebidas-test.sh` muta con el valor fijo `3`. Con el proyecto ya en 3, el caso «configuraciones distintas» deja de fallar y el banco da «1 de 7 casos fallan». Con 4 no se dispara. No lo arreglo aquí (fuera de alcance): card aparte.
- **Espera de merges:** #692 (import, S27m) estaba en CI al arrancar. Espera acotada a 45 min (hasta ~23:23).
- **Gate:** el diff compilable es solo `project.pbxproj`. Gate como en los builds anteriores: build `Yala Dev` + `validate-coverage` + banco de versiones. Sin simulador.

## Resultado (2026-10-29 23:36 Lima)

- **Yala 2.2 (4)** subido desde `dde39115e` (merge de #692) + bump. App, widgets y share en 2.2 (4). Firma de producción en el `.ipa` (`aps-environment` production, `appattest` production, `get-task-allow` false). Preflight OK.
- Upload `a466604f…`: `COMPLETE` en ~7 min → build `VALID`, `internalBuildState: IN_BETA_TESTING`. Asignado a la versión 2.2 de App Store, que sigue en `PREPARE_FOR_SUBMISSION`.
- **Dentro:** todo lo mergeado a `2.2` hasta #692, incluidos #681, #682, #683 (S27), #685 (S27b), #686 (Grupos opción A), #687 (Bandeja), #688 (Vaciar datos / Eliminar cuenta), #690 (UI tests en 8 tandas), #691 (S27l) y #692 (S27m). Nada de la lista quedó fuera.
- **Gate:** archive `Yala` Release ✓, build `Yala Dev` ✓, `validate-coverage` ✓, banco de versiones (7 casos) ✓. Sin simulador.
- **Encontrado:** #665 (bump a 3) sigue abierto y queda obsoleto; su `coverage-index` rojo es del banco de versiones, que muta con un `3` fijo. Card propia, asignada a Frank. En ASC hay una reserva de upload 2.2 (4) `c6a8c4eb` en `AWAITING_UPLOAD` que no es de esta subida; no se tocó.
