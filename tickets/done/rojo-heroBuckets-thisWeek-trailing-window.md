---
id: rojo-heroBuckets-thisWeek-trailing-window
status: done
area: panel
created: 2026-09-02
updated: 2026-09-02
resolved: 2026-09-02
source: /gate de la sesión de diseño del Panel (2026-09-02)
---


# Rojo preexistente: `periodPreviousInterval_thisWeek_returnsFullTrailingWindow`

## Qué pasa

`YalaTests/HeroBucketsCalculatorTests` falla **1 de 15**:

```
✘ periodPreviousInterval_thisWeek_returnsFullTrailingWindow()
  HeroBucketsCalculatorTests.swift:432
  Expectation failed:
    result   → 2026-04-06 05:00:00 +0000 … 2026-04-09 05:00:00 +0000   (3 días)
    fullPrev → 2026-04-06 05:00:00 +0000 … 2026-04-13 04:59:59 +0000   (7 días)
```

El test afirma que la ventana previa de `.thisWeek` es la semana ANTERIOR COMPLETA;
el código la devuelve **truncada** al mismo día-equivalente. O sea, MTD-aligned.

## No es de la sesión que lo encontró

Medido, no supuesto: se hizo `git stash` de los 24 ficheros de la sesión de diseño
del Panel y el test **falla exactamente igual** en el árbol limpio
(`ad07ceca` + `f84eb7eb`). Ninguno de esos ficheros toca cálculo de fechas.

No estaba registrado en ningún sitio: sin entrada en `docs/`, `tickets/` ni `qa/`.

## Por qué importa decidirlo y no dejarlo

Las dos lecturas son defendibles y el repo tiene doctrina para las dos:

- **A favor de truncar**: es la regla MTD-vs-MTD que se aplicó a propósito en
  `PreviousPeriodHelper` y en la comparativa del hero (`f779a7ab`, `c27448dc`) —
  comparar una semana entera contra tres días infla la variación.
- **A favor de la ventana completa**: es lo que el test dice, por su nombre y por
  su aserción, y alguien lo escribió creyéndolo.

Mientras no se decida, el suite entero de `HeroBucketsCalculatorTests` está en rojo
y tapa cualquier regresión NUEVA que aparezca ahí dentro: es el coste real.

## Qué hay que hacer

1. Decidir cuál de las dos semánticas es la correcta para `.thisWeek`.
2. Arreglar el lado que esté mal —el cálculo o la aserción— y dejar escrito el
   porqué junto al otro caso de MTD, que ya está documentado en `CLAUDE.md`
   («Cálculos con fechas»).
3. Revisar si el mismo criterio aplica a los demás períodos con ventana previa.

## Dueño

Sin asignar. Detectado por el `/gate` del 2026-09-02; queda fuera de esa sesión
porque es lógica de fechas y aquella tocaba sólo presentación del Panel.


---

## Resuelto — 2026-09-02

**El código estaba bien. El test era un fósil.** La ventana previa de `.thisWeek` SÍ debe
truncarse al weekday equivalente (WTD-vs-WTD): el actual va de lunes a hoy (parcial) y
`PreviousPeriodHelper` devuelve la semana calendario anterior ENTERA, así que sin truncar se
comparan 3 días contra 7 un miércoles.

### Por qué el ticket planteaba mal la disyuntiva

El ticket presentaba «dos lecturas defendibles». No lo eran: la segunda descansaba en un docstring
**falso**. `HeroBucketsCalculator.periodPreviousInterval` afirmaba que `.thisMonth` era el único
caso asimétrico y que en `.thisWeek` el alineador era no-op. Las dos cosas eran mentira desde
`f6d4101d` (2026-08-17).

Historia medida en git, no supuesta: el test nació en `74ef5203` (2026-07-23) y **entonces era
verdadero** — `.thisWeek` compartía rama con `.last7Days` y su previo sí era una ventana trailing de
igual duración, así que alinear era no-op de verdad y el nombre `returnsFullTrailingWindow`
describía la realidad. `f6d4101d` invirtió las dos cosas en el MISMO commit (semana calendario
como previo + entrada en el gate) y actualizó los tests vecinos, pero no éste. **Rojo desde el
2026-08-17.**

### Lo que decidió el caso

- `YalaTests/DateAlignmentHelperTests.swift:343` es un test **en verde** que exige exactamente 3
  días (lun-mié) para el MISMO helper, período y modo. Dos tests del árbol se contradecían.
- `96bd55fb` (18-ago) lleva la doctrina en el título: «En Esta semana, Distribución e Informe ya no
  comparan lun–hoy contra la semana anterior completa.»
- Toda la app trunca ya: Estadísticas, Distribución, Informe y los chips del propio Panel. Cambiar
  el código habría dejado el hero como la ÚNICA superficie comparando 3 contra 7 — el mismo
  miércoles, en la misma pantalla, el hero diría −57 % y los chips de abajo +0 %.
- Coste para el usuario de la otra lectura: sesgo de −(1 − d/7)·100, o sea −85,7 % cada lunes,
  pintado además de morado («gastaste menos») por ser contexto de gasto.

### Qué se tocó

- **El test**: renombrado a `periodPreviousInterval_thisWeek_truncatesToEquivalentWeekday`, con la
  aserción invertida y una tercera que es la que de verdad guarda la doctrina — **paridad de
  duración** entre la ventana previa y la actual, que no depende del `firstWeekday` de la máquina.
- **Ocho copias de la afirmación caducada**, que eran el vector real: los docstrings de
  `HeroBucketsCalculator` y `DateAlignmentHelper` (×3, incluida una que justificaba un borde con un
  offset negativo **imposible por construcción** — `((weekday - currentWeekday) % 7 + 7) % 7` está
  normalizado a [0,6]), `InsightsCalculator`, seis comentarios de `PanelViewModel`, el comentario
  del test vecino y `qa/coverage-index.json`. Donde había una lista repetida ahora hay un puntero al
  gate, que es la SSOT.
- **`docs/DECISIONS.md`**: la entrada de julio seguía marcada «Activa» afirmando el gate
  `.thisMonth`-only. Se conserva —no se borran decisiones— y se marca superada por una entrada
  nueva `[2026-08-17]` que registra la inversión con dos semanas y media de retraso.

### Punto 3 del ticket: los demás períodos

Barridos los nueve casos de `DetailPeriod`. **Ninguno más compara parcial contra completo sin
truncar, y ninguno trunca cuando no debe.** Dos residuales anotados y NO tocados aquí:

- `HeroBucketsCalculator` pasa modo `.month` a `.lastYear` (debería ser `.year`). Medido: hoy
  idéntico resultado; latente si el gate se ampliara. Documentado en el docstring.
- `.last7Days` abarca 8 días de calendario y `.last30Days` 31. No sesga la comparación (el previo
  hereda la duración), pero el nombre promete un día menos del que cuenta.

### Fuera de alcance, ticket aparte

Encontrado de paso y **verificado**: `PreviousPeriodHelper.swift:112` es la única de las siete ramas
que NO resta 1 segundo al `end`, e `InsightsCalculator` filtra ambos lados con `.contains` sin el
guard de disjunción que sí tiene el hero. Es la **quinta** instancia de la trampa que `CLAUDE.md` da
por replicada en cuatro. Es un bug de comportamiento, no de documentación, y no se mezcla con este
rojo.
