---
id: 2026-11-20-captura-cuenta-automatica-y-reglas
status: backlog
priority: medium
area: "captura, cuentas, foto, apple-pay, avisos-del-banco, ia"
created: 2026-11-20
updated: 2026-11-20
source: "encargo 2026-11-20-captura-cuenta-automatica-y-reglas-maquetas"
---

# La cuenta se elige sola al leer una captura, y reglas de cuenta

Jürgen (20-nov, 09:36): «Si el pantallazo dice “Tarjeta de crédito” y solo hay una cuenta con ese nombre, que se
asigne sola. Si tengo una cuenta “Zip” y el pantallazo dice “Zip”, que la IA entienda que es esa cuenta.» Y reglas:
«si viene de Apple Pay con esta tarjeta, siempre va a esta cuenta», o «si el pantallazo trae estas palabras, va a esta
cuenta».

Maquetas, medidas y preguntas: artifact «Cuenta sola al leer» (https://claude.ai/artifact/SLKNr8yEwSrW156erj6EEj) y
su copia en `docs/maquetas/captura-cuenta-automatica-y-reglas/index.html`. La sesión de diagnóstico:
`tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas-maquetas.md`. **Jürgen contesta las preguntas en la base
del artifact (colección `decisiones`, un documento por pregunta: `enfoque`, `aviso`, `varias`, `parecidos`, `donde`,
`condiciones`, `choque`, `partir`, cada uno con `valor` y `nota`).** Este ticket describe las recomendadas; si elige
otra, cambia su sección y los criterios siguen valiendo.

## Diseño recomendado (opción A: «Yala decide en tu teléfono»)

La IA solo **copia** las palabras del medio de pago que ve; la cuenta la **decide Swift** contra las cuentas y las
reglas del usuario. Es la regla que ya rige voz, Siri y chat desde la card «Yala IA: detectar medio de pago»
(2026-11-04, cabecera de `Yala/App/Logic/PaymentMethodAccountLogic.swift`): ni los nombres de las cuentas ni las
reglas salen del teléfono.

Escalera común, de lo más seguro a lo menos (la primera que decide gana):

1. **Regla del usuario** (parte 2): tarjeta de Apple Pay › comercio › palabras juntas › varias palabras › una palabra.
   Empate entre reglas que apuntan a cuentas distintas → no elige.
2. **Últimos 4 dígitos** leídos («****4417», «terminada en 4417») contra los 4 últimos dígitos del «Número de cuenta»
   (`Account.accountNumber`, que hoy existe y nadie usa para casar).
3. **Nombre entero de la cuenta** escrito en el medio de pago. Si casan varias, gana la de nombre más largo que aparece
   entero («Zip Visa» frente a «Zip» con «Zip Visa» en la imagen); empate de longitud → no elige.
4. **Palabras del nombre** (`PaymentMethodAccountLogic.account(for:among:)`, como hoy). Dos que casan → no elige.
5. **Clase de medio de pago** (efectivo / crédito / débito / tarjeta), como hoy.
6. **Única cuenta en la moneda** (`DraftBuilder.findAccount(byCurrency:)`), como hoy. En Apple Pay se mantiene la regla
   de símbolo ambiguo con la última cuenta usada (`ApplePayDraftService.resolveCurrency`).
7. **Pregunta**: «Selecciona cuenta», como hoy.

La escalera vale para **foto, Apple Pay, avisos del banco, correo del banco, voz, Siri y chat**. Hoy foto, Apple Pay y
avisos del banco solo usan la moneda.

### Cómo se ve

- Cuenta elegida sola: chip de cuenta con «✦» y una línea bajo los chips las tres primeras veces que pasa
  («Elegí **Tarjeta de crédito** porque la imagen lo dice. Toca la cuenta para cambiarla.»). Desde la cuarta, solo la
  estrella. Variantes de la línea por regla y por últimos 4 (textos en el artifact).
- Varias coinciden: chip naranja «Elige cuenta · 2 coinciden»; el selector de cuenta pone arriba «Coinciden con
  «Visa»» y debajo «Otras cuentas». Choque de reglas: «Dos reglas apuntan a cuentas distintas», cada fila con su regla.
- Ninguna: igual que hoy.
- Tras corregir a mano una cuenta en una captura con medio de pago leído: línea «¿Siempre que diga «Zip»?» con un solo
  botón «Recordar» (y una ✕ para descartar). Al tocarlo: «Listo. Cuando diga «Zip», irá a Zip Visa.».
- Reglas: sección «Reglas de captura» en Editar cuenta (filas por regla + «Añadir regla» + pie «Cuando leo un pago que
  cumple una de estas reglas, lo pongo en esta cuenta. Las reglas se aplican en tu teléfono; no se mandan a la IA.»).
  Editor «Nueva regla»: «Cuando» (Paga con Apple Pay · El texto dice · El comercio es), campo, «Todas, en cualquier
  orden» / «Juntas, tal cual», «Va a», y vista previa con un ejemplo.
- Ayuda bajo «Número de cuenta»: «Con los últimos 4 dígitos también reconozco tu tarjeta en capturas y avisos.»
- Textos nuevos en su propia tabla de strings, nunca en `Localizable.strings` (regla de `l10n.md`). Ningún botón debajo
  de otro.

## Conviene partirlo en dos

### Parte 1 · Coincidencia por nombre (sin cambios de modelo de datos)

1. **Foto**: campo nuevo `payment` en `VisionTransaction` (las palabras del medio de pago tal como salen, o null) y su
   regla en `ImageVisionService.systemPrompt`, que hoy le prohíbe al comercio ser «the bank, the wallet or the card»
   pero no le pide el medio de pago en ningún campo. La palabra se descarta si no aparece en la respuesta, como
   `paymentHint` en voz; la app distingue «el modelo dijo null» de «el campo no vino» (molde de
   `TranscriptionParserService`, `paymentHintAnswered`).
2. **Servidor**: el gateway valida `photo.read` con un esquema cerrado (`gateway/src/ai/routes.ts`, `PHOTO_SCHEMA`,
   `additionalProperties: false`). Añadir `payment` ahí y en `bench/tasks/`, desplegar a staging antes de probar. La
   app funciona igual sin el campo.
3. **Avisos del banco**: usar `cardLast4`, que `BankNoticeParser` ya lee y nadie consume
   (`Yala/App/Logic/AtajoBanco/BankNoticeReading.swift`).
4. **Apple Pay**: dato opcional «Tarjeta» en la acción (`QuickExpenseIntent`, hoy solo `amount` y `merchant`), guardado
   en `ApplePayPendingExpense` y cruzado por nombre en la escalera. Paso nuevo en la guía de Apple Pay
   (`YalaStepGuide`) para pasarlo, y aviso suave para quien tiene el atajo viejo.
5. Escalera común (pasos 2–7) en un solo sitio, llamada por `VisionDraftFactory`, `ApplePayDraftService`,
   `BankNoticeDraftService`, `BankEmailDraftService` y los tres de `TranscriptionParserService`.
6. Chip con estrella, línea de «por qué» (contador de tres por persona en `AppPreferences`) y selector con «Coinciden
   con…». El borrador guarda por qué se eligió la cuenta (motivo + palabra) para pintar la línea.

### Parte 2 · Reglas de cuenta

1. **Primero, medir en el iPhone 14 con una tarjeta real** qué texto entrega el dato «Tarjeta» de la automatización de
   Wallet (nombre de Wallet o algo genérico). Lo dicen reportes de usuarios, no Apple. Si no sirve para distinguir
   tarjetas, la condición «Paga con Apple Pay» se cae de esta versión y se dice.
2. Modelo nuevo de regla (cuenta, tipo de condición, valor, modo de palabras, fecha) en SwiftData con sus reglas de
   CloudKit (`swiftdata-cloudkit.md`: valores por defecto, relación opcional) y su paso por el borrado de cuenta,
   «Vaciar mis datos», exportar e importar.
3. «Reglas de captura» en Editar cuenta, editor, «Recordar» al corregir y aviso de regla repetida («Ya tienes esta
   regla para Interbank Visa. ¿La paso a Zip Visa?»).
4. Choques: la más concreta gana; empate → pregunta con el motivo en el selector.

La parte 2 toca sincronización y migración: pasa por el revisor con la lista de confiabilidad del paso 4 bis de
`/gate`.

## Criterios de aceptación

Parte 1:
- Con cuentas «Cuenta Principal», «Efectivo» y «Tarjeta de crédito» (semilla `ficha`), una foto cuyo medio de pago es
  «Tarjeta de crédito» sale con esa cuenta, el chip con estrella y «Guardar» encendido.
- Cuentas «Zip» y «Zip Visa»: «Zip» → Zip; «Zip Visa ****4417» → Zip Visa; «Visa» con «BCP Visa» e «Interbank Visa» →
  sin cuenta y chip «Elige cuenta · 2 coinciden».
- «****4417» elige la cuenta cuyo número de cuenta acaba en 4417, aunque el nombre no aparezca.
- Una palabra que no está escrita en la respuesta de la IA no elige nada.
- Sin el campo nuevo en el servidor, la foto se comporta como hoy.
- Un aviso del banco con «****4417» y un pago de Apple Pay con la tarjeta «Interbank Visa» eligen su cuenta sin
  conexión.
- La línea de «por qué» sale tres veces y luego no; la estrella sigue.
- Ningún nombre de cuenta viaja en la petición de la foto (comprobado sobre el cuerpo de la petición).

Parte 2:
- Una regla «El texto dice “zip”» manda una captura con «Zip» a Zip Visa aunque exista una cuenta llamada «Zip».
- Corregir la cuenta y tocar «Recordar» crea la regla; la siguiente captura con esa palabra va sola.
- Dos reglas de igual concreción hacia cuentas distintas → no elige y el selector muestra las dos con su regla.
- Las reglas se sincronizan entre dos aparatos y desaparecen al borrar su cuenta.

## Pruebas previstas

- Unitarias de la escalera (pura, sin `@Model`): cada peldaño, el desempate por longitud, últimos 4, empates, palabra
  inventada descartada. Molde: las pruebas de `PaymentMethodAccountLogic`.
- Unitarias de decodificación de `VisionTransaction` con y sin `payment`.
- Paridad del prompt y del esquema del gateway (`bench/tasks/` y la prueba del gateway de `PHOTO_SCHEMA`).
- XCUITest de «Esto leí» con `-uitest-image-result` y un perfil nuevo que devuelva medio de pago: chip con estrella,
  línea y «Guardar» encendido; y el caso de dos coincidencias con el selector. Ojo: el seam de hoy rellena la cuenta a
  mano (`UITestDemoAccountLogic` en `ImageSelectionView.uiTestDrafts`), así que el perfil nuevo no puede pasar por ahí
  o la prueba saldría verde sin la escalera.
- Parte 2: unitarias de concreción y choques; XCUITest de «Recordar»; pruebas de borrado y exportación con reglas.
- Device-QA en el iPhone 14: Apple Pay real con la tarjeta y un aviso del banco reales.

## Fuera de alcance

- Recordar la cuenta por comercio sin que la persona cree la regla.
- Mandar nombres de cuentas o reglas a la IA (opción B del artifact).
- `ImageOCR` (`ScreenshotSingleExtractor`, `ScreenshotListExtractor`): no lo llama nadie en producción; si se quiere
  retirar, card aparte.
