---
id: groups-budget
status: done
priority: medium
area: groups
created: 2026-07-01
source: YalaWiki/Backlog/groups-presupuesto-de-grupo.md
updated: 2026-09-08
qa-status: passed
qa-date: 2026-09-08
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

## Decisión Jürgen (2026-09-06)

**Un límite por grupo, no varios.** Elegida entre «un límite (dos campos en el grupo)» y «varios
presupuestos (tabla nueva)». Motivo, tal como se le puso delante y ratificó: barato de desplegar y de sincronizar, cubre el caso del viaje, y
varios presupuestos se pueden añadir después si alguien los pide. Campos: `budgetLimitAmount` en la
moneda del grupo (`currencyCode` ya existente).

**Aviso al que lo implemente:** este ticket habla de CloudKit y `CKRecordTranslator`; Grupos va hoy
por el backend propio, así que el coste de esquema es **DDL + RPCs de pull/push + gateway**, no
`RecordType`. Es una inferencia del estado actual del repo hecha al decidir, **no re-medida**: el
`/spec` la comprueba antes de reescribir el plan.

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

## 2026-09-07 — implementado (sesión autónoma)

### Lo primero: la premisa de este ticket era FALSA, y por eso el plan de arriba no se siguió

Todo el bloque «⚠️ Riesgo de schema CloudKit» y su checklist de 7 pasos hablan de
`CKConstants.RecordType`, `CKRecordTranslator`, `SplitSyncManager`, los `.ckdb` y un deploy al
CloudKit Dashboard. **Nada de eso existe ya.** Medido en este árbol el 2026-09-07: los tres símbolos
dan **cero ocurrencias de código** en `Yala/` (solo aparecen en comentarios stale y en la cabecera de
`.claude/rules/swiftdata-cloudkit.md`, que ya avisa de que la Fase 3 del Modo Nube borró el
transporte). Tampoco existe `CloudKitGroupsSchemaParityTests`, el test que ese checklist invocaba
como red.

La nota del owner del 6-sep ya lo sospechaba y pedía comprobarlo: queda **confirmado**. El coste de
esquema es DDL + grants + dos RPCs en Postgres, y **cero** CloudKit.

### Qué se construyó

Un límite por grupo, en la moneda del grupo, tal como se decidió. **Un solo campo nuevo**
(`budget_limit_amount` / `SplitGroup.budgetLimitAmount`), sin tabla ni modelo nuevos.

- **Servidor** (`qa/cloud/g14_01_group_budget_limit.sql`, **aplicado en producción**): columna
  `bytea` **cifrada** —el modelo de amenaza de G7 cifra los montos, y un tope de presupuesto lo es—,
  su grant de UPDATE por columna, y los dos RPCs que enumeran columnas (`apply_group_delta` y
  `groups_pull_rows_split_groups`).
- **Wire**: `group_capability_manifest.json`, la emisión, la proyección Merkle y las fixtures golden
  regeneradas (una muestra CON presupuesto y otra sin él, para que el golden cruce las dos ramas).
- **App**: fijar/cambiar/quitar el límite en Ajustes del grupo (solo ADMIN), y una tarjeta con barra
  de progreso en la pestaña de registros.

### Las tres decisiones de diseño que no estaban en el ticket

1. **El límite se cifra.** El ticket no lo menciona porque fue escrito antes de G7. Dejarlo en claro
   en la misma tabla cuyo `name` está cifrado habría sido una regresión del modelo de amenaza. El
   coste real fue una entrada en la lista de columnas † y **una trampa que destapó**: la
   normalización de escala del cifrado estaba atada al nombre literal `'amount'`, con el comentario
   «`'amount'` es la ÚNICA columna † numérica» — cierto hasta esta migración. Sin tocarlo,
   `budget_limit_amount` se habría cifrado como texto crudo, sin escala; con el cliente iOS de hoy el
   resultado habría sido byte-idéntico **por casualidad**, y un cliente que mandara `"3000"` habría
   dejado un root de Merkle divergente permanente para ese grupo.

2. **El progreso SÍ convierte divisas, y el resumen compartible NO.** Parece una incoherencia y no lo
   es. La regla del resumen («una moneda, un bloque: los totales nunca se suman entre divisas») tiene
   un motivo escrito: una conversión al cambio del momento **se congela en una imagen** que cada
   miembro leería distinto según cuándo se generó. Una barra de progreso no se congela: se recalcula
   al abrir la pantalla. Lo que sí la alcanzaría es **no** convertir — un viaje con tope en soles y
   media cuenta en dólares enseñaría una barra falsamente baja, que es la mentira peligrosa, la que
   deja gastar de más. Es además lo que ya hace el presupuesto PERSONAL
   (`BudgetsViewModel.budgetAmount`, «coherente con la semántica presupuesto consumido HOY»). Cuando
   hay conversión, el número va marcado con `≈`.

3. **Fijarlo es de ADMIN, y no por criterio de la app.** La policy `split_groups_update` del backend
   exige `is_group_admin`. Si la UI se lo ofreciera a un miembro normal, el server devolvería
   `{"noop":true,"reason":"not_authorized_or_gone"}`, el delta se purgaría como aplicado y el cambio
   se quedaría **solo en su teléfono**, divergiendo en silencio del resto del grupo.

### Cómo se verificó (medido, no inferido)

- **Migración**: sandbox transaccional contra el esquema y el motor REALES de producción, con el
  probe previo que confirma que el `rollback` revierte. Control positivo (admin fija 3000,0000 → el
  pull lo devuelve con la escala intacta y en disco son 75 bytes cifrados) y control negativo (un
  miembro no-admin recibe `not_authorized_or_gone` y el valor **no cambia**), este último con su
  propio control positivo: el mismo no-admin sobre `icon_name` —una columna vieja— recibe el mismo
  rechazo, así que lo que protege es la RLS y no un accidente del campo nuevo. Sin rastro tras el
  rollback: 0 filas sintéticas y los md5 de ambas funciones de vuelta a los originales.
- **Sin drift documental**: el `.ddl` del repo y el `prosrc` de producción coinciden **byte a byte**
  (md5 idénticos) antes y después de aplicar. Se comprobó ANTES de editar, precisamente porque así
  nació el drift que g13_05 tuvo que cerrar.
- **App**: 23 tests nuevos de `GroupBudgetLogic` (23/23) y 97/97 de las suites de contrato
  —paridad emisión↔manifest, proyección Merkle↔manifest y el golden cross-lenguaje—.
- **Server real**: `gateway/test/groups.goldens.test.ts` **25/25 contra staging**, que además mide
  algo útil: el manifest con la columna nueva **no rompe un server que no la tiene** mientras nadie
  fije un presupuesto. El día que alguien lo fije contra staging, fallará.

### Lo que queda abierto, y de quién es

1. **Device-QA de dos teléfonos** (no es mío: pide TestFlight y App Attest en `enforce`): que el
   límite que fija un admin aparezca en el teléfono de otro miembro tras el sync, que un no-admin no
   pueda cambiarlo, y —si se implementan los avisos— que la notificación llegue.
2. ~~**Staging arrastra ya TRES migraciones sin aplicar**~~ — **RESUELTO el 2026-09-08**: las tres aplicadas en staging y verificadas por md5 (`join_group` `4982b50d…`/5365, `apply_group_delta` `61c38595…`, el reader `2cac864c…`), grants intactos y `anon` revocado. Se destrabó dando acceso al proyecto de staging por el conector. Registro: `docs/RUNBOOK-staging-ddl.md`. Lo que decía: g13_04,
   g13_05 y g14_01 pendientes desde el 4-sep por falta de credencial de DDL. Producción ya estaba al
   día; ahora staging también, y **la bomba del dead-letter queda desarmada**.
3. **Device-QA de los avisos**, que van dentro de este mismo cambio (ver abajo) pero cuya entrega
   real solo se puede ver en un teléfono: la notificación al cruzar 50/75/90/100 %.

### Residuales conscientes

- **`budget_limit_amount` no forma unidad de coherencia con `currency_code`**, aunque el límite se
  exprese en ella. No es un olvido: el manifest es **append-only** y una columna no puede cambiar de
  grupo después de existir, así que meter `currency_code` en una unidad nueva estaba cerrado. Efecto:
  si dos personas cambian a la vez la moneda del grupo y el límite, el LWW puede quedarse con una de
  cada. Cambiar la moneda de un grupo es raro y el arreglo es re-teclear el tope.
- **La tarjeta no se pinta si el grupo no tiene ningún gasto**, porque el contenedor donde vive es la
  rama «hay registros» de la pestaña. Con cero gastos la barra diría 0 % y el tope ya se ve en
  Ajustes, así que no se reestructuró el estado vacío por ello.

### Los avisos al cruzar un umbral (dentro de este cambio)

`GroupBudgetAlertService` + `GroupBudgetAlertTracker`, con el molde de sus dos vecinos:
`BudgetAlertService` (el del presupuesto personal) para la forma, y `GroupSettlementReminderService`
para los gates de Grupos. Umbrales **fijos** 50/75/90/100 — la decisión fue un límite con **un** campo
nuevo, y unos umbrales configurables por grupo habrían pedido una segunda columna que nadie pidió.

Tres cosas que no son obvias y por las que se decidió así:

- **No hay gate de frescura**, y su vecino de dominio sí lo tiene (espera hasta 30 s por evidencia del
  canal). La diferencia es qué se afirma: el nudge de liquidación avisa de una **ausencia** («esta
  deuda lleva tres semanas sin moverse»), y una ausencia medida sobre datos sin sincronizar es falsa.
  Este avisa de una **presencia** («ya lleváis el 75 %»), y los gastos que hay en local ya son gasto
  real. Si faltan gastos por bajar, el aviso llega **tarde**; si el límite aún no ha bajado, no hay
  presupuesto y no avisa nada. Los dos errores posibles caen del lado seguro, así que pagar 30 s en
  cada foreground no compraría corrección.
- **Una sola notificación por grupo y ciclo**, la del umbral más alto. Un gasto grande puede cruzar
  cuatro umbrales de golpe, y cuatro avisos casi idénticos son ruido. Los menores se marcan igual; el
  más alto **solo si iOS confirmó la entrega**, así que un fallo de entrega lo deja reintentable.
- **El importe del tope vive DENTRO de la clave de dedup.** El presupuesto personal reparte sus claves
  por período; este no tiene períodos, tiene un tope. Cuando el tope cambia, los avisos se reabren:
  subir de 3.000 a 6.000 y volver a cruzar el 50 % es un aviso legítimo, no un duplicado — y bajarlo a
  3.000 con el grupo ya al 80 % avisa en el acto, que es justo lo que hay que decirle a quien acaba de
  recortar. La clave usa la **misma escala 4 que el wire**, para que dos importes que el canal
  representa igual compartan clave en todos los teléfonos del grupo.

Reusa el toggle de avisos de presupuesto que ya existe (`budgetAlertsEnabled`) y el maestro de
notificaciones de Grupos, en vez de inventar un ajuste nuevo. Un grupo archivado, oculto o congelado
no avisa. Las claves del tracker se barren en `DataWipeService` por prefijo, como las de su vecino.

## La review adversarial cambió el cambio, y en un sitio evitó romper la app

Cuatro lentes independientes (contrato de sync · cálculo financiero · migración y servidor · UI, permisos
y l10n). **Ninguna dio el visto bueno tal cual**, y lo que encontraron no fueron descuidos de tecleo: casi
todo eran decisiones mías defendibles que resultaron estar mal.

### Lo que estaba a punto de romper otra cosa

**El `.alert` con un botón condicional.** El editor del tope tenía `if group.budgetLimitAmount != nil {
Button("Quitar") }` dentro del `actions` builder. `.claude/rules/swiftui-ds.md` tiene medido —el 6-sep,
bisecando— que un `actions` con contenido dependiente del estado **no rompe la alerta: rompe la app**, en
una pantalla sin relación (aquel caso dejó de completarse el guardado de una transacción, y el rojo salió
en `QuickActionsFavoritesUITests`). Dos botones fijos ahora, y «quitar» se mudó a su propia fila con
confirmación — que además es mejor: era destructivo y estaba pegado a «guardar».

### Los dos que habrían llegado a producción sin que nadie los relacionara con esto

**El Merkle de TODO el parque.** Añadir una columna al manifest de Grupos cambia el root de **todas** las
filas —el canon emite `null` para las que no la traen—, y el canal de Grupos, a diferencia del personal,
**no manda `X-Yala-Capability-Set`**, así que el server no puede podar por versión. Un cliente con el
contrato anterior habría calculado un root distinto en el 100 % de sus grupos: divergencia falsa,
canario quemado y `resetGroupCursors` + re-pull completo una vez por sesión — el reset que la regla L151
declara dañino por tres vías. Es **la primera columna que se añade a ese manifest desde que existe**, así
que el precio no lo había pagado nadie todavía. Mitigado subiendo `canon_version` a `c2`: esos clientes
caen en el guard de canon y **saltan** la verificación en vez de remediar algo que no está roto. El
arreglo estructural (portar el capability-set) queda en `groups-canal-sin-capability-set`.

**Un tope de 15 dígitos se perdía en silencio.** `Canonc1Codec.decimalFixed` lanza a partir de 1e14, y
quien traga ese throw es `appendUpsert`, que devuelve `nil` y **no crea la fila de outbox** (su log vive
bajo `#if DEBUG`). El tope se guardaba en local, no salía del teléfono sin dejar rastro en Release, y el
Merkle local saltaba esa fila dejando el grupo en divergencia permanente. Ahora hay cota
(`GroupService.maxBudgetLimitAmount`) y el formulario lo rebota.

### Y los que eran defectos míos, sin más

- **«Te pasaste por S/ 0,00», en rojo.** `isExceeded` comparaba `Double` con `>` estricto sobre una suma
  de importes de dos decimales. `915,69 + 53,48 + 30,83` son 1.000,00 exactos y `1000.0000000000001` en
  coma flotante: en un barrido de repartos de 1.000 en 3-8 importes, **el 16,5 %** cruzaba el `>` por el
  último bit. Peor: mi test del borde usaba **un solo gasto de 1000**, el único caso donde el `>` y el
  `>=` decimal coinciden trivialmente — el test decía proteger justo lo que no podía ver.
- **Guardar con el campo vacío borraba el presupuesto de todo el grupo, sin avisar.**
  `AmountInputHelper.parseDecimal` devuelve `0` para lo que no sabe leer, y mi `setBudgetLimit`
  normalizaba `0` a «sin presupuesto». Abrir el editor para subir el tope, borrar el campo para
  reteclear y tocar Guardar lo quitaba para todos. Ahora lo ilegible se contesta con un aviso.
- **La fila no gateaba el grupo CONGELADO**, y el servicio sí: fila activa, guardado rechazado. Es
  literalmente lo que `GroupExpenseService` documenta como «ves algo que no funciona, que es peor que no
  verlo».
- **Los errores salían en inglés de desarrollador** (`GroupService: Only group admins…`) en los 16
  idiomas. El fichero se había dado permiso para dejarlo estar en cuatro acciones viejas «porque no las
  nombra este cambio»; ésta sí la nombra.
- **`Color.hotPink` como TEXTO sobre tarjeta**: contraste 3,77 contra el mínimo AA de 4,5, y encima en
  `caption`, para el único aviso de que te has pasado. En la barra —superficie rellena— sigue siendo
  correcto; el requisito es del texto.
- **El aviso miraba hacia atrás.** Sin línea base, reinstalar la app hacía sonar «llegasteis al
  presupuesto» por un viaje cerrado hace meses, y ponerle hoy un tope a un grupo con año y medio de
  gastos disparaba los cuatro umbrales de golpe. Ahora la primera vez que se ve un par (grupo, tope) se
  siembra lo ya cruzado **sin avisar**.
- **Archivar un grupo le borraba la memoria de avisos** y desarchivarlo volvía a anunciar lo mismo.
- **El golden del Merkle no ejercitaba el camino real**: emitía el importe como número JS mientras
  producción sirve **texto** (la columna es † y `yala_try_decrypt` devuelve `text`). Con 3000 coincide
  por casualidad — el mismo «byte-idéntico por accidente» que esta columna ya había destapado en el
  servidor, reintroducido en el test.
- **El orden de la migración.** Con la columna creada y la función vieja, un push metía el importe **en
  claro** dentro de la columna cifrada (`byteain` en formato escape acepta texto arbitrario sin error) y
  después `yala_try_decrypt` fallaba y el presupuesto desaparecía para el grupo. Producción se aplicó en
  ese orden y salió bien; el fichero va reordenado, con transacción explícita y con la firma de la
  función fijada por `::regprocedure`.
- **La afirmación central del cambio no tenía ni un test.** El comentario del apply decía que leer por
  presencia-de-clave es lo que permite QUITAR un presupuesto, y nada lo pinneaba: un `/simplify` que
  alineara esa línea con sus diez vecinas reintroducía el bug con la suite en verde. Ya hay tres.

### Dos residuales que la review dejó escritos como decisión, no como imposibilidad

1. **`budget_limit_amount` no forma unidad de coherencia con `currency_code`.** El argumento
   «el manifest es append-only» cierra *mover* `currency_code` a un grupo, pero **no cerraba** una
   columna `budget_limit_currency_code` propia — se descartó por la decisión de un solo campo. Efecto:
   si dos admins cambian a la vez la moneda del grupo y el tope, el LWW puede quedarse con una de cada, y
   **el Merkle no lo detecta** porque cliente y server coinciden en el estado malo. Es una puerta de un
   solo sentido: si mañana hace falta, ya no se arregla sin romper el append-only.
2. **El presupuesto cuenta TODO el historial del grupo**, no desde que se fijó. El AC original pedía una
   «fecha de inicio» y la decisión del 6-sep no la menciona; añadirla sería un segundo campo. Ponerle hoy
   un tope a un grupo viejo abre la barra ya excedida — coherente con el resumen compartible, que también
   cubre todo el historial por decisión tuya, pero conviene saberlo. Los AVISOS sí están protegidos por
   la línea base.

---

## QA Visual · 2026-09-08

**Veredicto: PASS** (la mitad de un solo dispositivo; lo cross-device sigue fuera, abajo).

iPhone 17 Pro (iOS 26.5), `Yala Dev`, seed `grupos`, grupo **«Viaje a Cusco»** siendo admin, con
gastos en **PEN y USD** (S/ 1.230,00 + $ 370,00).

### Lo que se vio

1. **Fijar el tope.** Ajustes del grupo → «Presupuesto del grupo» (decía «Sin presupuesto») →
   se escribió **5000** → Guardar. La fila de Ajustes pasa a mostrar **S/ 5.000,00**.
2. **La tarjeta aparece** en la pestaña de gastos del grupo, con identificador `group_budget_card`:
   - **«Quedan S/ 2.415,80»**
   - **«≈ S/ 2.584,20 de S/ 5.000,00»**
   - **«Incluye gastos en otras monedas, convertidos al cambio de hoy.»**
3. **El «≈» aparece porque hubo conversión**, que es justo lo que pedía el AC. Y la nota lo explica
   en lenguaje de usuario en vez de dejar el símbolo suelto.
4. **«Quitar presupuesto»** aparece como fila propia en Ajustes en cuanto hay tope (antes no
   estaba).

### La aritmética cuadra, y delata la conversión

```
5.000,00 − 2.584,20 = 2.415,80   ← «Quedan», exacto
2.584,20 − 1.230,00 = 1.354,20   ← la parte en USD, ya convertida
1.354,20 ÷ 370,00  = 3,66        ← TC PEN/USD implícito, plausible
```

O sea que el gasto consumido **no** es la suma cruda de 1.230 + 370: la parte en dólares entró
convertida a soles a ~3,66. Es la prueba de que el «≈» no es decorativo.

### Captura

- `qa-groups-budget-01-tarjeta-con-aprox-20260908-212258.png`

### Lo que NO se cubrió

- **El no-admin no ve la fila**: exige el perfil `grupos-invitado`, no se recorrió en esta pasada.
- **Cambiar y quitar** el tope: se vio que «Quitar presupuesto» aparece, pero no se ejecutó.
- **La mitad cross-device** (que el tope de un admin llegue al teléfono de otro miembro tras el
  sync) y **la entrega real de los avisos al 50/75/90/100 %**: eso sí es device y sigue en la cola
  del owner.
