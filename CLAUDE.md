# Yala (iOS)

Yala es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack

- Swift, SwiftUI, SwiftData (.xcodeproj)
- **Target iOS 26+** — APIs nativas (Liquid Glass, ToolbarSpacer, etc.)
- Schemes: **Yala** (producción) | **Yala Dev** (con toggle Pro y `DEV_BUILD`) | Tests: YalaTests
- Simulador: **iPhone 17 Pro**
- 20 SwiftData models. ModelContainer via `SwiftDataConfiguration`. Divisas SSOT en `Yala/Utils/CurrencyUtils.swift` (`CurrencyCode`, 48 divisas).

## Docs (leer cuando sea relevante)

| Archivo | Propósito |
|---------|-----------|
| `$VAULT/planning/CODEBASE-MAP.md` | Tablas de Services / Calculators / ViewModels / Tests con paths |
| `$VAULT/planning/UI-PATTERNS.md` | Design System, gotchas de SwiftUI, formularios, glass |
| `$VAULT/planning/SWIFT-STYLE.md` | ViewModel pattern, idioms modernos, DS.Semantic / DS.Gradients, "añadir preferencia" |
| `$VAULT/planning/L10N.md` | 16 locales, workflow para añadir keys, tests CI |
| `$VAULT/planning/DEVICE-QA.md` | Setup Yala Dev + agent-device patterns |
| `$VAULT/planning/BRAND-VOICE.md` | Tono y estilo de marca |
| `$VAULT/planning/WORKFLOW.md` | Workflow detallado de skills |
| `$VAULT/planning/PROJECT.md` · `ROADMAP.md` · `STATE.md` | Producto, plan, progreso |
| `$VAULT/planning/DECISIONS.md` | Registro de decisiones arquitectura |
| `$VAULT/planning/QA-SCENARIOS.md` | Escenarios de prueba |
| `qa/README.md` | QA automatizado (agent-device + suites) |

`$VAULT` = `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/` (Obsidian, sync vía iCloud).

Carpetas del vault: `Backlog/` · `Ideas/` · `Bugs/` · `Attachments/` · `planning/`. Skills: `/backlog`, `/spec`, `/promote`.

## General Rules

- Hacer SOLO los cambios explícitamente solicitados. No mover UI, refactorizar adyacente, ni añadir mejoras no pedidas.
- Antes de editar, listar archivos a modificar y qué cambia. Esperar aprobación si son más de 3 archivos.
- Confirmar que rutas referenciadas existen antes de proceder. Si no, preguntar al usuario.
- Evitar refactors grandes innecesarios. No introducir dependencias nuevas sin justificación.
- Mantener separación UI / lógica / SwiftData.

## Reglas inviolables

### Errores y unwraps
- NUNCA `try?` que silencia. Usar `do { try } catch { print("Service: Error: \(error)") }`.
- NUNCA force unwraps sin validación previa (`guard let x = ... else { return }`).
- Logs SIEMPRE dentro de `#if DEBUG` — nunca datos sensibles en producción.
- API keys: NUNCA hardcodear. Usar `Secrets.xcconfig` + `Info.plist` via `Bundle.main.object(forInfoDictionaryKey:)`.

### SwiftData
- SIEMPRE `@Relationship(inverse:)` en relaciones bidireccionales.
- Verificar `deleteRule` en cada relación.
- `@MainActor` en servicios que manipulan `ModelContext`.
- **CloudKit compat:** NUNCA `@Attribute(.unique)`, propiedades con default obligatorias, ni relaciones non-optional.

### State Management (SwiftUI)
- `@Observable` SIEMPRE con `@MainActor`. `@State` SIEMPRE `private`.
- NUNCA `Binding(get:set:)` en body — usar `@Binding` + `.onChange()`.
- NUNCA `@AppStorage` dentro de `@Observable` (no triggerea updates).
- Preferir `@Observable` + `@State`/`@Bindable` sobre `ObservableObject`/`@Published`/`@StateObject`.
- **Preferencias persistentes → `AppPreferences` inyectado via `@Environment`.** NUNCA `@AppStorage` directo en views nuevas.

### Gotchas críticos
- **`containerRelativeFrame(.horizontal)` en `ScrollView(.vertical)` con `.contentMargins`** → deadlock de layout, splash nunca dismissa, sin crash log. Usar `onGeometryChange`. Detalles en UI-PATTERNS.md.
- **`YalaFormatter` no auto-refresca prefs** — lee `UserDefaults` directo. Vista que lo use con `decimalPlaces` o `currencyDisplayFormat` debe inyectar `@Environment(AppPreferences.self)` y leer `let _ = appPreferences.X` en body para registrar dependencia.
- **Forms con `TextField`/`TextEditor`/`SecureField`** (sin `Form`): obligatorio `dismissKeyboardOnTap()` desde el primer commit. Detalles en SWIFT-STYLE.md.

### iOS 26 Liquid Glass (OBLIGATORIO)
- `ToolbarSpacer(.fixed, placement: .topBarTrailing)` — placement es OBLIGATORIO.
- `.glassEffect()` para chips, barras flotantes, elementos translúcidos.
- Si existe API iOS 26 que mejore integración con sistema, USARLA.

### Tests (OBLIGATORIO)
Detalles completos en `$VAULT/planning/TESTING-STRATEGY.md`. Reglas mínimas:
- `makeTestContext()` es seguro desde Fase 5 (2026-04-29) — usa UUID suffix + `isRunningTests` detecta Swift Testing. Aún así prefiere `@Model` directos sin contexto cuando la lógica lo permite (más rápido).
- NUNCA `UserDefaults.standard` directo en tests → `UserDefaults(suiteName: "test.\(UUID().uuidString)")!` (helper `makeIsolatedDefaults()`).
- NUNCA tocar singletons `.shared` sin `@Suite(.serialized)` + `defer { restore }` o `_testReset()`.
- NUNCA `Task.sleep(.seconds(N))` con N>0.5 — usar señales determinísticas. Excepción: `≤50ms` para forzar dealloc.
- NUNCA `Date()` / `Calendar.current` en lógica testeada — inyectar vía param opcional `now: Date = .now` (patrón canónico, ya en `FinancialScoreCalculator`/`BudgetAlertService`).
- NUNCA `@Test(.disabled(...))` sin entrada en Lista Negra (TESTING-STRATEGY.md) con owner + deadline.
- NUNCA declarar fix completo si un test falla. "Preexistente" no es excusa: arreglar o registrar en Lista Negra con plan.
- Ejecutar con `-parallel-testing-enabled YES` (recomendado, -30% tiempo). `NO` solo como fallback si aparece race en singleton no cubierto.

### Audit markers
- `// A11Y-DT:` justifica font size hardcodeado (Dynamic Type).
- `// A11Y-DM:` justifica color hardcodeado (Dark Mode).

### Design System (en cambios UI)
- SIEMPRE `DS.Spacing`, `DS.Radius`, `DS.Typography`, `DS.Semantic.*`, `DS.Gradients.*` — NUNCA hardcoded.
- SIEMPRE filas clicables con `Button` + `contentShape(Rectangle())`.
- Componentes estándar: `YalaPrimaryButton`, `YalaEmptyState`, etc.
- Tablas DS.Semantic / DS.Gradients en SWIFT-STYLE.md.

### Documentation & copy
- Describir features desde la perspectiva del USUARIO, no técnica.
- NUNCA fabricar features — solo lo confirmado en scope.
- Copy nuevo: leer BRAND-VOICE.md.

## Workflow

Skills disponibles vienen en el system-reminder de cada sesión. Flujos canónicos:

```
Feature:    /clear → /next → Plan Mode → /review-plan → implementar →
            /verify-ios → /test-smart → /device-qa → /swift-audit → /commit-one → /clear
Bug fix:    /next → implementar → /verify-ios → /device-qa → /commit-one
Autónomo:   /clear → /next → Plan Mode → /review-plan → /yolo
Complejo:   añade /analyze-impact antes de Plan Mode + /simplify antes de commit
```

**Regla QA-SCENARIOS:** cada feature nueva requiere escenarios en `$VAULT/planning/QA-SCENARIOS.md` ANTES del commit.

## Testing

| Tipo de cambio | Comando |
|----------------|---------|
| Modelo / servicio | `/test-smart` (relevantes) |
| Solo UI (Views) | `/verify-ios` |
| Antes de commit | `/test-smart` siempre |
| Tras merge / refactor grande | `/test-ios` (todos) |

Después de implementar cualquier cambio, SIEMPRE ejecutar `/verify-ios` o `xcodebuild` antes de presentar como completado.

## Corrección de errores

- SIEMPRE buscar TODAS las instancias del mismo patrón antes de declarar fix completo.
- NO confiar ciegamente en "BUILD SUCCEEDED" — verificar todos los casos.
- Si hay errores tras build exitoso, limpiar cache: `xcodebuild clean`.

## Self-Maintenance

Cuando se modifican modelos / servicios / ViewModels:
- Actualizar tablas en `$VAULT/planning/CODEBASE-MAP.md`.
- Actualizar conteo de tests si se agregaron nuevos.
- Agregar gotchas descubiertos a "Reglas inviolables" de este archivo.

Para preferencias nuevas (`UserDefaults`): ver checklist en SWIFT-STYLE.md sección "añadir una preferencia nueva".

## Control de Ejecución

Después de implementar código:
1. Mostrar resumen de cambios **en lenguaje de usuario** (qué cambia para él / qué problema resuelve), no descripción técnica de archivos editados.
2. Ejecutar `/verify-ios` SIEMPRE para confirmar que el build pasa.
3. Sugerir siguiente paso.
4. DETENERSE y esperar instrucción del usuario.
5. NO ejecutar tests, device-qa o commits automáticamente — solo el build.

**Git:** ejecutar cada comando de lectura UNA SOLA VEZ, secuencialmente, nunca en paralelo. No matar shells con git en curso.

**Tags:** SIEMPRE semver con prefijo `v` → `v1.0.0`, `v1.1.0`. Nunca sin prefijo o sin 3 componentes.

## Decisiones Recientes (TTL: hasta cierre de fase)

[Formato: [FECHA] Decisión breve — se archiva en DECISIONS.md al cerrar fase. Máx 3-5 entradas activas.]

- [2026-04-28] Traducciones reales keys-por-keys de los 4 locales nuevos (nl `b3f16aba`, pl `d6b3748e`, zh-Hans `d6697ec5`, ja `8891408f`). Cierra épico l10n M14 — reemplaza rule-based v0. Approach validado: ~17 Edits grandes (50-150 keys), `grep -c` por Edit, sesión ~60 min. Decisiones específicas por locale (forma です/ます ja, pronombre `你` zh, voseo es-AR, glosarios financieros, counter words contextuales, placeholder reorder con notación positional para idiomas SOV). Pendiente: device QA visual en simulador para los 4 locales. Siguiente: M16 (ASC metadata localizada).
- [2026-04-28] 3 fixes runtime logs post-QA chat-registrar-transacciones (`773fe651` + `35bd11d1` + `aade3042`). (1) Sheet collision chat→NTV — gate del consumer `.panel` mientras `showChatSheet=true` vía markUnready/markReady del AppRouter. (2) ProfileImageStorage — guard `fileExists` antes de `Data(contentsOf:)` (caso normal vs error real). (3) UserSegmentService race — `currentSegment` se leía como `.dormant` durante cold start (recalculate antes del primer importEvent). Fix con NotificationCenter (patrón establecido) + 2 flags separadas (`hasCompletedFirstImport` en iCloudSyncService + `hasRecalculatedAfterFirstImport` en UserSegmentService) + helper `markRecalculatedAfterFirstImport()`. AppBootstrapper:555 gate-ea con la flag — caía a "require interaction" si segmento no confiable. Tests: 2 nuevos (`@Suite(.serialized)` en UserSegmentService). Pendiente: device QA con cold launch + cuenta poblada >100 tx (verificar log `(pre-import)` en primer scan).
- [2026-05-04] Subset 2 del épico Groups Pulido Final (`8945a30b`) — A10 + A9 + A13 + A12. (1) **A10**: `GroupTransactionBridge.resolveAccount` cambia de `-> Account?` a `throws -> Account` con `noAccountsAvailable`. Propagación selectiva: creación bubble-up al alert; batch import + updates `try?` (resilient). Pattern matching catch directo en GroupExpenseService. Logger.error reemplaza print debug-only. 1 key l10n × 13 locales. (2) **A9**: eliminadas 43 líneas de heurísticas (nameMatch único + admin único / oldest joinedAt) en `ensureCurrentUserMemberExists`. Identidad solo desde `cloudKitUserRecordID`. Path defensivo legacy backfill intacto. Riesgo duplicación legacy mitigado por `deterministicUUID(zoneID, recordName)`. (3) **A13**: nuevo `GroupService.updateCurrentUserDisplayName(_:)` con cache de grupos por zoneID + filtro `displayName != trimmed` (idempotente). Llamada en `GroupInviteOnboardingView.performSilentSetup` paso 8.5 + boot-time reconciliation `AppBootstrapper.reconcileCurrentUserDisplayNameIfNeeded` (paso 16.6) cubre kill-app entre acceptShare y onboarding-complete. Self-healing sin flag. (4) **A12**: función pura `AppBootstrapper.inviteRouteDecision(hasCompletedOnboarding:onboardingMode:) -> InviteRouteDecision` reutilizada por `acceptShareFromURL` y `YalaAppDelegate` — simetría perfecta entre branded link y CKShare nativo. Verificado: `ContentView.onJoin` ya invoca `acceptShare(metadata:)`. Tests: +8 (resolveAccount + inviteRouteDecision con 4 estados). Cleanup `/simplify`: hardcoded `"userName"`/`"hasCompletedOnboarding"` → `AppPreferences.Keys.*`. Pendiente: device QA full al final del épico (acumulado, no por subset). Siguiente: Subset 3 (A6 race bridgeExpense + A7 dedup balance + A8 leave/remove con deuda).
- [2026-05-05] **A0-Bridge** del épico Groups Pulido Final — rediseño completo del bridge `SplitExpense` ↔ `TransactionItem` (modelo M5 simplificado). 16 commits F1-F16, 14 fases técnicas + L10n + QA docs. **Decisiones clave**: (1) TX expenses van TODAS a cuenta virtual `Grupos [moneda]` (auto-creada por `ensureSystemAccount`) — desacopla bridge de conciliación bancaria. (2) Settlements sí tocan cuenta real (Caso C/D) pero solo `.full`/`.completed`; `.groupInvite` solo virtual con upsell. (3) **5 subcategorías sistema** en 2 categorías (`Grupos` expense + `Cobros de grupos` income) con naming contable claro: Préstamo a grupos, Cobro de préstamo, Pago de liquidación, Liquidación enviada, Liquidación recibida. (4) **TX-puntero** para drafts groupExpense: TX1 se crea con subcat=nil + draft con `targetTransactionID` → finalize UPDATEa subcat (saldo virtual cuadra desde t=0). (5) **Idempotency vía delete+recreate** en bridge — robusto a edits de payer/monto y sync race. (6) **Drafts groupExpense/groupSettlement no eliminables** — solo desde el grupo origen. (7) **3 toggles AppPreferences** synced: includeGroupTransactionsInFeed, includeGroupsInPanelTotal, includeGroupTransactionsInStats. (8) **Auto-archive** cuenta virtual cuando vacía + recreación lazy on demand. **Diferidos a iteración posterior**: BridgeActivationSheet/DeactivationSheet UI (lógica core completa via `importGroupHistory` async + `unbridgeAllForGroup`); GroupExpenseDraftFinalizationSheet/GroupSettlementDraftFinalizationSheet visualmente distintivos (drafts funcionan en Inbox normal con icons distintivos `person.2.fill`/`arrow.left.arrow.right.circle.fill`); GroupDraftsPendingBanner del Panel; bloqueo edición `EditTransactionView` de TX bridgeadas (protección operativa via pickers que excluyen sistema + bridge idempotency). **Tests A0-Bridge**: 61 tests pure-logic (F1=24, F2=9, F3=8, F4=12, F15=8). Tests integration con `makeTestContext()` en blacklist R8 — validación funcional via Device QA F16 (21 escenarios documentados en `$VAULT/planning/QA-SCENARIOS.md`). **L10n**: 37 keys × 13 locales con traducciones reales (voseo es-AR, です/ます ja, 你 zh-Hans, vouvoiement fr, Sie de). **Sin migración**: grupos no estaban en producción; deploy aplica desde cero (instruir testers borrar app + reinstalar). Pendiente: completar UI sheets diferidas + device QA full.
- [2026-05-05] **A0-Bridge V2.0** del épico Groups Pulido Final — completa los 4 items P0+P1 pendientes que quedaron diferidos del A0-Bridge inicial (commits `414dc75b` F1, `f2e08e6d` F2, `eb59c9b7` F3, `179e621b` F4, `ab786490` F5). 5 commits F1-F5 + tests/verificación F6. **Items entregados**: (1) **P0-1 Settlement form Caso C proactivo** — `SettlementFormView` con AccountSelector filtrado por currency, preselect desde `defaultSettlementAccount`, `createSettlement`+`confirmSettlement` con `accountForCurrentUser` para disparar bridge inmediato (2 TX al instante). `.groupInvite` oculta selector. `AccountSelectorSheet` extendido con parámetro opcional `currencyFilter` (retrocompat). (2) **P0-2 Sheets activación/desactivación tardía** — `BridgeActivationSheet` con opciones "Empezar desde ahora" / "Importar todo el historial" (corre `importGroupHistory` async con `ProcessingProgressView` determinate); `BridgeDeactivationSheet` con "Eliminarlas" / "Mantenerlas como histórico". Toggle `personalAutoCreate` intercepta cambios cuando hay data pre-existente. **Anti-loop guard D8** via flag `isInternalToggleRevert` (revert visual del binding sin re-disparar `onChange`). **Alert error** propaga `error.localizedDescription` al user (en lugar de solo log DEBUG). (3) **P1-3 Bloqueo edición TX bridgeadas** — `NewTransactionView` detecta `splitExpenseID/splitSettlementID` y entra en read-only: oculta `transactionTypeSelector`, `ContextualGuideBanner` y toolbar trailing favorites; `disabled + opacity 0.5` en form; banner CTA contextual (`assignFromInbox` / `editFromGroup` / `editSettlementInGroup`) navega a Inbox o `groupDetail(zoneID)` (fallback `groups`). (4) **P1-4 Sheets finalización drafts especializados** — `GroupExpenseDraftFinalizationSheet` (read-only header + selector subcat, path TX-puntero existente), `GroupSettlementDraftFinalizationSheet` (read-only header + AccountSelector con preselect + persiste `defaultSettlementAccount`). `InboxView` switch por `draft.sourceType` con fallback a `InboxDraftEditSheet` para sources personales. **Decisión D7 crítica**: `approveDraft` rama `groupSettlement` crea TX manual INDEPENDIENTE — **NO setea** `splitSettlementID`/`splitGroupZoneID`. Razón: el bridge hace delete+recreate sobre TX con esos IDs al editar el settlement; mantener los IDs haría que una edición posterior borre la TX manual del user. La TX virtual (lado bridge) sigue ligada al settlement y se regenera. **Currency** se resuelve desde origen (`SplitExpense`/`SplitSettlement` por ID) en `.onAppear` — `cachedCurrencyCode` solo se popula en `approveDraft`. **L10n**: 11 keys × 16 locales con traducciones reales (voseo es-AR "Asigná"/"finalizá", です/ます ja, 你/账户 zh-Hans, vouvoiement fr, Sie de, "Posteingang" de para Inbox, "Caixa"/"Skrzynkę" pt/pl, "Finalise" en-GB). **Aprendizajes**: `/review-plan` cazó 7 problemas reales antes de implementar (loop infinito en onChange, `approveDraft` borrando TX manual, currency no cacheado, alert error faltante, read-only incompleto en toolbar/typeSelector). `@Query` reemplazado por fetch directo en `.onAppear` para evitar re-fetch. Tests A0-Bridge integration siguen verdes; flake R8 preexistente confirmado en `resolveAccount_throwsNoAccountsWhenEmpty` (pasa aislado, falla en suite paralela — race con `makeTestContext()` documentado). Pendiente: `/device-qa` full con 21 escenarios F16 acumulados (borrar app + reinstalar antes). Bloquea: A3 (`pendingApproval`) + A4 (Welcome Chooser) — desbloqueados ahora.
- [2026-05-05] **A3 — pendingApproval flow (opción B)** del épico Groups Pulido Final. 6 fases F1-F6 (modelo + servicios + notificación + UI admin + UI invitado + L10n + tests/docs). **Items entregados**: (1) **F1 modelo**: `SplitMemberStatus` extiende con `.pendingApproval` y `.rejected` (rawValue String CloudKit-compat); helpers `isPendingApproval`, `isRejected`, `canWrite`. `GroupService` añade `pendingMembers(in:)`, `approveMember(_:in:)`, `rejectMember(_:in:)` (todos `requireCurrentUserAdmin`). `ensureCurrentUserMemberExists` modificado: invitados nuevos entran como `.pendingApproval` (owner siempre `.active`); existing `.rejected`/`.removed` re-pone en `.pendingApproval`; **case explícito para `.pendingApproval` no-op** evita bug donde re-tap link convertía pending a active. `validateCurrentUserCanWrite` en `GroupExpenseService` lanza nuevo `pendingApproval`. `bridgeExpense`/`bridgeSettlement` endurecen guard a `currentMember.isActive` — pending/rejected no triguean bridge. (2) **F2 notificación admin**: `RemoteChangeSet.newPendingMembers` + `buildPendingMemberNotification` con prioridad sobre newMember. `SplitSyncManager` bifurca al clasificar `splitMember` records leyendo `record["status"]` directo del CKRecord, con **pre-cache `isCurrentUserAdminOfGroup` por zoneID** dentro del batch — solo admins reciben notif. (3) **F3 UI admin**: `pendingApprovalSection` en `GroupSettingsView` (gated `isCurrentUserAdmin && !pendingApprovalMembers.isEmpty`) con avatar + nombre + 2 botones Aprobar/Rechazar y confirmation dialogs. `GroupDetailViewModel.pendingApprovalMembers` computed. (4) **F4 UI invitado**: `PendingApprovalBanner` (pending + rejected states) en `GroupDetailView` con `DS.Semantic.warningBackground` / `errorBackground`. **FAB ya bloqueado** por `canCurrentUserParticipate` existing — sin tocar. **Refresh wiring** ya cubierto por `.onChange(of: sessionState.dataVersion)` existing. Step 3 onboarding "Solicitud enviada" en `GroupInviteOnboardingView` con detección async vía `mostRecentGroup()` + `ensureCurrentUserMemberExists`. (5) **F5 L10n**: 14 keys × 16 locales con traducciones reales (voseo es-AR, です/ます ja, 你/管理员 zh-Hans, vouvoiement fr, Sie de, "ligação" pt-PT, "Anfrage" de) + 1 plural `pendingRequestsCount` × 12 stringsdict (4 reglas pl, sin distinción singular ja/zh). **stringsdict pattern**: keys plain (sin `%d` literal), `%#@count@` resuelve plural. (6) **F6 tests**: +8 (4 SplitModels: rawValue stable, pending/rejected not active, garbage rawValue fallback; 2 GroupService errorDescription; 2 CKRecordTranslator round-trip pending/rejected). **Decisiones clave**: `rejected` case nuevo (no reusa `removed`) — mejor UX copy + telemetría. Re-pone en pending tras rechazo/removed (sin límite reintentos V2.0). Owner siempre `.active`. Last-write-wins en aprobación concurrente. Sin unbridge en reject (pending nunca creó gastos). Deeplink reusa `groups/{UUID}` (un tap más a Settings). Trade-off bridge: removed/rejected dejan de bridgear updates remotos (caso edge, aceptado). **F0 pre-flight cazó 5 hallazgos**: FAB ya cubierto por `canCurrentUserParticipate`, refresh wiring ya existe en GroupDetailView:153, `GroupInviteOnboardingView` no recibe `group` (usa `mostRecentGroup()`), stringsdict keys plain confirmado, bug `else { active }` en branch reactivateInactive. **Aprendizajes**: `/review-plan` cazó el bug del branch reactivateInactive antes de implementar (caso explícito `.pendingApproval` no-op crítico). `SectionBox` no acepta `subtitle` (count va inline como label). `DS.Typography.callout` y `title3` no existen — usar `label` y `title2`. `L10n.Common.continue` no existe — usar `Action.continueAction`. Pendiente: device QA acumulado (21 escenarios F16 A0-Bridge + 9 escenarios A3-01..A3-09 nuevos). Siguiente: A4 (Landing + AASA + Welcome Chooser).
- [2026-05-05] Subset 3 del épico Groups Pulido Final (`dbce20a6`) — A6 + A7 + A8. Cierra Fase A salvo A3/A4 (no son código Swift). (1) **A6**: NSLock descartado tras `/review-plan` — habría introducido regresión (descartar second-call legítimo de update). `@MainActor` + sync function + idempotency check via fetch existing TX/Draft ya garantizan atomicidad por construcción. Comment documenta el invariante en `bridgeExpense` línea 80. Sin test E2E (runner crashea con globals del bridge — patrón documentado Subset 1). (2) **A7**: dedup `expenses` por `id` con `Dictionary(grouping:by:\.id).values.compactMap(\.first)` en `calculateBalances` y `rawDebts` (cubre `calculateDebts` + `globalSummary` por propagación). +4 tests cubren las 3 funciones + regresión de IDs distintos. (3) **A8**: eliminada restricción "balance == 0"; `removeMember` y `leaveGroup` ya no lanzan `outstandingBalance`. UI: warning copy en confirmation dialog (mensaje dinámico), helper `hasNonZeroBalance(for:)` extraído por `/simplify` (reuse). Limpieza simétrica: `case GroupServiceError.outstandingBalance` + branch + helpers privados `memberHasOutstandingBalance`/`memberBalances` + key `leaveGroupDisabledHint` × 13 locales. 2 keys nuevas con traducciones reales por locale (voseo es-AR, です/ます ja, 你 zh-Hans, vouvoiement fr). Aprendizajes: `/review-plan` cazó la regresión del NSLock antes de implementar; greps previos zanjan ambigüedades de "qué eliminar"; `/simplify` post-implementación detecta duplicación de computeds. Pendiente: device QA full al final del épico. Siguiente: A3 (decisión `.readOnly` vs iOS 26 access requests) + A4 (landing page web + AASA).
