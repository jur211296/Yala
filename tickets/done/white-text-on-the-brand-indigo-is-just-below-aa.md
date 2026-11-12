---
id: white-text-on-the-brand-indigo-is-just-below-aa
status: done
priority: low
area: "design-system, accesibilidad"
created: 2026-10-17
updated: 2026-10-17
source: "pulido del 2026-10-17 (botones púrpura con texto oscuro), medición fuera de alcance"
---

# El texto blanco sobre el índigo de marca se queda a 0,03 del contraste AA

## El problema, en lenguaje de usuario

Los botones rellenos con el color de la app y texto blanco —«Nuevo registro» del Panel, «Aplicar» de Filtros y unos
40 sitios más que pintan con `theme.accent`— miden **4,47:1** (#6366F1 con blanco). AA pide 4,5:1 para texto normal y
3:1 para texto grande. Los botones de 17 pt en negrita pasan como texto grande; los de 15 pt medio («Nuevo registro»)
se quedan 0,03 por debajo.

No se ve: el 17-oct se cambió solo el botón que salía con texto **negro** (el «Activar» del aviso de IA, que pinta el
sistema; ver la regla de la alerta en `.claude/rules/swiftui-ds.md`).

## Por qué no se arregló en el sitio

Pasarlo a AA es oscurecer el acento de marca. Medido: no hay ningún índigo del mismo tono que dé a la vez blanco AA
encima (luminancia ≤ 0,183) y AA como texto sobre negro en modo oscuro (≥ 0,175 sobre #000, y ya hoy no llega sobre
las tarjetas oscuras: 3,8:1). Es una decisión de marca, no un arreglo de una pantalla.

## Opciones

1. **(Recomendada)** Un token de relleno para botones (`#585BEC`, 5,09:1 con blanco, casi idéntico a la vista) y usarlo
   en los botones rellenos con texto, sin tocar el acento de texto, iconos ni gráficas. Ya existe como
   `Color.alertActionIndigo` para la alerta.
2. Oscurecer el acento entero: arregla los botones y empeora el acento como texto en oscuro.
3. Dejarlo: pasa AA como texto grande en la mayoría.

## Hecha cuando

Hay decisión y, si es la 1, los botones rellenos con texto blanco miden ≥ 4,5:1.

## Resolución (2026-10-17)

**Decisión de Jürgen (17-oct 16:17):** «Oscurece un poco el acento de marca para que pase AA» (opción 2, en el token).

- `electricIndigo` pasa de `#6366F1` a **`#6063F1`**: mismo tono y saturación, solo menos luminosidad (ΔE 2,2, no se
  distingue). Blanco encima: **4,61:1** en los cinco temas índigo (Claro, Oscuro, Índigo, Traslúcido, Liquid Glass).
- Mismo hex en sus copias: `AccentColor` (claro; el oscuro sigue en `#585BEC`), `LaunchBackground`,
  `WidgetColors.primary` y el color «disponible» del Sankey. La alerta en claro sigue con texto negro: 4,55:1.
- Como texto: sobre la tarjeta blanca pasa a AA (4,61); sobre negro sigue AA (4,55). Sobre los fondos de Liquid Glass y
  Traslúcido baja de 4,51/4,39 a 4,37/4,25 — conflicto matemático con el blanco encima, en
  `indigo-accent-as-small-text-on-dark-themes-is-below-aa`.
- Rosa, Teal y Minimalista tienen otro acento: `white-text-on-the-rosa-teal-and-minimal-accents-is-below-aa`.
- Los `#6366F1` que son datos (color por defecto de cuentas y categorías, paletas, seeds) no se tocan.
- Test: `BrandAccentContrastTests` (contraste por tema resuelto y paridad de las copias).
