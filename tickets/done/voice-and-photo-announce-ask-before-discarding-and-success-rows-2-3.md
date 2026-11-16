---
id: voice-and-photo-announce-ask-before-discarding-and-success-rows-2-3
status: done
priority: medium
area: "new-record"
created: 2026-11-12
updated: 2026-11-12
source: revisión 2.3 · Nuevo registro, decisiones 80, 62, 81, 65 y 83 (card tablero-2-3-voz-y-foto-al-registrar-avisos-la-ho-69q6)
qa-status: passed
qa-date: 2026-11-12
qa-notes: XCUITest VozFotoAvisos23UITests en el simulador iPhone 17 Pro iOS 27.2, 8 rojos sin el arreglo y verdes con el, capturas en entregas
---

# Voz y foto: avisan a VoiceOver, preguntan antes de descartar, y «¡Listo!» se lee entero

Decidido el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`), ficha en
`docs/ux/revision-vistas-2.3/32-nuevo-registro/`.

1. **Decisión 80.** La foto con varios registros pasa la hoja a grande sola al terminar de leer: antes se quedaba a
   media altura y enseñaba una fila de siete. SwiftUI no mueve la hoja (ni cambiando la selección ni quitando la media
   altura, medido en iOS 27.2): se le pide a la hoja de UIKit (`ImageEntrySheetHeight.swift`). Con una sola fila, igual
   que antes.
2. **Decisión 62.** Voz y foto anuncian a VoiceOver cada fase («Escuchando…», «Esto entendí», «Leí 7 registros»…) y cada
   fallo con su porqué, también «no se pudo guardar» y las fotos que no se leyeron (`EntryPhaseFeedback.swift`).
3. **Decisión 81.** «Volver a grabar» y «Otra foto» preguntan «¿Descartar lo que entendí / leí?» si hay registros de esa
   vez sin guardar; «Seguir revisando» lo deja como estaba. Desde un fallo no hay nada que perder y no preguntan. Textos
   en los 16 idiomas.
4. **Decisión 65.** En «¡Listo!», fecha y descripción ocupan hasta dos líneas y luego cortan.
5. **Decisión 83.** «Registrar otro» lleva el identificador `transaction_success_create_another`.

Tests: `YalaTests/VozFotoAvisos23Tests` (lógica) y `YalaUITests/Flows/VozFotoAvisos23UITests` (ocho casos, rojos sin el
arreglo; el de dos líneas, además, rojo con el mutante de una línea). `VoiceEntryReviewUITests#test_recordAgain_returnsToListening`
confirma ahora la pregunta.

Nada queda para la mano de Jürgen: VoiceOver no entra en su QA manual y el resto lo fija el simulador.
