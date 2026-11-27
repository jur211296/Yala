---
id: 2026-11-26-eficiencia-5-render-del-scroll
status: done
priority: medium
area: "performance, panel, registros, design system"
created: 2026-11-26
updated: 2026-11-26
source: "pedido de Jürgen del 26-nov-2026, 10:44 Lima («encola los 6 lotes de mejoras de eficiencia de la sesión del calor»), lote 5 del informe docs/qa/rendimiento-iphone14-2026-11-26/"
---

# Scroll más liviano: cristal, sombras y recortes del Panel y de Registros

Al desplazar el Panel o Registros, el sistema hacía de 33 a 68 pasadas fuera de pantalla por fotograma (mediana en el
iPhone 14, hasta 115): cada sombra de vista y cada pieza de cristal suelta se recalculaba en cada fotograma.

## Hecho cuando

- Medido por pieza en el iPhone 14 cuántas pasadas añade cada sombra, recorte y cristal del Panel y de Registros.
- Lo que pesa, cambiado sin que se vea distinto; lo que no pesa, sin tocar.
- Capturas antes/después en claro y oscuro, iPhone 14, de cada pantalla tocada.
- Medido antes y después con la pasada D del informe.

## Resolución (2026-11-26)

- **Fila de lista** (`ListRowCardModifier`): fondo y sombra dibujados con la forma, sin recortar el contenido ni sombra de
  vista. Mismos valores (`DS.ListRow`).
- **Píldoras de acción rápida** (`PanelQuickActionsRow`): la sombra pequeña del DS pasa del botón al relleno de la cápsula.
- **Botones flotantes** (`FABStackView`): los dos círculos de cristal en un `GlassEffectContainer(spacing: DS.Spacing.xs)`.
- Medido (pasada D, 16 k, 3 rondas): mediana de pasadas por fotograma **37 → 24** (máximo 115 → 66); Registros 68 → 19,
  Panel 33 → 23, Tendencias 58 → 34, Distribución 55 → 34. Tirones de render 0,22 → 0,31/s (ruido: 1-2 por pantalla);
  el total, 1,48 → 1,26/s, es casi todo hilo principal. Informe:
  `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-5-render-del-scroll/README.md`.
- Atribución con interruptores temporales (retirados): tarjetas sólidas sin recorte, contenedores de cristal en cabeceras,
  chips y barra de filtros, y la sombra de las burbujas de las tartas no movían nada; se revirtieron. Los efectos no se
  suman: el cristal encima multiplica lo que cuestan las sombras de debajo.
- Capturas al píxel en Liquid Glass, claro y oscuro: iguales (≤ 0,006 % de píxeles).
- Pin: `YalaTests/EficienciaRenderScroll/RenderScrollCableadoTests`.

## Lo que queda

- Objetivo «mediana < 20» cumplido en Registros y Resumen, no en el conjunto (24). El suelo de Panel, Tendencias,
  Distribución y Pagos (~23-34) no sale de las piezas medidas; candidatos sin medir: barras del sistema y gráficas.
- Objetivo «< 0,5 tirones/s»: los de render ya lo cumplen; el total depende del hilo principal (otros lotes).
