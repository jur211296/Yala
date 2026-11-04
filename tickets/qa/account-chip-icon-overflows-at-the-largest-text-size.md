---
id: account-chip-icon-overflows-at-the-largest-text-size
status: qa
priority: low
area: "panel, accesibilidad"
created: 2026-11-03
updated: 2026-11-04
source: "pase de estrés del barrido de QA 2.2 (encargo 2026-11-03-barrido-qa-2-2-b)"
---

# El chip de una cuenta en «Tus finanzas» saca el icono de su cápsula con el texto más grande

## En lenguaje de usuario

Con el texto de accesibilidad al máximo, el primer chip de «Tus finanzas» en el Panel pinta el icono de la cuenta
fuera de la cápsula, a la izquierda, y montado sobre el principio del nombre («Ahorros USD»). Se lee, pero se ve roto.

## Lo medido (2026-11-03)

- iPhone 17e y iPhone 17 Pro Max, iOS 27.2, AX5, modo oscuro, Yala Dev sobre `origin/2.2` en `8625a7edd`, semilla
  `realista`. Capturas: `~/Claude/worktrees/_capturas/barrido-qa-2-2-b/estres-17-pro-max/1-panel-realista.png` y
  `~/Claude/worktrees/_capturas/barrido-qa-2-2-b/estres-17e/1-panel-realista.png`.
- No medido: si pasa ya en 2.2 (5) o lo trajo el chip «Grupos» de #758 (`PanelAccountChipsRow.swift`). Primer paso:
  la misma captura con el build de `1a78abf51`.

## Hecho cuando

Con AX5 en el iPhone más pequeño y el más grande, el icono queda dentro de su chip y no tapa el nombre; captura del antes
y el después.

## Arreglo (2026-11-04)

El cuadrito del icono del chip crece con el texto, con techo de 40 pt, y el glifo deja de crecer en AX1: a AX5 el
icono queda dentro de la cápsula. A tamaño normal el cuadrito mide los 24 pt de siempre. El chip «Agregar» lleva el
mismo cuadrito para que los dos midan igual. Capturas del antes y el después en el PR (17e, 17 Pro Max e iPad).

## Montaje de QA (iPhone de pruebas, Yala Dev)

1. Ajustes del iPhone › Accesibilidad › Pantalla y tamaño del texto › Texto más grande: activa «Tamaños más grandes» y
   lleva el control al máximo. Deja el modo oscuro puesto (Centro de control › mantén el brillo › Modo oscuro).
2. Abre Yala Dev con datos de verdad (cuentas, algún grupo con deudas y Yala Pro para leer recibos).

## Guion

1. En el Panel, baja hasta «Tus finanzas» con la sección plegada (la flecha apunta hacia abajo).
2. Mira el primer chip de cuenta: el icono tiene que verse **dentro** de la cápsula, a la izquierda del nombre, sin taparlo.
3. Desliza la fila de chips hasta «Agregar»: su «+» va en el mismo cuadrito y la cápsula mide lo mismo de alto.
4. Pon el modo claro y repite el paso 2.
5. Vuelve el texto al tamaño normal: los chips se ven como antes.
