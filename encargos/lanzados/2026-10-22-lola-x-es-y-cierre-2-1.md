Encargo Yala · una sola sesión con dos partes. Fuente: ~/Claude/tmp-frank/cola-yala-2026-10-16-noche.md, secciones «PRIORIDAD LOLA (2026-10-22 05:50)», «+ MISMA sesión de Lola» y «+ Buenas prácticas». Léelas enteras; todo está confirmado por Jürgen en su 1:1 con Frank (06:00 y 06:01).

PASO 0: el disco de la Mini está en 23 GB libres. Corre `limpiar-mac` antes de renderizar o compilar. Este worktree nació de origin/2.1: haz git fetch y pásate a origin/2.2 antes de tocar nada.

PARTE A · Cierre de 2.1 (Apple publicó 2.1 el 22-oct a las 2:16 Lima). 1.0 (main) queda como la rama oficial de la web y la app y todo se trabaja en 2.2:
1) Arregla `lanzar-sesion` (en ~/bin) para que las sesiones Yala nazcan de origin/2.2 y no de origin/2.1.
2) Merge 2.1 → 1.0. Tag `v2.1` en ese punto. Etiqueta también las versiones anteriores que no tengan tag. Crea el GitHub Release `v2.1` con notas.
3) Pasa a 2.2 los PR abiertos que apuntan a 2.1, y solo después borra la rama remota 2.1.
4) Protege 1.0 (solo PR con CI verde, sin push directo). Rama por defecto de GitHub → 2.2. Workflows de CI y avisos que miran 2.1 → 2.2 y 1.0 (Frank ya cambió su rutina de avisos). Documenta el flujo de hotfix en docs: sale de 1.0, tag v2.1.x, merge también a 2.2.
5) Vercel, proyecto `yala-app` (yala-app.pe): rama de producción → 1.0, deja un deploy READY desde 1.0 en producción. Diagnostica por qué los deploys de producción salen CANCELED desde el 16-oct (commit 48968c7, PR #525; último 5ad5472, 21-oct 17:35), por ejemplo un ignored build step, corrígelo y confirma que la web publica lo último de 1.0. No toques los «gratis» de la web.

PARTE B · Pedido de Lola, material X en ES (misma maqueta que EN, ES y EN a la vez), en ~/Claude/marketing/biblioteca/:
1) carruseles/panel-presupuestos/es-16x9/: 6 láminas de 1600×900.
2) carruseles/yala-ia/es-16x9/: 6 láminas de 1600×900.
3) carruseles/grupos y el bento de Grupos en X ES y X EN a 1600×900 (no rehagas lo que ya exista), y el reel de Grupos para X en ES y EN, 9:16 y con la misma duración.
4) Barrido: que ningún estático ni carrusel pendiente tenga solo la versión EN para X; sácale la ES en el mismo formato.
Los reels existentes no se tocan. Nunca escribas «OpenAI» en los textos. Montos en soles.

Reglas: no esperes el CI de ningún PR. Solo simulador, nunca los iPhone/iPad reales de Jürgen. No toques en ~/Yala los .ckdb de CloudKit, Yala.xcscheme ni encargos/pendientes/. No toques tmux salud--, sat-lab-- ni clinicas-dentales-bi--. Ningún secreto en archivos; los secretos van en 1Password. En el digest en español: la lista de rutas de los assets y el estado del repo y de Vercel, más capturas de las piezas. Mueve la card al cierre.
Al terminar: /cerrar-total

## Paso 0 — decisiones (resueltas en autónomo, bypass)

- **Base:** la rama del encargo se movió a `origin/2.2` (5fb3a3f88) antes de tocar nada; el PR va contra `2.2`.
- **lanzar-sesion:** no se toca la cascada; se declara `Yala 2.2` en `~/.claude/scripts/ramas-base.conf`, el mapa que ya leen `lanzar-sesion` y `/cerrar-total` (como sat-lab). Probado: la función da `origin/2.2`. El script vive en `~/.claude/scripts/`, no en `~/bin`.
- **Merge 2.1 → 1.0:** `1.0` era ancestro de `2.1`; merge `--no-ff` con commit propio, como los merges de 2.0 → 1.0 de junio. Árbol idéntico a 2.1.
- **Tags:** el encargo pide `v2.1` y `CLAUDE.md` exige 3 componentes: van los dos (`v2.1` y `v2.1.0`) en el mismo commit, y la excepción queda escrita en `CLAUDE.md`. Versiones publicadas sin tag, medidas en ASC: 2.0 (build 25 → `1814117e3`) y 2.0.1 (build 32 → `0a20bdc83`). 2.0.5 nunca se publicó: sin tag.
- **Release v2.1:** notas = las «Novedades» publicadas en ASC (es-ES, resumen en-US) + nota de ramas.
- **PR contra 2.1:** #567, #314 y #117 pasan a `2.2` aunque tienen conflictos (ya los tenían): resolverlos no es del encargo, se dice.
- **2.1 → 2.2:** 2.1 tenía 22 commits que 2.2 no (semilla de marketing, build 20, docs de QA). Se mergea `origin/1.0` en esta rama, que es el paso 5 del flujo de hotfix, y por eso pasa por `/gate`.
- **Protección de 1.0:** ruleset nuevo sin bypass: PR obligatorio, checks `tests`, `coverage-index` y `gateway` (los de 2.2), sin borrado ni force-push. 0 aprobaciones requeridas (Jürgen trabaja solo).
- **Avisos:** `qa.yml` push → `2.2` y `1.0`; `nocturna-vigilante` push → `2.2`; resumen diario de Grok → `2.2` (1.0 recibe pocos merges y sus rojos ya avisan por `qa.yml`). La nocturna corre en la rama por defecto, que pasa a `2.2`.
- **Árbol principal:** sigue en la rama local `2.1` con cambios de Jürgen; no se toca. Pasarlo a `2.2` queda para él.
- **Parte B:** la hace un fork en paralelo con las fuentes de `_fuente/` (sin simulador). Bento X y estáticos de Grupos X ya medían 1600×900: no se rehacen. Reel de Grupos X: ficheros nuevos en `reels/grupos/x/`, los existentes intactos.
- **Aviso a Lola:** un solo mensaje al cierre, con rutas y estado de repo y Vercel.

## Resultado

- **lanzar-sesion:** `Yala 2.2` en `~/.claude/scripts/ramas-base.conf` (commit `7042f0f` en `~/.claude`). La base de Yala da `origin/2.2`.
- **1.0:** `Merge branch '2.1' into 1.0` (`b3b544cc9`). Tags `v2.1` y `v2.1.0` ahí; `v2.0.0` (`1814117e3`, build 25) y `v2.0.1` (`0a20bdc83`, build 32). GitHub Release `v2.1` con las Novedades de la App Store.
- **PR #567, #314 y #117:** ahora contra `2.2`; los tres siguen con conflictos (en la memoria de Frank y en `marketing/README.md`).
- **Rama 2.1 borrada** del remoto. Rama por defecto: `2.2`. Ruleset nuevo de `1.0` (PR obligatorio, `tests`, `coverage-index` y `gateway`, sin borrado ni force-push, sin bypass); el de las ramas de trabajo pasa a cubrir solo `2.2`.
- **Vercel `yala-app`:** rama de producción `1.0`. Los CANCELED del 16 al 21-oct eran el Ignored Build Step (`git diff --quiet HEAD^ HEAD ./`): ningún merge tocó `Web/` y la web publicada ya era la de 2.1. El paso compara ahora con el último deploy bueno (`VERCEL_GIT_PREVIOUS_SHA`). Deploy `dpl_4MHjA8ooTEngZ6CeeHxM3BGnp8fy` READY en producción desde `1.0` @ `b3b544cc9`, alias yala-app.pe, que responde 200.
- **2.2:** trae los 22 commits de 2.1 por merge de `1.0` (gate verde: build ×2, 110 unit en 13 suites, 38 XCUITest en 8 suites).
- **Parte B:** 18 láminas ES 16:9 (panel-presupuestos, yala-ia, grupos) y el reel de Grupos para X en ES y EN (9:16, 21,2 s los dos). Nota `PARA-LOLA-x-es-22-oct.md` y hoja `hoja-x-es-22-oct.jpg`.
