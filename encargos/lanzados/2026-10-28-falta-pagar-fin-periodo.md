# «Lo que te falta pagar» cuenta hasta fin del periodo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: high.
Slug: `falta-pagar-fin-periodo` · Sesión cola **S12e** · al cerrar → **S13**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/falta-pagar-fin-periodo-x3ti.md`

Léelo y ejecútalo tal cual. Decisión ya tomada: **A · hasta fin del periodo**.

## Qué NO tocar
Lo que diga el brief. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief + PR a 2.2.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Qué es «fin del período» por período.** Esta semana → último segundo de la semana (primer día de la semana del
   usuario); Este mes → 31 a las 23:59:59; Este año → 31-dic 23:59:59. *Asumido:* Últimos 7 / 30 días son móviles y su
   período acaba hoy → sin cambio. Todo el tiempo no tiene fin → sin cambio (hoy). Personalizado → su rango. Mes y año
   pasados (cerrados) → sin cambio.
2. **Dónde vive el intervalo.** Se reutiliza `FinancialScoreCalculator.commitmentsInterval` (ya daba mes y año
   completos cerrando 23:59:59) y se le añade `.thisWeek`. Su otro llamador, la puntuación financiera, descarta la semana
   antes (`isShortPeriod`), así que no cambia. Evita un segundo «fin del período» que divergiría.
3. **Alcance.** Solo el pendiente de `InsightsCalculator.calculateCommitments` (el que pinta «Lo que te falta pagar» y lo
   que de él lee Yala IA, `pending_payments`). Totales, días, promedios y presupuestos del Resumen siguen cerrando hoy.
   El copy no dice «hasta hoy»: no se toca.
4. **Pagos vencidos antes de hoy dentro del período** siguen contando (como antes): el inicio del intervalo no cambia.
5. **Test.** Suite nueva `InsightsToPayUntilPeriodEndTests`: caso del brief (hoy 27, vence 28 → entra) y cada frontera
   por los dos lados (mes, semana, año), más controles de lo que no cambia. Mutante: volver al intervalo viejo → rojo.
6. **Sin capturas antes/después**: el cambio es de cifra, no de diseño; la evidencia es el unit test.
