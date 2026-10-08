---
id: suggestions-rewriter-drops-german-and-polish-rewrites
status: backlog
priority: medium
area: chat, ai, l10n
created: 2026-10-07
updated: 2026-10-07
source: banco de chat.rewrite (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md)
---

# Las sugerencias del chat en alemán (y a veces en polaco o inglés) caen siempre a las fijas

## Qué le pasa al usuario

Con Yala en alemán, las sugerencias del chat que reescribe la IA no se enseñan nunca: la app las descarta y pone las
fijas, con cualquier modelo.

## Lo medido (2026-10-07)

- `SuggestionsRewriterService.isValid` toma por nombre propio toda palabra con mayúscula que no sea la primera. En alemán
  todos los sustantivos van con mayúscula («Ausgaben», «Monat»), así que ninguna reescritura pasa.
- En polaco no casan los nombres declinados («w Biedronce» frente a «Biedronka»); en inglés, los meses («October»).
- El banco lo replica en `gateway/bench/lib/chatRewrite.ts` y lo mide aparte («lo que la app conserva»).

## Hecho cuando

- Una reescritura alemana correcta pasa el validador y se enseña; una con un comercio inventado sigue sin pasar.
- Test con frases reales en alemán, polaco e inglés.
