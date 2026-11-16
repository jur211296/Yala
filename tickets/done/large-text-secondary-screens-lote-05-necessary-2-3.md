---
id: large-text-secondary-screens-lote-05-necessary-2-3
status: done
priority: medium
area: "a11y, estadisticas, reportes, bandeja, ajustes"
created: 2026-11-10
updated: 2026-11-10
source: lote 05 de la consolidación de mejoras necesarias 2.3 (docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md), card tablero-mejoras-necesarias-2-3-texto-grande-en-e-zoid
---
# Texto grande en Estadísticas, Reportes, Bandeja, Ajustes y Etiquetas

Con el texto en los tamaños de accesibilidad (medido en AX3, iPhone 17 Pro), cinco pantallas secundarias cortaban
importes o partían palabras por sílabas porque la fila no les dejaba sitio. Ninguno estaba arreglado en 2.2
(`git log origin/2.3..origin/2.2` sin cambios en esas vistas el 2026-11-10) ni en el ticket
[[large-text-leftovers-outside-the-main-iphone-screens]], que no nombra estas vistas.

Todo cambia **solo a tamaños de accesibilidad**: a tamaño normal cada fila es la de siempre (diff de capturas al píxel).
No se eligió ninguna alternativa de rediseño de las revisiones (filas D1 de Estadísticas, iconos G1 de Ajustes).

1. **Estadísticas › Distribución** (zona 35, P3): el importe baja bajo el nombre (`AdaptiveRowStack`) en las filas de
   categoría y subcategoría; antes «S/2,3….00» y «Ali-menta-ción». La fila de chips desplaza el chip elegido hasta
   verse entero («Distribució» salía cortado).
2. **Reportes** (zona 36, P5): la fila de la Comparativa se apila (nombre a lo ancho; cifra, cambio y período anterior
   debajo) y «Te quedó» pone la cifra bajo el título; antes el nombre desaparecía y la cifra se cortaba. El mes del flujo
   de caja pone título, estado y «Llevas el…» uno debajo del otro («No-viem-bre»).
3. **Bandeja** (zona 38, P7): «Editar» de la selección baja bajo el contador, a todo lo ancho («Edi-tar»); la fila de
   «¿Ya lo apuntaste?» baja el importe («S/ 120.0 0»); los botones del borrador del chat van uno debajo del otro
   («Gua rdar»).
4. **Ajustes** (zona 40, P7): el icono de cada fila va encima del título («Personaliza-ción»). El icono se queda: si
   sobra a esos tamaños es la decisión G1 de la revisión, que sigue abierta.
5. **Etiquetas y Cuentas** (zona 39, P8 · H2): la lista mide su contenido (`contentSizedListHeight`) en vez de filas ×
   alto fijo; la última fila quedaba cortada.

Tests: `LargeTextSecondaryScreensUITests` (un caso por punto, rojo en la base y verde con el arreglo) y
`LargeTextSecondaryScreensWiringTests` (lo que el árbol de accesibilidad no expone).
