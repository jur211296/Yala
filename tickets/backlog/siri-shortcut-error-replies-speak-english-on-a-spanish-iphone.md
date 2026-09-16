---
id: siri-shortcut-error-replies-speak-english-on-a-spanish-iphone
status: backlog
priority: medium
area: "intents, siri, l10n"
created: 2026-09-16
updated: 2026-09-16
source: "barrido /qa del 2026-09-16 (`storekit-appgroup-siri-pro-gate`), visto en simulador"
---

# Con el iPhone en español, las respuestas de error de «Anotar con Siri» salen en inglés

## El problema, en lenguaje de usuario

Tengo el iPhone en español de Perú. Uso «Anotar con Siri» sin ser Pro y la respuesta es «Activate Yala
Pro to use Siri entry.». Si soy Pro pero Yala no entiende lo que dije, me sugiere «I didn't understand.
Try: 'Note 50 dollars on coffee'…». En cambio, cuando sí crea el borrador, me contesta en español:
«Borrador básico creado: …». La misma acción me habla en dos idiomas según cómo le vaya.

## Lo medido (simulador, 2026-09-16)

- iPhone 17 Pro con iOS 26.5, `Yala Dev` sin `-uitest`. Idioma del sistema: `AppleLanguages = (es-PE,
  en-PE)` y `AppleLocale = es_PE`. Atajos y Yala se ven en español.
- La acción se lanzó desde Atajos (Crear atajo → «Anotar con Siri»). Estas son las respuestas que se vieron:

| Situación | Cómo se construye (`Yala/App/Intents/QuickExpenseIntent.swift`) | Idioma visto |
|---|---|---|
| Usuario Free | `.result(dialog: "shortcut.siriNatural.error.proRequired")` | **inglés** |
| Pro, sin IA disponible y sin un importe que entienda el lector local | `.result(dialog: "shortcut.siriNatural.error.parsingFailedHelp")` | **inglés** |
| Pro, borrador creado sin IA | `IntentDialog(stringLiteral:)` sobre `String(localized: "shortcut.siriNatural.success.offline …")` | español |

- Las claves tienen traducción al español: están en `es.lproj` y en `es-419.lproj` (por ejemplo,
  `Yala/Resources/es.lproj/Localizable.strings:2493`, «Activa Yala Pro para usar registro con Siri.»).
- El mismo patrón aparece en la ficha de información de la acción «Registrar pago de Apple Pay» dentro de
  Atajos: «Amount / The transaction amount (from Wallet)». El resumen de esa misma acción sí sale en
  español («Registrar desde Apple Pay los campos de cantidad: Cantidad…»).
- En `QuickExpenseIntent.swift` hay **4** respuestas construidas con la clave literal: `noText`,
  `proRequired`, `noAccount` y `parsingFailedHelp`.
- Capturas: `qa/evidencia-barrido-20260916/34-siri-free-pide-pro.jpg`,
  `35-siri-pro-pasa-la-puerta-no-entiende-texto.jpg` y `36-siri-pro-borrador-creado-en-espanol.jpg`.

## Lo que NO está medido

- **La causa.** La diferencia que se ve es clave literal (`LocalizedStringResource`, que resuelve el
  sistema) frente a `String(localized:)` (que resuelve la app). No he medido por qué la primera cae en
  inglés con es-PE. Hay tres candidatas sin comprobar: la cadena de idiomas de la región (es-PE → es-419
  → es), la tabla que lee el sistema para estas claves, o `developmentRegion = en` en el proyecto.
- **Un iPhone real con Siri por voz.** Solo se vio en simulador, lanzando la acción desde Atajos.
- Si pasa también en los otros idiomas de la app.

## Criterio de hecho

- [ ] Con el sistema en es-PE, las cuatro respuestas de error de «Anotar con Siri» salen en español.
- [ ] Los nombres y las descripciones de los parámetros de las acciones de Yala salen en Atajos en el
      idioma del sistema.
- [ ] Hay una red que avisa si una respuesta nueva vuelve a salir en inglés o, si no se puede testear,
      el motivo queda escrito aquí.
