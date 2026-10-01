---
id: iphone-landscape-headers-fill-the-short-screen
status: backlog
priority: low
area: "design-system, iphone, adaptativo, records, statistics"
created: 2026-10-01
source: "iphone-supports-landscape-orientation (carril adaptativo, paso 11), capturas del 2026-10-01"
---

# En el iPhone girado, la cabecera de Registros y Estadísticas llena casi toda la pantalla

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
