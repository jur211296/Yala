---
id: inbox-crash-convert-to-group-expense
status: done
created: 2026-07-22
updated: 2026-08-28
source: YalaWiki/Bugs/crash-inbox-convertir-a-gasto-grupo-draft-borrado.md
---


## Fase 2 (2026-07-22, implementación) — RESUELTO (commit `88a43237`, rama `2.0.5`)

**Fix ampliado a TODA la clase de crash** (no solo la conversión reportada). El `/code-review high` adversarial cazó (verdict CONFIRMED, verificado también a mano) que los **4 sheets de finalización de grupo** (`GroupExpenseDraftFinalizationSheet`, `GroupExpenseAccountFinalizationSheet`, `GroupExpenseAccountAndSubcategoryFinalizationSheet`, `GroupSettlementDraftFinalizationSheet`) + los **drafts-puntero hermanos** que borra `DraftService.approveGroupExpenseAccountDraft`/opt-in tienen la MISMA ventana delete-antes-de-podar. La premisa del plan Fase 1 ("protegidos por su ciclo de vida — el delete ocurre dentro del sheet que tapa la fila") era **FALSA**: `InboxDraftRowView` recibe el `InboxDraft` (@Model) y lo lee en el `body`, así que observa el objeto y re-renderiza al invalidarse aunque esté cubierto por el sheet — idéntico a la conversión. Prueba decisiva: `handleDraftConvertedToGroupExpense` (conversión, crash CONFIRMADO) también llamaba `incrementDataVersion()` y aun así crasheó → el prune `dataVersion→loadData` es async y llega tarde; el fix real es podar SÍNCRONO antes del delete. Decisión del owner (AskUserQuestion): **ampliar ahora** (directiva no-diferir).

**Mecanismo (commit `88a43237`, 7 archivos, +299/−16):**
- `InboxRowPruneCoordinator` (nuevo): puente MainActor síncrono (`weak var viewModel`) para que la capa de servicio pode la fila del Inbox antes de `context.delete`. No-op si el Inbox no está montado.
- `DraftService.deleteInboxDraftPruningRow(_:in:)` (nuevo helper): reemplaza los ~9 `context.delete` de InboxDraft de los flujos de grupo (conversión + los 4 sheets vía `approveDraft` + hermanos + settlement opt-in).
- `InboxViewModel.removeDraft(id:)` (nuevo) + cableo del coordinador en `setContext`.
- `finalizeGroupScheduledExpense` (InboxView): poda vía `viewModel.removeDraft(draft)` directo — su service (`ScheduledPaymentDraftService`) vive fuera del subsistema Inbox y lo edita otra sesión en paralelo, así que no se tocó ese archivo.
- El path personal genérico (`approveDraft` → `status = .approved`, sin borrar) NO invalida el @Model → intacto (verificado).

**Tests:** `InboxRowPruneCoordinatorTests` (5, regresión DETERMINISTA — roja al revertir la poda en cualquier iOS, la red que el XCUITest no da en sim 26.x) + `InboxConvertToGroupUITests` (flujo end-to-end de conversión; usa seed `grupos-invitado` = 1 grupo elegible para evitar el `GroupPickerSheet`, inestable en XCUITest). Unit 35/35 + XCUITest 3/3 verdes; `DraftServiceHandleConvertTests` intacto; `validate-coverage` OK (áreas `inbox-crud`/`inbox-convert-to-group`/`groups-bridge-personal` actualizadas en el mismo commit).

**Repro en sim NO logrado** (iOS 26.5, el trap de SwiftData es iOS 27+); verificación manual en sim confirmó la conducta sin crash + draft reemplazado. **Pendiente: device QA en iOS 27 / TestFlight** (build nuevo) — finalizar cualquier draft de grupo (asignar subcategoría/cuenta/liquidación) + convertir, sin crash. Verificación forense opcional: simbolizar el `.ips` con dSYM de ASC (build 2).

**Nota operativa:** el fix se implementó en el repo principal (`/Users/jur/Yala`, rama `2.0.5`) con otra sesión editando en paralelo `ScheduledPaymentNotification*`/L10n; el commit aisló SOLO los 7 archivos del fix (coverage-index staged vía patch contra HEAD para no arrastrar sus cambios).

## Fase 1 (2026-07-22, investigación) — RESUMEN

- **P1 CONFIRMADA contra código vivo** (tip de `2.0.5`, `fd982447`): `onExpenseCreated` se invoca síncrono ANTES del `dismiss()` del form (`GroupExpenseFormView.swift:781`) → `finalizeConvertedDraft` → `handleDraftConvertedToGroupExpense` borra+persiste sin podar `InboxViewModel.allDrafts/pendingDrafts`. La fila observa el `@Model`; único path de borrado de bandeja sin la mitigación `removeDraftWithAnimation` — junto con el hermano de abajo.
- **Segunda instancia de la MISMA clase (hallazgo nuevo)**: `finalizeGroupScheduledExpense` → `ScheduledPaymentDraftService.handleGroupScheduledExpenseApproved` (`:491`) — mismo delete+save sin poda desde el mismo `onExpenseCreated` (drafts `.groupScheduledExpense`). El plan la incluye en el fix.
- **Repro en sim NO logrado (2 intentos completos, iPhone 17 Pro iOS 26.5, seed `grupos`)**: la conversión completa sin crash — el trap depende del assert estricto de SwiftData de iOS 27 beta (el `.ips` es 24A5380h). Observación útil del run: el bridge Caso A crea un draft NUEVO `.groupExpense` con la MISMA nota ("Falta: Subcategoría") ⇒ el XCUITest no puede assertear por `waitForNonExistence` de la fila (asserts fijados en el plan).
- **Fix diseñado**: poda + persistencia SÍNCRONAS en los 2 finalizers (NO replicar el delay 400ms del patrón canónico: el `onDismiss → loadData()` del sheet de conversión re-hidrataría el draft aún-no-borrado a ~350ms y re-abriría la ventana). Services sin cambios; los 5 tests de `DraftServiceHandleConvertTests` quedan intactos. + XCUITest nuevo `InboxConvertToGroupUITests` + coverage-index (`inbox-convert-to-group`) en el mismo commit + `/code-review high` con checklist explícito. Detalle completo en el plan.

# Crash al crear gasto compartido desde la Bandeja — `InboxDraftRowView` renderiza el draft recién borrado por la conversión

## Crash log (analizado)

- 2.0.5 (2) TestFlight, iOS 27.0 beta (24A5380h), device real. `EXC_BREAKPOINT`/SIGTRAP, thread 0.
- Stack: `_assertionFailure` de **SwiftData** ← 3 getters Yala ← closure del **label de un `Button`** ← `Button.init(action:label:)` ← body de vista Yala ← `ViewBodyAccessor.updateBody`. Patrón inequívoco: **el label de un Button lee propiedades de un `@Model` borrado/invalidado durante un re-render**.
- **Simbolización pendiente**: el dSYM de build 2 NO está en esta Mac (archives locales son build 25/26, UUID `E24B33DC…`; el objetivo es `4895A11F-F521-3633-B13D-1A37509047CC`, base `0x10476c000`). Descargar dSYMs de ASC (build 2) y correr:
  `atos -arch arm64 -o Yala.app.dSYM/Contents/Resources/DWARF/Yala -l 0x10476c000 0x104cc6b98 0x104cc7330 0x104cc79d8 0x104cc8c98 0x104cca124`

## Causa raíz (P1, match casi seguro incluso sin simbolizar)

El path de conversión bandeja→grupo borra el draft **sin podarlo antes del array cacheado del ViewModel** — es el ÚNICO path de borrado de la bandeja que no pasa por la mitigación existente:

1. `InboxDraftEditSheet.swift:755-775`: "Convertir a gasto compartido" → `saveDraft()` → callback → dismiss.
2. `InboxView.swift:378-394, 155-176`: retiene `ConversionContext(let draft: InboxDraft)` y monta `GroupExpenseFormView(presentsSuccessScreen: false, onExpenseCreated: { finalizeConvertedDraft(draft: ctx.draft) })` (`:425-438`).
3. Al guardar: `finalizeConvertedDraft` (`:206-208`) → `DraftService.handleDraftConvertedToGroupExpense` (`DraftService.swift:99-110`) → **`context.delete(draft)` + `save()` directos**, con `InboxView` aún montado bajo el sheet.
4. SwiftData invalida y notifica → SwiftUI re-evalúa las filas en el MISMO runloop, con `InboxViewModel.allDrafts`/`filteredDrafts` (`InboxViewModel.swift:103-114`) **aún reteniendo el draft borrado** (el `loadData` que poda llega después, vía `onChange(dataVersion)`/`onDismiss`).
5. `InboxDraftRowView.body` es literalmente `Button(action:) { label }` (`InboxDraftRowView.swift:23-65`) y su label lee props SwiftData-backed del draft pending (`hasAllRequiredFields` → `status` + relaciones `account`/`subcategory`, `displaySubcategoryName/AccountName/CategoryColorHex` — `InboxDraft.swift:232-274`) ⇒ assertion ⇒ SIGTRAP. Encaja frame a frame con la pila.

**La prueba de que el repo ya conocía la clase de bug:** swipe delete/reject pasan por `removeDraftWithAnimation` (`InboxView.swift:803-828`) que quita el draft del array ANTES de persistir (delay 400ms) "para evitar acceder relaciones SwiftData invalidadas". La conversión (feature del 5-jul, `8d1c9211`) no lo usa. Crash del 16-jul, mismo componente.

P2 (misma clase, otro frame): el fault en `filteredDrafts`/`groupedDrafts` leyendo `$0.status`/`effectiveDate` del borrado (`InboxViewModel.swift:106, 121`) — mismo root cause, encaja menos con el frame `Button.init`.

Descartados: success views del inbox (reciben structs de primitivos, diseñadas justo para esto); ramas archivadas de la fila (usan `cached*`).

## Fix conceptual

Alinear el path de conversión con la mitigación existente: `handleDraftConvertedToGroupExpense` debe podar primero (`viewModel.removeDraft`/patrón `removeDraftWithAnimation`) y borrar/persistir después. Revisión adicional recomendada: la fila y los computed de `InboxDraft` podrían defenderse de modelos invalidados (p.ej. guard por `isDeleted`/snapshot), pero la poda-antes-de-borrar es el fix real y consistente con el resto.

## Verificación

- Repro dirigido: 2+ borradores pendientes → convertir uno a gasto de grupo → guardar el form. Debería reproducir en sim/device.
- Confirmación definitiva: con la poda aplicada, el crash desaparece; y/o simbolizar con el dSYM de ASC (si `0x104cc6b98` resuelve a `InboxDraftRowView.body`, P1 confirmado).

migrated from YalaWiki Bugs/crash-inbox-convertir-a-gasto-grupo-draft-borrado.md @ 1934e8ad

## Owner check 2026-08-28 (Jurgen, Lima, TF 2.1 build 12, teléfono A) — QA device PASS

- Convirtió un borrador de la Bandeja en **gasto compartido de grupo**, sobre un grupo en uso ese día.
- **La app no crasheó.** El borrador **salió de la bandeja**. El gasto **quedó en el grupo**.
- Veredicto del owner: **PASS**.

⇒ **Cerrado por QA device**: el PASS drena el «Pendiente: device QA en iOS 27 / TestFlight» que la Fase 2
dejó abierto el 2026-07-22 — el único trabajo que le faltaba a este ticket.

**Este cierre es QA, no un fix nuevo.** Medido hoy en este árbol (`2.1` @ `2175e53e`): `88a43237` es
ancestro de `2.1`, `Yala/App/ViewModels/InboxRowPruneCoordinator.swift` existe y
`DraftService.deleteInboxDraftPruningRow` (definido en `:100`) tiene **9 call-sites** en
`Yala/Services/DraftService.swift` (`:115`, `:171`, `:191`, `:251`, `:691`, `:777`, `:783`, `:836`,
`:932`). Aquí no se toca Swift.

### Lo que este PASS no dice

- **Cubre el path de CONVERSIÓN**, que es el que reportó el crash log — no los otros sitios a los que el
  fix se amplió: los 4 sheets de finalización de grupo (subcategoría / cuenta / cuenta+subcategoría /
  liquidación) y los drafts-puntero hermanos **no se ejercitaron hoy**. Lo que los sostiene es
  `InboxRowPruneCoordinatorTests` (regresión determinista, roja al revertir la poda), no una observación
  en device.
- **El owner no declaró la versión de iOS del teléfono A.** El trap original es el assert estricto de
  SwiftData de iOS 27 beta (el `.ips` es 24A5380h), así que un run sin crash en un OS con el assert más
  laxo no prueba por sí solo la ausencia del bug. Lo que este PASS **sí** añade es que el path arreglado
  funciona de punta a punta en campo: el borrador se fue y el gasto llegó al grupo.
- **Hoy no hubo subida a TestFlight**: el PASS es sobre el build 12 que ya estaba en campo, no sobre
  ningún build posterior.
- La **verificación forense** que este ticket ofrecía como opcional —simbolizar el `.ips` con el dSYM del
  build 2 desde ASC— sigue **sin hacer**, y sigue siendo opcional: confirmaría el frame de un camino que
  el fix ya hizo inalcanzable.

### El hermano de feature queda en `qa/`

`inbox-convert-draft-to-group-expense` (la acción «Convertir a gasto compartido» en sí) **no se cierra
con este PASS**. La corrida de hoy usó ese flujo con éxito y eso drena la mayor parte de su punto 1
(guardar crea el gasto y borra el borrador), pero su guion pendiente del 2026-08-14 tiene tres puntos más
que hoy no se tocaron: **cancelar** deja el borrador intacto, los **dos casos negativos** (ni ingreso ni
sin grupos elegibles muestran el botón) y la **fecha en pantalla** con un borrador de fecha pasada. Ni
siquiera su punto 1 quedó completo: el owner no reportó la contraparte **bridgeada a la cuenta personal**.
AC distinta ⇒ sigue en `qa/`; ver la nota del 2026-08-28 en ese ticket.
