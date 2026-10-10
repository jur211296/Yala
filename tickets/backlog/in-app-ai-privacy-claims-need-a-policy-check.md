---
id: in-app-ai-privacy-claims-need-a-policy-check
status: backlog
priority: high
area: "l10n, privacy, ai"
created: 2026-10-10
source: "Encargo 2026-10-10-app-privacy-copy-data-never-leaves-device (hallazgo), medido sobre origin/2.1 349f3145c"
---

# Lo que la app promete sobre la IA no está contrastado con la política

El encargo de los textos de privacidad corrigió las frases que decían que los datos no salen del
dispositivo. Dejó fuera, a propósito, las que prometen algo sobre **qué hace la IA con los datos**,
porque eso lo decide la política de privacidad (card bis6 de Lola) y no el código.

Medido en es-419 (las 16 `.lproj` tienen las mismas claves):

| Clave | Texto | Dónde se ve |
|---|---|---|
| `onboarding.privacyNoSharingShort` | «IA segura» | Onboarding, último paso, rejilla 2×2 (`OnboardingView.swift:1222`) |
| `onboarding.privacyNoSharing` | «Las funciones de IA no comparten ni almacenan datos sensibles» | Sin uso en código |
| `insights.activateAIDisclaimer` | «Solo se envían datos resumidos a OpenAI (totales, porcentajes, tendencias). Nunca se comparten tus gastos individuales ni datos personales.» | Sin uso en código |

Lo que se sabe del código: la voz, el escaneo de recibos y el chat mandan su contenido a nuestro
gateway, que lo reenvía a OpenAI (`ProxyClientFactory`, `gateway/src/ai/providers/openai.ts`). El
escaneo manda la imagen del recibo, que es un gasto individual: la tercera frase no es verdad para él.

## Qué hace falta

1. Que la política de 2.1 (Lola, bis6) diga qué guarda OpenAI y durante cuánto.
2. Con eso, Jürgen decide el texto de la tarjeta «IA segura» y si las dos claves sin uso se borran o
   se corrigen.
3. Si se corrigen, añadir sus frases a `PrivacyCopyForbiddenPhrasesTests`.

## Hecho cuando

Ninguna frase visible de la app promete sobre la IA algo que la política no diga, en los 16 idiomas.
