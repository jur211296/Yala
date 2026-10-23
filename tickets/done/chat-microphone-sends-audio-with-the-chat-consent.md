---
id: chat-microphone-sends-audio-with-the-chat-consent
status: done
priority: medium
area: yala-ia, privacidad
created: 2026-10-20
updated: 2026-10-22
source: revisión de Yala IA 2.2 (docs/ai/revision-ia-2-2.md §1)
---

# El micrófono del chat manda el audio a la IA con el permiso del chat, que no habla de audio

## Qué le pasa al usuario

Quien acepta el permiso de Yala IA y nunca aceptó el de voz y foto puede dictar en el chat: el audio sale a
`voice.transcribe` igual. El texto del permiso del chat (`aiConsent.chatMessage`) habla de «un resumen de tus últimos
13 meses» y no menciona audio; el que lo menciona es el de voz y foto (`processingMessage`).

## Lo medido (2026-10-20, origin/2.2)

- `ChatSheetView.swift:498` llama a `viewModel.startVoiceInput()` y `ChatAssistantViewModel.stopVoiceInput()` manda el
  audio a `VoiceTranscriptionService.transcribe` sin mirar `aiDataConsentAccepted` (grep en los dos ficheros: cero).
- Siri, al revés, exige el permiso de voz y foto para mandar el texto a `text.parse` (`QuickExpenseIntent.swift:229`).
- Registrar desde el chat manda el texto a `text.parse` también con el permiso del chat.

## Qué hay que decidir

Card a jurgen. A) el micrófono del chat pide además el permiso de voz y foto (recomendada: es el que habla de audio);
B) el texto del permiso del chat pasa a decir que, si dictas, el audio se transcribe con un servicio de IA (16 idiomas);
C) dejarlo.

## Cerrado (2026-10-22) — decisión A de Jürgen

El micrófono del chat pide el permiso de voz y foto (el mismo aviso que Voz y Foto del Panel) antes de grabar; con él
aceptado graba como antes (`ChatVoiceInputGateLogic`). Registrar desde el chat con texto sigue con el permiso del
chat: no entró en la decisión. Tests: `ChatVoiceInputGateTests`.
