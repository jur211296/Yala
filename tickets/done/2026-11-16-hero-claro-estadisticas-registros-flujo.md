---
id: 2026-11-16-hero-claro-estadisticas-registros-flujo
status: done
priority: medium
area: "statistics, records, cash-flow, panel"
created: 2026-11-16
updated: 2026-11-16
source: "encargo de Jürgen del 16-nov (17:20 y 18:02 Lima, con capturas)"
---

# El hero claro del Panel, en Estadísticas, Registros y Flujo de caja

## Qué pidió Jürgen

«El nuevo hero con textos claros y la ayuda, y quitar el hueco antes del valor están perfecto en el panel, pero no lo
hemos llevado a las vistas de estadísticas, registros, flujo de caja.» Y en el análisis de una cuenta, «Tus gastos más
grandes» y «Últimos registros» dentro de una tarjeta como la del Panel.

## Qué cambió para quien usa Yala

- Resumen, Tendencias, Distribución y Registros (la pestaña y la página): la cifra va pegada al rótulo, sin el hueco de
  ~40 pt; el rótulo lleva un «?» que abre una hoja con qué es la cifra, cómo se calcula, qué no cuenta y un ejemplo con
  números; Ingresos y Gastos aparecen rotulados en chico encima de sus montos.
- Flujo de caja: «Al 30 de noviembre tendrías» (o lo que queda del mes) con su «?» y la cifra pegada.
- Análisis de cuenta: las dos listas en la tarjeta de «Últimos registros» del Panel.
- Textos nuevos en los 16 idiomas.

## Cómo se verificó

- `HeroClaroLogicTests` (lógica, cableado y los 16 idiomas), `YalaTests` entero y los XCUITest de las áreas tocadas.
- Capturas antes/después en el iPhone 17 Pro (claro y oscuro), iPhone SE, iPad Pro 13 y con el iPhone girado:
  https://claude.ai/artifact/M2t2Zx4SSQaQQ5nWAboFBd

## Fuera

- La incoherencia entre el hero y el texto de IA de la captura no es de cálculo: ticket
  `stats-ai-summary-shows-figures-from-before-the-latest-records`.
- El Flujo de caja no recibe la fila de acciones (Nuevo registro, Voz, Foto, Yala IA): es una función nueva, no claridad.
