---
id: ipad-records-empty-detail-half-hidden-with-chat-open
status: backlog
priority: low
area: "ipad, records, chat, adaptativo"
created: 2026-10-03
updated: 2026-10-08
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

## Medido en 2.1 (triage 2026-10-08)

- El vacío (`records_detail_placeholder` en `RecordsStandaloneView`, y su gemelo en `DetailContainerView`) sigue centrado en la columna de detalle entera; `ListDetailSplit.swift` no se toca desde `5c831f109` (2026-10-02), anterior a la captura.
- La captura citada (`qa/evidencia-adaptativo-20261003/…/ipad-pro-13__08-chat-h.jpg`) no está en este árbol.
- Decisión pendiente. A) centrar el vacío en lo que la lista deja a la vista (`ListDetailSplitState` ya conoce `splitWidth` y `detailWidth`); B) no pintarlo mientras la lista lo tapa. Recomendada: A, porque conserva la pista de dónde aparecerá lo que elijas. Con A sigue en `low`.

Triage 2026-10-08: abierto · low → low · El vacío de `RecordsStandaloneView` sigue siendo un `ContentUnavailableView` centrado en todo el detalle, y `ListDetailSplit` no ha cambiado desde el 2026-10-02; falta la decisión de qué hacer con él.
