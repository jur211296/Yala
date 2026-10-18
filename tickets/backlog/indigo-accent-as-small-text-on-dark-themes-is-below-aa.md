---
id: indigo-accent-as-small-text-on-dark-themes-is-below-aa
status: backlog
priority: low
area: "design-system, accesibilidad"
created: 2026-10-17
updated: 2026-10-17
source: "pulido del 2026-10-17 (acento de marca a AA), conflicto medido fuera de alcance"
---

# El índigo de marca como texto pequeño no llega a AA sobre los temas oscuros

## El problema, en lenguaje de usuario

Los enlaces y textos pequeños pintados con el color de la app («Política de Privacidad» bajo Ajustes › Privacidad de
la IA, «Ver todo», chips seleccionados) se leen peor en los temas oscuros que en el claro. AA pide 4,5:1 para texto
normal y 3:1 para texto grande e iconos.

## Medido (2026-10-17, acento `#6063F1`)

| Superficie | Contraste | Con el acento anterior `#6366F1` |
|---|---|---|
| Negro puro (tema Oscuro) | 4,55 | 4,70 |
| Fondo de Liquid Glass `#060612` | 4,37 | 4,51 |
| Fondo de Traslúcido `#0A0A1A` | 4,25 | 4,39 |
| Tarjeta de Liquid Glass (blanco 4 % sobre el fondo) | 4,09 | 4,23 |
| Tarjeta del tema Oscuro `#1C1C1E` | 3,69 | 3,81 |
| Tarjeta del tema Índigo `#1E293B` | 3,17 | 3,27 |

El 17-oct Jürgen decidió oscurecer el acento para que el texto BLANCO encima de los botones pase AA (4,61:1). Con un
solo color no se pueden cumplir las dos cosas: el blanco encima pide luminancia ≤ 0,183 y el texto sobre `#060612`
pide ≥ 0,184. El único uso que cruzó la línea con el cambio es el texto pequeño directamente sobre el fondo de Liquid
Glass y de Traslúcido; sobre tarjetas oscuras ya estaba por debajo.

## Opciones

1. **(Recomendada)** Un token de texto índigo para los temas oscuros, más claro (p. ej. `#818CF8`, el que ya usa la
   web para lo mismo), y usarlo en enlaces y texto pequeño sobre acento; el relleno de botones sigue con el acento.
2. Dejarlo: iconos, gráficas y texto grande pasan (≥ 3:1) en todas las superficies.

## Hecha cuando

Hay decisión y, si es la 1, el texto pequeño índigo mide ≥ 4,5:1 sobre las superficies de la tabla.
