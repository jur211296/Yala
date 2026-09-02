---
id: rojo-heroBuckets-thisWeek-trailing-window
status: backlog
area: panel
created: 2026-09-02
updated: 2026-09-02
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
