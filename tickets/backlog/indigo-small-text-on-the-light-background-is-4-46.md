---
id: indigo-small-text-on-the-light-background-is-4-46
status: backlog
priority: very-low
area: "design-system, accesibilidad"
created: 2026-10-25
updated: 2026-10-25
source: "lote 12.3 (card 1c9w), medido al fijar `ThemeTokenContrastTests`"
---

# En el tema Claro, el índigo como texto pequeño sobre el fondo da 4,46:1

`theme.accentText` del tema Claro es `electricIndigo` (#6063F1): 4,61:1 sobre las tarjetas blancas (AA) y **4,46:1**
sobre el fondo #FAFBFF, a una centésima del 4,5. Pasa con el texto pequeño en el color de la app que va directo sobre el
fondo, sin tarjeta (enlaces de pie de sección, «Ver todo» fuera de tarjeta). Lo anota ya
`.claude/rules/swiftui-ds.md`.

Salida barata si se quiere cerrar: un `accentText` de claro un punto más oscuro (p. ej. #5558E8: 5,1:1 sobre el fondo y 5,3 sobre blanco), sin tocar el
relleno de los botones. `ThemeTokenContrastTests.accentText_light_onWhiteCard` pasaría a medir también el fondo.
