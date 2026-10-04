# Mejorar el registro por imagen de punta a punta (diseño 2.1)

## Contexto
Card tablero: `tablero-mejorar-el-registro-por-imagen-de-punta-g5wl` (ya en in progress). Cola de diseño 2.1 antes del QA del lunes (Jürgen 2026-10-03/04). Acaba de cerrar el registro por voz como PR #351 (propuesta C): una sola hoja que escucha y confirma, orbe del dictado #350, fila del registro con píldoras #348, Guardar ahí mismo, fallos en lenguaje de usuario. Dictado de Yala IA es el panel de escucha B (#350). El proceso de registro por imagen se ve pobre de punta a punta (captura → lectura → card → confirmación).

Entrada: cámara / galería / soltar imagen o PDF (`ImageSelectionView`, `ImageVision`/`ImageOCR`, intents `ImageEntryIntent` / `presentImageEntry`, share extension, drop en iPad). No tocar marketing ni claves de firma.

## Que se pide
1. Recorrer el flujo completo de registro por imagen (Panel «+» › Imagen, atajos, drop si aplica) y documentar qué se ve hoy y dónde se siente pobre.
2. Proponer 2–3 rediseños concretos (A/B/C) alineados con el lenguaje visual recién cerrado: misma hoja captura/procesa/confirma, fila del registro + píldoras, fallos claros, detent medium primero. Lienzo/artifact + capturas de estado actual (`capturas/antes*.png`).
3. **Decisiones de UI abiertas → deja las propuestas y ESPERA a Jürgen.** No implementes el rediseño elegido hasta que diga cuál. No inventes un default y cierres.
4. Si al explorar salen bugs acotados o tickets nuevos, anótalos en el board (assignee frank) sin ampliar el alcance a implementación de diseño.
5. Arranca ya sobre `origin/2.1`. No esperes a que entre el PR anterior (#351) ni partas de la rama en auto-merge. Justo antes del gate: si #351 sigue en CI, espera a que entre y rebasa una sola vez con el simulador apagado; si `2.1` no se movió, sigue de frente; si ese CI falla, no esperes: rebasa con lo que haya y sigue. Build y simulador solo después de ese rebase, una sola vez.
6. Pipeline serial Mini: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests/capturas → apagar/limpiar. Norma 1 sim. No solapar swift-frontend + SpringBoard + app + UITests.

## Que NO hay que tocar
- No cambies modelo ni proveedor de visión/OCR.
- No implementes el rediseño sin la decisión de Jürgen (esta card es propuestas + espera).
- No toques el formulario de cuenta del PR #341 ni marketing/.
- No CloudAgent: solo este worktree.

## Como se sabe que esta bien
- Hay 2–3 propuestas claras (antes → después) con artifact/lienzo y capturas del estado actual.
- La sesión se detuvo pidiendo la decisión de Jürgen (cuál propuesta), sin mergear un rediseño no elegido.
- Ticket/board actualizado; capturas listadas en el resumen.

## Paso 0 — decisiones

Encargo de **propuestas + espera**: el rediseño elegido NO se implementa en esta sesión.

- **Decidido por Jürgen (2026-10-04):** propuesta **C**, y construirla en esta sesión (la pregunta fue «¿cuál
  construyo?»). Compartir sin Pro es un hueco: se cierra.
- **Asumido — lienzo:** un canvas de Design nuevo con el mismo lenguaje que el de voz
  (L34Tg6iimtk1xhsQG2vq57): hoja oscura a media altura, color del tema, fila con píldoras del #348.
- **Asumido — capturas del antes:** solo lo que el simulador enseña sin red ni seam nuevo
  (selección, cuenta atrás, procesando, el fallo que sale en el simulador y «Editar borrador» desde la Bandeja).
  No añado un `-uitest-image-result` ahora: sería código de la implementación, que espera a la decisión.
- **Asumido — capturas fuera del worktree:** `~/Claude/worktrees/_capturas/<slug>/` (sobreviven al retiro del
  worktree) y copia en `capturas/` para el bot.
- **Asumido — bugs que salgan:** ticket en `tickets/backlog/` + tarjeta del tablero (assignee frank). Nada de
  código de producción en este PR.
- **Asumido — entrega:** el diff solo toca `tickets/`, `docs/` y `encargos/` (este último no está en la lista
  «sin nada que compilar», así que va por PR como los encargos anteriores). Ningún código de producción ni rediseño:
  el PR entra en cola de auto-merge (sesión en bypass) sin esperar a la decisión, que vive en el ticket.
- **Rebase:** Jürgen confirmó (2026-10-04) que el #351 no toca las pantallas de imagen: el build y las capturas
  del «antes» se hicieron sobre `origin/2.1` sin esperar su CI. El diff no compila nada, así que el rebase es
  solo de git.
