# Grupos — Diseño de funcionalidad (Splitwise-like)

> Estado: Investigación completada. Pendiente de implementación futura.
> Última actualización: 2026-02-25

## Resumen

Funcionalidad de división de gastos integrada en Yala. Permite crear grupos, dividir gastos entre miembros, hacer seguimiento de deudas, y registrar automáticamente la parte del usuario como TransactionItem.

---

## Decisiones de arquitectura

### Solo CloudKit compartido (Tier 2)
- **NO hay modo local/offline-only.** Todos los usuarios tienen iCloud (iOS only).
- Datos compartidos usan CloudKit directo (`CKRecord` + `CKShare` + `CKSyncEngine`).
- Datos personales siguen en SwiftData (como hoy).
- Si no hay cuenta iCloud → estado vacío explicando que se necesita iCloud.

### Invitación solo por enlace
- El admin genera link via `CKShare` → share sheet nativo.
- No hay búsqueda por email, teléfono ni alias.
- El alias es solo display name dentro del grupo, no mecanismo de búsqueda.
- Flujo: Admin genera link → invitado toca → Yala se abre → acepta → aparece como miembro.

### Dos capas de datos
```
┌─────────────────────────────────────────────────┐
│                   Yala App                       │
├────────────────────┬────────────────────────────┤
│   CAPA PRIVADA     │     CAPA COMPARTIDA        │
│   (como hoy)       │     (nueva)                │
│                    │                            │
│   SwiftData        │   CloudKit directo         │
│   + CloudKit auto  │   CKSyncEngine x2          │
│                    │   (private + shared DB)     │
│   TransactionItem  │                            │
│   Account          │   SplitGroup (CKRecord)    │
│   Category         │   SplitExpense (CKRecord)  │
│   Budget           │   SplitShare (CKRecord)    │
│   ...              │   SplitSettlement (CKRec.) │
│                    │                            │
│                    │   encryptedValues para      │
│                    │   montos y descripciones    │
├────────────────────┴────────────────────────────┤
│          PUENTE: splitExpenseID en               │
│          TransactionItem vincula ambas capas     │
└─────────────────────────────────────────────────┘
```

### Encriptación
- Campos sensibles (montos, descripciones, notas) → `record.encryptedValues`
- Campos para queries (fecha, memberID, isSettled) → `record["field"]` normal
- Solo participantes del CKShare pueden desencriptar
- Apple maneja distribución de llaves via iCloud Keychain
- Con Advanced Data Protection activado, ni Apple puede leer los datos

---

## Modelo de datos — Capa compartida (CloudKit directo)

Cada grupo = una `CKRecordZone` en la private database del creador.

```
CKRecordZone: "SplitGroup-{uuid}"
├── CKShare (1 por zona, gobierna acceso)
│
├── CKRecord "GroupMeta"
│   ├── encrypted: name, description
│   └── plain: currencyCode, createdAt, iconName, colorHex,
│              simplifyDebts (Bool)
│
├── CKRecord "SplitExpense" (N por grupo)
│   ├── encrypted: amount, description, note
│   └── plain: date, paidByMemberID, splitType, isSettled,
│              currencyCode
│
├── CKRecord "SplitMember" (N por grupo)
│   ├── encrypted: displayName
│   └── plain: memberID (CKShare.Participant userRecordID),
│              role (admin|member), joinedAt
│
├── CKRecord "SplitShare" (N por expense, 1 por miembro)
│   ├── encrypted: amount
│   └── plain: expenseRecordName, memberID, isPaid
│
└── CKRecord "SplitSettlement" (N por grupo)
    ├── encrypted: amount, note
    └── plain: fromMemberID, toMemberID, date, isConfirmed
```

### splitType (cómo dividir un gasto)
- `equal` — partes iguales (default)
- `exact` — montos específicos por persona
- `percentage` — porcentajes
- `shares` — proporciones (2:1:1)

### Puente con TransactionItem (SwiftData)
- Campo nuevo en TransactionItem: `splitExpenseID: String?`
- Cuando se crea un SplitExpense → se genera TransactionItem por "tu parte"
- Si se edita el SplitExpense → se actualiza el TransactionItem vinculado
- Si se elimina → se elimina el TransactionItem

---

## Modelo de datos — Cache local (SwiftData)

Para rendimiento y acceso offline, los datos compartidos se cachean localmente:

```swift
// SplitGroup — cache local del GroupMeta
@Model final class SplitGroup {
    var id: UUID = UUID()
    var cloudKitZoneID: String = ""       // "SplitGroup-{uuid}"
    var name: String = ""
    var iconName: String = "person.2.fill"
    var colorHex: String = "#8B5CF6"
    var currencyCode: String = "PEN"
    var simplifyDebts: Bool = false
    var createdAt: Date = Date()
    var isOwner: Bool = false              // true si yo creé el grupo
    var isArchived: Bool = false
}

// SplitMember — cache local
@Model final class SplitMember {
    var id: UUID = UUID()
    var groupZoneID: String = ""
    var displayName: String = ""
    var cloudKitUserRecordID: String = ""  // CKRecord.ID del usuario
    var role: String = "member"            // "admin" | "member"
    var isCurrentUser: Bool = false
    var joinedAt: Date = Date()
}

// SplitExpense — cache local
@Model final class SplitExpense {
    var id: UUID = UUID()
    var groupZoneID: String = ""
    var amount: Double = 0
    var currencyCode: String = ""
    var expenseDescription: String = ""
    var note: String?
    var date: Date = Date()
    var paidByMemberID: String = ""
    var splitType: String = "equal"
    var isSettled: Bool = false
    var createdAt: Date = Date()
}

// SplitShare — parte de cada miembro en un gasto
@Model final class SplitShare {
    var id: UUID = UUID()
    var expenseID: UUID = UUID()
    var memberID: String = ""
    var amount: Double = 0
    var isPaid: Bool = false
}

// SplitSettlement — liquidación entre miembros
@Model final class SplitSettlement {
    var id: UUID = UUID()
    var groupZoneID: String = ""
    var fromMemberID: String = ""
    var toMemberID: String = ""
    var amount: Double = 0
    var currencyCode: String = ""
    var note: String?
    var date: Date = Date()
    var isConfirmed: Bool = false
}
```

---

## UI — Vista principal: GroupsContainerView

Ubicación: Tab "Más" → Grupos. Background: `PanelBackgroundView()`.

### Toolbar
Patrón `DetailContainerView`:
- **Trailing glass group 1:**
  - Botón estadísticas (`chart.bar.xaxis`) → sheet insights
  - Botón filtro (`line.3.horizontal.decrease`) → Menu
    - Todo (default)
    - Con saldos pendientes
    - Donde debo
    - Donde me deben
  - Dot hotPink cuando filtro activo
- **ToolbarSpacer(.fixed, placement: .topBarTrailing)**
- **Trailing glass group 2:** `ProfileToolbarItem`

### Search
`.searchable` filtra grupos por nombre (scope local a esta vista).

### Resumen header
Patrón `ScheduledPaymentsView` summary card:
- Dos columnas: "Te deben" (successForeground) | "Debes" (hotPink)
- Montos agrupados por moneda
- `.thCard`, `DS.Radius.xl`, stroke + shadow

### Lista de grupos
Patrón `BudgetRowView`:
- Icono circular 40x40 (color + SF Symbol)
- Nombre del grupo + "{N} personas"
- Línea de deudas: "Te deben X · Debes Y"
- Saldo neto a la derecha (moneda preferida, verde/hotPink)
- `.thCard`, `DS.Radius.md`, stroke + shadow

### FAB
Patrón `DetailContainerView` FAB:
- Manual (electricIndigo)
- Voz (hotPink)
- Imagen (teal)
- Nuevo grupo (`#8B5CF6` purple)

### Empty state
```swift
YalaEmptyState(
    icon: "person.2.slash",
    title: "Sin grupos",
    message: "Crea un grupo para dividir gastos con otras personas",
    actionTitle: "Crear grupo"
)
```

---

## UI — Creación de grupo: GroupFormView (sheet)

Patrón `IconColorPickerSheet` + formulario:
- Preview icono 80x80 → tap abre `IconColorPickerSheet`
- TextField: nombre del grupo
- CurrencyPicker: moneda del grupo (para cálculos de saldo neto)
- Toggle: Simplificar saldos (reduce pagos necesarios entre miembros)
- Toolbar: Cancelar / Guardar

---

## UI — Dentro del grupo: GroupDetailView (fullScreenCover)

### Navegación
- navigationTitle con nombre del grupo
- Back button (chevron) para volver a lista
- Botón settings (⚙️) arriba a la derecha

### Chips de navegación
Patrón `DetailContainerView` (safeAreaInset top, glass effect):
- **Registros** (`list.bullet`) — lista de gastos del grupo por fecha
- **Saldos** (`arrow.left.arrow.right`) — quién debe a quién + liquidar
- **Estadísticas** (`chart.pie`) — gráficas del grupo

### FAB
Dentro del grupo: botón + para nuevo gasto compartido.

---

## UI — Ajustes del grupo: GroupSettingsView (sheet)

Patrón `ProfileView` con `SectionBox`:
- Icono grande editable (tap → IconColorPickerSheet)
- Nombre editable (TextField)
- Moneda del grupo
- Toggle simplificación

### Sección Miembros
- Lista de miembros con rol (Admin 👑 / Miembro)
- El admin ve context menu en cada miembro: convertir en admin / eliminar
- Múltiples admins permitidos

### Acciones
- Invitar por enlace (share sheet con URL de CKShare)
- Salir del grupo (destructive)
- Eliminar grupo (solo admin, destructive, confirmación)

---

## UI — Registro de gasto compartido: GroupExpenseFormView

Similar a `NewTransactionView` pero para el grupo:
- Monto + moneda
- Descripción
- Fecha
- "Pagado por" → selector de miembro
- "Dividir entre" → selector de miembros (excluir los que no participan)
- Tipo de split: igual / montos exactos / porcentajes / proporciones
- Categoría (opcional, para estadísticas)
- Nota (opcional)

Al guardar:
1. Crea SplitExpense + SplitShare por cada miembro en CloudKit
2. Crea TransactionItem local por "tu parte" via GroupTransactionBridge

---

## Notificaciones

### Nuevo NotificationType
```swift
case groups = "groups"
// icon: "person.2.fill", color: "#8B5CF6", time: 10:00 AM
// isDeletable: false, requiresDynamicContent: true
```

Se agrega a `createDefaults()` como sortOrder 7, inactivo por defecto.

### Deep link
Nuevo case `DeepLinkDestination.groups` → navega a Más → Grupos.

### Prompt primera vez
En `GroupsContainerView.onAppear`: si `!hasSeenGroupsNotificationPrompt` (@AppStorage), mostrar alerta preguntando si activar notificaciones de grupos.

### Eventos que disparan notificación
- Nuevo gasto agregado por otro miembro
- Liquidación recibida
- Nuevo miembro se unió
- Cambio en un gasto existente

Se detectan via `CKSyncEngine` al recibir cambios en zona compartida → `GroupNotificationService` genera notificación local.

---

## Algoritmo de simplificación de deudas

Cuando `simplifyDebts = true`:
- Se ejecuta localmente (no necesita server)
- Algoritmo minimum cash flow (greedy, O(n²))
- Ejemplo: A→B $10, B→C $10 se simplifica a A→C $10

Cuando `simplifyDebts = false`:
- Solo suma y resta directa de quién debe a quién
- Sin optimización de transferencias

---

## CKSyncEngine — Sync manager

Dos instancias de `CKSyncEngine`:
1. **Private engine** — zonas de grupos que yo creé
2. **Shared engine** — zonas de grupos donde me invitaron

### Responsabilidades
- Sync bidireccional de CKRecords
- Cachear state token para resume
- Actualizar modelos locales (SwiftData) cuando llegan cambios remotos
- Ejecutar GroupTransactionBridge cuando cambian gastos
- Disparar GroupNotificationService cuando hay cambios de otros

### Conflictos
Estrategia: **server wins + notificar al usuario**. En datos financieros es mejor que todos vean el mismo dato. Discrepancias se resuelven socialmente.

---

## Límites de CloudKit

| Límite | Valor |
|--------|-------|
| Participantes por CKShare | ~100 |
| Records al crear share | 5,000 (sin límite después) |
| Tamaño por record | 1 MB |
| encryptedValues | Mismos límites que campos normales |
| Tipos en encryptedValues | String, Double, Date, Data, CLLocation, Array |
| NO encriptable | CKRecord.Reference |

---

## Estructura de archivos

```
Yala/App/Views/Groups/
├── GroupsContainerView.swift
├── GroupCardView.swift
├── GroupSummaryHeader.swift
├── GroupDetailView.swift
├── GroupSettingsView.swift
├── GroupFormView.swift
├── GroupExpenseFormView.swift
├── GroupSplitSelectorView.swift
├── GroupBalancesView.swift
├── GroupRecordsView.swift
├── GroupStatsView.swift
└── GroupMemberRow.swift

Yala/App/ViewModels/
├── GroupsViewModel.swift
├── GroupDetailViewModel.swift
└── GroupExpenseViewModel.swift

Yala/Services/
├── SplitSyncManager.swift
├── DebtSimplificationService.swift
├── GroupTransactionBridge.swift
└── GroupNotificationService.swift

Yala/Models/
├── SplitGroup.swift
├── SplitMember.swift
├── SplitExpense.swift
├── SplitShare.swift
└── SplitSettlement.swift
```

---

## Fases de implementación

| Fase | Alcance |
|------|---------|
| **A** | Modelos SwiftData + SplitSyncManager (CKSyncEngine x2) + CKShare zone creation |
| **B** | UI: GroupsContainerView + GroupFormView + GroupCardView + GroupSummaryHeader + empty state |
| **C** | UI: GroupDetailView con chips + GroupSettingsView + invitación/aceptación CKShare |
| **D** | GroupExpenseFormView + split selector + GroupTransactionBridge (puente → TransactionItem) |
| **E** | GroupBalancesView + DebtSimplificationService + liquidaciones |
| **F** | GroupNotificationService + NotificationType.groups + prompt primera vez |
| **G** | GroupStatsView + insights sheet desde toolbar |

---

## Referencias

- [Apple sample-cloudkit-zonesharing](https://github.com/apple/sample-cloudkit-zonesharing)
- [Apple sample-cloudkit-encryption](https://github.com/apple/sample-cloudkit-encryption)
- [Apple sample-cloudkit-sync-engine](https://github.com/apple/sample-cloudkit-sync-engine)
- [Zone sharing in CloudKit — Swift with Majid](https://swiftwithmajid.com/2022/03/29/zone-sharing-in-cloudkit/)
- [CKSyncEngine — Superwall](https://superwall.com/blog/syncing-data-with-cloudkit-in-your-ios-app-using-cksyncengine-and-swift-and-swiftui/)
- [CloudKit sharing permissions — Tact Blog](https://blog.justtact.com/cloudkit-share-permissions/)
- [CKShare — Apple Documentation](https://developer.apple.com/documentation/cloudkit/ckshare)
- [Encrypting User Data — Apple Documentation](https://developer.apple.com/documentation/cloudkit/encrypting-user-data)
- [WWDC21: What's new in CloudKit](https://developer.apple.com/videos/play/wwdc2021/10086/)
- [WWDC23: Sync to iCloud with CKSyncEngine](https://developer.apple.com/videos/play/wwdc2023/10188/)
- [Splito (open source, SwiftUI + Firebase)](https://dev.to/divyesh_vekariya/i-found-splito-an-exciting-open-source-bill-splitting-app-31di)
