---
release: no
depende: "#700"
---
# Subir TestFlight 2.2 (5) con lo mergeado hasta el barrido QA

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Slug: `subida-testflight-2-2-5` · Sesión cola **S28tf** · al cerrar → **S29** (capturas App Store).

## Contexto
Pedido de Jürgen (2026-10-29 21:32 Lima): otra subida a TestFlight **después** del barrido QA de 2.2 (S28) y **antes** de las capturas App Store (S29), con todo lo mergeado a 2.2 hasta ese momento. No es App Store. Receta: `~/Claude/tmp-frank/sesion-S27tf-subida-testflight-2-2-4.md` (S27tf), `sesion-S12tf-subida-testflight-2-2-3.md` (PR #665) y `subida-testflight-2-2-v1.md`. App `Yala`, bundle `com.jurgenschmidt.yala`, ASC **6758253109**, scheme **«Yala»** (nunca «Yala Dev»). Último previsto: 2.2 (4) de S27tf; **no lo asumas, mídelo**.
Card: `tablero ver tablero-subir-testflight-2-2-5-con-el-barrido-qa-d7fu`.

Debe ir en este build: todo lo de 2.2 (4) más el barrido de animaciones iOS 27 (S27c, barrido-ios27-animaciones), los pre-check de eficiencia y notificaciones (S27e eficiencia-carga-por-vista, S27f notificaciones-orden-prioridades — PR #696, que arregla S27o pr696-test-modo-uso —, S27g notificaciones-abrir-destino-correcto, S27p divisa-widget-exportar-animaciones) y los arreglos del barrido QA (S28, barrido-qa-2-2). También: el PR #650 (tarjeta de crédito con fecha de corte, ya mergeado a 2.2) y el PR #700 (Grupos: montos en el color del texto, Gráficas como Tendencias y Welcome centrado; en cola de auto-merge a las 15:22 del 30-oct). Esta sesión depende del #700.

## Qué se pide
0. **Qué entra:** con `gh pr list -R jur211296/Yala --base 2.2 --state merged` comprueba que los PR de la lista de arriba ya están en origin/2.2. Si alguno no entró, anota en el cierre y en la card qué quedó fuera. Si hay CI en rojo real (no flaky, no cancelado) en un PR que debía entrar, no subas: dilo en el cierre, crea card cierra-sola y cierra con /cerrar-total.
1. `git fetch origin` y trabajar sobre **`origin/2.2`**. **Medir el último build antes del bump** con `asc builds list --paginate` y `asc versions list --app 6758253109`: confirma tren 2.2 y el **siguiente** `CURRENT_PROJECT_VERSION` = mayor medido + 1 (se espera 5; si 2.2 (4) no subió, usa el siguiente que corresponda según lo medido).
2. Bump en los **20 targets**: `MARKETING_VERSION` = 2.2; `CURRENT_PROJECT_VERSION` = el siguiente medido.
3. Archive scheme `Yala` (`nice -n 10 xcodebuild -jobs 2`, `-derivedDataPath .deriveddata/`), export con `.asc/ExportOptions.plist`, `scripts/asc-preflight.sh`, `asc builds upload`.
4. Espera `VALID` + `internalBuildState: IN_BETA_TESTING`. Si se queda horas en processing, reporta y cierra.
5. `asc versions attach-build` a la versión 2.2 (sin revisión, sin tocar textos/capturas de Lola).
6. Mismo PR a 2.2: bump + Resultado en `encargos/lanzados/`. PR: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR. Card a in qa (Jürgen instala y prueba).

## Si hace falta algo de Jürgen
Firma, certificado, perfil, 2FA, acuerdo ASC, tren cerrado: de noche NO uses AskUserQuestion ni esperes. No improvises ni toques certificados: crea card cierra-sola asignada a jurgen con el error exacto, deja el bump sin subir en el PR (o sin PR si no hay nada útil) y cierra con /cerrar-total.

## Qué NO hay que tocar
- `marketing/`, `Web/`, ficha App Store, capturas (eso es S29).
- Código de producto (si bloquea la firma: ticket + card).
- No borrar builds, no grupos de testers, no beta review externa. No instalar en el iPhone de Jürgen.
- No lanzar otras sesiones Yala.

## Reglas de Mini
Pipeline serial: limpiar → build sin sim → apagar sims. Borra al lanzar y al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados, sin preguntar. `limpiar-mac --apply` al cerrar.

## Cómo se sabe que está bien
- Build 2.2 (N) VALID / IN_BETA_TESTING, adjunto a la versión 2.2, con los PR de S27c, S27e, S27f, S27g, S27p y S28 dentro.
- PR del bump mergeable a 2.2. Cierre con número de build, commit y estado ASC.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen: es de noche (21:00–6:00).
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en el ticket/card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total

## Paso 0 (Frank, 2026-10-30 15:30 Lima, Mini)

- **Número de build: 5.** Medido con `asc builds list --paginate`: el último del tren 2.2 es el 4 (VALID, subido 2026-10-29 21:32 PT). `asc versions list`: versión 2.2 en `PREPARE_FOR_SUBMISSION`.
- **`origin/2.2` ya lleva 2.2 / 4** en los 20 targets (el bump de #693 entró). Este PR sube solo `CURRENT_PROJECT_VERSION` 4 → 5.
- **Qué entra:** #694 (S27c), #695 (S27e), #696 (S27f, con el arreglo de S27o), #697 (S27g), #698 (S27p), #699 (S28) y #650 (tarjeta) ya están en `origin/2.2`. #700 estaba en cola de auto-merge con `tests` en curso: el encargo declara `depende: "#700"`, así que se espera su merge (tope ~55 min) antes de archivar. Si cae en rojo real, no se sube.
- **Gate:** el diff compilable es solo `project.pbxproj`. Gate como en los builds anteriores: archive `Yala` Release + build `Yala Dev` + `validate-coverage` + banco de versiones. Sin simulador.
- Es de día (15:30), pero el encargo es autónomo: nada aquí es decisión de producto.

## Resultado (2026-10-30 16:40 Lima)

- **Yala 2.2 (5)** subido desde `d449a80dd` (merge de #700) + bump 4 → 5. App, share y widgets en 2.2 (5). Firma de producción en el `.ipa` (`aps-environment` production, `appattest` production, `get-task-allow` false). Preflight OK.
- Upload `2546fd42…` → build `VALID`, `internalBuildState: IN_BETA_TESTING`. Asignado a la versión 2.2 de App Store, que sigue en `PREPARE_FOR_SUBMISSION`.
- **Dentro:** todo lo mergeado a `2.2` hasta #700: #694 (S27c animaciones iOS 27), #695 (S27e eficiencia), #696 (S27f notificaciones, con S27o), #697 (S27g abrir destino), #698 (S27p divisa/widget/exportar), #699 (S28 barrido QA), #650 (tarjeta con fecha de corte) y #700 (Grupos en blanco, Gráficas, Welcome centrado). Nada de la lista quedó fuera.
- **Gate:** archive `Yala` Release ✓, build `Yala Dev` ✓, `validate-coverage` ✓, banco de versiones (8 casos) ✓. Sin simulador.
