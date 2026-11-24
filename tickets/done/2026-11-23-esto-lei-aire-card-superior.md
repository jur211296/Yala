---
id: 2026-11-23-esto-lei-aire-card-superior
status: done
priority: medium
area: "image-entry, esto-lei, ui"
created: 2026-11-23
updated: 2026-11-23
source: "pruebas de Yala 2.3 en el iPhone de Jürgen (modo oscuro), 23-nov"
---

# «Esto leí»: la primera tarjeta, pegada a la cabecera y sin borde visible

En la hoja «Esto leí» (foto de un recibo) el borde de arriba de la tarjeta se confundía con el glass de la hoja y quedaba
pegado a la X y a la miniatura de la foto. Medido en el simulador antes del cambio: 4 pt entre la cabecera y la tarjeta,
la tarjeta sin contorno (solo el relleno `.thCard`, casi del mismo gris que el glass en oscuro) y, en el iPhone SE, la
`.medium` dejaba fuera la fila de chips y la nota de la Bandeja.

## Hecho cuando

- La primera tarjeta arranca con aire claro bajo la cabecera.
- Su contorno se distingue en oscuro y en claro.
- «Guardar» y la nota «Si cierras sin guardar…» se ven a media altura en el iPhone 17 Pro y en el SE.

## Resolución (2026-11-23)

- Aire: 16 pt (`EstoLeiCardLayout.airAboveFirstCard`) entre la cabecera y lo leído, antes 4.
- Contorno: 1 pt propio de la tarjeta (`EstoLeiCardLayout.edge`), blanco al 20 % en oscuro y negro al 12 % en claro;
  con «Aumentar contraste», 40 % y 30 %. Sirve también a «Esto entendí» (voz), que usa la misma tarjeta.
- Altura: la hoja personal de foto abre a `ImageEntrySheetHeightLogic.estoLeiPartial`, la `.medium` del sistema salvo
  cuando no le cabe un registro con su nota y «Guardar» (450 pt con el texto de siempre). La foto de Grupos sigue con
  `.medium`.
- Pin: `YalaTests/EstoLeiCardSuperior/EstoLeiCardSuperiorTests`.

## Fuera

- El aire de arriba en la hoja de voz (`VoiceRecordingView`) no se tocó: no estaba en el encargo.
- La foto de Grupos (`GroupPhotoCaptureView`) sigue con la `.medium`: en el SE puede cortar igual.
