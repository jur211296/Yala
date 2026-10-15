---
name: yala-ia-en-el-simulador
description: El chat de Yala IA no llega al servidor desde el simulador; sus estados se pintan con args -uitest-chat-* y el contador con -chatQuestionsToday N
metadata:
  type: reference
---

Medido el 2026-10-15 (lote 14 de la auditoría UX, iPhone 17 Pro iOS 27.0, Yala Dev): el chat real responde «Yala IA no
está disponible» y apaga la caja. Para ver cada estado sin servidor:

- `-uitest-ai-chat-ready` (consentimiento y presentación vistos) · `-uitest-chat-suggestions` (tres sugerencias fijas) ·
  `-uitest-chat-conversation` (una pregunta con respuesta) · `-uitest-chat-draft` (dos registros propuestos).
- Contador de preguntas: `-chatQuestionsToday N -chatLastQuestionDate AAAA-MM-DD` (dominio de argumentos de
  UserDefaults; manda sobre lo guardado). 74 = queda una; 75 = tope.
- `-uitest-ai-consent` es el permiso de VOZ/IMAGEN, no el del chat: con él, tocar «IA» sigue pidiendo el del chat.

**Trampa:** `xcrun simctl privacy … grant microphone` mata la app al momento; relanza con los mismos args.
Relacionado: [[maqueta-de-variantes-por-xcuitest]].
