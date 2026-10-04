# Registro por voz de punta a punta, alrededor del panel de dictado

## Contexto
El dictado de Yala IA acaba de cerrar como panel de escucha (propuesta B) en el PR #350, en auto-merge a 2.1 y todavía no en origin. Esa pieza ya no es otra sesión: este encargo es el flujo completo de registro por voz. Card: tablero-mejorar-el-registro-por-voz-de-punta-a-p-u58k. Versión 2.1, antes del QA del lunes.

## Que se pide
Recorre el registro por voz completo y déjalo a la altura de ese panel. Si el diseño queda cerrado con lo que ya hizo el #350, implementa y cierra con /cerrar-total. Si queda una decisión de interfaz que solo Jürgen puede tomar, deja propuestas y para. No cambies de modelo ni de proveedor.

Justo antes del gate, mira si el PR #350 sigue en CI. Si sigue, espera a que entre en origin/2.1 y rebasa una sola vez, con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build (xcodebuild -jobs 2, sin simulador) y la suite van después de ese rebase, una sola vez. Puedes encender el simulador durante el trabajo para capturas; apágalo antes del rebase. Si una captura depende del código nuevo de 2.1, sácala una vez, ya rebasado.

Pipeline: limpiar, build sin simulador, un simulador, tests, apagar y borrar los datos de ese device.

Si el cambio se ve, deja capturas/antes.png y capturas/despues.png y lista las rutas en el cierre.

## Que NO hay que tocar
El formulario de cuenta del PR #341. No partes de la rama en auto-merge: la base es origin/2.1. No cambies modelo ni proveedor.

## Como se sabe que esta bien
El flujo de voz se ve y pasa un solo gate, o hay propuestas concretas si el diseño no está cerrado.

## Paso 0

**Decidido por Jürgen (2026-10-04, lienzo https://claude.ai/artifact/L34Tg6iimtk1xhsQG2vq57):** propuesta **C ·
Escucha y confirma aquí**, con el **color del tema** (como el dictado del #350).

Asumido por mí, sin preguntar (técnico o de proceso):

- **Al tocar Voz, la hoja ya escucha.** Sin pantalla de reposo ni cuenta atrás 3-2-1: Cancelar la sustituye.
- **La hoja abre a media altura** (grande con texto de accesibilidad), con el mismo `mediumFirst` de los selectores
  del #349. Con varios registros se desplaza dentro: agrandarla por código no movía la hoja en el simulador (medido
  dos veces, también aplazándolo una vuelta), así que el usuario la estira si quiere.
- **Escuchar reusa `VoiceListeningPanel` del #350** con un parámetro para ir sin tarjeta dentro de una hoja; la pista
  y los títulos reusan sus claves («Escuchando…», «Prueba: …»), ya traducidas.
- **Procesar** = el orbe gira con el paso en curso y lo grabado; se puede cancelar, como hoy.
- **Lo entendido** = una fila por borrador con las píldoras de la card de Yala IA (#348): mismos selectores
  (`ChatDraftFieldSheet`), lo que falta en ámbar, «Detalles» abre el formulario completo de siempre
  (`InboxDraftEditSheet`). «Guardar» aprueba con `DraftService.approveDraft`, el camino de la Bandeja.
- **Cerrar sin guardar deja los borradores en la Bandeja**, como hoy, y la hoja lo dice. **Volver a grabar** borra
  los borradores pendientes de ESA grabación (si no, se duplicarían en la Bandeja).
- **Errores en lenguaje de usuario, con salida**: nunca `localizedDescription` (hoy salen en inglés o en técnico).
- **La práctica guiada (checklist) conserva su contrato**: un solo borrador, «Ahora no» y los mismos callbacks.
- **Fuera:** el formulario de cuenta (#341), modelo y proveedor, la Bandeja, el dictado del chat.
- **Rebase:** #350 entró en `origin/2.1` a las 14:50 UTC; rebasé una vez, con el simulador apagado, antes de construir.
