# Ordenar la carpeta marketing/ del repo (marca, funcionalidades, copys, calendario)

Card eorp (Yala/marketing): «Ordenar carpeta marketing/ del repo (marca, funcionalidades, copys, calendario)». Effort medium.

## AUTONOMÍA Y REGLAS (léelo primero)
- Jürgen y Lola están dormidos. **Nunca uses AskUserQuestion y nunca esperes respuesta**: decide tú, apunta cada decisión en el README/cierre y cierra con `/cerrar-total`.
- Destino: marketing de Yala (carril de Lola). Si hay trabajo visual, lee primero `~/Claude/referencias-ui/README.md` (inspiración de patrones, nunca copiar).
- **No publiques ni subas nada**: ni a App Store Connect ni a redes sociales (IG, X, TikTok…). Todo queda como borrador en disco.
- Simuladores: uno como máximo; al terminar (y antes de cerrar) `xcrun simctl shutdown all`; nunca entre 9:00 y 11:00 Lima. `nice -n 10 xcodebuild -jobs 2`, carga < 8.
- PR contra 2.1 **solo si cambian archivos del repo**: `git fetch origin && git rebase origin/2.1` antes de abrirlo. Si no cambia nada del repo, sin PR.
- Copy siempre fiel a la app y a la política 2.1 (PR #469): «más de 50 divisas», Grupos en la nube (no iCloud), exportación gratis de todos los períodos, sin Modo Nube ni conector de Claude en lo público, nada de «no almacenamos nada en servidores».

## Qué se pide (de la card)
Crear en `marketing/` del repo:
- `marca/`: paleta navy, brillos rosa/azul/teal, titular blanco con palabra subrayada, pill tag, logo; tomado de los posts de @yala_app.pe (si no son accesibles, de los assets del repo) y de `docs/planning/BRAND-VOICE.md`.
- `funcionalidades/`: una ficha por feature con guion de demo, desde `~/Claude/lola-borradores/2.1/funcionalidades-2.1.md`.
- `copys/`: `changelog-2.1.md` y `app-store-2.1.md` de `~/Claude/lola-borradores/2.1/`, corregidos según las reglas de copy de arriba.
- `assets/`: checklist desde `~/Claude/lola-borradores/2.1/app-store-assets-2.1.md`.
- `calendario/`: plantilla semanal IG + X.
- `plantillas/`: HTML sin Figma para post 1080x1350, reel 1080x1920 y carrusel.
- `README.md` índice.
Respeta lo que ya exista en `marketing/` (muévelo, no lo borres). Sin simulador.

## PR a 2.1
Sí (cambian archivos del repo). Un PR con la estructura y el README.

## Cómo se sabe
PR abierto contra 2.1 con la estructura y el README; CI verde.

## Paso 0 (Frank, 2026-10-13, autocontestado)

- **Quién escribe `marketing/`:** Lola. La sesión abrió como Frank (cwd = raíz del worktree) y `marketing/` no es territorio de Frank; el contenido lo hace Lola como subagente y Frank solo lleva git, PR y cierre.
- **Lo existente se respeta:** nada se borra ni se mueve de `App Store/`, `screenshots-appstore/`, `remotion/`; mover rompería rutas de scripts (`asc-extra-locales-2.0.py`, generator, remotion). `x-presencia-minima.md` va a `calendario/` con `git mv` si ningún script lo referencia. El README índice enlaza todo.
- **Marca:** sin acceso a los posts de @yala_app.pe en modo nocturno sin login; se toma de los assets del repo y `BRAND-VOICE.md`, y se dice en `marca/README.md`.
- **Sin PR de código:** diff solo en `marketing/` + `encargos/` ⇒ el gate salta a la validación del índice.
