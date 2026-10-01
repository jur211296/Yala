---
id: iphone-landscape-headers-fill-the-short-screen
status: done
priority: low
area: "design-system, iphone, adaptativo, records, statistics"
created: 2026-10-01
updated: 2026-10-01
source: "iphone-supports-landscape-orientation (carril adaptativo, paso 11), capturas del 2026-10-01"
---

# En el iPhone girado, la cabecera de Registros y Estadísticas llena casi toda la pantalla

**Hecho el 2026-10-01.** Con poco alto, la cabecera va en banda: la cifra a la izquierda y período, entradas y salidas
y recuento a la derecha (si no cabe, el período al lado de la cifra; si tampoco, la pila de siempre con menos margen).
Lo decide el alto del contenedor contando sus barras (`DS.Adaptive.shortContainerMaxHeight` = 500), nunca la
orientación. En el SE girado la primera fila de Registros pasa de quedar bajo la barra de pestañas a verse y tocarse;
en el Pro Max asoma 69 pt en vez de 19. El vertical no cambia (diff al píxel). Componente: `SummaryHeaderStack`.
Tests: `IPhoneLandscapeUITests#test_shortHeight_*`, `ShortContainerHeightTests`. Evidencia:
`qa/evidencia-adaptativo-20261001/iphone-landscape-headers-fill-the-short-screen/`. La columna estrecha con AX5 del
Pro Max girado salió a su ticket: [[list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max]].

**Sale del paso 11 del carril adaptativo** ([[iphone-supports-landscape-orientation]]), que abrió la horizontal en
iPhone y no tocó ninguna pantalla.

## Qué le pasa al usuario

Con el iPhone en horizontal la pantalla tiene poco alto (375 pt en un SE, 440 en un Pro Max). Las cabeceras de
**Registros** y de **Estadísticas › Resumen** (período, neto, entradas y salidas, recuento) están pensadas para el
vertical y ocupan casi todo ese alto. La primera fila de la lista queda debajo de la barra de pestañas y hay que
deslizar para ver un solo registro. Nada se pierde ni se corta: se llega deslizando. Con texto AX5, cada pantalla
enseña un solo elemento a la vez.

Evidencia: `qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/despues/*-h.jpg`
(`04-registros`, `02-estadisticas`).

**Con AX5 en el Pro Max girado, además, la columna de la lista se queda estrecha.** A ancho regular el Pro Max pinta lista
y detalle a la vez, y la lista mide lo mismo que en un iPad (el ancho de un SE); con texto AX5 en esa columna «Este
mes» se parte en dos líneas y el chip «Presupuestos» se corta (`promax-ax5__03-planificacion-h.jpg`,
`promax-ax5__04-registros-h.jpg`). Se puede usar, pero pide decidir si con texto de accesibilidad la lista cede el sitio
al detalle (`ListDetailOverlayLogic.listYieldsToDetail` ya lo hace cuando no cabe).

## Qué hacer, si se hace

La regla de layout ya lo prevé para el Panel en iPad: «cabecera más baja en horizontal» (fase 2b). El equivalente aquí
es decidir por el **alto** del contenedor, no por la orientación: con alto compacto, cabecera en una banda o plegada al
desplazar. Decisión de diseño: toca cómo se ve la cabecera, no solo dónde se coloca, así que no entra por la regla del
§6.1 del carril.

## Relacionados

[[iphone-supports-landscape-orientation]] · [[floating-buttons-cover-row-amounts-on-ipad-landscape]] (el «+» flotante
también tapa el importe en el iPhone girado).
