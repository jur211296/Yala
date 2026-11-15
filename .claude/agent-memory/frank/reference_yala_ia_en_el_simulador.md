---
name: yala-ia-en-el-simulador
description: Yala IA en el simulador: sin servidor; estados con -uitest-chat-*, sin red con -uitest-network-offline; el modelo de Apple sale LISTO
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

- Sin conexión (desde el 2026-11-12): `-uitest-network-offline` deja `NetworkMonitor` en «sin red». Con él, el
  chat enseña «Necesitas conexión…» y el muro de Pro sin precios, las alternativas gratis.
- **El modelo de Apple del simulador sale DISPONIBLE en esta Mac** (medido el 2026-11-12, iOS 27.2): un caso que
  afirme «sin modelo, sin Siri gratis» tiene que fingirlo con `-uitest-siri-model deviceNotEligible`; a pelo sale rojo.
- `axe tap` sobre «Yala IA» de Registros no abrió el muro (dos intentos): las capturas del antes/después salieron de un
  XCTAttachment dentro del XCUITest, corrido sobre la base y sobre el arreglo.

**Trampa:** `xcrun simctl privacy … grant microphone` mata la app al momento; relanza con los mismos args.
Relacionado: [[maqueta-de-variantes-por-xcuitest]].
