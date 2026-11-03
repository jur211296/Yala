
# Widgets de categorías con porcentajes que suman 100 % y pago planificado ya pagado que dice a qué mes aplican sus acciones

Cierre: **cierra-sola** → al terminar, `/cerrar-total`. Esfuerzo: high.
Versión **2.2**. Base `origin/2.2`.
Slug: `widgets-porcentajes-y-pago-planificado-mes` · Encargo 03 de la cola Yala (junta S35t y S35u) · al cerrar → encargo 04.

## Cards y criterio de hecho
- `tablero-widgets-de-categorias-los-porcentajes-se-znu5` — Widgets de categorías: los porcentajes se miden contra el total con signo
  - Hecha cuando: con un gasto y su devolución, los porcentajes del widget suman 100 % y el centro coincide con la suma de las filas; test de la foto y de la extensión.
- `tablero-pago-planificado-ya-pagado-ya-lo-pague-y-3zva` — Pago planificado ya pagado: «Ya lo pagué» y «Saltar este mes» no dicen a qué mes se refieren
  - Hecha cuando: con la ocurrencia actual pagada, se ve a primera vista a qué mes aplican las acciones, y la Bandeja y el widget dicen lo mismo; con tests y capturas antes y después.

## 1. Widgets de categorías (znu5)
### Contexto
Este hallazgo salió de la review de la tanda 3 de widgets (PR #726). Cuando hay una devolución en el período, las tartas y los rankings de Categorías del widget muestran porcentajes que suman más del 100 %, y un total menor que la suma de sus filas. Pasa porque los trozos suman en positivo, pero el porcentaje se divide por el total con signo. Ticket: tickets/backlog/widget-category-percentages-use-the-signed-total.md.
### Qué se pide
- Usa como denominador la suma de magnitudes del lado (gasto o ingreso), según la regla de ingreso-gasto.md.
- Aplícalo en WidgetDataCache y en el camino de emergencia de WidgetDataService.
- Agrega tests de la foto y de la extensión con un gasto y su devolución.
### Qué NO hay que tocar
- El diseño de los widgets de la tanda 3.
- Los porcentajes de Estadísticas dentro de la app, salvo que compartan el mismo código y estén igual de mal (si es así, anótalo en el digest).
### Cómo se sabe
Con un gasto y su devolución, los porcentajes del widget suman 100 %, el centro coincide con la suma de las filas, y el CI queda verde.

## 2. Pago planificado ya pagado (3zva)
### Contexto
Este bug lo reportó Jürgen el 1-nov a las 08:52 (captura: /Users/jur/Claude/tmp-frank/capturas/2026-11-01-pago-planificado-ya-pagado-botones.png). Pasa en el detalle de un pago planificado cuya ocurrencia actual ya está pagada. Por ejemplo, «Google Workspace Yala», $17.99 mensual, vence el 1 de cada mes: la tarjeta dice «Vence en 30 días · 1 de diciembre» y «Noviembre de 2026 ya está pagado». Aun así siguen apareciendo «Ya lo pagué» y «Saltar este mes» («No se apunta nada; los demás meses siguen igual»), y no se entiende si se refieren a noviembre o a diciembre.

Precisión de Jürgen: el aviso de a qué mes aplican los botones tiene que ser más PREDOMINANTE, es decir, más visible y con más jerarquía. No basta con un texto más claro.
### Qué se pide
- Cuando la ocurrencia actual ya está pagada, las acciones apuntan explícitamente a la próxima: «Ya pagué diciembre» y «Saltar diciembre».
- El mes al que aplican va con jerarquía visual propia, siguiendo el design system: por ejemplo, un encabezado o chip «Próximo: diciembre 2026» encima de las acciones, más visible que el pie actual. Otra opción es ocultar las acciones o bajarlas de nivel. Elige lo más claro y justifícalo en el PR.
- Revisa que el texto de ayuda («No se apunta nada…») nombre el mes.
- Revisa que la Bandeja y el widget de pagos usen el mismo criterio y el mismo mes.
- Cubre los 16 idiomas en los textos nuevos.
### Qué NO hay que tocar
- La lógica de cálculo de ocurrencias, salvo que sea necesario para saber cuál es la próxima.
- Otras pantallas de pagos que no muestren estas acciones.
### Cómo se sabe
- Con la ocurrencia actual pagada, se entiende a primera vista a qué mes aplican las acciones.
- Con la ocurrencia actual sin pagar, todo sigue como antes.
- Hay tests de los dos casos y capturas antes y después en modo claro y oscuro.
- El CI queda verde.

## Al abrir el PR
Las dos cards quedan en «in qa» de Jürgen, con un guion corto para el iPhone para cada una. Fuera de estas dos cards no se toca nada (ni marketing/ ni Web/).

## Pie fijo (lanzar-sesion)
- Proyecto Yala, repo `jur211296/Yala`. Versión **2.2**. Base `origin/2.2`; el PR va a `2.2` con auto-merge.
- Una sesión Yala a la vez: no lances otras sesiones Yala ni trabajes en paralelo con otra. Un solo PR para todo este encargo y un solo cierre.
- Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial de la Mini: limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (nunca las de un worktree vivo); build con `xcodebuild -jobs 2` sin sim booteado; bootear 1 sim; tests; apagar y borrar el sim. `limpiar-mac --apply` al cerrar.
- Pasa cada card a «in qa» (o «done» si no necesita ojos de Jürgen) al abrir el PR, con `--agente` de la sesión.
- Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog), y lista sus títulos en el PR y en el cierre.
- Cierre autónomo: se lanza con `--permission-mode bypassPermissions`. Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
- Al cerrar, Frank publica el digest y lanza el siguiente encargo de `~/Claude/flota/cola-yala/`.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 01:30 Lima, fuera del horario de preguntas): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** (1) Los porcentajes de la foto YA se dividen por la suma de magnitudes desde el
2026-10-23 (`expenseTotalMagnitude`, en la app y en la extensión). Lo que sigue roto es otra cosa: el centro de la tarta
y el «Otros» se miden contra el total CON SIGNO (`summary.totalExpense`), y cada trozo suma la magnitud de cada
movimiento (gasto 100 + devolución 30 = trozo 130, centro 70). (2) La tarta de Estadísticas de la app ya decidió lo
contrario: la devolución resta de su categoría (`TopSpendingCategoriesCalculator`, test «Una devolución en Comida resta,
y la tarta sigue cuadrando con el total»). (3) Pagar una ocurrencia (aprobar, «Ya lo apunté», «Apuntarlo ahora») avanza
`nextDueDate`, que es lo que leen la Bandeja (crea el borrador cuando `nextDueDate <= hoy`) y el widget de pagos.

**D1 · ¿Qué mide cada trozo del widget de categorías?** → El neto de la categoría, como Estadísticas: la devolución resta
de su trozo. Por qué: «el mismo dinero da la misma cifra» (`ingreso-gasto.md`); el centro de la tarta dice «Total» y
así coincide con el gasto del período y con la tarta de la app. Alternativa descartada: dejar los trozos en magnitud
por movimiento y poner en el centro su suma (130): cuadra por dentro pero enseña un «Total» que no es el gasto de nadie.

**D2 · ¿Contra qué se miden porcentajes, centro y «Otros»?** → Contra la suma de magnitudes de TODOS los trozos del
lado gasto (`expenseBreakdownTotal`, campo nuevo y opcional de la foto, en las dos copias del DTO). Por qué: es lo que
pide el encargo y garantiza 100 % aunque una categoría quede a favor. Sin categorías a favor es el gasto del período.
Una foto vieja sin el campo cae al total de antes. Alternativa descartada: recalcular el total en la vista sumando filas
(las subcategorías no cubren todo el gasto y la foto trae como mucho 20 filas).

**D3 · ¿Se tocan los porcentajes de Estadísticas?** → No. No comparten código con el widget. Su denominador es el
total con signo y solo se descuadra con una categoría a favor: se anota en el digest, no se arregla aquí.

**D4 · ¿Cómo se marca a qué mes aplican las acciones del detalle con el mes en curso ya pagado?** → Encabezado propio
encima de los botones, separado por una línea: icono de calendario + «Próximo: diciembre de 2026» en tipografía de
titular (no pie gris), y los botones nombran el mes: «Ya pagué diciembre» / «Saltar diciembre», con la ayuda «No se
apunta nada en diciembre; los demás meses siguen igual». Por qué: Jürgen pidió jerarquía, no solo texto; el encabezado
la da y los botones repiten el mes donde se toca. Alternativa descartada: ocultar o bajar de nivel las acciones —
quita pagar por adelantado, que es legítimo— y una segunda píldora, que competiría con la de arriba.

**D5 · ¿Y si el mes de la próxima fecha tiene varias fechas (semanal, diario)?** → Se nombra la fecha, no el mes:
«Próximo: 1 de diciembre», «Ya pagué el del 1 de dic.»/«Saltar el del 1 de dic.» (texto del día en su forma corta si no
cabe). Por qué: «Saltar diciembre» mentiría, porque saltar quita UNA fecha. La regla vive en una función pura con test.

**D6 · ¿Cambia algo con el mes en curso sin pagar?** → Nada: mismos textos, sin encabezado. Lo pide el encargo.

**D7 · ¿Bandeja y widget de pagos?** → Se miden, no se cambian: los dos leen `nextDueDate`, que pagar el mes avanza a
la misma fecha que el detalle llama «próxima». Se fija con un test de paridad (detalle ↔ puntero) en vez de tocar su
código.

**D8 · Capturas** → Widget: banco `qa/widget-render` con la foto `realista` editada para modelar un gasto y su
devolución, antes (código base) y después. Detalle: XCUITest conductor sobre la semilla `minimal`, claro y oscuro.
