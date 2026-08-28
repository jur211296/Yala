---
id: inbox-convert-draft-to-group-expense
status: qa
priority: medium
area: "groups, inbox"
created: 2026-07-01
updated: 2026-08-28
source: YalaWiki/Backlog/qa_inbox-convertir-a-gasto-de-grupo.md
---


# Convertir un draft de Inbox en gasto compartido de grupo

## Problema

Hoy un `InboxDraft` personal (creado por Apple Pay, voz, foto de recibo, chat, import CSV, etc.) solo puede aprobarse de una forma: como una `TransactionItem` personal, vía `InboxDraftEditSheet` → `DraftService.approveDraft(...)`.

Ejemplo concreto del owner: paga con Apple Pay (automatización en background, pantalla bloqueada — ver `ApplePayTransactionIntent`), se crea un `InboxDraft` con `sourceType == .applePay` esperando en la bandeja. Al abrir la bandeja para clasificarlo, el usuario puede notar que ese gasto en realidad lo quiere **dividir con alguien de un grupo** (ej. pagó la cena de dos con su tarjeta y quiere que la otra persona le devuelva su mitad). Hoy no hay forma de hacerlo desde ahí: tiene que aprobarlo como personal y luego, por su cuenta, ir al grupo y crear un gasto compartido nuevo desde cero (reescribiendo monto, descripción y fecha a mano) — sin ningún vínculo entre ambos registros.

La idea del owner es agregar un botón en el form de aprobación del draft que permita **convertir ese draft en un gasto de grupo (`SplitExpense`)** en lugar de aprobarlo como transacción personal, reusando los datos que el draft ya capturó (monto, descripción, fecha).

## Solucion

Agregar una acción secundaria "Convertir a gasto compartido" en `InboxDraftEditSheet` (el form de aprobación genérico) que, en lugar de llamar a `approveDraft`, abre `GroupExpenseFormView` **prellenado** con los datos del draft (monto, descripción/nota, fecha) vía el mismo mecanismo de plantilla (`GroupExpensePrefillTemplate`) que ya usa el flujo de pagos planificados de grupo (`.groupScheduledExpense`, shippeado 2026-07-01). Si el usuario tiene más de un grupo elegible, se le pide elegir uno primero (reusando `GroupPickerSheet`, igual que el composer del FAB del tab Grupos). Al guardar el `GroupExpenseFormView`, el `SplitExpense` se crea normalmente — y el bridge personal existente (`GroupTransactionBridge.bridgeExpense`, invocado automáticamente por `GroupExpenseService.createExpense`) se encarga de reflejarlo en las cuentas personales de todos los participantes, sin necesidad de ningún bridge nuevo. El `InboxDraft` original se elimina (no queda huérfano ni se aprueba dos veces).

Este NO es un feature simétrico a "pagos planificados de grupo" (que va de grupo → Inbox → grupo): aquí el draft **nace personal** (fuente externa: Apple Pay, voz, foto, chat, CSV, manual) y el usuario decide, en el momento de clasificarlo, redirigirlo a un grupo. El botón es una bifurcación de flujo, no una fuente de datos de grupo.

## Estado actual confirmado en el código

- `Yala/Models/InboxDraft.swift:14-36` — `enum DraftSourceType` tiene 13 cases: `voice`, `receiptPhoto`, `screenshotList`, `screenshotSingle`, `emailAlert`, `scheduledPayment`, `subscription`, `applePay`, `automation`, `siri`, `groupExpense`, `groupSettlement`, `manual`, `groupScheduledExpense`. La computed `isFromGroup` (línea 33-35) es `true` solo para `.groupExpense` y `.groupSettlement`.
- `Yala/Models/InboxDraft.swift:319` — `requiresApprovalForm: Bool { sourceType == .groupScheduledExpense }` es el flag que hoy fuerza abrir un form dedicado en lugar de quick-approve (swipe/bulk). Es el precedente directo de lo que necesitaríamos para el nuevo flujo, pero con semántica distinta: `.groupScheduledExpense` SIEMPRE requiere el form de grupo (nace de un `ScheduledPayment` de grupo); el botón nuevo es **opcional** sobre drafts que por default siguen siendo personales.
- `Yala/App/Views/Inbox/InboxDraftEditSheet.swift` — el form de aprobación genérico. `actionButtons` (línea 684-724) hoy solo tiene 2 botones: "Aprobar luego" (`saveDraft`, secundario, solo si `initialStatus == .pending`) y "Aprobar" (primario, `approveDraft`, deshabilitado si `!isReadyToApprove`). No hay ningún gancho para redirigir a un flujo distinto.
- `Yala/Services/DraftService.swift:89-334` — `approveDraft(_:currencyConverter:)` es el método que crea la `TransactionItem` personal. Ya tiene una guarda explícita al inicio (línea 99-101) que bloquea `.groupScheduledExpense`: `guard draft.sourceType != .groupScheduledExpense else { throw DraftServiceError.groupScheduledExpenseRequiresForm }` — este es el patrón de "esta fuente no se aprueba por el path genérico".
- `Yala/App/Views/Inbox/InboxView.swift:222-295` — el `.sheet(item: $selectedDraft)` hace `switch draft.sourceType` para decidir qué sheet abrir. El case `.groupScheduledExpense` (líneas 251-275) es el precedente exacto de UI a reutilizar: llama a `loadGroupScheduledContext(for:)` (líneas 64-117) para resolver `group`/`members`/`lookup`/`template`, y si lo logra, abre:
  ```swift
  GroupExpenseFormView(
      group: ctx.group,
      members: ctx.members,
      memberNameLookup: ctx.lookup,
      groupChip: .readOnly,
      initialTemplate: ctx.template,
      onSave: { shouldDismissAfterApproval = true },
      onExpenseCreated: { expenseID in
          finalizeGroupScheduledExpense(draft: draft, expenseID: expenseID)
      }
  )
  ```
  Nota: usa `groupChip: .readOnly` porque el grupo ya viene fijado por el `ScheduledPayment`. En el flujo nuevo el grupo NO está fijado — hay que usar `.editable` (o el patrón completo de `GroupExpenseComposerView`, ver abajo).
- `Yala/App/Views/Groups/GroupExpenseFormView.swift:22-33` — `struct GroupExpensePrefillTemplate` es la plantilla de prellenado:
  ```swift
  struct GroupExpensePrefillTemplate {
      let totalAmount: Double
      let currencyCode: String
      let splitType: SplitType
      let participantIDs: [UUID]
      let values: [UUID: Double]
      let description: String
      let accountPrefill: Account?
  }
  ```
  Se aplica en `onAppear` (línea 202-204) vía `viewModel.applyTemplate(template)` solo cuando NO hay `expenseToEdit`.
- `Yala/App/ViewModels/GroupExpenseViewModel.swift:337-361` — `applyTemplate(_:)` puebla `amountString`, `currencyCode`, `expenseDescription`, `splitType`, `selectedMemberIDs` (intersectado con miembros activos), los valores per-tipo de split (`exactAmounts`/`percentages`/`sharesCounts`), y `selectedAccount` si viene `accountPrefill`. El pagador (`paidByMemberID`) NO se toca — queda fijado a "yo" desde el `init` del VM (línea 270: `members.first(where: { $0.isCurrentUser && $0.isActive })`). Esto es exactamente lo que se necesita: el usuario que convierte el draft es siempre el pagador (Caso A del bridge).
- `Yala/App/Views/Groups/GroupExpenseComposerView.swift` — es el patrón completo y ya construido para "elegir grupo si hay más de uno + abrir `GroupExpenseFormView` con chip editable", usado hoy por el FAB "Nuevo gasto" del tab Grupos (`GroupsContainerView.swift:156-165`). Recibe `groups: [SplitGroup]`, `initialGroup: SplitGroup`, y 3 closures (`activeMembers`, `memberNameLookup`, `memberCount`) — remonta el form con `.id(selectedGroup.id)` al cambiar de grupo vía `GroupPickerSheet`. Es la abstracción a reutilizar tal cual, solo que además necesita aceptar un `initialTemplate` opcional para pasarlo al `GroupExpenseFormView` interno (hoy no lo expone).
- `Yala/App/Views/Groups/GroupPickerSheet.swift` — selector de grupo, recibe `groups` ya cargados (sin `ModelContext`), no necesita cambios.
- `Yala/App/ViewModels/GroupsViewModel.swift` — NO es singleton, es `@Observable` instanciado localmente por `GroupsContainerView`. Los helpers relevantes:
  - `eligibleGroupsForExpense() -> [SplitGroup]` (línea 360-368): filtra `groups` (fetch crudo) con `GroupExpenseEligibilityLogic.canCreateExpense(currentMemberStatus:isArchived:isHiddenForAll:)` — grupo activo, no oculto, y el current user con `status == .active` ya presente como miembro.
  - `activeMembers(for:)` (línea 371-373), `memberNameLookup(for:)` (línea 377-382), `memberCount(for:)` (línea 336-338) — todos leen de `membersByGroup` (cache poblado en `loadData()`).
  - Para usar esto desde el Inbox (que no tiene ese ViewModel montado) hay dos caminos: (a) instanciar un `GroupsViewModel` local en el sheet nuevo y llamar `setContext(modelContext)` — barato, mismo patrón que ya usa `GroupsContainerView`; o (b) ir directo a `GroupService.shared.fetchAllGroups()` / `fetchMembers(for:context:)` (línea 894-913+ de `GroupService.swift`) sin pasar por el ViewModel. La opción (a) es más consistente y reutiliza `eligibleGroupsForExpense()` sin reimplementar el filtro.
- `Yala/App/Logic/GroupExpenseEligibilityLogic.swift` — pure-logic, sin SwiftData, testeable directo. Reutilizable sin cambios.
- `Yala/Services/Groups/GroupExpenseService.swift:56-140` — `createExpense(in:amount:currencyCode:description:note:date:paidByMemberID:splitType:subcategoryName:shares:accountForCurrentUser:isOpeningBalance:)` ya invoca automáticamente `GroupTransactionBridge.shared.bridgeExpense(expense, in: group, accountForCurrentUser:, isRemoteSync: false)` en la línea 127-138 tras el `save()`. **Esto confirma que no hace falta ningún bridge nuevo ni lógica de "reflejar personalmente" — ya existe y corre automáticamente para toda creación de `SplitExpense`.**
- `Yala/App/Services/ScheduledPaymentDraftService.swift:455-499` — `handleGroupScheduledExpenseApproved(draft:expenseID:context:)` es el precedente de "qué hacer con el draft original tras crear el `SplitExpense`": vincula `scheduledPaymentID` en la TX real bridgeada y hace `context.delete(draft)`. Para el flujo nuevo el equivalente es mucho más simple (no hay `ScheduledPayment` que actualizar) — solo `context.delete(draft)` + `save()`.

## Plan técnico

### Servicios/vistas existentes a reutilizar

| Pieza | Rol en el flujo nuevo | Cambios necesarios |
|---|---|---|
| `GroupExpensePrefillTemplate` | Prellenar monto/descripción/fecha/moneda desde el draft | Ninguno — se construye un valor con `totalAmount: abs(draft.amount)`, `currencyCode: draft.account?.currencyCode ?? cachedCurrencyCode`, `splitType: .equal`, `participantIDs: []` (el usuario elige participantes en el form, no hay plantilla de split previa), `values: [:]`, `description: draft.note`, `accountPrefill: nil` |
| `GroupExpenseViewModel.applyTemplate(_:)` | Aplicar la plantilla al abrir el form | Ninguno |
| `GroupExpenseFormView` | El form de creación de gasto compartido | Ninguno estructural — ya acepta `initialTemplate` y `groupChip: .editable` |
| `GroupExpenseComposerView` | Elegir grupo (si hay >1) + montar el form | Extender `init` para aceptar un `initialTemplate: GroupExpensePrefillTemplate?` opcional (default `nil`, no rompe el callsite existente del FAB) y pasarlo al `GroupExpenseFormView` interno; aceptar también un `onExpenseCreated: ((String) -> Void)?` opcional para poder cerrar el ciclo del draft (default `nil`, tampoco rompe el callsite del FAB) |
| `GroupPickerSheet` | Elegir grupo cuando hay varios elegibles | Ninguno |
| `GroupsViewModel.eligibleGroupsForExpense()` / `activeMembers(for:)` / `memberNameLookup(for:)` / `memberCount(for:)` | Resolver grupos elegibles + miembros | Ninguno — se instancia un `GroupsViewModel` local en el sheet nuevo, igual que hace `GroupsContainerView` |
| `GroupExpenseEligibilityLogic.canCreateExpense` | Filtro pure-logic de grupos elegibles | Ninguno |
| `GroupExpenseService.createExpense(...)` | Crear el `SplitExpense` + bridge automático | Ninguno — ya bridgea de vuelta a personal sin cambios |
| `GroupTransactionBridge.bridgeExpense` | Reflejar el gasto en la cuenta personal (Caso A) | Ninguno — se invoca automáticamente desde `createExpense` |

### Qué falta construir

1. **`DraftConvertibleToGroupLogic` (pure-logic nuevo, `Yala/App/Logic/`)**: decide si un draft es candidato a mostrar el botón "Convertir a gasto compartido". Regla: `!draft.isFromGroup && draft.sourceType != .groupScheduledExpense && (draft.amount ?? 0) < 0` (solo gastos, no ingresos — dividir un ingreso con un grupo no tiene sentido en el modelo actual) `&& hasAtLeastOneEligibleGroup`. Testeable sin SwiftData (recibe los booleans ya resueltos, no el draft ni el context).
2. **Botón nuevo en `InboxDraftEditSheet.actionButtons`** (o en un lugar visualmente separado, ej. debajo de `sourceIndicator`, para no competir con "Aprobar"/"Aprobar luego"): "Convertir a gasto compartido" — visible solo cuando `DraftConvertibleToGroupLogic` da `true`. Al tocarlo, dispara el flujo de conversión (paso 3) en lugar de `approveDraft`.
3. **Extender `GroupExpenseComposerView`** (o crear un wrapper específico, ver Notas Técnicas) para que reciba `initialTemplate` y `onExpenseCreated`, montado desde `InboxDraftEditSheet` (o `InboxView`, ver Notas Técnicas sobre dónde vive el sheet) cuando: (a) hay exactamente 1 grupo elegible → abre directo con `initialGroup` ese único grupo; (b) hay 2+ → abre con `GroupPickerSheet` disponible (comportamiento ya existente del composer); (c) hay 0 → el botón nuevo NO debe mostrarse en absoluto (cubierto por el pure-logic del paso 1 — el usuario sin grupos jamás ve la opción).
4. **`DraftService.convertToGroupExpense(_:expenseID:) throws`** (o nombre similar) — el equivalente de `handleGroupScheduledExpenseApproved` pero sin `ScheduledPayment`: solo `context.delete(draft)` + `save()` + `SessionState.shared.incrementDataVersion()` + `WidgetDataCache.updateCache(...)` + telemetría (ej. `TelemetryService.track(.draftConvertedToGroupExpense, parameters: ["source": draft.sourceTypeRaw])` — nuevo case en `AnalyticsEvent`). Se invoca desde el `onExpenseCreated` del `GroupExpenseFormView`, análogo a `finalizeGroupScheduledExpense` en `InboxView.swift:119-124`.
5. **L10n**: 1-2 keys nuevas (`inbox.convertToGroupExpense` para el label del botón, quizás `inbox.convertToGroupExpenseHint` si hace falta un accessibility hint) × 16 locales, siguiendo el patrón de voz de marca existente (voseo es-AR, Sie de, vouvoiement fr, です/ます ja, 你 zh-Hans, tu/você split pt-PT/pt-BR).
6. **`qa/coverage-index.json`**: extender el área `group-scheduled-payments` (o crear una nueva, ej. `inbox-convert-to-group`) con el escenario nuevo, clasificación `agentic` (requiere `/device-qa`, igual que el resto del subsistema de bridge).

## Acceptance Criteria

- [ ] En `InboxDraftEditSheet`, un draft con `sourceType` personal (voice, receiptPhoto, screenshotList, screenshotSingle, emailAlert, applePay, automation, siri, manual — NO `scheduledPayment`/`subscription`, ver Notas Técnicas) y `amount < 0` (gasto) muestra un botón/acción "Convertir a gasto compartido" cuando el usuario tiene al menos 1 grupo elegible (`GroupExpenseEligibilityLogic.canCreateExpense == true` para al menos un grupo).
- [ ] Si el usuario no tiene ningún grupo elegible, el botón no aparece (no hay dead-end ni mensaje de error — simplemente no se ofrece la opción).
- [ ] Al tocar el botón con exactamente 1 grupo elegible, se abre `GroupExpenseFormView` directamente prellenado con monto (`abs(draft.amount)`), descripción (`draft.note`), fecha (`draft.effectiveDate`) y moneda de la cuenta del draft si tiene una asignada.
- [ ] Al tocar el botón con 2+ grupos elegibles, se muestra primero `GroupPickerSheet` para elegir el grupo, y luego el form prellenado igual que el caso anterior (chip de grupo `.editable`, puede cambiar de grupo sin perder el prellenado).
- [ ] El pagador (`paidByMemberID`) del gasto queda fijado al usuario actual (Caso A) — el usuario NO puede cambiarlo desde este flujo (coherente con "yo pagué con Apple Pay, quiero dividirlo").
- [ ] El usuario puede editar libremente monto, descripción, fecha, moneda, participantes y modo de división antes de guardar — el prellenado es un punto de partida, no un valor fijo.
- [ ] Al guardar el `GroupExpenseFormView`, se crea el `SplitExpense` normalmente (con sus `SplitShare`s), se sincroniza al grupo (CKSyncEngine), y el bridge personal existente refleja automáticamente la contraparte en las cuentas personales de todos los participantes (sin código nuevo de bridge).
- [ ] Tras guardar, el `InboxDraft` original se elimina del Inbox (no queda pendiente, no se puede aprobar dos veces como personal).
- [ ] Si el usuario cancela el `GroupExpenseFormView` (botón X) antes de guardar, el `InboxDraft` original permanece intacto en el Inbox, sin cambios — el usuario puede volver a intentarlo o aprobarlo como personal normalmente.
- [ ] Tests pure-logic para `DraftConvertibleToGroupLogic` cubriendo: draft de ingreso (no debe mostrar botón), draft ya de grupo (no debe mostrar botón), draft `.groupScheduledExpense` (no debe mostrar botón — usa su propio flujo), 0 grupos elegibles (no debe mostrar botón), 1+ grupos elegibles con gasto personal (debe mostrar botón).
- [ ] `/verify-ios` build verde (scheme Yala + Yala Dev).
- [ ] `qa/coverage-index.json` actualizado con el escenario nuevo.

## Notas Tecnicas

**Decisiones abiertas — necesitan input del owner antes de implementar:**

1. **¿Qué `DraftSourceType`s ofrecen el botón?** El brief sugiere "todos los que producen drafts personales editables". Candidatos claros: `voice`, `receiptPhoto`, `screenshotList`, `screenshotSingle`, `emailAlert`, `applePay`, `automation`, `siri`, `manual`. Casos dudosos:
   - `scheduledPayment` / `subscription`: son drafts que vienen de un `ScheduledPayment` PERSONAL recurrente (ej. "Netflix", "Alquiler"). Convertir uno de estos a gasto de grupo dejaría el `ScheduledPayment` personal original apuntando a nada (su `sourceScheduledPaymentID` se perdería sin actualizar `lastPaidDate`/`nextDueDate` del pago recurrente). Sugerencia: **excluirlos** de este feature — si el usuario quiere que un pago recurrente sea compartido, ya existe el flujo dedicado "pagos planificados de grupo" (crear el `ScheduledPayment` directamente con `groupZoneID` asignado, ver commit `b98f31cd`). Mezclar ambos caminos (un `ScheduledPayment` personal que se convierte ad-hoc a un `SplitExpense` de grupo una sola vez) generaría un estado inconsistente entre el pago recurrente y el grupo. **Necesita confirmación del owner.**
   - `groupExpense` / `groupSettlement` / `groupScheduledExpense`: ya son de grupo por definición (`isFromGroup == true` para los primeros dos; el tercero tiene su propio flujo dedicado) — quedan excluidos sin ambigüedad.
2. **¿Solo gastos, o también ingresos?** El modelo de `SplitExpense`/`SplitShare` está diseñado para gastos compartidos (alguien pagó, otros le deben su parte). No hay noción de "ingreso compartido" en el subsistema de Grupos. Sugerencia: **restringir a `amount < 0`** (gasto). Si el draft es un ingreso, el botón no se muestra. **Asumido en los Acceptance Criteria arriba — confirmar con el owner si hay un caso de uso de ingreso compartido que no se está considerando.**
3. **¿Dónde vive el sheet nuevo — dentro de `InboxDraftEditSheet` o como una rama nueva en el `switch` de `InboxView.swift`?** Dos approaches:
   - **(A) Botón dentro de `InboxDraftEditSheet`** que, al tocarse, hace `dismiss()` del sheet actual y notifica a `InboxView` (vía un callback nuevo `onConvertToGroup: (() -> Void)?`) para que abra el composer de grupo en su lugar. Más consistente con el patrón de callbacks ya usado (`onApproved`, `onApproveNext`, `onEditTransaction`).
   - **(B) `InboxDraftEditSheet` presenta el composer de grupo como un sheet ANIDADO** (sheet-sobre-sheet) sin pasar por `InboxView`. Más simple de cablear pero menos consistente con cómo Yala maneja transiciones entre sheets del Inbox hoy (todas pasan por el `switch` de `InboxView`, ver `Yala/App/Views/Inbox/InboxView.swift:211-295`).
   Sugerencia: **(A)**, siguiendo el patrón de `onEditTransaction` (línea 89 de `InboxDraftEditSheet.swift`, que hace exactamente esto: cierra el sheet actual y abre otro desde `InboxView` tras un delay). **Necesita decisión de diseño antes de implementar** (afecta cuántos archivos se tocan).
4. **¿Debe el `GroupExpenseFormView` mostrar algún indicio visual de que viene de un draft de Inbox** (vs. crear un gasto desde cero)? El precedente `.groupScheduledExpense` no tiene ningún indicio visual especial (usa el mismo form, solo con `groupChip: .readOnly` porque el grupo viene fijo). Sugerencia: **no añadir nada especial** — mantener el form idéntico, solo prellenado. Simplifica el trabajo y es coherente con "el prellenado es solo un punto de partida editable".
5. **Naming del método nuevo en `DraftService`**: propuesto `convertToGroupExpense`, pero podría alinearse mejor con el naming existente (`handleGroupScheduledExpenseApproved`, `approveDraft`). Sugerido: revisar junto con el reviewer del plan (`/review-plan`) antes de fijarlo.
6. **Currency**: si el draft tiene una `account` asignada, usar `account.currencyCode` como default del `GroupExpensePrefillTemplate`; si no, usar `draft.cachedCurrencyCode` o caer al `group.currencyCode` (el form ya tiene un `CurrencySelectorSheet` para que el usuario lo cambie si no calza).
7. **No aplica ningún bridge de "vuelta"**: la pregunta 8 del brief original (¿hace falta que el gasto de grupo se refleje personalmente, como el bridge de Caso A?) queda respondida por el código existente — `GroupExpenseService.createExpense` YA invoca `GroupTransactionBridge.bridgeExpense` automáticamente para TODO `SplitExpense` nuevo, sin importar su origen. No hay nada especial que construir aquí; es el mismo camino que toma cualquier gasto de grupo creado desde el FAB del tab Grupos.
8. **Riesgo de currency mismatch**: si el draft tiene monto en una moneda distinta a la del grupo (ej. draft en USD, grupo en PEN), el `GroupExpensePrefillTemplate.currencyCode` prellenaría con la del draft, pero el form permite cambiarla (`showCurrencyPicker`). No hace falta conversión automática — el usuario decide el monto final en el form, igual que hoy con cualquier gasto de grupo.

## Implementación

### 2026-07-05 — `8d1c9211` (branch `2.0.4`)
**Resumen:** acción "Convertir a gasto compartido" en el editor de un borrador de la bandeja. En vez de aprobarlo como `TransactionItem` personal, abre `GroupExpenseFormView` prellenado y crea un `SplitExpense` de grupo; el bridge existente refleja la contraparte en la cuenta personal; el borrador se elimina. Reusa el vehículo del precedente de pagos planificados de grupo (`b98f31cd`).

**Archivos (27 — 10 código + 16 `.strings` + coverage-index):**
- `Yala/App/Logic/DraftConversionEligibilityLogic.swift` (nuevo) — gate del botón; allowlist de 9 sources puntuales.
- `Yala/App/Logic/DraftToGroupExpenseTemplateLogic.swift` (nuevo) — `abs` del monto, fallback de moneda cached→grupo, split `.equal`.
- `Yala/App/Views/Inbox/InboxDraftEditSheet.swift` — botón terciario (no gated por `isReadyToApprove`) + `@State eligibleGroups` en `.task` + `saveDraft()` antes de convertir.
- `Yala/App/Views/Inbox/InboxView.swift` — ruteo Approach A (structs `PendingConversion`/`ConversionPickerData`/`ConversionContext`, un sheet a la vez con delays), `buildConversionContext`, `finalizeConvertedDraft`, prioridad en `onChange(selectedDraft)`.
- `Yala/Services/DraftService.swift` — `handleDraftConvertedToGroupExpense` (borra draft + refresh + telemetría/canario bridge).
- `Yala/Services/Groups/GroupService.swift` — helper `eligibleGroupsForExpense(context:)`.
- `Yala/Services/TelemetryService.swift` — evento `draftConvertedToGroupExpense`.
- `Yala/Utils/L10n.swift` + 16 `.strings` — `inbox.convertToShared`.
- `YalaTests/DraftConversionEligibilityLogicTests.swift` + `DraftToGroupExpenseTemplateLogicTests.swift` (nuevos).
- `qa/coverage-index.json` — área `inbox-convert-to-group`.

**Decisiones técnicas:**
- **Approach A** (callback a `InboxView`, no sheet anidado): todo el ruteo de drafts de grupo ya vive en `InboxView`; apilar sheets arriesga watchdog.
- **Resolver el grupo antes** (no extender `GroupExpenseComposerView`): su cambio de grupo en caliente dejaría los `participantIDs` del template stale.
- **El botón no hereda `isReadyToApprove`** ni el gate se computa fuera del sheet — descubierto en `/review-plan`: si no, un draft de Apple Pay sin subcategoría no podría convertirse, y los edits vivos del sheet se perderían. `saveDraft()` antes del callback los persiste.
- **D1 replanteado en implementación:** el helper de `GroupService` usa fetch fresco; el `GroupsViewModel` usa su cache. Hacer que el VM delegara habría roto el cache del tab. La lógica de filtro (`GroupExpenseEligibilityLogic`) ya está compartida → sin drift. **No se tocó `GroupsViewModel`.**

**Tests añadidos:** `DraftConversionEligibilityLogicTests` (barrido de los 14 `DraftSourceType`, ingreso, sin monto, sin grupos, no-pending) + `DraftToGroupExpenseTemplateLogicTests` (abs, fallback de moneda, split `.equal`, participantes). 24 tests verdes con `LocalizationParityTests`.

## QA Visual

### 2026-07-05
**Resultado:** PARCIAL — cold launch OK en simulador; flujo e2e queda para device/TestFlight.

**Cold launch (scheme Yala):**
![[qa-inbox-convert-to-group-coldlaunch-20260705-074145.jpg]]
La app arranca sin crash a la pantalla de bienvenida. Confirma que el código nuevo (2 pure-logic, cambios en `InboxView`/`InboxDraftEditSheet`/`DraftService`/`GroupService`/`TelemetryService`, migración lightweight de SwiftData) no rompe el bootstrap ni el arranque en frío.

**Verificado (estático + simulador):**
- Build scheme **Yala** verde, 0 warnings en los archivos tocados.
- 24 tests unit verdes: `DraftConversionEligibilityLogicTests` (barre los 14 `DraftSourceType`, ingreso, sin monto, sin grupos, no-pending), `DraftToGroupExpenseTemplateLogicTests` (abs del monto, fallback de moneda, split `.equal`), `LocalizationParityTests` (key `inbox.convertToShared` en 16 locales, sin marcadores/duplicados).
- Cold launch scheme Yala sin crash.
- `qa/validate-coverage.sh`: OK (área nueva `inbox-convert-to-group`).

**No reproducible en simulador (device/TestFlight):**
El botón "Convertir a gasto compartido" exige simultáneamente (a) un borrador de gasto —típicamente de Apple Pay, que no existe en el simulador— y (b) al menos un grupo elegible, que requiere iCloud/CloudKit/CKShare (no disponible en sim). Es el mismo límite que todo el subsistema de grupos/bridge.

**Pendiente device/TestFlight:**
1. El botón aparece en un gasto puntual pendiente con ≥1 grupo elegible; desaparece en un ingreso o sin grupos.
2. El botón es visible aunque el borrador no esté clasificado (sin subcategoría/cuenta) — caso Apple Pay.
3. 1 grupo → abre el form directo prellenado; >1 → selector de grupo → form.
4. Guardar → crea el `SplitExpense`, refleja la contraparte en la cuenta personal (bridge Caso A) y borra el borrador.
5. Cancelar el form deja el borrador intacto en la bandeja.

**Nota de tooling:** el scheme **Yala Dev** no compila por un error **preexistente y ajeno** en `SiriPendingStore.swift` (`SiriPendingEntry` no conforma `Equatable` bajo Swift 6); el QA se hizo con el scheme **Yala**, que compila. `agent-device` entró en conflicto con el runner de XcodeBuildMCP (su `AgentDeviceRunner` tomó el foreground), por lo que la navegación interactiva quedó limitada.

## Referencias

- Precedente: feature de pagos planificados de grupo (commit `b98f31cd`, 2026-07-01) — mismo patrón de prefill-then-confirm (`GroupExpensePrefillTemplate` + `GroupExpenseViewModel.applyTemplate` + `GroupExpenseFormView.onExpenseCreated`), pero en dirección inversa (grupo → Inbox → grupo, en vez de personal → Inbox → grupo).
- `Yala/Models/InboxDraft.swift` — modelo del draft, enum `DraftSourceType`, flags `isFromGroup`/`requiresApprovalForm`.
- `Yala/App/Views/Inbox/InboxDraftEditSheet.swift` — form de aprobación genérico (dónde va el botón nuevo).
- `Yala/App/Views/Inbox/InboxView.swift:59-124,222-295` — routing por `sourceType` y precedente `.groupScheduledExpense`.
- `Yala/Services/DraftService.swift` — `approveDraft`, guardas por `sourceType`, precedente de "esta fuente no aprueba por el path genérico".
- `Yala/App/Services/ScheduledPaymentDraftService.swift:455-499` — `handleGroupScheduledExpenseApproved`, precedente de "cerrar el ciclo tras crear el SplitExpense".
- `Yala/App/Views/Groups/GroupExpenseFormView.swift` — form de gasto compartido, `GroupExpensePrefillTemplate`.
- `Yala/App/ViewModels/GroupExpenseViewModel.swift:337-361` — `applyTemplate`.
- `Yala/App/Views/Groups/GroupExpenseComposerView.swift` — patrón "elegir grupo + abrir form" reusado por el FAB del tab Grupos.
- `Yala/App/Views/Groups/GroupPickerSheet.swift` — selector de grupo.
- `Yala/App/ViewModels/GroupsViewModel.swift:360-382` — `eligibleGroupsForExpense`, `activeMembers`, `memberNameLookup`, `memberCount`.
- `Yala/App/Logic/GroupExpenseEligibilityLogic.swift` — pure-logic de elegibilidad de grupo.
- `Yala/Services/Groups/GroupExpenseService.swift:56-140` — `createExpense`, invocación automática del bridge.

---

## QA Visual · 2026-08-14 · simulador iPhone 17 Pro (iOS 26.5), scheme Yala Dev

**AVANCE PARCIAL, y lo importante es que REFUTA la premisa que bloqueaba este QA desde julio.**

### La premisa caducada

El `qa-notes` de 2026-07-05 dice: «El flujo del boton Convertir a gasto compartido **NO es reproducible
en simulador**: exige un borrador de Apple Pay y un grupo elegible **con CloudKit**, ninguno disponible
en sim (mismo limite que todo el subsistema grupos/bridge)».

**Era cierto entonces y es FALSO hoy.** El entorno cambio por debajo: Grupos ya no vive en CloudKit
—`YalaGroups` es un store SwiftData local (`cloudKitDatabase: .none`) que el pull materializa— y
existen los seams `-uitest-fake-cloud-session` y `-uitest-groups-consent`. Es la regla de CLAUDE.md
«una hipotesis caduca: si el entorno cambio, vuelve a comprobarla».

### Verificado EN PANTALLA

Con `-uitest -uitest-seed grupos -uitest-skip-onboarding -uitest-fake-cloud-session
-uitest-groups-consent`, Panel → Bandeja de entrada (2 pendientes) → abrir el borrador «Almuerzo
equipo» (S/ -42.50, gasto puntual):

**el boton `inbox_convert_to_shared_button` («Convertir a gasto compartido») APARECE en el form de
aprobacion.** Ni el borrador de Apple Pay ni CloudKit hacen falta: basta un draft de gasto pendiente y
un grupo elegible en el store local.

⇒ el resto del guion PENDIENTE del ticket **es ejercitable en simulador**, al contrario de lo que decia.

### Lo que NO se completo en esta tanda

El flujo aguas abajo del boton (selector de grupo con >1 grupo → `GroupExpenseFormView` prellenado →
guardar crea `SplitExpense` + bridge + borra el draft; cancelar deja el draft intacto). Se perdio el
hilo por un artefacto de MI sesion, no de la app: pruebas previas de `simctl openurl` habian dejado la
app Atajos en foreground y al relanzar Yala los `elementRef` del arbol se invalidaron.

**Para la proxima tanda**: el estado se monta en un solo launch con los cuatro args de arriba y el
recorrido son 3 taps (Bandeja → draft → boton). Cuesta minutos, ya no es device-only.

### Los dos casos NEGATIVOS del guion, que valen igual

El ticket pide tambien: el boton NO debe aparecer en un INGRESO ni cuando no hay grupo elegible. Los
dos son montables aqui (un draft de ingreso; y un launch sin `-uitest-seed grupos`), y **son los que
mas facil pasan por la razon equivocada**: sin grupos sembrados el boton falta por muchas razones, asi
que hay que comprobar ANTES que el mismo draft SI lo muestra con grupos.

> [!warning] Precision sobre el ENTORNO de este QA (anotado el 2026-08-14)
> La corrida se hizo con el scheme «Yala Dev» pero **configuracion `Debug`**, y esa combinacion produce
> el bundle de **PRODUCCION** (`com.jurgenschmidt.yala`), no el `.dev`. Medido despues con
> `xcodebuild -showBuildSettings`: `Debug` → `com.jurgenschmidt.yala`; `Debug-Dev` →
> `com.jurgenschmidt.yala.dev`. Fue un error de configuracion mio, no del proyecto.
>
> **Por que lo verificado SIGUE VALIENDO**: los seams `-uitest-*` viven bajo `#if DEBUG` y el build era
> Debug, asi que funcionaron (se vieron en pantalla); y las mediciones de `UserDefaults` se hicieron
> sobre el plist del bundle QUE CORRIA, con control positivo y negativo. Lo que NO tuvo el build es
> `DEV_BUILD`, que enciende por defecto algunos flags remotos ⇒ **la corrida fue en el entorno MAS
> restrictivo**, no en uno mas permisivo.


### Correccion del guion para la proxima tanda (medido el 2026-08-14)

El guion generado para este ticket manda tapear `panel_inbox_button` tras lanzar con
`-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed grupos`. **Medido: con esos
args NO hay Panel.** `-uitest-seed grupos` deja `onboardingMode` en solo-grupos ⇒ la tab bar solo trae
Grupos / Mas / Buscar, y la Bandeja no es alcanzable. La via «Activar Yala completo» abre el
onboarding de 8 pasos, que es demasiado caro para una tanda de QA.

**Lo que SI funciona** (es como se vio el boton en la primera pasada de hoy): montar el modo COMPLETO
primero y sembrar los grupos DESPUES, sin resetear —
`-uitest -uitest-reset -uitest-seed minimal -uitest-skip-onboarding` y a continuacion un segundo
launch `-uitest -uitest-skip-onboarding -uitest-fake-cloud-session -uitest-groups-consent` **sin
`-uitest-reset`**, que conserva el modo completo y los grupos del seed anterior.

**Y el paso que mas valor tiene del guion, sin ejecutar todavia**: el 7-9, la FECHA.
`GroupExpensePrefillTemplate` no lleva campo de fecha y `GroupExpenseViewModel.date` arranca en
`.now`, asi que un borrador con fecha PASADA la perderia al convertirse. Como el seed fecha los dos
borradores en `Date.now`, quien no cambie la fecha antes de convertir vera «Hoy» y dara por buena una
AC que el codigo probablemente no cumple. **Es el primer sitio donde mirar la proxima vez.**

---

## QA Visual · SEGUNDA PASADA · 2026-08-14 · «Yala Dev» (Debug-Dev, bundle .dev)

**El flujo principal PASA. Y aparece un defecto: la conversion PIERDE la fecha del borrador.**

### Verificado EN PANTALLA

Panel → `panel_inbox_button` → `inbox_draft_row_Almuerzo equipo` (S/ -42.50) →
`inbox_convert_to_shared_button`:

| Paso | Resultado |
|---|---|
| El boton existe en un borrador de gasto | **SI** (`inbox_convert_to_shared_button`) |
| Con >1 grupo sale el SELECTOR | **SI** — dos filas `group_picker_row_<uuid>`: «Viaje a Cusco» (3 miembros) y «Viaje a Lima» (2) |
| El selector es tapeable | **SI** — el guion avisaba de que podia no serlo por ser sheet-sobre-sheet; lo es |
| El formulario abre PRELLENADO | **SI** — `group_expense_description` = «Almuerzo equipo», `group_expense_amount` = 42.50, `group_expense_group_chip` = «Grupo: Viaje a Lima», reparto ya calculado («Caro te debe S/ 21.25») y «Guardar» habilitado sin tocar nada |

### El defecto: la FECHA no viaja

`GroupExpensePrefillTemplate` (`GroupExpenseFormView.swift:24-33`) tiene **siete** campos —
`totalAmount`, `currencyCode`, `splitType`, `participantIDs`, `values`, `description`,
`accountPrefill` — y **ninguno es la fecha**. `GroupExpenseViewModel.date` (`:36`) arranca en `.now`.

⇒ un borrador de Apple Pay de hace tres dias se convierte en un gasto de grupo fechado **HOY**. La
descripcion del ticket promete literalmente reusar «los datos que el draft ya capturo (monto,
descripcion, **fecha**)».

**Honestidad sobre la evidencia: esto esta MEDIDO EN EL CODIGO, no observado en pantalla.** El
formulario mostro «Hoy», pero el borrador del seed tambien es de hoy (`DevSeedDrafts` los fecha en
`Date.now`) ⇒ **el fixture no discrimina**, que es exactamente el falso verde que el guion advertia.
Para observarlo hay que cambiar la fecha del borrador antes de convertir, y el chip de fecha del
editor **no es tapeable desde el arbol de accesibilidad** (no tiene identifier y no aparece como
target) — habria que darle uno, o sembrar un borrador con fecha pasada.

### Lo que queda sin ejercitar

Guardar (crea `SplitExpense` + bridge + borra el draft), cancelar (draft intacto), y los dos casos
NEGATIVOS (ingreso / sin grupos).

### Nota de entorno que ahorra tiempo

`-uitest-seed grupos` **NO** monta el modo solo-grupos, al contrario de lo que anote en la primera
pasada: lo montaba el residuo de un `-uitest-group-invite` de un lanzamiento ANTERIOR, que **sobrevive
a `-uitest-reset`** y ni siquiera vive en el plist de la app (se comprobo: la key `onboardingMode`
estaba ausente y el modo seguia pegado). Al encadenar corridas de QA con seams de modo, el estado
arrastra: si la tab bar sale reducida sin haberlo pedido, es eso.

## ✅ El defecto de la FECHA está ARREGLADO — 2026-08-14 (tarde), `5954306f`

Decisión del owner el mismo día: arreglarlo en el momento, ya que estaba localizado.

**Qué cambió, en lenguaje de usuario:** al convertir un borrador en gasto de grupo se conserva **su**
fecha. Antes, un borrador de hace tres días producía un gasto fechado hoy.

**Alcance real — eran DOS sitios, no uno.** El barrido encontró un segundo productor del prellenado
que tenía el mismo agujero y que este ticket no nombraba:

| Productor | Qué pasa ahora |
|---|---|
| `InboxView.loadConversionContext` → `DraftToGroupExpenseTemplateLogic` | pasa `draft.effectiveDate` (el caso de este ticket) |
| `InboxView.loadGroupScheduledContext` (aprobar un pago planificado de grupo) | pasa `draft.effectiveDate`, **no** `payment.nextDueDate`: el pago recurrente ya avanzó a la ocurrencia siguiente y habría fechado el gasto en el mes que viene |

`effectiveDate` y no `date`: éste es opcional, y su respaldo (`createdAt`) es el que el resto de la
Bandeja ya usa para mostrar y ordenar.

**El campo nuevo va SIN valor por defecto a propósito.** Un default `.now` habría cumplido la forma y
dejado el mismo agujero abierto en silencio para cualquier productor futuro — que es exactamente cómo
nacieron los dos que había. Ahora el compilador obliga a decidir la fecha.

**Tests:** `DraftToGroupExpenseTemplateLogicTests` pasa de 6 a 8, con **fecha de fixture FIJA y
PASADA**. Eso cierra el punto de honestidad que esta sección planteaba: contra un `.now` de fixture el
fallo es invisible, que es justo por lo que el QA en simulador no pudo observarlo. **Mutación
verificada a exit 65**: devolver `Date.now` al constructor tumba exactamente los dos tests nuevos y
deja los seis viejos en verde. Suite completa 5902/578 verde.

### Lo que sigue pendiente de QA en este ticket

El arreglo NO cierra el ticket. Falta ejercitar en pantalla:

1. **Guardar** — crea el gasto compartido, lo puentea a la cuenta personal y borra el borrador.
2. **Cancelar** — el borrador queda intacto.
3. Los **dos casos negativos**: que el botón no aparezca en un ingreso, ni sin grupos elegibles.
4. **Y ahora también la fecha EN PANTALLA**: el arreglo está pinneado por unitario + mutación, pero
   sigue sin observarse visualmente. Para verlo hace falta un borrador con fecha PASADA — el sembrado
   los fecha hoy, así que el fixture no discrimina. Lo desbloquea sembrar un borrador antiguo, o dar
   un identificador al chip de fecha del editor.

migrated from YalaWiki Backlog/qa_inbox-convertir-a-gasto-de-grupo.md @ 1934e8ad

## Corrida en device del owner 2026-08-28 (Jurgen, Lima, TF 2.1 build 12, teléfono A) — SIGUE EN `qa/`

El owner convirtió un borrador de la Bandeja en gasto compartido de un grupo en uso: la app no crasheó,
el borrador salió de la bandeja y el gasto quedó en el grupo. Ese PASS cerró el hermano de crash
(`inbox-crash-convert-to-group-expense` → `done/`), y **este ticket se evaluó para cerrarlo con él**.

**No se cierra.** El guion pendiente que este ticket dejó escrito el 2026-08-14 tiene cuatro puntos y la
corrida de hoy toca uno solo:

| Pendiente del 2026-08-14 | Hoy |
|---|---|
| 1 · **Guardar** crea el gasto compartido, lo puentea a la cuenta personal y borra el borrador | **Parcial**: se vio el gasto en el grupo y el borrador fuera de la bandeja; la contraparte **bridgeada a la cuenta personal** no se reportó |
| 2 · **Cancelar** deja el borrador intacto | Sin ejercitar |
| 3 · Los **dos casos negativos**: el botón no aparece en un ingreso ni sin grupos elegibles | Sin ejercitar |
| 4 · La **fecha en pantalla**, con un borrador de fecha **pasada** | Sin ejercitar |

El punto 4 es el que más pesa: el arreglo de la fecha (`5954306f`, ancestro de `2.1`) está pinneado por
unitario y mutación, pero **nunca se ha observado en pantalla**, y el sembrado fecha los borradores HOY,
así que el fixture no discrimina — es el falso verde que este mismo ticket ya se advirtió dos veces. Un
grupo en uso hoy, con un borrador de hoy, tampoco lo discrimina.

⇒ Lo que hoy queda drenado es el riesgo de **crash** del flujo, no la AC de esta feature. Para la próxima
tanda: los cuatro puntos siguen tal cual, y el punto 4 necesita un borrador con fecha pasada (sembrarlo,
o darle identificador al chip de fecha del editor).
