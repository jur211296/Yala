---
id: 2026-11-22-esto-lei-construir-opcion-a
status: done
area: "captura"
created: 2026-11-22
updated: 2026-11-22
source: "Jürgen eligió la opción A · Tarjeta B1 en el artifact de propuestas (22-nov) con tres ajustes: «Ver todo» en la misma hoja (sí), la línea ✦ en una línea (sí), el botón dice lo que falta (no)"
---

# «Esto leí» con la tarjeta B1 (opción A)

La hoja que sale tras leer un registro por foto («Esto leí») o por voz («Esto entendí») pasa a la opción A de
`docs/propuestas/2026-11-22-esto-lei/` (ticket de propuestas: `tickets/done/2026-11-22-esto-lei-propuestas-diseno.md`).

## Qué cambia para quien usa la app

- **Un registro** es una hoja B1 en pequeño: «Ver todo» arriba a la derecha, la descripción centrada (se corrige
  tocándola en la foto), la cápsula de moneda y el monto grande, la categoría bajo el monto con su categoría y
  necesidad, y la fila Hoy · Cuenta · # con los chips de Nuevo registro. Si falta la categoría, «● Elige categoría ▾»
  en ámbar abre el selector de siempre. La línea ✦ de la cuenta elegida va en una sola línea.
- **Varios:** la vista de siempre (total, barra, días). Tocar una fila la despliega con lo que falta, la fecha, la cuenta
  y «Ver todo»; la primera marcada a la que le falta algo sale desplegada sola y el recuento dice «· N por completar».
- **«Ver todo»** abre el editor completo de la Bandeja dentro de la misma hoja, con ‹ para volver. ‹ guarda lo editado.
- **Barra como B1:** la X a la izquierda, el título al centro y, a la derecha, las fotos (se abren a pantalla completa)
  o el micro con «Lo que dijiste».
- **«Otra foto» / «Otra vez» suman** a lo leído en vez de borrarlo, sin preguntar; ‹ vuelve a lo leído.
- **Botones** siempre en una fila: con texto grande, «Otra foto» se queda en su icono y «Guardar» encoge el texto.
  «Guardar» sigue apagado si falta algo (sin cambiar de texto).
- **Cerrar sin guardar** lo deja en la Bandeja, como antes, y ahora sale el aviso «Lo que leí quedó en tu Bandeja · Ver».

## Dónde

- `Yala/App/Views/Voice/VoiceDraftReviewCard.swift` (la tarjeta), `MultiDraftReviewList.swift` (la fila desplegable),
  `VoiceRecordingView.swift`, `EstoLeiInboxNotice.swift`; `Yala/App/Views/Image/ImageSelectionView.swift`,
  `DraftNoteInlineEditor.swift`, `EntrySheetCloseButton.swift` (‹), `EstoLeiPhotoViewer.swift`.
- Lógica pura: `EstoLeiLogic` en `Yala/App/Logic/VoiceEntryFlowLogic.swift`; tests en `YalaTests/EstoLei/`.
- Fuera del `toca`, lo mínimo para «Ver todo» en la misma hoja: `Yala/App/Views/Inbox/InboxDraftEditSheet.swift` con un
  modo empujado (`onBack`).
- Textos: 14 claves `estoLei.*` en los 16 `Localizable.strings`, en español neutro también en es-ES y es-AR.

## Pruebas

- `YalaTests/EstoLei/EstoLeiLogicTests` (lógica).
- `YalaUITests/EstoLei/EstoLeiRecorridoUITests` (completar, Ver todo y ‹, guardar, cerrar con aviso, varios).
- Actualizados a lo nuevo: `XNativaHojaFotoUITests`, `CaptureConvertToGroupUITests`, `ImageEntryReviewUITests`,
  `MultiDraftReviewUITests`, `VozFotoAvisos23UITests`, `VoiceEntryReviewUITests`.
- Capturas del antes y el después: `EstoLeiCapturasUITests` (a mano, `TEST_RUNNER_CAPTURA_DIR`).
