---
id: 2026-11-19-contraste-modo-claro-botones-blancos
status: done
priority: medium
area: "themes, design-system"
created: 2026-11-19
updated: 2026-11-19
source: "Jürgen, 19-nov 12:51, con capturas de Nuevo registro y Yala IA en su iPhone"
---

# Modo claro: los campos y botones blancos no se distinguían del fondo

En el tema claro, los chips de atajos, «Hoy», las sugerencias de categoría, «Categoría», «Etiquetas», la divisa, la
caja «Escribe tu pregunta…», el «+» y los botones redondos casi no se separaban del fondo de la hoja (`#FAFBFF` contra
blanco: 1,03:1). No se veía el contorno, así que no se sabía qué era un botón. Referencia que le gustó: «Send money»
(fondo gris claro, superficies blancas bien definidas).

## Hecho cuando

El fondo claro es un gris neutro, lo blanco se despega con un contorno visible, el oscuro y los temas Pro no cambian y
el texto de color sigue en AA. Verificado en Nuevo registro (con y sin teclado), Yala IA y un barrido de Panel,
Registros, Presupuestos, Pagos, Flujo de caja y Ajustes.

## Resolución (2026-11-19)

En los tokens, no pantalla por pantalla:

- `YalaTheme.light.background`: gris `#F4F4F6` (`#EAEAEE` con «Aumentar contraste»). Elegido entre cuatro variantes
  en el simulador (solo gris · gris + borde · gris + borde + sombra · gris más oscuro `#F2F2F7`); `#F2F2F7` dejaba el
  verde de «te deben» en 4,49:1.
- `.thCard` pasa a ser `ThemeSurface`: en el claro trae dentro del relleno un borde finísimo (sombra de 0,5 pt) y una
  sombra suave (`YalaTheme.surfaceEdge`); en los oscuros, `nil`. Todo lo que se rellena con `.thCard` lo hereda.
- `cardBorder` del claro, del 5 % al 8 % (22 % con «Aumentar contraste»).
- `accentText` del claro, `#5B5EE4` (el índigo de marca un 5 % más oscuro): sobre el gris bajaba a 4,20:1.
- El degradado de las pantallas completas arranca en el mismo gris; abajo sigue el tinte índigo.
- Fuera de `Theme/`, lo mínimo para heredar: `SelectionChip` sin elegir usa `.thCard` en vez del color crudo, y las
  cajas de texto de Yala IA y del chat de Grupos llevan el fondo en la forma (`clipShape` se comía el contorno).

Pin: `YalaTests/ContrasteModoClaro/ContrasteModoClaroTests` (9 casos). La convención («un `.thCard` recortado pierde el
contorno») está en `.claude/rules/swiftui-ds.md`.
