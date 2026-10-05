---
id: chat-dictation-looks-poor
status: qa
priority: medium
area: "chat, yala-ia, voz, design-system"
created: 2026-10-04
updated: 2026-10-04
qa-status: needs-testing
source: Jürgen, 2026-10-03 («el dictado se ve pobre»); tarjeta del tablero `tablero-mejorar-el-diseno-del-dictado-en-yala-ai-apsc`
---

# El dictado de Yala IA se veía pobre: panel de escucha

## Qué le pasaba al usuario

Al tocar el micro en Yala IA la caja de escribir se cambiaba por un icono, «Escuchando…» y un botón
rojo. No se veía cuánto llevaba grabado ni si el micro le oía. Tampoco podía arrepentirse: parar
siempre transcribía, y desaparecía el «+».

## Lo decidido (2026-10-04)

Tres propuestas en un lienzo (A nota de voz · B panel de escucha · C dentro de la caja). Jürgen
eligió la **B**, porque «se siente más Brand Voice Yala», y pidió textos más sencillos.

- Mientras dictas, la caja se cambia por un panel con el título «Escuchando…» y la pista «Prueba:
  «Gasté 25 en el almuerzo con la tarjeta»». En el centro hay un orbe del color del tema que late
  con la voz. Debajo van el tiempo, con un punto rojo, y los botones **Cancelar** y **Listo**.
- **Cancelar** descarta la grabación sin transcribirla y suelta el micro. **Listo** la transcribe,
  y el texto queda en la caja como hasta ahora: no se envía.
- Mientras transcribe, el orbe gira y el panel dice «Revisa tu texto antes de enviarlo.» junto con
  lo grabado. En ese estado no hay botones: cancelar a media transcripción no cortaría la petición.
- Con «Reducir movimiento», el halo se queda quieto y el spinner es el del sistema.

## Fuera

El registro por voz del FAB (`VoiceRecordingSheet`), la respuesta por voz y la mascota (2.2).

## Guion de device-QA (iPhone físico)

1. Abre Yala IA desde el botón «Pregúntale a Yala» de Registros o del Panel.
2. Toca el micro. Comprueba que la caja se cambia por el panel, con «Escuchando…», la pista, el
   orbe, el tiempo corriendo y los botones Cancelar y Listo.
3. Habla en voz normal y luego más fuerte. El halo del orbe tiene que crecer con la voz y encogerse
   en silencio. **Es lo que el simulador no puede medir.**
4. Toca **Cancelar**. Tiene que volver la caja de escribir vacía, sin ningún aviso de error. Pon
   música en otra app y comprueba que vuelve a sonar normal.
5. Vuelve a tocar el micro, di «gasté 25 en el almuerzo con la tarjeta» y toca **Listo**. Durante la
   transcripción, el orbe gira, se lee «Revisa tu texto antes de enviarlo.» y aparece «0:0X
   grabados». Al terminar, el texto queda en la caja **sin enviarse**.
6. Repite el paso 2 con Ajustes › Accesibilidad › Movimiento › Reducir movimiento activado. El halo
   no se mueve y la transcripción enseña el spinner del sistema.
7. Repite el paso 2 con el texto más grande (Ajustes › Pantalla y brillo › Tamaño del texto al
   máximo). El panel no se corta y los dos botones se leen enteros.

## Evidencia

Capturas de antes y después en `~/Claude/worktrees/_capturas/2026-10-04-mejorar-el-diseno-del-dictado-en-yala-ai/`.
El lienzo con las tres propuestas está en https://claude.ai/artifact/Hdrw8D3ukrDaAUSfyGcPhh.
