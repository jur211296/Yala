---
id: 2026-11-23-reportes-rebote-encabezado-comparativa-flujo
status: qa
priority: high
area: "reportes, comparativa, flujo-de-caja"
created: 2026-11-23
updated: 2026-11-24
source: "pruebas de Yala 2.3 de Jürgen en el iPhone (23-nov), vídeo 2026-11-23-rebote-comparativa-flujo-caja.mp4"
qa-status: needs-testing
qa-notes: el bucle no sale en el simulador; falta el gesto del video en el iPhone
---

# Reportes: la parte de arriba rebota al quedarse en el umbral del título

En Reportes financieros, en Comparativa y en Flujo de caja, al plegar el título y volver a bajar despacio hasta el punto
donde el título grande se despliega, el título, la barra «Comparativa / Flujo de caja» y la lista saltaban juntos arriba
y abajo hasta empujar fuera de ese punto.

## Causa

La barra de chips colgaba de la pantalla con `.safeAreaBar(edge: .top)`, justo bajo la barra de navegación. Esa barra mide
52 pt más con el título grande, así que los chips cambiaban de sitio con cada cambio de título, y con ellos el área
segura del scroll, que es lo que UIKit mira para decidir si el título va grande o compacto. En el umbral, cada cambio
provocaba el contrario. Medido en el vídeo, fotograma a fotograma: el chip elegido iba de 127 a 179 pt y vuelta (24
vaivenes, ~1 s en cada posición, sin posiciones intermedias).

## Resolución (2026-11-24)

- La barra pasa a ser una cabecera fija DENTRO del scroll de cada pestaña (`ReportChipsHeaderStack`, en
  `FinancialReportView.swift`): Comparativa, vacío del Flujo de caja, armado del plan (`CashFlowSetupView`) y tabla del
  plan (`CashFlowTableView`). El título se pliega como en el Panel y la barra ya no toca el área segura.
- Fija, la cabecera lleva debajo el mismo tramo del fondo de la pantalla (sobre el del sistema): las filas que pasan por
  detrás o por encima de los chips no se leen (lo que pedía el S2 del 18-nov). En reposo no se ve.
- Pruebas: `YalaTests/ReportesReboteEncabezado/ReportesReboteEncabezadoTests` (cableado) y el conductor manual
  `FlujoFluidezMedicionUITests.test_reboteUmbral`.
- Regla en `.claude/rules/swiftui-ds.md`.

## Verificado

- Simulador (iPhone 17 Pro, iOS 27.2), Comparativa y Flujo de caja, claro y oscuro: aspecto en reposo igual que antes;
  desplazado, los chips quedan fijos bajo el título compacto y nada se lee detrás. En el arrastre lento hacia abajo el
  chip sigue al contenido de forma continua (127 → 179 pt), sin saltos.
- El bucle NO se pudo reproducir en el simulador ni antes del arreglo (XCUITest y Device MCP: el toque sintético no
  tiembla). El iPhone 14 no estaba conectado esa noche.

## Guion de device-QA (iPhone, el mismo gesto del vídeo)

1. Instala el build de `2.3` que lleve este cambio y abre **Más › Comparativa**. Elige **Mes pasado**.
2. Desliza hacia arriba hasta que «Reportes financieros» quede pequeño en la barra.
3. Vuelve a bajar muy despacio y detén el dedo justo donde el título empieza a crecer. Mantenlo 3-4 s, muévelo un poco
   arriba y abajo sin soltar, y suelta.
   - Esperado: el título y los chips se mueven con el dedo y se quedan quietos al pararlo; nada rebota solo.
4. Baja hasta el final y sube de golpe hasta arriba del todo (el gesto del 20-nov).
   - Esperado: un solo movimiento; la barra de abajo no se encoge y despliega sola.
5. Desplaza la tabla: los chips quedan fijos bajo el título pequeño y ninguna fila se lee detrás ni por encima de ellos.
6. Toca **Flujo de caja** y repite 2-5 sobre el mes.
7. Repite 3 en tema claro (Ajustes › Temas › Claro).
