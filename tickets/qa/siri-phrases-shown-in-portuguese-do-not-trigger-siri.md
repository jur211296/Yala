---
id: siri-phrases-shown-in-portuguese-do-not-trigger-siri
status: qa
priority: medium
area: siri, l10n
created: 2026-10-16
updated: 2026-10-18
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

## Hecho en 2.2 (2026-10-18, card «Integrar Yala con el nuevo Siri con IA de iOS 27»)

**Medido antes del cambio**, en el bundle compilado (`Yala.app/Metadata.appintents/root.ssu.yaml`, lo que Siri entrena
por idioma): los 16 idiomas recibían las mismas 8 frases de cada acción, en español e inglés. En portugués, ninguna de
las que enseña la app.

**Arreglo**: `Yala/Resources/AppShortcuts.xcstrings` traduce las frases de `AppShortcutsProvider` a `pt`, `pt-BR` y
`pt-PT` (24 frases, también las de las preguntas nuevas «Quanto gastei no Yala» y «Quanto tenho no Yala»). Medido
después: en portugués Siri entrena solo las frases en portugués; en los otros 13 idiomas, las mismas de antes.

**Red**: `YalaTests/SiriIOS27Tests.swift` › `SiriPhrasesPortugueseTests` lee el `root.ssu.yaml` del bundle y exige que
cada frase que enseña la app en pt/pt-BR/pt-PT (`siriShortcuts.siri.*`, `siriShortcuts.phrase.*`, `tips.siri.detail`)
esté entrenada para su acción, y que es/en y los siete idiomas de L15-5 sigan con las frases del código.

**Fuera, a propósito**: alemán, francés, italiano, japonés, neerlandés, polaco y chino siguen como estaban (decisión
L15-5, card `tablero-ux-2-2-l15-5-en-10-de-los-16-idiomas-nin-wewa`).

### Guion de iPhone (Jürgen, 5 min)

Siri por voz no existe en el simulador: hace falta el iPhone.

1. Instala el TestFlight de 2.2 que traiga este cambio.
2. Ajustes › General › Idioma y región › añade **Português (Brasil)** y ponlo primero. Ajustes › Siri › Idioma: **Português (Brasil)**.
3. Abre Yala una vez y ciérrala.
4. Di «Oi Siri, **Anota uma despesa no Yala**». Debería preguntarte qué quieres registrar.
5. Di «Oi Siri, **Registre no Yala**». Debería abrir Nuevo registro.
6. Vuelve el iPhone a español.

Si los pasos 4 y 5 funcionan, el ticket pasa a `done`.
