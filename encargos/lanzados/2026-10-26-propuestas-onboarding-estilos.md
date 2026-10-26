# Propuestas: onboarding estilos vs resto

Cierre: **propuesta-visual** → PARA (sin merge ciego; **no** `/cerrar-total` con implementación).
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `propuestas-onboarding-estilos` · Sesión cola **S4** · al cerrar → **S5**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/onboarding-estilos-propuestas-i00g.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones (resueltas en autónomo (bypass))

- **Formato de las propuestas:** cuatro decisiones por eje (botones, titulares, listas, textos) con A recomendada, como S3. Alternativa descartada: paquetes cerrados, que obligan a aceptar ejes juntos.
- **Choque con lo ya decidido:** solo D2-B (quitar el serif) choca con el 15-sep; se ofrece marcado y no se recomienda. El fondo fijo y la forma de los selectores no entran en ninguna opción.
- **Dónde queda:** lienzo Design (capturas + maquetas) y sección en el ticket vía PR #640 sin auto-merge. Sin código.
- **Capturas:** simulador con Yala Dev sobre `origin/2.2`, en `_capturas/onboarding-estilos/`; no hay `capturas/antes|despues` porque no hay cambio visible.
