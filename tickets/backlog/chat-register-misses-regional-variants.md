---
id: chat-register-misses-regional-variants
status: backlog
priority: low
area: chat, ai, l10n
created: 2026-10-07
updated: 2026-10-07
source: banco de chat.answer (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md)
---

# Yala IA trata de «informal you» a quien tiene la app en una variante regional

## Qué le pasa al usuario

Con Yala en es-ES, es-AR, pt-BR, pt-PT o en-GB, el prompt del chat pide «informal you» en vez de tuteo, voseo o «você».

## Lo medido (2026-10-07)

- El `switch` del registro del chat solo mira códigos sin región (`es`, `pt`, `en`), así que las variantes caen al caso
  por defecto.
- Desde el 2026-10-07 la tabla vive en `AIPromptLanguage.informalRegister(forBaseLanguage:)`, compartida con Insights.
  Insights le pasa el código base (`AIPromptLanguage.baseCode`) y no tiene el fallo; el chat sigue pasándole
  `SupportedLocale.from(language)?.code`, que conserva la región. El arreglo es el código base en el chat.

## Hecho cuando

- Cada variante recibe su registro (es-AR con voseo, según `docs/planning/BRAND-VOICE.md` §9.4), con test del prompt.
