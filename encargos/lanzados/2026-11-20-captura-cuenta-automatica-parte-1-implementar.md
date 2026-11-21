Yala
# La cuenta se elige sola al leer una captura: escalera en el teléfono y la IA como segunda capa (parte 1)
---
toca: Yala/App/Logic/PaymentMethodAccountLogic.swift,Yala/App/Logic/CuentaSolaAlLeer/,Yala/App/Services/ImageVision/ImageVisionService.swift,Yala/App/Services/ImageVision/VisionDraftFactory.swift,Yala/App/Services/DraftBuilder.swift,Yala/App/Services/ApplePayDraftService.swift,Yala/App/Logic/AtajoBanco/BankNoticeDraftService.swift,Yala/App/Logic/AtajoBanco/BankNoticeReading.swift,Yala/App/Services/BankEmailDraftService.swift,Yala/Services/TranscriptionParserService.swift,Yala/App/Intents/QuickExpenseIntent.swift,Yala/App/Intents/ApplePayPendingStore.swift,Yala/App/Views/Settings/ApplePayAutomationGuideView.swift,Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/UITestSharedImageStage.swift,Yala/App/Views/Image/CuentaSolaAlLeer/,Yala/App/Services/AppPreferences.swift,Yala/App/Views/Accounts/AccountFormView.swift,Yala/Utils/L10n+CuentaSolaAlLeer.swift,Yala/Resources/*.lproj/CuentaSolaAlLeer.strings,gateway/src/ai/routes.ts,gateway/bench/tasks/photo.read.ts,gateway/test/ai.photo-cuenta.test.ts,YalaTests/CuentaSolaAlLeer/,YalaUITests/CuentaSolaAlLeer/,tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas.md,tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Implementa la **parte 1** del ticket `tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas.md` (maquetas: artifact «Cuenta sola al leer», https://claude.ai/artifact/SLKNr8yEwSrW156erj6EEj, copia en `docs/maquetas/captura-cuenta-automatica-y-reglas/index.html`). Léelo entero antes de empezar.

## Decisión de Jürgen (20-nov, 17:00, registrada)

Todas las recomendadas del artifact valen (aviso al elegir sola, varias coincidencias, nombres parecidos, dónde viven las reglas, condiciones, choques y partir en dos), **salvo el enfoque: va A + B**, no solo A. Sus palabras: «creo que aplicaría A y B. No depender solo del teléfono, sino que la IA también sea una capa de seguridad».

Cómo se combinan (criterio tomado por Frank; si al construir ves un caso que lo contradiga, decídelo con la opción más segura y anótalo en «Decidido sin consultar»):
1. **Primero decide el teléfono** con la escalera del ticket (pasos 2–7 en esta parte; las reglas del paso 1 llegan en la parte 2).
2. **Después, en foto y chat** (los que ya pasan por la IA y necesitan conexión), la IA recibe los **nombres de las cuentas** y su clase y moneda, **sin saldos, sin números de cuenta ni últimos 4**, y devuelve, además de las palabras del medio de pago, la cuenta que cree (solo un nombre de la lista o null).
3. Teléfono y IA coinciden → la cuenta va sola (chip con «✦» y la línea de «por qué»).
4. El teléfono no decide y la IA propone una cuenta **que existe** y cuyas palabras aparecen en lo leído → se preselecciona como **sugerida** (chip distinto, sin «Guardar» automático en el sentido de «elegida sola»; textos nuevos con el tono del artifact). Una cuenta que no está en la lista se descarta.
5. Se contradicen → no elige; chip «Elige cuenta» y el selector muestra arriba las dos con su motivo («Lo dice la imagen» / «Lo sugiere Yala IA»).
6. Apple Pay, avisos del banco y correo del banco no pasan por la IA: siguen solo con la escalera y funcionan sin conexión.
7. Sin el campo nuevo en el servidor o sin conexión, la foto se comporta como la escalera sola.

Esto **sustituye** la línea de «Fuera de alcance: mandar nombres de cuentas o reglas a la IA (opción B)» del ticket y la cabecera de `PaymentMethodAccountLogic.swift` que dice que los nombres no salen del teléfono: actualiza ambas con la nueva regla (los nombres sí viajan en foto y chat; saldos, números y reglas todavía no). En la parte 2, las reglas también viajarán a la IA como texto; esta sesión deja el hueco preparado, sin construir reglas.

## Qué construir (parte 1 del ticket + la capa B)

- Todo el bloque «Parte 1 · Coincidencia por nombre» del ticket (campo `payment` en `VisionTransaction`, `cardLast4` de avisos, «Tarjeta» opcional en `QuickExpenseIntent` con su paso en la guía de Apple Pay, escalera común en un solo sitio en `Yala/App/Logic/CuentaSolaAlLeer/`, chip, línea de «por qué» con contador y selector «Coinciden con…», ayuda bajo «Número de cuenta»).
- La capa B: nombres de cuentas en la petición de foto (y en la del chat si su ruta pasa por `TranscriptionParserService`; si el chat va por otro archivo fuera del `toca`, déjalo para la parte 2 y anótalo), campo de salida de cuenta en el prompt de `ImageVisionService` y en `PHOTO_SCHEMA` del gateway, combinación de los puntos 3–5.
- Gateway: despliega a **staging** para probar. Producción del gateway solo con el OK registrado de deploys de IA que ya existe en el repo; si no cubre este cambio, deja el PR listo y pregunta.
- Textos nuevos solo en `CuentaSolaAlLeer.strings` (16 idiomas), nunca en `Localizable.strings`. Ningún botón debajo de otro. Revisa claro y oscuro.

## Criterios de aceptación

Los de la parte 1 del ticket, **cambiando** «Ningún nombre de cuenta viaja en la petición de la foto» por: «En la petición de la foto viajan los nombres de las cuentas y su clase y moneda, y **nunca** saldos, números de cuenta ni últimos 4 (comprobado sobre el cuerpo de la petición)». Además:
- Teléfono y IA coinciden → sola con «✦».
- Solo la IA propone una cuenta existente → sugerida, distinguible de «elegida sola».
- La IA propone un nombre que no existe → se ignora.
- Teléfono e IA discrepan → no elige y el selector muestra las dos con su motivo.
- Sin conexión, Apple Pay y un aviso del banco con «****4417» eligen su cuenta.

## Pruebas

Las del ticket para la parte 1, más unitarias de la combinación teléfono + IA (los cinco casos de arriba) y la prueba del gateway del esquema con el campo de cuenta. Ojo con el seam de UI test que rellena la cuenta a mano (`UITestDemoAccountLogic` en `ImageSelectionView.uiTestDrafts`): el perfil nuevo no puede pasar por ahí. Device-QA en el iPhone 14 por DeviceMCP para Apple Pay y aviso del banco reales si están disponibles; si no, anótalo. Puedes usar un segundo simulador en la Max si otra sesión ocupa el primero.

## Al cerrar

El ticket queda con la parte 1 en `tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas.md` y la **parte 2 (reglas de cuenta)** sigue en backlog, actualizada con la decisión A + B (las reglas también viajan a la IA como texto, la escalera manda) y con la **lista exacta de archivos** que tocará (modelo SwiftData, Editar cuenta, borrado de cuenta, «Vaciar mis datos», exportar e importar), para encolarla con un `toca` acotado.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (nocturno, bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Los nombres de las cuentas viajan a la IA de la foto en los dos modos?** → Solo con la cuenta en la nube
(`CloudSyncFlags.storageMode == .cloud`). En iCloud privado la foto usa la escalera sola.
Por qué: el permiso de voz y foto dice que en privado solo se envía «la foto»; la regla «Modo nube» de
`ai-gateway.md` permite leer lo que haga falta solo en la nube, y versionar el permiso es una decisión de Jürgen.
Es la opción más segura que pide el encargo. Alternativa descartada: mandarlos siempre (rompe lo que promete el permiso).

**D2 · ¿Chat de Yala IA con la capa B?** → Fuera de esta parte. Su petición se arma en `ChatAssistantService.swift`,
fuera del `toca`; queda anotado para la parte 2. Voz, Siri, chat y correo sí ganan la escalera (pasos 2–5) porque todos
pasan por `DraftBuilder.findAccount(paymentMention:)`.

**D3 · ¿Dónde viven chip «✦», línea de «por qué» y «Coinciden con…»?** → La decisión de la escalera se guarda en
memoria en la hoja de foto (sin tocar el modelo de datos) y llega por el entorno a `VoiceDraftReviewCard`,
`MultiDraftReviewList` y `AccountSelectorSheet`, que están fuera del `toca` pero no los toca ningún PR abierto.
Apple Pay, avisos y correo eligen la cuenta sola en la Bandeja sin chip nuevo (su hoja no está en el `toca`).

**D4 · ¿Qué es «sugerida»?** → La cuenta de la IA se preselecciona, el chip dice «sugerida» en otro estilo y la línea de
«por qué» sale siempre («Lo sugiere Yala IA. Revísala antes de guardar.»); «Guardar» queda encendido. Sin estrella.

**D5 · ¿Cuándo vale la cuenta de la IA?** → Si casa con el nombre exacto (sin tildes ni mayúsculas) de una cuenta
elegible y al menos una palabra de su nombre está escrita en el medio de pago leído. Si no, se ignora.

**D6 · ¿La cuenta elegida por moneda lleva estrella?** → No: es la regla de siempre y va callada, como hoy. La estrella
es para lo que dice la imagen (últimos 4, nombre, palabras, clase) o el aviso.

**D7 · ¿Últimos 4 con dos cuentas que acaban igual?** → No elige y el chip dice «2 coinciden».

**D8 · Contador de la línea de «por qué»** → `AppPreferences`, sube al enseñar la línea en un borrador; tres por persona
y aparato (no se sincroniza).

**D9 · Dato «Tarjeta» de Apple Pay** → Parámetro opcional fuera del resumen de la acción (sale en «Mostrar más»); el
paso de la guía explica cómo conectarlo. El aviso del atajo viejo va en la guía, sin detectar nada.

**D10 · Banco de la foto** → No se corre (cobra del saldo de producción). La prueba del gateway fija el esquema y que el
prompt del Swift pide los dos campos.

**D11 · ¿Mismo nombre de ticket en done y backlog?** → La parte 1 se queda con el id original en `tickets/done/` y la
parte 2 pasa a `tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md`.
Por qué: en `docs/TICKETS.md` el nombre del fichero es el id, y dos ficheros con el mismo id se pisan en el índice.

**D12 · Ficheros fuera del `toca`** → `VoiceDraftReviewCard`, `MultiDraftReviewList`, `AccountSelectorSheet` (chip y
selector), `.claude/rules/ai-gateway.md` (decía que los nombres no salen del teléfono), `qa/coverage-index.json`,
`docs/TICKETS.md` y `YalaTests/PaymentMethodAccountLogicTests.swift` (una prueba fijaba la regla vieja «Yape» + «Yape
BCP» → ninguna, que la escalera cambia a propósito). Medido: ningún PR abierto los toca.

**D13 · Avisos del banco: ¿solo `cardLast4`?** → También el nombre del banco como medio de pago («BCP» → «BCP Soles»),
como ya hacía el correo. Si casan varias, la moneda desempata; si no decide, la regla de siempre.
