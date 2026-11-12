---
id: white-text-on-the-rosa-teal-and-minimal-accents-is-below-aa
status: done
priority: low
area: "design-system, accesibilidad, temas"
created: 2026-10-17
updated: 2026-10-25
source: "pulido del 2026-10-17 (acento de marca a AA), hallazgo fuera de alcance"
---

# En los temas Rosa, Teal y Minimalista el texto blanco de los botones no llega a AA

## El problema, en lenguaje de usuario

Los botones rellenos con el color del tema (`YalaPrimaryButton`, «Nuevo registro» del Panel, «Aplicar» de Filtros)
llevan texto blanco en todos los temas. En los tres temas PRO con otro acento se lee mal:

| Tema | Acento | Blanco encima |
|---|---|---|
| Rosa | `#FF0080` (`hotPink`) | 3,77:1 |
| Teal | `#00C2CB` (`priorityNeed`) | 2,19:1 |
| Minimalista | gris 75 % (`#BFBFBF`) | 1,84:1 |

AA pide 4,5:1 (3:1 para texto grande). El 17-oct se arregló el índigo de marca (`#6063F1`, 4,61:1), que cubre Claro,
Oscuro, Índigo, Traslúcido y Liquid Glass; estos tres quedaron fuera porque cambiarlos es cambiar la identidad de cada
tema.

## Opciones

1. **(Recomendada)** Que el texto sobre el acento lo decida el tema (un `onAccent`): blanco en los índigo, negro en Teal
   y Minimalista (negro sobre `#00C2CB` da 9,6:1 y sobre `#BFBFBF` 11,4:1), y para Rosa un relleno más profundo
   (`emphasisPinkFill`, `#D6006B`, 5,2:1 con blanco) o texto negro (5,6:1).
2. Oscurecer el acento de cada tema hasta que el blanco pase: Teal y Minimalista cambiarían mucho de aspecto.
3. Dejarlo.

## Hecha cuando

Hay decisión y, si es la 1, el texto de los botones rellenos mide ≥ 4,5:1 en los ocho temas.

Hecho en el lote 12.3 (2026-10-25), opción 1: token `YalaTheme.onAccent` (blanco en los índigo; negro en Teal, Rosa y Minimalista) en todos los rellenos de acento con texto, incluidos el ✓ de las hojas y los «+» flotantes (`theme.onFill`). ≥ 4,5:1 en los diez temas (`ThemeTokenContrastTests`): Teal 9,6 · Minimalista 11,4 · Rosa 5,6 · índigo 4,6. Rosa con texto negro y no con relleno más profundo, para no cambiar el color del tema.
