---
id: multi-draft-review-sheet-cramped-at-the-largest-text-size
status: done
priority: medium
area: "registro, accesibilidad"
created: 2026-11-03
updated: 2026-11-05
source: "pase de estrés del barrido de QA 2.2, parte C (card del tablero tablero-pase-de-estres-2-2-c-con-el-texto-al-max-48ri)"
---

# Con el texto al máximo, la hoja de varios registros deja la lista en una franja y corta el total y «Guardar»

## En lenguaje de usuario

Al leer un recibo o un audio con varios movimientos, con el texto de accesibilidad al máximo, el aviso ámbar y los dos
botones quedaban fijos abajo y la lista se veía en una franja de ~150 pt: los registros se revisaban de uno en uno. El
total salía «S/2….71» y el botón decía «Guar-dar…».

## Arreglo (2026-11-04)

Solo a tamaños de accesibilidad: el aviso ámbar entra en el scroll, bajo el título; los dos botones van uno encima del
otro a todo lo ancho; el total va encima de «Quitar todos». Lo mismo en la hoja de voz. A tamaño normal, la hoja no
cambia (diff de píxeles en el PR).

## Montaje de QA (iPhone de pruebas, Yala Dev)

1. Ajustes del iPhone › Accesibilidad › Pantalla y tamaño del texto › Texto más grande: activa «Tamaños más grandes» y
   lleva el control al máximo. Deja el modo oscuro puesto (Centro de control › mantén el brillo › Modo oscuro).
2. Abre Yala Dev con datos de verdad (cuentas, algún grupo con deudas y Yala Pro para leer recibos).

## Guion

1. En el Panel toca «+» › Imagen y elige la foto de un recibo con varios movimientos (o graba un audio con dos o más).
2. Con la hoja «Leí N registros» abierta, estírala hacia arriba.
3. El total se lee entero y «Quitar todos» va debajo.
4. Si hay registros sin categoría, el aviso ámbar sale bajo el título y se desplaza con la lista.
5. Abajo, «Otra foto» y «Guardar N · total» van uno encima del otro y ninguna palabra se parte.
6. Desplaza la lista: se ven al menos dos filas a la vez.
7. Desmarca los incompletos y guarda: se guardan los marcados, como siempre.
8. Repite con el texto normal: la hoja se ve como antes (botones lado a lado).

Cerrado en el barrido de QA 2026-11-05: accesibilidad/tamaños, criterio de Jürgen; arreglo del PR #771 fijado por MultiDraftReviewUITests.
