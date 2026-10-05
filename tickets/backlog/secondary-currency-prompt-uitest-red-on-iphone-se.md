---
id: secondary-currency-prompt-uitest-red-on-iphone-se
status: backlog
priority: low
area: "testing, currency"
created: 2026-10-03
source: hallazgo de account-form-as-medium-detent-sheet (2026-10-03)
---

# `test_secondaryCurrencyPromptAppearsForNonPreferred` sale rojo en el iPhone SE

## Lo medido

- `SecondaryCurrencyPromptUITests.test_secondaryCurrencyPromptAppearsForNonPreferred` falla **2 de 2**
  en `YalaLane-Adapt-iPhone-SE` (iOS 27.0), con `No apareció la cuenta 'Ahorros USD' del seed.`
  (`SecondaryCurrencyPromptUITests.swift:34`). Corrida aislada, centinela en 0.
- En `YalaLane-Adapt-iPhone-ProMax` pasa (1 de 1), con el mismo build.
- En el momento del fallo la pantalla es el **Panel**, no Perfil › Cuentas: la jerarquía del adjunto
  muestra «Disponible», «Nuevo registro» y la tarjeta de pérdida por tipo de cambio.
- El formulario de cuenta **no llega a abrirse**: el fallo es anterior, así que no lo causa el cambio
  de detent del formulario que lo destapó.

## Hipótesis (sin medir)

`dropSecondaryCurrency` vuelve de Divisa con `app.navigationBars.buttons.firstMatch.tap()`. En el SE
ese primer botón puede ser el cierre de la hoja de Perfil en vez del «atrás», y entonces la hoja se
cierra y el test sigue desde el Panel. Para confirmarlo, mirar el vídeo del xcresult o buscar el
botón de atrás por identificador.

## Por qué importa

El gate corre en el iPhone 17 Pro, donde pasa, así que hoy no bloquea a nadie. Pero cualquier sesión
que verifique en el SE se encuentra un rojo que parece una regresión del formulario de cuenta.
