---
id: siri-intent-dual-container
status: done
priority: medium
area: "intents, siri, app-lifecycle"
created: 2026-07-04
updated: 2026-09-16
source: YalaWiki/Bugs/ok_siri-intent-dual-container-refactor.md
qa-status: passed
qa-date: 2026-09-16
---


> [!done] IMPLEMENTADO (2026-07-05, commit `49ed98a2`) — pendiente QA en TestFlight
> El fix propuesto abajo **ya se ejecutó**: el intent de Siri dejó de tocar SwiftData y se migró al patrón de cola (App Group → la app materializa), espejando Apple Pay. `SiriPendingStore` + `SiriIntentContextCache` + `SiriDraftService`; se borró el andamiaje que solo usaba Siri (`personalLocalWriteConfiguration`, `PendingIntentSaveSignal`, `scheduleIntentSaveRefire`). 19 tests verdes, build limpio, cold launch sin crash en sim. **Solo queda el e2e device/TestFlight** (Siri + LLM + red + Pro no reproducen en simulador). El cuerpo original se conserva abajo como registro de diseño.

> [!info] Follow-up del refactor de Apple Pay (2026-07-04) — CONTEXTO HISTÓRICO
> Cuando se arregló Apple Pay sacando SwiftData del intent, `SiriNaturalEntryIntent` quedó **conscientemente fuera de alcance** (decisión del owner) por ser más delicado. Comparte el MISMO mecanismo roto → era una bomba latente. Este ticket lo aisló (ya resuelto, ver callout de arriba).

# Bug (latente): el intent de Siri (`SiriNaturalEntryIntent`) usa el mismo patrón dual-container que rompía Apple Pay

## Descripción

`SiriNaturalEntryIntent` (`Yala/App/Intents/QuickExpenseIntent.swift`, ~línea 271) crea su **propio `ModelContainer`** con `SwiftDataConfiguration.personalLocalWriteConfiguration` (`cloudKitDatabase: .none`) sobre el mismo SQLite que la app, y guarda el/los `InboxDraft` él mismo. Es exactamente el patrón que en Apple Pay dejaba una **ventana de reconciliación** que vaciaba la UI al abrir la app justo después del intent (warm: solo Panel; cold: todo en 0; recuperable cerrando/reabriendo). Ver `qa_applepay-shortcut-ios27-warm-launch-datos-vacios`.

**No está reportado como roto** (Siri es Pro, se invoca manualmente y con menos frecuencia que la automatización de Apple Pay), pero el defecto estructural es el mismo. Si un usuario Pro invoca Siri con la app en background y la abre enseguida, puede ver el mismo síntoma.

## Fix propuesto (replicar el patrón de Apple Pay)

Que el intent de Siri **deje de tocar SwiftData**: parsear, encolar en App Group y notificar; la app materializa el/los `InboxDraft` al abrir. Infraestructura ya existente del fix de Apple Pay (reutilizable):
- `Yala/App/Intents/ApplePayPendingStore.swift` — cola App Group (una key por pago; `append`/`peekAll`/`remove`). Generalizar a "intents" o crear un `SiriPendingStore` análogo.
- `Yala/App/Services/ApplePayDraftService.swift` — materializa gateado por `iCloudSyncService.shared.isImportQuiescent`, enganchado en `AppBootstrapper` (bootstrap, `handleBecameActive`, trailing-edge del observer de remote-change).
- `Yala/App/Intents/ApplePayAmountParser.swift` — parseo puro sin SwiftData.

## Complejidad extra de Siri (por eso quedó fuera del primer cambio)

1. **Parseo LLM**: usa `TranscriptionParserService.parseMultiple` (network) y hoy recibe la lista de subcategorías visibles vía fetch de SwiftData (hint para el LLM). Decidir: (a) el intent hace el LLM sin ese hint y la app lo recupera con `MerchantMemory`/`matchSubcategoryByHint` al materializar, o (b) cachear los nombres de subcategoría en App Group. Fallback offline: `AmountParser`.
2. **Diálogo hablado**: devuelve `ProvidesDialog & ShowsSnippetView` — el diálogo debe seguir confirmando el monto parseado (el intent SÍ tiene el monto tras el LLM).
3. **N drafts de un texto**: un enunciado puede generar varias transacciones + dedup (`DraftDeduplicationService`). El payload de App Group debe soportar múltiples.
4. **Pro-gate**: `isProUser` (App Group) — se mantiene.

## Limpieza habilitada al migrar Siri

Una vez ni Apple Pay ni Siri creen su propio container, se puede **borrar el andamiaje del parche anterior** que hoy solo usa Siri:
- `SwiftDataConfiguration.personalLocalWriteConfiguration`
- `PendingIntentSaveSignal` (+ su consumo en `AppBootstrapper.bootstrap`/`handleBecameActive`)
- `AppBootstrapper.scheduleIntentSaveRefire`
- Breadcrumbs de `IntentSignalBreadcrumb` que ya no apliquen.

## Verificación

- Unit tests del parseo/cola (como en Apple Pay).
- Build Yala + Yala Dev.
- e2e device-only (TestFlight): invocar Siri con la app en background → abrir → borrador(es) en Bandeja sin cerrar/reabrir; sin regresión del diálogo hablado.

migrated from YalaWiki Bugs/ok_siri-intent-dual-container-refactor.md @ 1934e8ad

## QA Visual · 2026-09-16 — PASS

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev` sin `-uitest`, con «Simular Pro». El e2e de la verificación —invocar con la app viva en
segundo plano, abrirla y ver el borrador sin cerrar ni reabrir—, lanzado desde Atajos en lugar de la voz:

1. Yala Dev abierta: Panel con datos (Gastos PEN 12, cuenta PEN -12) y 1 borrador en la Bandeja. Inicio.
2. Atajos → atajo con la acción «Anotar con Siri», texto «Cafe 25» → «Borrador básico creado: Cafe 25…».
3. Volver a Yala Dev: **la misma instancia** (pid 71520 antes y después, medido con `launchctl`).
4. Panel **con sus datos** y Bandeja con **2** borradores «Cafe 25», sin cerrar ni reabrir.

**No se ejerció:** la voz real, que llega al mismo `perform()`, ni la apertura con iCloud importando a la
vez. Esa parte comparte montaje con el caso (d) de `applepay-shortcut-warm-launch-empty-data`, que sigue
en la cola de device.

Captura: [Bandeja en caliente](../../qa/evidencia-barrido-20260916/39-siri-en-caliente-segundo-borrador-sin-reiniciar.jpg).
