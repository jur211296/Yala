---
id: account-card-reports-cashflow-carousel-uitest-is-flaky
status: backlog
priority: low
area: tests, reportes
created: 2026-10-20
updated: 2026-10-21
source: gate de la revisión de Yala IA 2.2
---

# `test_cashFlow_byCard_hidesTheLinePage_andByLineShowsIt` falla a veces al deslizar el carrusel

## Lo medido (2026-10-20, iPhone 17 Pro, iOS 27.0)

`AccountCardReportsUITests.test_cashFlow_byCard_hidesTheLinePage_andByLineShowsIt` falló 2 de 7 veces sobre el árbol de
la revisión de Yala IA (que no toca reportes ni el flujo de caja) y pasó 5 de 5 sobre `origin/2.2`. Los dos rojos
fueron los primeros, justo después de la tanda de XCUITest del gate, y en aserciones distintas: «Por tarjeta no tiene
página para la tarjeta» (`:138`) y «Por línea no tiene página para la línea en dólares» (`:144`). Las tres corridas
siguientes del mismo árbol, verdes. Inferido: `carouselShows` desliza con `press(forDuration: 0.05, thenDragTo:)` cinco
veces y mira `isHittable`; con el simulador cargado el gesto no siempre pasa de página.

## Qué hay que hacer

Que el helper espere a que el carrusel se asiente entre deslizamientos (o busque la página por su id), y medirlo con
N corridas seguidas tras una tanda.

## Otra vez (2026-10-21, gate del lote decidido 2.2 · 10)

Mismo árbol (sí toca flujo de caja y reportes): verde en la tanda de 25 suites del gate y en una corrida suelta, rojo en
la corrida que siguió a la unit completa (`:146`, «Por línea no tiene página para la línea en dólares»), y 3/3 verde
justo después, aislado. Centinela a 0 en la roja: no hubo otra corrida encima. Sigue el patrón de arriba.
