---
id: 2026-11-24-cifra-del-hero-pequena-con-texto-de-accesibilidad
status: backlog
priority: low
area: "statistics, records, planning, a11y"
created: 2026-11-24
updated: 2026-11-24
source: "Pase de estrés del barrido de QA de la 2.3 antes de la build 8 (iPhone 14 e iPad Pro 13)"
---

# Con texto de accesibilidad, la cifra grande sale más pequeña que sus líneas de debajo

## Qué se vio

Con el texto al máximo (AX5), en Estadísticas (las cuatro pestañas), Registros y Pagos planificados («Te falta pagar»)
la cifra grande del hero queda más pequeña que el ingreso y el gasto de debajo, que sí crecen. La jerarquía se invierte:
lo principal se lee menos que lo secundario. En el Panel la cifra crece con el texto (`HeroMonthView.figureFont`).

Capturas: `~/Claude/entregas/2026-11-24-barrido-qa-2-3-antes-build-8/evidencia/iphone14/09-estadisticas-ax5-cifra-pequena.png`
e `ipad/ax5-statistics.png`, `ipad/ax5-records.png`, `ipad/ax5-scheduledPayments.png`.

## Pista (sin medir)

`StatsHeroView` pinta la cifra con `DS.Typography.panelHeroAmount`, un tamaño fijo, y el Panel lo escala a mano con
techo a tamaños de accesibilidad. Medir si es el token fijo o el reparto de `HeroClaroRows` lo que la encoge.

## Hecho cuando

A AX5 en el iPhone SE y el iPad, la cifra del hero de Estadísticas, Registros y Pagos planificados es la más grande de
su bloque, como en el Panel, sin cortarse.
