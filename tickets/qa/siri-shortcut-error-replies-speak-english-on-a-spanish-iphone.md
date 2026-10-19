---
id: siri-shortcut-error-replies-speak-english-on-a-spanish-iphone
status: qa
priority: medium
area: "intents, siri, l10n"
created: 2026-09-16
updated: 2026-10-18
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

## Medido en 2.1 (triage 2026-10-08)

- `QuickExpenseIntent.swift`: las respuestas de error siguen como clave literal en `.result(dialog:)`, en `:201` (noText), `:209`
  (proRequired), `:224` (noAccount) y `:261` (parsingFailedHelp). El éxito usa `String(localized:)` (`:292-314`).
- La causa sigue sin medir.

Triage 2026-10-08: abierto · medium → medium · Las 4 respuestas de error de QuickExpenseIntent siguen con la clave literal en .result(dialog:), y el éxito con String(localized:); el único commit posterior en Intents (33878deb5) no las tocó.

## Medido en el simulador (lote 15 de la auditoría UX 2.2, 2026-10-15)

iPhone 17 Pro, iOS 27.0, sistema en `es-PE` (`defaults read -g AppleLanguages` = `es-PE`), Yala Dev. Al tocar «Anotar
con Siri» en Atajos › Yala Dev, **la pregunta también sale en inglés**: «What do you want to record?», con «Text»,
«Cancel» y «Done». En la misma pantalla, los títulos de las cinco acciones de Yala salen en español («Anotar con
Siri», «Registrar por voz»…). O sea: no son solo las cuatro respuestas de error, y la pregunta usa la misma
`LocalizedStringResource` que el título. El proceso que corre el intent resuelve el idioma de Yala como inglés aunque
Atajos lo pinte en español. Captura: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-15-desde-fuera/capturas/15.6-01-anotar-con-siri-pregunta.png`.
Causa sin aislar; dos sospechas que se pueden medir: `CFBundleDevelopmentRegion = en` sin `CFBundleLocalizations` en el
`Info.plist`, y `es-PE` sin casar con `es-419` en ese proceso.

## Hecho en 2.2 (2026-10-18, card «Integrar Yala con el nuevo Siri con IA de iOS 27»)

**Medido en el SDK de iOS 27.1**: `IntentDialog(stringLiteral:)` lleva `@_semantics("localization_key.init_literal")`.
`.result(dialog: "clave")` y `$text.requestValue("clave")` mandan una CLAVE que resuelve el sistema, y con es-PE caía en
el idioma de desarrollo (`developmentRegion = en`). Lo que la app resuelve con `String(localized:)` salía en español.
Por qué el sistema elige inglés con es-PE no está aislado; no hace falta para el arreglo.

**Arreglo**: las cuatro respuestas de error (`noText`, `proRequired`, `noAccount`, `parsingFailedHelp`) y la pregunta
«¿Qué quieres registrar?» se traducen en la app y llegan ya resueltas (`IntentSpeech`, en `SiriQueryIntents.swift`).
Las acciones nuevas de 2.2 contestan igual.

**Red**: `IntentSpeechTests` (en `YalaTests/SiriIOS27Tests.swift`): ningún `dialog: "…"` ni `requestValue("…")` literal
en los ficheros de intents; las cuatro respuestas y la pregunta pasan por `IntentSpeech`; existen en es, es-419, es-ES,
es-AR y pt-BR y no son el inglés.

**Sin tocar**: los títulos de los parámetros en la ficha de Atajos («Amount / The transaction amount») son metadatos que
resuelve el sistema y no se pueden traducir desde la app en tiempo de ejecución. Se miden en el simulador (ver abajo).

### Guion de iPhone (Jürgen, 3 min)

1. iPhone en **español**, Siri en español. Yala **sin Pro** (o con el interruptor Pro apagado en Yala Dev).
2. Di «Oye Siri, **Anota un gasto en Yala**».
3. Siri pregunta «**¿Qué quieres registrar?**» (antes: «What do you want to record?»). Contesta «café cinco soles».
4. Siri contesta «**Activa Yala Pro para usar registro con Siri.**» en español (antes: «Activate Yala Pro…»).

Si el paso 3 y el 4 salen en español, el ticket pasa a `done`.

**Medido en el simulador (2026-10-18, iPhone 17 Pro, iOS 27.0, `es-PE`, Yala Dev sin Pro, atajo con la acción «Anotar
con Siri»)**: antes del cambio, «What do you want to record?» y «Activate Yala Pro to use Siri entry.»; después, «¿Qué
quieres registrar?» y «Activa Yala Pro para usar registro con Siri.». Siguen en inglés los botones «Cancel / Done» y el
«Text» del campo: los pinta el sistema (el «Text» es el título del parámetro, metadato que resuelve el sistema).
