---
id: ipad-records-empty-detail-half-hidden-with-chat-open
status: backlog
priority: low
area: "ipad, records, chat, adaptativo"
created: 2026-10-03
updated: 2026-10-03
source: "encargo cola-b-redesigns-must-hold-up-at-ipad-width, capturas del 2026-10-03"
---

# En iPad, con Yala IA abierto en Registros, «Elige un registro para verlo aquí» sale medio tapado

## Qué pasa

iPad Pro 13 en horizontal (`YalaLane-Adapt-iPad-Pro-13`, iOS 27.0), Registros sin nada abierto y Yala IA en su
columna a la derecha: el texto vacío del detalle queda cortado por la lista, y solo se lee «…a verlo aquí». Lo mismo
en el iPad mini girado.

Captura: `qa/evidencia-adaptativo-20261003/cola-b-redesigns-must-hold-up-at-ipad-width/ipad-pro-13__08-chat-h.jpg`.

## Por qué, inferido sin medir

Con el chat al lado, el split de Registros queda por debajo de dos anchos de iPhone y superpone la lista sobre el
detalle; con el detalle vacío la lista se queda a propósito (`ListDetailOverlayLogic`: esconderla dejaría la pantalla
sin salida). El texto vacío se centra en el detalle entero, y la lista tapa su mitad izquierda.

## Qué hacer

Decidir cuál de las dos: centrar el vacío en lo que la lista deja a la vista, o no pintarlo mientras la lista lo tapa.
No cambia nada en iPhone.
