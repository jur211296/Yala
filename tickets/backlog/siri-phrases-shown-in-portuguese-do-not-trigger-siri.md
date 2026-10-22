---
id: siri-phrases-shown-in-portuguese-do-not-trigger-siri
status: backlog
priority: medium
area: siri, l10n
created: 2026-10-16
updated: 2026-10-16
source: barrido del pt-BR del encargo 2026-10-16-capturas-video-app-store-en-pt · card `tablero-las-frases-de-siri-que-la-app-ensena-en-eol6`
---

# Las frases de Siri que la app enseña en portugués no activan Siri

`Yala/App/Intents/AppShortcutsProvider.swift` declara las frases de cada `AppShortcut` solo en español y en inglés
(comentarios «Spanish phrases» / «English phrases»). Pero la app enseña en portugués frases como «Cria um registro no
Yala», «Anota uma despesa no Yala» o «Salva uma despesa no Yala» (`siriShortcuts.siri.phrase`, `.alt1`, `.alt2`,
`tips.siri.detail`).

Inferido, no medido en un iPhone: con Siri en portugués, esas frases no casan con ningún atajo y Siri no abre Yala.

## Qué hay que hacer

1. Medirlo en un iPhone con Siri en pt-BR.
2. Si se confirma, frases en portugués en `AppShortcutsProvider` (vía `AppShortcuts.strings` por idioma, que es como
   Apple localiza las frases) y lo mismo para los demás idiomas que la app enseña.
