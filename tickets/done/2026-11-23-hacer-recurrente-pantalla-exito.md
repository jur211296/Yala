---
id: 2026-11-23-hacer-recurrente-pantalla-exito
status: done
priority: medium
area: "transactions, success-screen"
created: 2026-11-23
updated: 2026-11-23
source: "Jürgen, 2026-11-23 13:57: «Hacer recurrente» (desde «···» de Nuevo registro) también muestra la pantalla de éxito al guardar, igual que el guardado normal"
---

# «Hacer recurrente» muestra la pantalla de éxito al guardar

Tras la decisión de la mañana (la pantalla de éxito sale siempre al guardar un registro nuevo,
`nuevo-registro-exito-no-aparece`), «Hacer recurrente» del «···» seguía cerrando el formulario con el aviso breve
«Guardado · se repetirá cada mes». Jürgen decidió que también enseñe la pantalla de éxito.

## Hecho cuando

Guardar un registro nuevo con «Hacer recurrente» (la fila de frecuencia o el editor completo) enseña la misma pantalla
de éxito que «Guardar», sin el aviso breve encima ni después, con pruebas que lo cubren.

## Qué se hizo

- `TransactionSaveFeedbackLogic.recurringFeedback(isEdit:successScreenShown:)`: registro nuevo → pantalla completa;
  edición, o la oferta «Recurrente» de la propia pantalla de éxito → el aviso breve de siempre.
- La pantalla de éxito marca «Recurrente» con su frecuencia («Mensual», «Semanal», «Anual»), desactivado, como
  «Favorito» ya guardado. Sin textos nuevos: la frecuencia es la del pago planificado, ya traducida en los 16 idiomas;
  VoiceOver lee la frase entera del aviso de antes.
- El permiso de notificaciones del primer pago planificado se pide al salir con «Aceptar» (antes, al cerrar con el aviso).
- Desde el editor completo («Más opciones…») la pantalla sale al cerrarse su hoja.

## Consecuencia

El aviso con «Deshacer» y «Editar» tras guardar un registro nuevo ya no tiene ningún camino: «Guardar» y «Hacer
recurrente» enseñan la pantalla de éxito. Se retiraron sus dos pruebas de interfaz (`noticeWithUndo_restoresTheBalance`,
`editFromTheNotice_opensTheRecord`); las de posición del aviso llegan ahora por la oferta «Recurrente» del éxito.

## Pruebas

- unit: `YalaTests/HacerRecurrenteExito/HacerRecurrenteExitoTests` (lógica + cableado).
- xcuitest: `YalaUITests/HacerRecurrenteExito/HacerRecurrenteExitoUITests` (fila «Cada mes» y editor completo).
- Capturas antes/después en claro, oscuro y girado: https://claude.ai/artifact/TuSvBhAzqebzckuAq84TCz
