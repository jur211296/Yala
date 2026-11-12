# Welcome: borrar iCloud en bucle (grupos legacy)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `welcome-borrar-icloud-bucle` · Sesión cola **S24** · al cerrar → **S25**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/welcome-borrar-icloud-bucle-grupos-legacy-5b3g.md`

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


## Paso 0 — decisiones (resueltas en autónomo, bypass, 02:5x Lima)

1. **¿Causa confirmada?** Sí, en código (2.2 @ fda2fc445). La puerta de Grupos cuenta todo `SplitGroup`, pero el
   borrado de la vuelta al neutro (`.privateOnly`) solo se lleva el store de Grupos si hay grupos del backend. Un
   grupo de la era CloudKit sobrevive al borrado y la puerta vuelve a pedirlo en cada arranque. El iCloud no interviene.
2. **¿Reproducir en simulador?** No. La cadena se lee entera en el código y casa con los tres síntomas. Sembrar un
   grupo legacy y recorrer reinicios reales cuesta mucho más que lo que añade, con 19 GB libres de disco.
3. **¿Arreglar en esta sesión?** No. Cortar el bucle obliga a elegir entre borrar los grupos viejos (irrecuperables) o
   conservarlos, y Jürgen decide cuando una decisión mueve datos del usuario. Son las 2-3 h en Lima: no se le
   pregunta. Default: veredicto + ticket con las dos opciones (A recomendada) + card de decisión para Jürgen.
4. **¿Entrega?** Solo `tickets/`, `docs/TICKETS.md` y este encargo: no hay nada que compilar. Va por PR igualmente,
   para que el veredicto se lea antes de aterrizar; gate en su modo «solo índice».
5. **¿La card?** A `done` con el veredicto en la nota. El arreglo sigue en su ticket nuevo y en una card para Jürgen.
