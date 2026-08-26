---
id: groups-budget
status: backlog
priority: medium
area: groups
created: 2026-07-01
updated: 2026-08-26
source: YalaWiki/Backlog/groups-presupuesto-de-grupo.md
---


# Presupuesto de grupo

## Problema

Un grupo de viaje o de gasto compartido recurrente (ej. "Departamento") no
tiene forma de fijar un límite colectivo y ver cuánto llevan gastado entre
todos — algo como "Presupuesto del viaje: S/3000 · llevan S/2100 (70%)" con
barra de progreso y alerta al cruzar un umbral. Hoy el único límite que existe
en Yala es `Budget`, que es enteramente personal: filtra y suma
`TransactionItem` de la cuenta del usuario, nunca `SplitExpense` del grupo.
Es el complemento natural de "pagos planificados de grupo" (ya implementado,
commit `b98f31cd`) — ese resuelve "avisar de un gasto recurrente compartido
antes de que pase"; este resolvería "avisar cuando el gasto acumulado del
grupo se acerca a un tope".

## Solución

Un límite de gasto colectivo asociado a un grupo (o a un subconjunto de sus
gastos, si se decide con filtros), calculado sobre la suma de
`SplitExpense.amount` (el monto **total** del gasto compartido, no la porción
de cada miembro) desde una fecha de inicio, con alerta al cruzar umbrales
configurables — mismo patrón de UX que `BudgetAlertService` ya usa para
presupuestos personales, pero operando sobre datos y contexto de Grupos.

## ⚠️ Riesgo de schema CloudKit (leer antes de implementar)

**El hallazgo central de este ticket, que cambia la recomendación de diseño:**
`Budget` ya tiene un campo llamado `includeSharedExpenses: Bool`
(`Yala/Models/Budget.swift:60`) — pero **ya significa algo específico y
distinto** de lo que este ticket pide. Verificado en
`Yala/App/ViewModels/BudgetsViewModel.swift:578-579`
(`filterTransactions(forBudget:)`):

```swift
// Shared expense inclusion
if !budget.includeSharedExpenses {
    filtered = filtered.filter { $0.splitExpenseID == nil }
}
```

Esto filtra `TransactionItem.splitExpenseID`
(`Yala/Models/TransactionItem.swift:86`) — es decir, controla si un
presupuesto **personal** incluye o excluye las transacciones de la cuenta
virtual personal que fueron **bridgeadas** desde un gasto de grupo (el
mecanismo del bridge A0-Bridge/M6, extensamente documentado en CLAUDE.md
2026-05-05 y 2026-07-01). Es la porción personal de cada miembro, reflejada
en SU cuenta virtual "Grupos [moneda]" — no el total colectivo del grupo. Un
presupuesto de grupo como "S/3000 entre todos" es un concepto completamente
distinto: necesita sumar `SplitExpense.amount` (el monto **total**, no la
porción de nadie) a través de todos los gastos del grupo, un dato que solo
existe en el store de Grupos, nunca en `TransactionItem`.

**Por qué esto descarta la opción (a) del enunciado del ticket ("extensión
del modelo `Budget` existente con un `groupZoneID` opcional, como se hizo con
`ScheduledPayment.groupZoneID`") como una extensión trivial:** el patrón de
`ScheduledPayment.groupZoneID` funciona porque `ScheduledPayment` sigue
siendo, en esencia, una entidad **personal** — solo indica "cuando esto se
ejecute, va a generar un gasto de grupo", pero el propio `ScheduledPayment`
vive en `personalSchema`
(`Yala/Utils/SwiftDataConfiguration.swift:85-104`) y su ciclo de vida (crear,
editar, avanzar fecha) es 100% del lado personal — el vínculo de recurrencia
"vive SOLO del lado personal" según la entrada de CLAUDE.md 2026-07-01 sobre
ese mismo feature. `Budget` en cambio necesitaría, para calcular "cuánto
llevan gastado ENTRE TODOS", leer datos que viven en `groupsSchema`
(`SwiftDataConfiguration.swift:107-115`) — un contexto SwiftData distinto,
sincronizado por un mecanismo distinto (`CKSyncEngine` manual vs.
`NSPersistentCloudKitContainer` automático, ver `personalConfiguration` vs.
`groupsConfiguration` en `SwiftDataConfiguration.swift:188-232`). Añadir un
`groupZoneID` opcional a `Budget` sin resolver esto dejaría el campo sin
ningún cálculo de spending funcional detrás — sería solo un flag decorativo.

**Confirmado también:** ni `Category` ni `Subcategory` (los filtros que
`Budget` usa hoy vía CSV mirror,
`Budget.subcategoryIDs`/`accountIDs`/`tagIDs`,
`Yala/Models/Budget+CSVMirror.swift`) existen del lado de Grupos —
`SplitExpense.subcategoryName` (`SplitExpense.swift:25`) es solo un string
plano del nombre de la subcategoría del creador, no un ID resoluble ni
compartido. Cualquier filtro de "presupuesto de grupo por categoría" tendría
que operar sobre ese string plano, con matching por nombre (frágil si el
nombre cambia de idioma o el creador la renombra — ver el bug ya cerrado
documentado en la memoria `project_groups_bridge_locale_fix`, donde el bridge
resolvía subcategorías de sistema por nombre traducido y se rompía al
cambiar idioma; cualquier filtro nuevo por nombre de subcategoría hereda ese
mismo riesgo).

**Si se opta por (b) — modelo nuevo tipo `SplitBudget`, viviendo en
`groupsSchema` junto a `SplitGroup`/`SplitExpense`/etc.** — el checklist de
deploy es el mismo patrón ya usado para cada modelo/campo de Grupos, sin
excepción:
1. Nuevo `@Model` con todas las propiedades con default explícito (CloudKit
   no admite propiedades sin default ni `@Attribute(.unique)`, ni
   relaciones non-optional — reglas inviolables del proyecto). Vínculo a
   `SplitGroup` por `groupZoneID: String` plano, **nunca** `@Relationship`
   — ningún modelo de Grupos usa relaciones SwiftData entre sí (ver
   comentarios de cabecera de `SplitExpense.swift`, `SplitMember.swift`:
   "Vinculado a SplitGroup via groupZoneID (no @Relationship)").
2. Nuevo entry en `CKConstants.RecordType`
   (`Yala/Services/Groups/CloudKitConstants.swift:20-26`) + un nuevo enum de
   campos (ej. `CKConstants.BudgetField`, espejando `GroupMetaField`/
   `ExpenseField`).
3. Las 3 funciones de traducción bidireccional en `CKRecordTranslator`
   (`Yala/Services/Groups/CKRecordTranslator.swift`) — `applyBudgetFields`,
   `budget(from:)`, `update(_:from:)` — siguiendo el patrón exacto de las 4
   secciones ya existentes ahí (SplitGroup↔GroupMeta, SplitExpense,
   SplitMember, SplitShare, SplitSettlement), con lectura default-safe
   (`record[F.campo] as? Tipo ?? default`, o `readBool(record, key:,
   default:)` para booleanos) para tolerar records viejos sin el campo.
4. **Añadir el modelo nuevo a `groupsSchema`**
   (`SwiftDataConfiguration.swift:107-115`) — esto es una migración
   SwiftData del store `YalaGroups`, el mismo store que protagonizó la saga
   de crashes de restore de iCloud documentada extensamente en CLAUDE.md
   (entradas 2026-06-20 a 2026-06-22: "Sync de Grupos [CKSyncEngine] NO debe
   arrancar/`save()` sobre el `mainContext` compartido antes de que el
   primer import personal de CloudKit se asiente — crash-loop en restore de
   iCloud"). Un modelo nuevo no causa ese bug por sí mismo, pero cada pieza
   nueva en ese schema es una superficie más donde un problema de timing
   similar puede reaparecer si el código que lo alimenta (el chequeo de
   umbral, análogo a `BudgetAlertService`) no respeta el mismo gate de
   quiescencia que ya protege el resto del sync de Grupos
   (`SplitSyncStartGate`).
5. Nuevo case en el switch de clasificación de
   `handleFetchedRecordZoneChanges`
   (`Yala/Services/Groups/SplitSyncManager.swift:1037` en adelante, que
   despacha por `record.recordType`) y en `applyGroupMeta`/`applyExpense`/
   etc. (funciones privadas de `SplitSyncManager` que insertan/actualizan
   cada tipo de modelo tras un fetch remoto — buscar `applyExpense`,
   `SplitSyncManager.swift:1613-1626`, como plantilla exacta a replicar
   para `applyBudget`).
6. Deploy en CloudKit Dashboard — revisar el diff antes de confirmar
   (append-only en producción, sin margen de error de tipo, sin poder
   borrar un campo/record type una vez desplegado).
7. **El chequeo de umbral (equivalente a `BudgetAlertService`) debe leer
   `SplitExpense` desde el mismo `ModelContext` de Grupos** — verificar
   contra el patrón ya usado por `GroupExpenseService.fetchExpenses(for:)`
   (`GroupExpenseService.swift:519-527`) y `GroupBalanceService`, y
   **cualquier `save()` que ese chequeo dispare** (ej. para marcar "ya
   notifiqué este umbral", si se implementa con estado persistido en el
   nuevo modelo) hereda el mismo riesgo de timing de boot descrito en el
   punto 4 — debe gatearse por quiescencia igual que el resto del sync de
   Grupos, nunca disparar en boot temprano sin ese gate.

## Plan técnico

### Modelo/campos nuevos propuestos

**Recomendación: opción (b), modelo nuevo `SplitBudget`** — no una extensión
de `Budget` (ver justificación completa en la sección de riesgo: `Budget`/
`BudgetAlertService`/`BudgetsViewModel.calculateSpending` están cableados
100% sobre `TransactionItem` y el contexto personal; extenderlo con un
`groupZoneID` dejaría el campo sin cálculo funcional detrás, o forzaría a
`BudgetAlertService` a aprender a leer un segundo `ModelContext` para un solo
caso de uso, contaminando un servicio hoy simple y puramente personal).

Campos propuestos para `SplitBudget` (viviendo en `groupsSchema`, junto a
`SplitGroup`):
- `id: UUID`
- `groupZoneID: String` — vínculo plano a `SplitGroup`, mismo patrón que
  `SplitExpense.groupZoneID`.
- `name: String` — ej. "Presupuesto del viaje".
- `limitAmount: Double`
- `currencyCode: String`
- `startDate: Date` — desde cuándo se cuenta el gasto acumulado (a diferencia
  de `Budget` personal, que tiene períodos recurrentes
  `weekly`/`monthly`/`yearly`/`unique` — un presupuesto de viaje probablemente
  es más simple, un solo período fijo sin recurrencia, aunque podría
  reusarse `periodType`/`endDate` de `Budget` como inspiración si se quiere
  soportar "presupuesto mensual del departamento compartido", recurrente).
- `alertThresholds: String?` — CSV de umbrales, mismo formato que
  `Budget.alertThresholds` (`Budget.swift:57`, ej. `"50,75,100"`).
- `isArchived: Bool = false`
- `ckSystemFieldsData: Data?` — igual que todos los modelos de Grupos, para
  uploads sin conflicto.

**Filtro opcional por categoría (V2, no V1):** dado que `SplitExpense` solo
tiene `subcategoryName: String?` como texto plano (sin ID resoluble
cross-member, ver sección de riesgo), un filtro "presupuesto solo para
gastos de categoría Transporte" en V1 sería frágil (matching por string) —
**recomendación: V1 sin filtro de categoría, el presupuesto de grupo aplica a
TODOS los gastos del grupo** (o a un subconjunto por fecha, que es
suficiente para el caso de uso "presupuesto del viaje"). Un filtro por
categoría queda como V2, y solo si el proyecto decide en el futuro
sincronizar algún catálogo de categorías compartido entre miembros de un
grupo (lo cual no existe hoy y sería un cambio de schema mucho más grande).

### Servicios/vistas existentes a reutilizar

- `BudgetAlertService`
  (`Yala/Services/BudgetAlertService.swift`) — **no extender directamente**,
  pero sí usarlo como plantilla exacta de patrón: un servicio nuevo
  `GroupBudgetAlertService` (o método nuevo dentro de un servicio de Grupos
  existente) replicaría la misma estructura: fetch de presupuestos activos
  con alertas habilitadas → fetch de gastos relevantes → calcular % →
  `BudgetAlertTracker`-equivalente para no re-notificar el mismo umbral (el
  tracker actual, `BudgetAlertTracker.shared`, es puramente personal —
  verificar si puede reusarse tal cual con un `periodKey` distinto, o si
  necesita su propia instancia scoped a Grupos).
- `GroupExpenseService.fetchExpenses(for:)`
  (`GroupExpenseService.swift:519-527`) — ya filtra por
  `groupZoneID`+ordena por fecha; el cálculo de spending del presupuesto de
  grupo puede filtrar el resultado por `startDate` (y `endDate` si se decide
  soportarlo) sin necesitar un fetch nuevo.
- `GroupBalanceService` no aplica aquí — calcula deudas entre miembros, no
  suma total del grupo. La suma total simplemente es
  `expenses.reduce(0) { $0 + $1.amount }` sobre el resultado de
  `fetchExpenses(for:)`, filtrado por fecha — no requiere lógica de balance.
- `NotificationService.shared.sendNotification(title:body:deepLink:)` — mismo
  canal que ya usan `BudgetAlertService.sendNotification` y
  `GroupNotificationService`, con `deepLink: "groups/\(groupID.uuidString)"`.
- UI: `GroupDetailView`/`GroupSettingsView` — un presupuesto de grupo
  probablemente aparece como una card nueva en el detalle del grupo, con
  barra de progreso (reusar el componente visual que `BudgetsListView`/
  `BudgetDetailView` ya usan para presupuestos personales, si es un
  componente compartido — verificar si hay un `BudgetProgressBar` o similar
  reutilizable sin acoplarlo al modelo `Budget` personal).
- L10n: revisar `L10n.Budgets.alertMessage50/75/90/100`
  (usadas por `BudgetAlertService.sendNotification`,
  `BudgetAlertService.swift:203-206`) como plantilla de copy, adaptando a
  contexto de grupo (mencionar quién/qué grupo, no solo el nombre del
  presupuesto).

### Qué falta construir

1. Modelo `SplitBudget` + los 3 puntos de tacto CloudKit (checklist de la
   sección de riesgo) + añadirlo a `groupsSchema`.
2. CRUD básico (crear/editar/archivar presupuesto de grupo) — probablemente
   en `GroupExpenseService` o un servicio nuevo dedicado, owner-only o
   cualquier miembro (a decidir — mismo patrón de permisos que
   `validateCurrentUserCanWrite`, `GroupExpenseService.swift:577-587`).
3. Cálculo de spending: suma de `SplitExpense.amount` desde `startDate`,
   excluyendo `isOpeningBalance == true` (igual que `GroupBalanceService`
   excluye settlements no confirmados — un saldo de apertura no es "gasto
   nuevo del viaje").
4. Servicio de chequeo de umbral (plantilla: `BudgetAlertService`), con su
   propio tracker de "ya notifiqué este umbral" — decidir si vive en
   `UserDefaults` local (más simple, sin riesgo de schema, pero no
   sincroniza "ya se notificó" entre dispositivos del mismo usuario ni
   informa a otros miembros que ya se avisó) o en un campo del propio
   `SplitBudget` (sincronizado, pero cada notificación dispararía un
   `enqueueSave` del presupuesto — evaluar si es aceptable dado que los
   umbrales cambian con poca frecuencia, a diferencia del caso de
   "recordatorio de liquidación" donde el mismo problema se descartó por
   ruido; aquí probablemente es aceptable porque cruzar un umbral de 50/75/
   90/100% no ocurre tan seguido como "cada semana sin actividad").
5. UI: card de presupuesto de grupo en el detalle del grupo, con barra de
   progreso y % — reusar componentes visuales de `Budget` personal si
   existen desacoplados del modelo.
6. Toggle de alertas + umbrales configurables en la UI de creación/edición.
7. L10n para todo el copy nuevo.
8. Tests pure-logic para el cálculo de spending y de umbral cruzado (mismo
   patrón que `BudgetAlertService.calculateBudgetStatus`/
   `BudgetsViewModel.calculateSpending`, que ya son testeables sin
   `ModelContext` en su núcleo de cálculo).
9. `qa/coverage-index.json` actualizado con el área nueva.

## Acceptance Criteria

- [ ] Un grupo puede tener un presupuesto colectivo con nombre, monto límite,
      moneda y fecha de inicio.
- [ ] El cálculo de "cuánto llevan gastado" suma `SplitExpense.amount`
      (monto total del gasto compartido, no la porción de un miembro) desde
      la fecha de inicio, excluyendo saldos de apertura.
- [ ] Se dispara una alerta al cruzar los umbrales configurados (mismo
      esquema 50/75/90/100% que `Budget` personal, o el que se decida).
- [ ] La misma alerta no se re-envía al mismo umbral más de una vez.
- [ ] El presupuesto de grupo se sincroniza correctamente vía CKSyncEngine —
      todos los miembros ven el mismo progreso tras el sync.
- [ ] Un `SplitBudget` viejo (si se añaden campos en una iteración futura) no
      crashea al leerse — fallback default-safe.
- [ ] La UI muestra una barra de progreso y el % consumido en el detalle del
      grupo.
- [ ] Tests pure-logic para el cálculo de spending y umbral cruzado.
- [ ] `qa/coverage-index.json` actualizado en el mismo commit.

## Notas

- **Decisión de diseño abierta:** ¿un grupo puede tener más de un
  presupuesto simultáneo (ej. "Presupuesto del viaje" + "Presupuesto de
  comida" dentro del mismo viaje) o solo uno activo a la vez? El enunciado
  original ("multi-presupuesto por grupo, más potente") sugiere que sí — el
  modelo `SplitBudget` propuesto ya soporta esto naturalmente (N registros
  por `groupZoneID`), a diferencia de si se hubiera optado por poner el
  límite como un campo único directo en `SplitGroup` (que solo permitiría
  uno). Esto refuerza la recomendación de modelo nuevo sobre "un campo de
  límite en `SplitGroup`" como alternativa más simple pero menos potente —
  mencionada aquí porque es la verdadera alternativa (a) de bajo riesgo de
  schema (un campo `budgetLimitAmount: Double?` + `budgetCurrencyCode:
  String?` directo en `SplitGroup`, sin modelo nuevo, sin nuevo record
  type) si el owner prefiere simplicidad sobre potencia y descarta
  multi-presupuesto.
- **Alternativa de menor riesgo, si se prioriza velocidad de entrega sobre
  potencia:** un solo límite directo en `SplitGroup` (2 campos nuevos:
  `budgetLimitAmount: Double?`, con `budgetCurrencyCode` implícito =
  `SplitGroup.currencyCode` ya existente, sin necesitar campo nuevo para
  eso) evita el checklist completo de "modelo nuevo" (sin nuevo
  `RecordType`, sin nuevo caso en el switch de `SplitSyncManager`) — solo
  serían 2 campos más en `applyGroupFields`/`group(from:)`/`update(_:from:)`
  de `CKRecordTranslator`, el mismo patrón ya usado para `isArchived`/
  `isHiddenForAll`. Esto es estrictamente más simple de desplegar que un
  modelo nuevo, al costo de renunciar a multi-presupuesto por grupo. Discutir
  con el owner cuál prioridad pesa más antes de implementar — este ticket
  documenta ambas rutas para que la decisión sea informada, no para
  prescribir una sola.
- Relación con "pagos planificados de grupo" (commit `b98f31cd`): ese
  feature vive enteramente del lado personal (`ScheduledPayment`) y nunca
  toca el schema de Grupos — no es un precedente de bajo riesgo aplicable
  aquí, a diferencia de lo que su similitud superficial ("otro feature de
  Grupos que avisa de algo") podría sugerir. El precedente de riesgo
  correcto para este ticket es más bien la serie de cambios de schema de
  Grupos ya hechos con cuidado (`isArchived`/`isHiddenForAll` en
  `SplitGroup`, `SplitMemberStatus.pendingApproval`/`.rejected` en
  `SplitMember`) — todos campos añadidos a modelos **existentes**, nunca un
  modelo enteramente nuevo. Este ticket sería, si se opta por (b), el primer
  modelo nuevo en `groupsSchema` desde que el sistema de Grupos está en
  producción — vale la pena tratarlo con el nivel de cuidado más alto posible
  (plan revisado con `/review-plan`, testing exhaustivo de upgrade-over-install,
  y verificación de que el chequeo de umbral respeta el gate de quiescencia)
  antes de considerarlo "solo otro campo más".

migrated from YalaWiki Backlog/groups-presupuesto-de-grupo.md @ 1934e8ad
