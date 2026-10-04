---
id: list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max
status: done
priority: low
area: "design-system, iphone, adaptativo, records, planning, accessibility"
created: 2026-10-01
updated: 2026-10-04
source: "iphone-landscape-headers-fill-the-short-screen (carril adaptativo), separado en su Paso 0 (D6)"
qa-status: not-replicable
qa-date: 2026-10-04
qa-notes: barrido 2026-10-04 sin device-QA - solo falta el iPad con texto AX5 en una ventana estrechada; el iPhone girado se capturo el 1-oct
---

# Con texto AX5 en el Pro Max girado, la columna de la lista se queda estrecha

**Sale de** [[iphone-landscape-headers-fill-the-short-screen]], que lo traía anotado y lo dejó fuera a propósito: aquel
compacta la cabecera con poco alto; esto es el ancho de la columna de la lista.

## Qué le pasa al usuario

Girado, el Pro Max es ancho regular y Registros y Planificación pintan lista y detalle a la vez. La columna de la lista
mide lo mismo que en un iPad (`DS.Adaptive.listColumn*Width`, el ancho de un SE). Con texto AX5 ahí dentro «Este mes»
se parte en dos líneas y el chip «Presupuestos» se corta. Se puede usar, pero se lee mal.

Evidencia: `qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/despues/promax-ax5__03-planificacion-h.jpg`
y `promax-ax5__04-registros-h.jpg`.

## Por qué no basta lo que hay

`ListDetailOverlayLogic.listYieldsToDetail` aparta la lista **solo con algo abierto en el detalle**. Con «Elige un…» la
lista se queda en su columna estrecha, que es justo el caso de las capturas.

## Qué hacer, si se hace

Decidir si con tamaños de accesibilidad el split da más ancho a la lista (o la deja sola hasta que se abre algo) en
`ListDetailSplit`. Toca a Registros, Planificación y Grupos a la vez, y también al iPad con AX5: es una decisión de
layout del contenedor, no de una pantalla.

## Qué se hizo (2026-10-01)

Con texto de accesibilidad (AX1–AX5):

- **Donde no caben dos columnas que lo lean, la página se pliega a la lista sola**, como en vertical: Registros,
  Planificación y Grupos en el Pro Max girado (832 pt) y en el iPad mini (744 vertical, 853 girado). Lo abierto se
  empuja o sale en hoja, igual que en el iPhone vertical.
- **Donde caben (iPad Pro 13), la columna de lista se ensancha** de 400 a 460 pt, y el umbral para apartarse al abrir
  algo crece con ella. Estadísticas › Registros usa los mismos anchos.
- Con texto de siempre, nada cambia: diff al píxel de 0 en el Pro Max, vertical y girado.

Por qué plegar y no solo ensanchar, medido: en el Pro Max girado el split no pone al lado del detalle una columna que
lea AX5. A 522 y a 582 pt la superpuso sobre «Elige un…», que quedaba medio tapado. La de 446 de siempre sí va al lado,
pero ahí AX5 parte «Este mes».

Prueba: `IPhoneLandscapeUITests#test_accessibilityText_turnedLargeIPhone_planningHeaderStaysReadable` (por UDID en el
Pro Max, y en el iPad Pro 13 como regresión; el mutante sin plegado lo pone en rojo) y `ListDetailOverlayLogicTests`.
Evidencia: `qa/evidencia-adaptativo-20261001/list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max/`.

## Guion de QA (Jürgen)

Queda en `qa` por lo único que no se pudo capturar aquí: el iPad con texto AX5 **en una ventana estrechada** (Split
View o «Apps en ventanas»).

1. En el iPad Pro 13 (simulador o físico): Ajustes › Accesibilidad › Pantalla y tamaño del texto › Texto más grande,
   activa «Tamaños más grandes» y lleva el control al máximo.
2. Abre Yala en Planificación, a pantalla completa y en horizontal. Esperado: lista a la izquierda (más ancha que con
   texto normal) y «Elige un presupuesto…» a la derecha; «Este mes» en una línea.
3. Estrecha la ventana de Yala (Split View con otra app, o arrastrando la esquina con «Apps en ventanas») hasta más o
   menos la mitad. Esperado: la página pasa a la lista sola, sin «Elige un…» al lado ni nada tapado.
4. Toca un presupuesto: se abre encima, con su botón de volver. Vuelve a ensanchar: lista y presupuesto lado a lado.
5. Repite 2-3 en Registros y en Grupos.

## Relacionados

[[iphone-landscape-headers-fill-the-short-screen]] · [[iphone-supports-landscape-orientation]] ·
[[large-text-leftovers-outside-the-main-iphone-screens]]

## Barrido de `qa` · 2026-10-04 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido antes del QA del lunes (encargo `2026-10-04-barrido-qa-antes-del-qa-del-lunes`), con el criterio de #224 y #291. Lo único que no se capturó es el iPad con texto AX5 en una ventana estrechada (Split View): no tiene camino en un iPhone. El iPhone Pro Max girado con texto grande se capturó el 1-oct.
