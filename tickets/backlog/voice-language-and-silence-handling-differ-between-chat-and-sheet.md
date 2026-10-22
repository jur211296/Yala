---
id: voice-language-and-silence-handling-differ-between-chat-and-sheet
status: backlog
priority: low
area: voice, chat, ai
created: 2026-10-07
updated: 2026-10-08
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H10)
---

# El dictado del chat y la hoja de voz transcriben distinto

> **Grupo: autónomo.** Coherencia de idioma y de manejo de errores. No cambia modelo ni proveedor.

## Qué le pasa al usuario

- Elige «Idioma de voz: inglés» en Ajustes. En la hoja de voz se respeta; al dictar en el chat, no:
  el chat transcribe con el idioma del sistema.
- Si graba silencio, `whisper-1` a veces «alucina» frases de relleno (créditos de subtítulos,
  «Thanks for watching»). El chat las filtra y dice «no se detectó voz»; la hoja de voz no las filtra y
  las manda al parser, que gasta otra llamada para no encontrar nada.

## Lo medido (2026-10-07, en este árbol)

- `ChatAssistantViewModel.stopVoiceInput` (≈459) llama a `transcribe(…, language: .system)`.
  `VoiceRecordingView.understand` (≈615) usa `appPreferences.voiceLanguage`.
- `.system` resuelve con `Locale.preferredLanguages` (`VoiceTranscriptionService.swift:63`), no con
  `AppLocale`, así que tampoco sigue el idioma elegido dentro de la app.
- `isWhisperHallucination` solo existe en `ChatAssistantViewModel.swift:490`.

## Qué hay que hacer

1. El chat usa la misma preferencia de idioma de voz que la hoja.
2. `.system` resuelve con `AppLocale`.
3. Mover el filtro de alucinaciones a `VoiceTranscriptionService` para que lo compartan los dos.

## Hecho cuando

- Tests: el chat pasa `voiceLanguage`; `.system` sigue a `AppLocale`; una transcripción «alucinada» no
  llega al parser desde la hoja.

## Medido en 2.1 (triage 2026-10-08)

- Punto 2 hecho: desde `3a0090cab` (2026-10-07) `VoiceLanguage.isoCode` resuelve `.system` con `AppLocale.current`, no con `Locale.preferredLanguages`.
- Siguen los puntos 1 y 3: `ChatAssistantViewModel.stopVoiceInput` pasa `language: .system` (`:461`) mientras `VoiceRecordingView` usa `appPreferences.voiceLanguage` (`:630`), e `isWhisperHallucination` solo existe en `ChatAssistantViewModel.swift:490`.
- Desde `52f09855a` la voz va a `gpt-transcribe`, no a `whisper-1`; no está medido si el modelo nuevo sigue inventando frases con el silencio.

Triage 2026-10-08: abierto · low → low · el punto 2 ya está hecho (3a0090cab), pero el chat sigue ignorando el idioma de voz elegido y el filtro de silencio sigue solo en el chat.
