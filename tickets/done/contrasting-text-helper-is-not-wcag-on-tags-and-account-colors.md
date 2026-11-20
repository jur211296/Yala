---
id: contrasting-text-helper-is-not-wcag-on-tags-and-account-colors
status: done
priority: low
area: "design-system, accesibilidad"
created: 2026-10-25
updated: 2026-11-19
source: "lote 12.3 (cards lbcr y 1c9w), visto al barrer el texto sobre el acento"
---

# El texto sobre etiquetas y cuentas de colores elige blanco o negro con una fórmula que no es la de WCAG

## Qué le pasa al usuario

Las etiquetas de color (filas de Registros, Bandeja, favoritos, detalle) y las tarjetas de cuenta rellenas con su color
eligen el texto con `Color.contrastingText(for:)`. Con colores medios sale blanco donde el negro se leería mejor: con el
turquesa de marca (#00C2CB) daba blanco a 2,19:1; con un naranja (#F97316) también sale blanco (2,8:1, negro 7,5:1).

## Por qué pasa

`contrastingText` mide la luminancia con la fórmula de vídeo (0,299 R + 0,587 G + 0,114 B, sin linealizar) y corta en
0,6. WCAG linealiza y compara contra los dos candidatos; para los colores medios saturados las dos dan resultados
distintos.

## Qué se hizo ya y qué falta

El lote 12.3 sacó de esa fórmula todo lo que va sobre el acento del tema (`theme.onAccent` / `theme.onFill`). Siguen
con ella las etiquetas, las cuentas (`AccountCardView`, `PanelAccountChipsRow`, `AccountDetailSheet`) y los rellenos de
otros colores. No se cambió porque toca el aspecto de etiquetas y tarjetas que el usuario coloreó.

## Hecha cuando

`contrastingText` elige por el contraste WCAG de los dos candidatos (blanco y negro) y un test lo fija con colores medios;
o Jürgen decide dejarlo así.

## Cerrado (2026-11-19, lote de temas)

`contrastingText` mide con WCAG 2.x: **blanco si llega a AA (4,5) o si queda a menos de medio punto del negro; si no,
negro.** El medio punto es un empate práctico medido en el Panel: el índigo por defecto de las cuentas (#6366F1) da 4,47
con blanco y 4,70 con negro, y con la regla estricta casi todas las cuentas pasaban a glifo negro. Pasa a negro donde el
blanco fallaba de verdad: turquesa (2,19 → 9,58), naranja (2,8 → 7,49), verde, azul, rosa vivo, violeta. Lo fija
`YalaTests/TemasRepintadoYContraste/ContrastingTextWCAGTests`.
