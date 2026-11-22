---
id: 2026-11-22-esto-lei-propuestas-diseno
status: done
area: "captura"
created: 2026-11-22
updated: 2026-11-22
source: "pedido de Jürgen del 22-nov (06:34 Lima) y GO a la sesión de propuestas (06:38): la hoja «Esto leí» no le encanta, quiere completar desde ahí y abrir el registro completo"
---

# Propuestas de diseño para la hoja «Esto leí»

Solo propuesta: no se tocó código de la app. Jürgen elige sobre el artifact y la implementación va en otro encargo.

## Dónde está

- Artifact (maquetas, recorridos, pros y contras y el bloque «Tu decisión»): **https://claude.ai/artifact/B9FnV4i3hneH9VchcoVW5i** (público con enlace).
- Fuente: `docs/propuestas/2026-11-22-esto-lei/index.html`, con las capturas de hoy en `capturas/`.
- La decisión se guarda en la base del artifact: colección `decision`, documento `jurgen` (`eleccion` A · B · C · otra,
  `detalles` d1-d3 con sí/no/después y `nota`). **Antes de implementar, leer esa decisión.**

## Estado de partida (medido en `origin/2.3` el 2026-11-22)

- La hoja es `ImageSelectionView.reviewContent` (foto) y su gemela en `VoiceRecordingView` (voz, «Esto entendí»).
  Un registro: `VoiceDraftReviewCard(editsNoteInPlace:)`; varios: `MultiDraftReviewList`.
- Un registro: icono, descripción editable en el sitio, «Falta la categoría» en ámbar, importe a la derecha y chips de
  la tarjeta de Yala IA (categoría, cuenta con ✦, fecha, + Etiqueta). Debajo, la nota de la cuenta elegida
  (`CuentaSolaAlLeerPorqueLine`) y el aviso de la Bandeja. Abajo, «Otra foto» y «Guardar» (gris si falta algo).
- Tocar la fila (fuera de la descripción) abre el formulario completo (`detailDraft`), pero nada lo indica.
- Varios: total grande, barra por categoría, días con subtotal y filas con marca; «Guardar 7 · S/ 248.71» se parte en
  dos líneas en el 17 Pro.
- Capturas medidas: simulador iPhone 17 Pro (claro con `-userTheme 1` y el tema de siempre) y iPad Pro 11, con los
  seams `-uitest-image-result` (`one`, `incomplete`, `two`, `many`, `cuenta-sola`) y `-uitest-voice-result`.

## Las tres propuestas

- **A · Tarjeta B1 (recomendada).** Cada registro es una B1 en pequeño: cápsula de moneda y monto grande, categoría
  bajo el monto («● Elige categoría ▾» en ámbar si falta), fila Hoy · Cuenta ✦ · # y «Ver todo» que empuja el editor B1
  dentro de la hoja con ‹ para volver. El botón principal nombra lo que falta («Elige la categoría», «Completa 2 para
  guardar») en vez de quedar gris. Con varios se conserva la vista de hoy y la fila que falta se abre sola.
- **B · Lista de ajustes.** El registro en una fila y sus datos como filas de Ajustes (Categoría ›, Cuenta ›…), cada una
  empuja su selector; «Abrir el registro completo» al final. Con varios, filas que abren el editor completo.
- **C · La hoja B1 directa.** Tras leer, la hoja ya es Nuevo registro con todo puesto y una franja «Leído de tu foto».
  Con varios, una página por registro con puntos.
- En las tres: barra como B1 (X a la izquierda, título al centro, la foto a la derecha), textos de barra en primary,
  ningún botón debajo de otro.

## Qué queda

- Jürgen elige en el artifact. La sesión que implemente lee `decision/jurgen` y abre su propio ticket.
