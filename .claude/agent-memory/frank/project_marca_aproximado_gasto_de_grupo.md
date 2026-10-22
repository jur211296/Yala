---
name: marca-aproximado-gasto-de-grupo
description: PR #113 cerró la familia del «≈» — el gasto de grupo ya lleva la incertidumbre de todas sus patas; falta device-QA y NO es simulable; deja 3 tickets, uno de ellos una pantalla entera sin marca
metadata:
  type: project
---

**El tercer medium de la cola (2026-09-09, PR #113) cierra la familia de la marca «≈».** Un gasto
compartido que adelantas y te devuelven en parte ya no se presenta como exacto cuando no lo es.

**Why:** el importe que ven las estadísticas es una **síntesis** —`pata real + Σ patas de préstamo`—
y las de préstamo están suprimidas del recorrido, así que su marca no la leía nadie. Con el umbral
del 8-sep eso pasó de perder una marca a **desplazar el cociente del bucket entero**.

**How to apply:**

- **Lo que falta es device-QA y NO es simulable**: hace falta una cuenta en divisa distinta de la
  preferida (la conversión identidad es `.exact` por construcción) más dos patas selladas con
  coberturas de tasas distintas. Espera a `qa-no-puede-crear-cuenta-en-otra-divisa` (**high**):
  medido el 9-sep, **cinco** tickets esperan ese montaje y **tres** están parados por él.
- **Deja tres tickets**, y el primero es el que más pesa: `financial-report-amounts-unmarked` — la
  pantalla de **Informes pinta 22 importes y ninguno puede llevar la marca**, y es justo donde el
  usuario va a buscar el detalle del número que salió marcado. Los otros dos:
  `widget-fallback-summary-uses-ten-rows` (el widget recalcula el total del mes sobre diez filas si
  le falta el resumen precalculado) y `bridge-synthesis-trusts-a-zero-converted-amount`.
- **El escenario es alcanzable en producción y conviene saber por dónde**, porque las dos patas
  nacen con el mismo flag: la real puede llegar **días más tarde** (el sync remoto sin cuenta local
  deja un draft y la pata de préstamo se crea igual), el reparador de tasas trabaja por cola y puede
  curar una sola, y editar la pata real la reconvierte con la escalera de hoy.
- **Lo que NO se toca**: el saldo histórico del widget y la fila cruda de `WidgetTransaction` leen el
  flag de la fila a propósito, porque su importe tampoco lleva ajuste. Hay un test que lo fija; si
  una review lo levanta como incoherencia, la respuesta está ahí.

Relacionado: [[el-denominador-de-una-resta-es-el-numero-que-se-ve]] (el numerador es su gemelo y lo
incumplí aquí), [[review-adversarial-caza-lo-mio]].
