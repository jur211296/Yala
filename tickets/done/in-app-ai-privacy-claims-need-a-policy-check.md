---
id: in-app-ai-privacy-claims-need-a-policy-check
status: done
priority: high
area: "l10n, privacy, ai"
created: 2026-10-10
updated: 2026-10-10
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

## Resuelto (2026-10-10)

Jürgen eligió la opción B (10-oct, 16:25): no esperar a la política y decir ya algo cierto.

- La tarjeta del último paso del onboarding dice «IA a través de nuestro servidor» y debajo «Tú decides
  si usarla», en los 16 idiomas. Las claves nuevas son `onboarding.privacyAIShort` y
  `onboarding.privacyAIDetail`; `onboarding.privacyNoSharingShort` desaparece.
- Las dos claves sin uso (`onboarding.privacyNoSharing`, `insights.activateAIDisclaimer`) se borran, con
  sus accesores de `L10n.swift`. Un grep confirmó que nadie las leía.
- `PrivacyCopyForbiddenPhrasesTests` caza ahora las tres promesas en todos los idiomas. «IA segura» y sus
  traducciones cuentan solo como frase entera, para no cazar «copia segura».

Medido en simulador iPhone SE (3.ª gen, iOS 27.0) en es-419, en y pl: la tarjeta entra sin truncar.
