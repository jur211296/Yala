---
id: groups-log-expense-via-chat-voice
status: backlog
priority: medium
area: groups
created: 2026-07-01
updated: 2026-08-26
source: YalaWiki/Backlog/groups-registrar-gasto-por-chat-voz.md
---


# Registrar gasto de grupo por chat/voz ("cena 120 dividida entre todos")

## Problema

Hoy el Chat IA "Pregúntale a Yala" solo puede registrar transacciones **personales** — si el usuario escribe "cena 120 dividida entre todos" mientras está en un grupo, no hay ningún camino para que eso se convierta en un `SplitExpense` de grupo. El usuario tiene que salir del chat, entrar al grupo, y llenar el form manual.

## Solución

Extender el pipeline de registro por chat (que hoy produce `ChatTransactionDraft` → `TransactionItem` personal) para que, cuando detecte intención de gasto de grupo, en vez de crear un draft personal prellene el form de gasto de grupo (`GroupExpenseFormView`) ya existente — mismo patrón "prefill-then-confirm" que ya usa la feature de pagos planificados de grupo (shippeada 2026-07-01).

## Por qué es Tier 1 (bajo riesgo)

No toca el schema CloudKit de Grupos. Reutiliza el modelo `SplitExpense`/`SplitShare` y el flujo de creación (`GroupExpenseService.createExpense`) sin cambios — solo cambia CÓMO se llega a prellenar el form (desde un draft de chat en vez de un tap manual o un `ScheduledPayment` vencido).

## Estado actual confirmado en el código (2026-07-01)

**Nada en el pipeline de chat es hoy consciente de grupos:**

- `ChatIntent` (`Yala/App/Models/ChatAssistantModels.swift:271-275`) solo tiene 3 cases: `ask`, `register`, `ambiguous`. Sin noción de grupo.
- `ChatIntentClassifierService.swift` — el prompt del clasificador (`buildSystemPrompt()`, 16 ejemplos few-shot) está 100% enmarcado en transacciones personales ("hoy gasté 50 en mercado" → register). Cero menciones a grupos.
- `ChatTransactionDraft` (`Yala/App/Models/ChatTransactionDraft.swift`) — struct `Codable` en memoria (vive en el blob de `UserDefaults` del chat del día, no en SwiftData hasta que el usuario guarda). **Sin ningún campo de grupo** (`groupZoneID`, participantes, split type).
- `FullFinancialContextBuilder.swift` (contexto financiero que ve el LLM en el flujo `ask`) — **cero referencias a `SplitGroup`/`SplitExpense`**. El LLM no puede ver "estás en los grupos X, Y, Z" hoy.

**El flujo de registro personal (`runRegisterFlow` en `ChatAssistantService.swift`)**: clasifica intent → `TranscriptionParserService.shared.parseMultiple(...)` (LLM aparte, compartido con voz) → `[ParsedTransaction]` → `DraftBuilder.build(...)` → `ChatTransactionDraft` → attachment `.drafts([draft])` en la respuesta del chat. El usuario edita/confirma vía `ChatDraftPrefill` → `RouterIntent.presentNewTransactionFromChatDraft` → abre `NewTransactionView` (personal) prellenado. **No hay ningún `RouterIntent` case para abrir un form de gasto de grupo** — los `RouterIntent` de Grupos existentes (`presentGroupInviteOnboarding`, `presentGroupReconnect`, `offerRestoreBeforeInvite`, `showInviteError`, `showGroupSyncError`, `presentFullModeActivation`) son todos de onboarding/sync, ninguno de creación de gasto.

**El scaffold exacto ya existe, para otro trigger — pagos planificados de grupo (shippeado hoy, commit `b98f31cd`):**

`GroupExpenseViewModel.applyTemplate(_ template: GroupExpensePrefillTemplate)` con:
```swift
struct GroupExpensePrefillTemplate {
    let totalAmount: Double
    let currencyCode: String
    let splitType: SplitType
    let participantIDs: [UUID]
    let values: [UUID: Double]     // per-participant raw value, vacío para .equal
    let description: String
    let accountPrefill: Account?
}
```
Se dispara desde `InboxView.swift:251-264` cuando un draft `.groupScheduledExpense` es tocado: carga grupo + members + construye el template desde el `ScheduledPayment` origen → presenta `GroupExpenseFormView(initialTemplate:, onExpenseCreated:)` en modo **confirmar-antes-de-guardar** (el usuario ve el form prellenado, debe tocar Guardar). Esto es exactamente el patrón a reutilizar — cambiando la fuente del template de un `ScheduledPayment` a un parseo de chat.

`InboxDraft` (`Yala/Models/InboxDraft.swift`) ya tiene `DraftSourceType.groupScheduledExpense` con `requiresApprovalForm: Bool { sourceType == .groupScheduledExpense }` (fuerza el form dedicado en vez de quick-approve) y campos `splitGroupZoneID`/`sourceScheduledPaymentID` para el vínculo — precedente directo para un futuro `.chatGroupExpense`.

**El cálculo de split ya está separado y es reusable**: `GroupSplitCalculator.calculate(total:splitType:participants:) -> [(memberID: String, amount: Double)]?` (`Yala/App/Logic/Calculators/GroupSplitCalculator.swift`) — toma un total + tipo de split + participantes y devuelve los montos por miembro. Un pipeline de chat llamaría esta misma función con `splitType: .equal` y los miembros activos seleccionados.

## Plan técnico

### Servicios/vistas existentes a reutilizar

| Archivo | Qué aporta |
|---|---|
| `ChatIntentClassifierService.swift` | Base del clasificador — extender con un 4to intent o post-clasificación |
| `TranscriptionParserService.swift` | Parser de monto/descripción compartido con voz — reusar tal cual para extraer monto+descripción |
| `GroupExpenseViewModel.applyTemplate(_:)` + `GroupExpensePrefillTemplate` | Scaffold de prefill-then-confirm ya shippeado (pagos planificados de grupo) |
| `GroupExpenseFormView` | Form de confirmación/edición — se reutiliza sin modificar |
| `GroupSplitCalculator.calculate(...)` | Cálculo de montos por miembro dado un split type |
| `GroupPickerSheet` | Disambiguación de grupo si el usuario pertenece a 2+ grupos y no especificó cuál — recibe `[SplitGroup]` ya cargado, sin `ModelContext` |
| `InboxDraft.requiresApprovalForm` / `DraftSourceType.groupScheduledExpense` | Precedente de cómo forzar el form dedicado en vez de quick-approve |

### Qué falta construir

1. **Detección de intención de grupo**: un 4to `ChatIntent` (ej. `.registerGroup`) o una post-clasificación por keywords ("dividido", "compartido", "grupo", "entre todos") sobre un `.register` ya detectado — decidir el enfoque según qué tan bien lo maneje el LLM del clasificador actual vs necesitar un prompt/few-shot nuevo.
2. **Contexto de grupos para el LLM** (opcional, mejora la detección): extender `FullFinancialContextBuilder` con la lista de grupos activos del usuario, para que el LLM pueda reconocer "cena en Depa Miraflores" si el usuario nombra un grupo.
3. **Parser de split desde texto libre**: extraer participantes ("entre todos" = todos los miembros activos; "entre Juan y yo" = 2 específicos) — puede empezar solo soportando `.equal` entre todos los miembros activos en v1, dejando splits específicos por nombre como v2.
4. **Nuevo `RouterIntent` case** (ej. `presentGroupExpenseFromChatDraft`) que cargue el `GroupExpensePrefillTemplate` + dispare `GroupPickerSheet` si hay ambigüedad de grupo, en vez de `ChatDraftPrefill`/`presentNewTransactionFromChatDraft`.
5. **Decidir el modelo de draft intermedio**: ¿un nuevo case de `ChatTransactionDraft` con campos de grupo, o un tipo paralelo? Dado que `ChatTransactionDraft` vive en memoria (no SwiftData) hasta confirmar, hay flexibilidad — pero hay que decidir si conviene reusar el mismo struct con campos opcionales de grupo o separar limpiamente.

## Acceptance Criteria

- [ ] El usuario, estando en el chat, puede escribir "cena 120 dividida entre todos" y recibir un draft que, al confirmar, abre `GroupExpenseFormView` prellenado con el monto, descripción y split equal entre los miembros activos del grupo relevante.
- [ ] Si el usuario pertenece a 2+ grupos y no especifica cuál, se presenta `GroupPickerSheet` para elegir antes de prellenar.
- [ ] Si el usuario no pertenece a ningún grupo, el chat degrada limpio a registro personal (comportamiento actual, sin cambios).
- [ ] El form prellenado NO se guarda automáticamente — el usuario debe confirmar/editar y tocar Guardar (mismo patrón que pagos planificados de grupo).
- [ ] Privacidad: solo el texto que el usuario escribe se envía a OpenAI — no se envía historial de gastos del grupo ni de otros miembros.
- [ ] Localización de cualquier copy nuevo en los 16 locales del proyecto.

## Notas

- **Decisión abierta**: ¿cómo el usuario indica "esto es de un grupo" — debe mencionar el grupo/participantes explícitamente ("dividido entre todos"), o el chat debería preguntar "¿esto es un gasto compartido?" cuando detecta ambigüedad? V1 razonable: solo activar el flujo de grupo si el texto contiene señales explícitas (dividido/compartido/grupo/entre + nombres), sin preguntar proactivamente — evita fricción en el caso común (gasto personal).
- **v1 vs v2**: limitar v1 a split `.equal` entre todos los miembros activos del grupo (sin parsear "solo entre Juan y yo" en texto libre) reduce mucho la complejidad del parser y cubre el caso de uso más común ("cena dividida entre todos"). Splits específicos por nombre quedan como iteración futura.
- Pagador en v1: siempre el usuario actual (igual que Caso A del bridge) — no intentar detectar "pagó Juan" desde texto libre en la primera versión.

migrated from YalaWiki Backlog/groups-registrar-gasto-por-chat-voz.md @ 1934e8ad
