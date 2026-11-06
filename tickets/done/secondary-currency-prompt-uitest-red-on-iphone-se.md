---
id: secondary-currency-prompt-uitest-red-on-iphone-se
status: done
priority: low
area: "testing, currency"
created: 2026-10-03
source: hallazgo de account-form-as-medium-detent-sheet (2026-10-03)
updated: 2026-11-05
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

## Medido en 2.1 (triage 2026-10-08)

- `SecondaryCurrencyPromptUITests.dropSecondaryCurrency` sigue volviendo con `app.navigationBars.buttons.firstMatch.tap()` (ahora `:57`). El fichero no tiene commits desde el 2026-10-03, así que la hipótesis sigue sin medir y sin arreglo.

Triage 2026-10-08: abierto · low → low · el test no ha cambiado (sigue el firstMatch de la barra) y solo afecta al carril del SE, no al gate.

## 2026-11-05 · cerrado en el lote T3

Re-medido en el iPhone SE (3.ª gen, iOS 27.2): con el test sin tocar, **verde** (1 de 1). La hipótesis no se pudo ver
en rojo, pero la fragilidad que señalaba el ticket seguía: se volvía con «el primer botón de la barra». Ahora se toca el
«‹» del sistema por su identificador (`BackButton`; Divisa no pinta el suyo, `ProfileView.paintsOwnBackButton`) y el
test exige que exista. Verde 3 de 3 en el SE y 3 de 3 en el iPhone 17 Pro (iOS 27.2), y en el lote.
