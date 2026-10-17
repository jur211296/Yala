---
id: ai-provider-still-named-outside-the-consent-notices
status: backlog
priority: low
area: "ia, privacidad, l10n"
created: 2026-10-17
updated: 2026-10-17
source: "pulido del 2026-10-17 (avisos de IA sin «OpenAI»), hallazgo fuera de alcance"
---

# Dos textos de la app siguen nombrando a OpenAI fuera de los avisos de consentimiento

## El problema, en lenguaje de usuario

Desde el 17-oct los avisos de IA dicen «un servicio de IA» y el nombre del proveedor queda en la Política de
privacidad. Pero dos pantallas de la app lo siguen nombrando, en los 16 idiomas:

- **Ajustes › Privacidad de la IA**, el pie de la lista (`aiPrivacy.footerHint`): «…y llegan a OpenAI a través de
  nuestro servidor».
- **Perfil › Datos personales**, el texto de privacidad (`profile.privacyDesc`): «…pasa por nuestro servidor hasta
  OpenAI, que lo procesa».

Además `insights.aiCaption` («OpenAI analiza tus datos agregados…») existe en los 16 idiomas pero ningún código la usa
(medido con grep el 17-oct): es una cadena muerta.

## Qué hay que decidir

La decisión de Jürgen del 17-oct (09:09) habla de los **avisos y pistas de consentimiento**. Estas dos pantallas son de
consulta, como la política, y el encargo no las incluía. Dos opciones:

1. **(Recomendada)** Quitarlo también aquí, con «un servicio de IA», para que la app no nombre al proveedor en ningún
   sitio y un cambio de proveedor solo toque la política. Ampliar `AIConsentProviderNameTests` a esas dos claves.
2. Dejarlo: son pantallas de detalle y nombrarlo ahí es información útil.

En los dos casos, `insights.aiCaption` se puede borrar de los 16 idiomas.

## Hecha cuando

La decisión está tomada y, si es la 1, ninguna cadena visible nombra al proveedor y el test lo protege.
