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
├── GroupMemberRow.swift
├── GroupInviteOnboardingView.swift    // Onboarding invitado (2 pasos)
├── GroupReconnectView.swift           // Reconexión para dormidos
└── GroupNudgeBanner.swift             // Banners contextuales de conversión

Yala/App/Views/Panel/
└── GroupsSummaryWidget.swift           // Widget de grupos en PanelView

Yala/App/ViewModels/
├── GroupsViewModel.swift
├── GroupDetailViewModel.swift
└── GroupExpenseViewModel.swift

Yala/App/Services/
├── UserSegmentService.swift            // Calcula segmento del usuario
└── NudgeService.swift                  // Nudges con frequency capping

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
├── SplitSettlement.swift
├── UserSegment.swift                   // Enum de segmentos
└── OnboardingMode.swift                // .full | .groupInvite | .completed
```

---

## Segmentos de usuario y estrategias diferenciadas

### Segmentación automática por datos reales

El segmento se determina por comportamiento observable, nunca por autodeclaración. Se recalcula en cada sesión.

| Segmento | Señal | Perfil |
|----------|-------|--------|
| **Invitado** | `onboardingMode: .groupInvite` | Llegó por link, no hizo onboarding completo |
| **Dormido** | Onboarding completo + <5 transacciones totales | Instaló, configuró, no enganchó |
| **Esporádico** | 5-30 transacciones, frecuencia irregular (>7 días promedio entre sesiones) | Lo usa de vez en cuando |
| **Activo** | >30 transacciones, frecuencia regular (<7 días entre sesiones) | Lo usa consistentemente |
| **Power user** | >100 transacciones + usa presupuestos o insights o exportación | Le saca jugo a Yala |

```swift
enum UserSegment: String {
    case invited      // onboardingMode == .groupInvite
    case dormant      // onboarding completo, <5 tx
    case sporadic     // 5-30 tx, sesiones irregulares
    case active       // >30 tx, sesiones regulares
    case powerUser    // >100 tx + features avanzadas

    static func current(
        onboardingMode: OnboardingMode,
        totalTransactions: Int,
        avgDaysBetweenSessions: Double,
        usesAdvancedFeatures: Bool
    ) -> UserSegment { ... }
}
```

### Principio rector

**Nunca pedirle algo que no le interesa. Nunca mostrar un nudge que el usuario ya superó.** Darle lo que vino a buscar y dejar que sus propios datos hagan el trabajo de conversión.

---

### Momento 1: Recibir la invitación al grupo

**Invitado (nuevo — no tiene Yala):**
Toca link → App Store → instala → detectamos `onboardingMode: .groupInvite`.

Onboarding reducido (2 pasos vs 7):

- **Paso 1: Bienvenida contextual**
  - Header: "[Nombre] te invitó al grupo **[Nombre grupo]**"
  - Avatar del grupo + ícono + avatares de miembros existentes
  - Subtítulo: "Yala te ayuda a dividir gastos y saber cuánto debes o te deben"
  - TextField: "Tu nombre" (prefilled del nombre de iCloud si disponible)
  - Botón: "Unirme al grupo"
- **Paso 2: Directo al grupo.** Navega a GroupDetailView inmediatamente. Sin cuenta, sin categorías, sin moneda, sin nada más.

Setup silencioso en background:
- `onboardingMode: .groupInvite` en UserDefaults
- Moneda preferida copiada del grupo
- Cuenta "General" creada automáticamente (destino de TransactionItems del puente)
- Categorías seed creadas en background (para cuando active modo completo)

**Dormido (tiene Yala abandonada):**
El link de grupo es una **segunda oportunidad**. No mostramos onboarding (ya lo hizo). Pantalla de reconexión:
> "Bienvenido de vuelta. Ana te invitó a **Depa Miraflores**."
> [Unirme al grupo]

Grupos se promociona como tab principal temporalmente. Es su nuevo punto de entrada. Si Yala no le enganchó por el registro manual, quizás le engancha por lo social. Cada notificación del grupo = una apertura de app = oportunidad de re-engagement.

**Esporádico (usa Yala de vez en cuando):**
Acepta invitación con un tap. Banner post-aceptación:
> "Tus gastos compartidos ahora aparecen junto a tus registros personales."

El grupo le da una razón para volver más seguido. Las notificaciones sociales (alguien agregó un gasto, alguien pagó) son más motivadoras que las notificaciones de reporte.

**Activo / Power user:**
Cero fricción. Acepta → va al grupo → sigue usando Yala como siempre. Grupos es una feature más, integrada naturalmente.

---

### Momento 2: Experiencia dentro de Grupos

**Invitado — lo que VE:**
- Tab Grupos (como tab principal, no en "Más")
- Dentro del grupo: gastos, saldos, liquidaciones — funcionalidad completa
- Tab "Mis registros" simplificada (solo sus gastos compartidos como TransactionItems)
- Notificaciones del grupo

**Invitado — lo que NO ve (todavía):**
- Panel con gráficas y widgets
- Estadísticas, presupuestos, pagos planificados, insights
- Configuración financiera avanzada
- Nada que requiera conocimiento financiero

Yala se siente como Splitwise. Limpio, simple, enfocado en lo que vino a hacer.

**Dormido/Esporádico — lo que cambia:**
- Grupos aparece como tab promocionada (no en "Más") si tienen grupos activos
- TransactionItems de grupos se integran en sus registros existentes
- Estadísticas incluyen gastos compartidos automáticamente

**Activo/Power user — integración completa:**
- Grupos como sección accesible (tab o en "Más" según personalización)
- Gastos compartidos integrados en Panel, Statistics, Insights, presupuestos
- Insights cruzados personal + compartido (ver sección de Insights IA)

---

### Momento 3: Nudges de conversión por segmento

**Regla de oro:** Nunca mostrar un nudge que el usuario ya superó. Frequency capping via `NudgeService` (max 1/semana, max 3/mes).

#### Invitado → objetivo: activar modo completo

| Timing | Nudge | Trigger |
|--------|-------|---------|
| Semana 1-2 | Cero nudges. Solo grupos. Que se sienta cómodo. | — |
| Semana 3 | "Este mes llevas S/ 850 en gastos compartidos. ¿Quieres ver en qué más gastas?" | Acumula >S/ 500 en gastos compartidos |
| Semana 4 | "Acabas de pagar S/ 120. ¿Quieres registrar de dónde salió?" | Después de liquidar una deuda |
| Mes 2 | "Tus grupos representan el 35% de lo que gastas. El otro 65% no lo estás viendo." | >10 gastos compartidos acumulados |
| Mes 2+ | "3 de tus amigos en [grupo] ya usan Yala completo" | Miembros del grupo con `onboardingMode: .completed` |

**Trigger psicológico para Perú:** No decir "gestiona tus finanzas" (suena a tarea aburrida). Decir **"¿A dónde se va tu plata?"** — pregunta universal de fin de mes. Yala responde con datos que ya tiene.

#### Dormido → objetivo: re-engagement via grupos

| Timing | Nudge | Trigger |
|--------|-------|---------|
| Inmediato | Grupos como tab principal | Al aceptar invitación |
| Semana 1 | Push: "Tu grupo tiene 3 gastos nuevos" | Cambios remotos via CKSyncEngine |
| Semana 2 | "Ya llevas S/ 450 en gastos compartidos. Tus otros gastos siguen sin registrar" | >5 gastos compartidos |
| Semana 3 | "Registra un gasto en 5 segundos" (con deep link al FAB) | Después de abrir Yala por notificación de grupo |

#### Esporádico → objetivo: aumentar frecuencia

| Timing | Nudge | Trigger |
|--------|-------|---------|
| Semana 1 | "Registraste 3 gastos compartidos esta semana pero solo 1 personal" | Desbalance compartido vs personal |
| Semana 2 | "¿Sabías que puedes poner presupuesto para gastos compartidos?" | >10 gastos compartidos en el mes |
| Mes 2 | "Tus gastos en [grupo] subieron 40% este mes" | Variación significativa |

#### Activo / Power user → objetivo: profundizar, no molestar

| Timing | Nudge | Trigger |
|--------|-------|---------|
| Siempre | Cero nudges de conversión (ya está convertido) | — |
| Contextual | Insights cruzados: "Gastos compartidos = 22% de tu presupuesto de Comida" | Tiene presupuesto + gastos en grupo con categoría similar |
| Si no es Pro | "Tus grupos generan muchos datos. Con Pro puedes ver insights con IA de tus gastos compartidos" | >3 grupos activos |

---

### Activación del modo completo (Invitado/Dormido)

Cuando el usuario decide activar, mini-onboarding de 2 pasos:
1. "¿Cuál es tu cuenta principal?" (banco/efectivo, saldo opcional)
2. "¿Quieres que te avisemos de tus gastos?" (notificaciones)

Todo lo demás ya existe: categorías seeded, moneda configurada, nombre registrado, historial de gastos compartidos como datos reales. Empieza con ventaja — no parte de cero.

`onboardingMode` pasa a `.completed`. Tabs se expanden al layout completo.

---

### Estrategia comercial

**Grupos es 100% FREE.** Sin límites de miembros, grupos ni gastos. Razones:
- Cada usuario de grupos es un canal de distribución orgánico (invita amigos → instalan Yala)
- Costo por usuario casi cero (CloudKit gratuito hasta volúmenes altos)
- La conversión a Yala completo es orgánica, basada en datos reales del usuario
- PRO se vende después, cuando ya están enganchados (insights IA, exportación, temas)

**Métricas clave:**
- Invites enviados por grupo (viralidad k-factor)
- % de invitados que activan modo completo (conversión)
- Tiempo promedio invitado → usuario completo (engagement)
- % de usuarios completos que vinieron via grupos (canal de adquisición)
- Retención de invitados a 30/60/90 días
- Retención de dormidos reactivados vs dormidos sin grupo

---

### Consideraciones técnicas

- `OnboardingMode` enum: `.full` (nuevo normal) | `.groupInvite` (invitado) | `.completed` (activó todo)
- `UserSegment` enum calculado en cada sesión por `UserSegmentService`
- `MainTabView` muestra tabs según `onboardingMode`:
  - `.groupInvite`: Grupos (principal) + Mis Registros (simplificado)
  - `.full`/`.completed`: Panel + Statistics + Records + Más (como hoy), con Grupos promocionado si hay grupos activos
- `NudgeService`: frequency capping (max 1/semana, max 3/mes), nunca repite nudge ya visto, respeta segmento actual
- `GroupTransactionBridge` funciona sin cuenta configurada (usa cuenta "General" auto-creada)
- Al activar modo completo, TransactionItems existentes se mantienen — el usuario no pierde historial
- Telemetría: `groupInviteAccepted`, `groupNudgeShown(type)`, `groupNudgeTapped(type)`, `fullModeActivated(fromSegment)`, `groupInviteSent`

---

## Integración de Grupos en Smart Insights (IA)

### Datos disponibles para el motor de insights

Cada TransactionItem generado por el puente tiene `splitExpenseID != nil`. Esto permite al motor de insights (rule-based y LLM) distinguir gastos personales de compartidos y cruzar ambas dimensiones.

**Datos que el puente expone al motor:**
- Monto de "tu parte" (ya es el TransactionItem)
- Monto total del gasto compartido (via SplitExpense cache)
- Grupo de origen (via SplitExpense → groupZoneID → SplitGroup)
- Quién pagó (paidByMemberID)
- Tipo de split (equal/exact/percentage/shares)
- Si fue liquidado o no
- Categoría asignada

### Insights rule-based (FREE)

Reglas nuevas para `InsightsCalculator` que se activan cuando el usuario tiene gastos compartidos:

**Proporción compartido vs personal:**
> "Este mes, el 28% de tus gastos fueron compartidos. El mes pasado fue 19%."

Regla: `sharedExpenseRatio = sharedTotal / totalExpense`. Mostrar cuando ratio > 15% y hay variación significativa vs periodo anterior.

**Grupo más costoso:**
> "Tu grupo 'Depa Miraflores' es donde más gastas: S/ 650 este mes."

Regla: agrupar gastos compartidos por grupo, mostrar el top 1 cuando >3 grupos activos.

**Frecuencia de gastos compartidos:**
> "Registras 12 gastos compartidos por mes, casi 1 cada 2 días."

Regla: `count(sharedTx) / daysInPeriod`. Mostrar cuando frecuencia > 0.3/día.

**Deuda pendiente alta:**
> "Tienes S/ 340 en deudas pendientes en 2 grupos."

Regla: sumar deudas no liquidadas. Mostrar cuando total > 10% del gasto mensual.

**Categoría compartida dominante:**
> "El 65% de tus gastos de Comida son compartidos."

Regla: por categoría, calcular `sharedInCategory / totalInCategory`. Mostrar cuando > 50%.

**Variación mes a mes:**
> "Tus gastos compartidos subieron 45% este mes vs el anterior."

Regla: comparar `sharedTotal` entre periodos. Mostrar cuando variación > 30%.

### Insights LLM (PRO)

El contexto enviado a GPT-4.1 Mini se enriquece con datos de grupos. Campos adicionales en el prompt:

```
## Gastos compartidos
- Total compartido este periodo: S/ 1,200 (28% del total)
- Total personal: S/ 3,100
- Grupos activos: 3 (Depa Miraflores, Viaje Cusco, Oficina)
- Grupo con más gasto: Depa Miraflores (S/ 650)
- Deuda pendiente total: S/ 340 (te deben S/ 180, debes S/ 160)
- Categorías más compartidas: Comida (65% compartido), Transporte (40%)
- Tendencia: gastos compartidos +45% vs mes anterior
```

**Tipos de insights que el LLM puede generar:**

Patrones sociales de gasto:
> "Gastas más los fines de semana cuando sales con el grupo Depa Miraflores. Los viernes tu gasto promedio sube 80%."

Optimización de liquidaciones:
> "Tienes deudas cruzadas en 2 grupos. Si Carlos te paga lo del Depa y tú le pagas lo de Oficina, se cancelan S/ 120."

Presupuesto compartido:
> "Si pusieras un presupuesto de S/ 800 para gastos compartidos, este mes lo habrías cumplido por S/ 50."

Anomalías:
> "El viaje a Cusco costó S/ 2,400 en total — 3x más que tu gasto compartido mensual normal."

Proyecciones:
> "Al ritmo actual, tus gastos compartidos este año serán ~S/ 14,400. El año pasado fueron S/ 9,600."

### Insights en contexto de grupo (GroupStatsView)

Dentro de cada grupo, los insights se enfocan en el grupo específico:

**Rule-based (FREE):**
- "Este mes el grupo lleva S/ 1,200 en gastos (tu parte: S/ 350)"
- "Carlos paga el 55% de los gastos del grupo"
- "El gasto más grande fue 'Supermercado Wong' por S/ 280"
- "El grupo gasta en promedio S/ 400/mes. Este mes va 20% arriba"

**LLM (PRO):**
- Patrones del grupo (quién gasta más, en qué categorías, tendencia)
- Sugerencias de liquidación óptima
- Comparativa entre grupos del usuario
- Predicción de cuánto costará el siguiente mes

### Panel — Widget de Grupos

Para usuarios activos/power users con grupos, un widget nuevo en PanelView:

```
┌─────────────────────────────────┐
│ Grupos                    Ver → │
│                                 │
│ Te deben    S/ 180              │
│ Debes       S/ 160              │
│ Neto        S/ 20 ↑            │
│                                 │
│ 2 liquidaciones pendientes      │
└─────────────────────────────────┘
```

Visible solo cuando el usuario tiene grupos con saldos pendientes. Tap → navega a GroupsContainerView.

### Estadísticas — Dimensión compartida

En StatisticsView (Trends/Categories), los gastos compartidos se pueden filtrar:
- Chip "Compartido / Personal / Todo" en FilterControlBar
- Gráficas respetan el filtro (solo personal, solo compartido, ambos)
- Pie charts muestran proporción compartido vs personal como categoría virtual

### Presupuestos — Inclusión de gastos compartidos

Los gastos compartidos ya son TransactionItems con categoría. Se incluyen automáticamente en presupuestos existentes. Opción adicional en BudgetFormView:
- Toggle: "Incluir gastos compartidos" (default: sí)
- Si no: `BudgetsViewModel.getBudgetSpending()` filtra `splitExpenseID == nil`

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
| **G** | GroupStatsView + insights rule-based del grupo (gastos, quien paga más, tendencia) |
| **H** | Segmentación: UserSegmentService + OnboardingMode enum + tabs dinámicas en MainTabView |
| **I** | Onboarding invitado: bienvenida contextual, setup silencioso, cuenta General auto, tabs reducidas |
| **J** | Onboarding dormido: pantalla reconexión, Grupos como tab principal, re-engagement path |
| **K** | NudgeService: frequency capping, nudges por segmento, triggers contextuales, telemetría |
| **L** | Mini-onboarding activación modo completo (2 pasos) + transición de tabs |
| **M** | Insights IA — rule-based: 6 reglas compartido/personal en InsightsCalculator |
| **N** | Insights IA — LLM: contexto enriquecido con datos de grupos en prompt GPT-4.1 Mini |
| **O** | Panel widget de Grupos + filtro compartido/personal en Statistics + toggle en presupuestos |

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
