# Explorar App Designer Pro: propuestas visuales Yala (posts, reels, ficha, encabezado)

Card czba (Yala/marketing). Effort high.

## AUTONOMÍA Y REGLAS (léelo primero)
- Jürgen y Lola están dormidos. **Nunca uses AskUserQuestion y nunca esperes respuesta**: decide tú, apunta cada decisión en el README/cierre y cierra con `/cerrar-total`.
- Destino: marketing de Yala (carril de Lola). Si hay trabajo visual, lee primero `~/Claude/referencias-ui/README.md` (inspiración de patrones, nunca copiar).
- **No publiques ni subas nada**: ni a App Store Connect ni a redes sociales (IG, X, TikTok…). Todo queda como borrador en disco.
- Simuladores: uno como máximo; al terminar (y antes de cerrar) `xcrun simctl shutdown all`; nunca entre 9:00 y 11:00 Lima. `nice -n 10 xcodebuild -jobs 2`, carga < 8.
- PR contra 2.1 **solo si cambian archivos del repo**: `git fetch origin && git rebase origin/2.1` antes de abrirlo. Si no cambia nada del repo, sin PR.
- Copy siempre fiel a la app y a la política 2.1 (PR #469): «más de 50 divisas», Grupos en la nube (no iCloud), exportación gratis de todos los períodos, sin Modo Nube ni conector de Claude en lo público, nada de «no almacenamos nada en servidores».

## Contexto
Jürgen compró App Designer Pro: es la skill `~/.claude/skills/app-designer-pro` (lee su `SKILL.md` y `references/`; primera vez: `(cd ~/.claude/skills/app-designer-pro && npm install)`; reels con ffmpeg). La skill entrevista al usuario: aquí **no**; decide tú con la marca del repo (`docs/planning/BRAND-VOICE.md`, `marketing/`) y los borradores de `~/Claude/lola-borradores/2.1/`.
**No dupliques la propuesta de capturas de App Store** ya hecha en `~/Claude/propuestas/capturas-appstore-2.1/` (PR #474); como mucho, refiérela en el README.

## Qué se pide (de la card)
Línea de diseño Yala: navy, brillos rosa/azul/teal, titular blanco con palabra subrayada, pill tag, logo yala.
- 3–5 posts IG 1080x1350.
- 2 portadas de reel 1080x1920.
- 2 carruseles.
- Encabezado de ficha App Store 21:9 3840x1646.
- Asset de resultados de búsqueda 3:2 (1920x1280 o mayor).
- Alguna exploración libre.
Pasa el escaneo de slop y la crítica puntuada de la skill.

## Salida
`~/Claude/propuestas-app-designer/2026-10-13/` con una carpeta por tipo y un `README.md` índice: qué es cada pieza, cómo se hizo, y un **veredicto de la herramienta** (qué hace bien, qué no, para qué usarla en Yala). Si algo pide login o licencia no disponible, documéntalo y sigue con lo que se pueda.

## Cómo se sabe
Carpeta con las piezas, README y veredicto, lista para enseñar a Jürgen al despertar; nada publicado.


## Reglas de esta noche
Totalmente autónomo: Jürgen y Lola duermen; nunca AskUserQuestion ni preguntas, decide tú. Base: origin/2.1. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar; ningún simulador de 9:00 a 11:00 Lima. Cierra con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 2026-10-13 de madrugada): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Línea de la card o la que empuja la skill?** → La de la card (navy, destellos rosa/azul/teal, titular blanco con palabra subrayada, pill tag, logo yala), ejecutada con las reglas de la skill: los destellos son la estrella de cuatro puntas del logo, nítida y nunca borrosa, y cada color tiene dueño (rosa = gasto, azul = ingreso, teal = Yala). Nada de manchas de luz detrás del texto.
Por qué: la línea es la marca que ya vive en el post diario y en `app-store-assets-2.1.md` §3; la skill marca «glow» y «navy fintech» como slop, así que se respeta la marca y se le quita lo que la hace genérica. Alternativa descartada: abandonar el navy (eso va a la exploración libre, no al set).

**D2 · ¿De dónde salen las pantallas?** → De las capturas reales de Yala 2.1 en `~/Claude/propuestas/capturas-appstore-2.1/_capturas-base/` (simulador, es-MX). No se arranca simulador.
Por qué: ya existen, son la app de verdad y ahorran el carril. Alternativa descartada: sacar capturas nuevas (sin ganancia y con coste de disco y simulador).

**D3 · ¿Qué copy?** → Español LatAm neutro, BRAND-VOICE, política 2.1 (PR #469): «más de 50 divisas», Grupos en la nube, exportación gratis de todos los períodos, sin Modo Nube ni conector de Claude. Sin emoji dentro de las imágenes (la skill los prohíbe en la pieza; el pie de foto de IG puede llevar uno).
Por qué: es lo que el encargo fija y lo que no se puede romper.

**D4 · ¿Se usa la skill entera?** → Solo su parte de venta (stages, panel, escaneo, reel y crítico). No se rediseña la app ni se hace la exploración de tres direcciones de la pantalla principal: la app ya existe. La exploración libre hace el papel de «tres direcciones» sobre un mismo post.
Por qué: el encargo pide piezas de marketing, no un rediseño.

**D5 · ¿Dónde vive la salida y hay PR?** → `~/Claude/propuestas-app-designer/2026-10-13/`, fuera del repo. El único cambio del repo es este Paso 0, que va por PR con auto-merge.
Por qué: nada se publica; el encargo pide PR solo si cambian ficheros del repo.

**D6 · Encabezado 21:9 y zona segura** → El contenido clave en el tercio central y el logo, no el icono. La zona exacta que recorta iPhone en vertical no está medida: se marca como pendiente de revisar en la vista previa de ASC.
