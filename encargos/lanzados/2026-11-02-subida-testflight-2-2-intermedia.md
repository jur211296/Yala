---
esfuerzo: medium
release: no
---
# Subir TestFlight 2.2 con lo mergeado hasta fluidez-hapticos-yala-ia

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `subida-testflight-2-2-intermedia` · Sesión cola **S35ntf** · al cerrar → **S35q** (`grupos-autor-del-gasto`).

## Contexto
Pedido de Jürgen (2026-11-02 18:02 Lima): TestFlight intermedio, justo después de fluidez-hapticos-yala-ia, para tener lo último en su iPhone y seguir encontrando cosas; después sigue la cola. No es App Store. Receta: `~/Claude/tmp-frank/sesion-S28tf-subida-testflight-2-2-5.md` (S28tf), `sesion-S27tf-subida-testflight-2-2-4.md` y `subida-testflight-2-2-v1.md`. App `Yala`, bundle `com.jurgenschmidt.yala`, ASC **6758253109**, scheme **«Yala»** (nunca «Yala Dev»). Último subido conocido: 2.2 (5); **no lo asumas, mídelo**.
Card: `tablero ver tablero-subir-testflight-2-2-con-lo-mergeado-has-e76v`.

Debe ir en este build: todo lo mergeado en origin/2.2 hasta ahora, incluido el PR #747 (fluidez-animaciones-apagadas) y el PR de fluidez-hapticos-yala-ia (si sigue en la cola de merge, espera hasta 45 min; si no entra, sube igual y anótalo).

## Qué se pide
0. **Qué entra:** con `gh pr list -R jur211296/Yala --base 2.2 --state merged` lista lo que entró desde 2.2 (5) y comprueba que los PR de arriba ya están en origin/2.2. Si alguno no entró, anota en el cierre y en la card qué quedó fuera. Si hay CI en rojo real (no flaky, no cancelado) en un PR que debía entrar, no subas: dilo en el cierre, crea card cierra-sola y cierra con /cerrar-total.
1. `git fetch origin` y trabajar sobre **`origin/2.2`**. **Medir el último build antes del bump** con `asc builds list --paginate` y `asc versions list --app 6758253109`: confirma tren 2.2 y el **siguiente** `CURRENT_PROJECT_VERSION` = mayor medido + 1 (probablemente 6; si 2.2 (5) no subió, usa el siguiente que corresponda según lo medido).
2. Bump en los **20 targets**: `MARKETING_VERSION` = 2.2; `CURRENT_PROJECT_VERSION` = el siguiente medido.
3. Archive scheme `Yala` (`nice -n 10 xcodebuild -jobs 2`, `-derivedDataPath .deriveddata/`), export con `.asc/ExportOptions.plist`, `scripts/asc-preflight.sh`, `asc builds upload`.
4. Espera `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta y cierra.
5. `asc versions attach-build` a la versión 2.2 (sin revisión, sin tocar textos/capturas de Lola).
6. Mismo PR a 2.2: bump + Resultado en `encargos/lanzados/`. PR: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR. Card a in qa (Jürgen instala y prueba).

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
- Build 2.2 (N) VALID / IN_BETA_TESTING, adjunto a la versión 2.2, con lo mergeado hasta fluidez-hapticos-yala-ia dentro.
- PR del bump mergeable a 2.2. Cierre con número de build, commit y estado ASC.

## Cierre autónomo
- Se lanza con `--permission-mode bypassPermissions`. Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-02 19:05 Lima, Mini)

- **Número de build: 6.** Medido con `asc builds list --paginate` (108 builds): el mayor del tren 2.2 es el 5 (VALID, subido 2026-10-30 14:11 PT). `asc versions list`: versión 2.2 en `PREPARE_FOR_SUBMISSION`.
- **`origin/2.2` lleva 2.2 / 5** en los 20 targets. Este PR sube solo `CURRENT_PROJECT_VERSION` 5 → 6.
- **Qué entra:** desde 2.2 (5) (#701) se mergearon #702–#747; #747 (fluidez-animaciones-apagadas) ya está en `origin/2.2`. #748 (fluidez-hapticos-yala-ia) está en cola de auto-merge con `tests` en curso: se espera hasta 45 min antes de archivar; si no entra, se sube sin él y se anota.
- **Gate:** el diff compilable es solo `project.pbxproj`. Gate como en los builds anteriores: archive `Yala` Release + build `Yala Dev` + `validate-coverage` + banco de versiones. Sin simulador.
- Es de noche y el encargo es autónomo: nada aquí es decisión de producto.
