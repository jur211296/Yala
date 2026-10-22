---
id: voice-cancel-does-not-resume-other-apps-audio
status: done
priority: medium
area: "voz, audio"
created: 2026-10-19
updated: 2026-10-20
qa-status: needs-testing
source: tarjeta del tablero `tablero-al-cancelar-la-voz-la-musica-de-otra-app-8171` (QA guiado del 2026-10-19, B · micrófono paso 3)
---

# Al cancelar la voz, la música de otra app no vuelve a sonar

## Qué le pasaba al usuario

Con música sonando en otra app, Panel › Voz › «Cancelar»: la música se paraba al empezar a escuchar y no volvía sola.
El guion de `voice-entry-end-to-end` (paso 4) pide que vuelva.

## Causa (medida en código)

`AudioRecorderService` pone la sesión en `.playAndRecord`, que interrumpe la música, y sus dos salidas (terminar y
cancelar) la soltaban con `setActive(false)` **sin** `.notifyOthersOnDeactivation`, que es lo que le dice a la otra
app que puede retomar. Había una tercera salida con el mismo efecto: si la grabación fallaba al arrancar con la sesión
ya activa, nadie la soltaba.

## Arreglo

Un solo sitio suelta la sesión (`releaseAudioSession()`), siempre con `.notifyOthersOnDeactivation`, y lo usan las
tres salidas. Cancelar sin grabación sigue sin tocar la sesión: esta app no activó nada.

Tests: `YalaTests/AudioSessionReleaseTests` (opciones, la decisión del cancelar con su control sin grabación, y el
cableado de las tres salidas).

## Device-QA (Jürgen, iPhone de QA)

1. Pon música en otra app (Música, Spotify).
2. Yala › Panel › Voz. La música se para mientras escucha.
3. Toca «Cancelar». **Esperado:** la música vuelve a sonar sola en un segundo o dos.
4. Repite con «Listo» tras decir un gasto. **Esperado:** la música vuelve al terminar de grabar.

Cerrado en el QA guiado 2026-10-20 (tanda del TestFlight 19): Yala Dev: la música de otra app vuelve al cancelar y al terminar la voz.
