# Presupuestos: selector de periodos a la derecha de «Nuevo presupuesto»

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `presupuestos-selector-periodos` · Sesión cola **S17b** · al cerrar → **S18**.

## Encargo
Cumple **íntegramente** este brief:

1. `~/Claude/tmp-frank/presupuestos-selector-periodos-ca00.md` — selector de periodos estilo calendario (Semanal/Mensual/Anual/Único, default Mensual) a la derecha de «Nuevo presupuesto», misma altura; quitar el segmento a lo ancho.

Léelo y ejecútalo tal cual. Este wrapper fija el hueco en la cola automática.

## Qué NO tocar
Lo que diga el brief. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.
