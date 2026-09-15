---
name: reference-skills-pulido-ui
description: Dos skills globales de pulido de UI (better-ui, emil-design-eng) instaladas el 2026-09-15; son de web, pero sus reglas de radio, pulsación y cuándo animar valen en SwiftUI
metadata:
  type: reference
---

Desde el 2026-09-15 hay dos skills globales que Jürgen mandó: **`better-ui`** y
**`emil-design-eng`**. Están escritas para web (CSS, Motion), así que sus recetas no se copian;
sus **reglas** sí valen en SwiftUI:

- Radio concéntrico: el radio exterior es el interior más el padding. Es lo que más delata una
  tarjeta anidada mal hecha.
- Alineación óptica sobre geométrica en botones con icono.
- Sombra para profundidad, borde solo para estructura o estado.
- Pulsación: escala 0,96, nunca menos de 0,95.
- Cuándo animar, por frecuencia: lo que se usa cien veces al día no se anima; lo raro (onboarding,
  celebración) puede tener detalle. Entradas y salidas con ease-out; movimiento con ease-in-out.
- Los iconos entran con opacidad, escala y blur, no apareciendo de golpe.

**How to apply:** en los tickets de rediseño abiertos el 15-sep (ajustes, chat de Yala IA) y en
la bienvenida, contrastar la propuesta contra estas reglas antes de enseñarla. Ver
[[reference-ui-flujo-por-pasos]] y [[reference-ui-onboarding-login]].
