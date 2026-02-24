# Batch 4: Quick Fixes — Remaining Functional Bugs (9 bugs)

## Context

9 bugs restantes del RELEASE-REVIEW.md que son fixes de 1-5 líneas cada uno. Los 4 bugs sistémicos de transfers (BUG-7/8/13/18) requieren un `transferPairID` en el modelo y se difieren a batch 5. BUG-11 (transfer categories por nombre) y BUG-23 (spending duplicada) son refactors que también se difieren. BUG-22 (tracker cleanup) es bajo impacto (UserDefaults crece lento).

---

## Archivos a modificar (9 + 6 L10n files)

| Archivo | Bug | Líneas cambiadas |
|---------|-----|------------------|
| `App/Views/Panel/ExchangeRateWidget.swift` | BUG-5 | 2 |
| `App/Views/Records/RecordsStandaloneView.swift` | BUG-17 | 4 |
| `Services/DraftService.swift` | BUG-31 | 8 |
| `App/Views/Inbox/InboxBulkActionsSheet.swift` | BUG-32 | 3 |
| `App/Views/SplashScreenView.swift` | BUG-35 | 4 |
| `App/Views/Settings/NotificationsSettingsView.swift` | BUG-36 | ~5 |
| `App/Views/Profile/ProfileView.swift` | BUG-38 | 6 |
| `App/Views/Import/ImportIntroSheet.swift` | BUG-39 | 1 + 6 L10n |
| `App/Views/Settings/SubscriptionView.swift` | BUG-40 | 1 |

---

## Implementación

### BUG-5: ExchangeRateWidget solo 2 colores de moneda
`ExchangeRateWidget.swift:39-40` — reemplazar 2 propiedades por array indexado:
```swift
// Reemplazar:
private var currencyAColor: Color { theme.accent }
private let currencyBColor = Color.hotPink

// Con:
private var currencyColors: [Color] { [theme.accent, Color.hotPink, Color.teal] }
```
Y en los usos, cambiar `currencyAColor`/`currencyBColor` por `currencyColors[index % currencyColors.count]`.

### BUG-17: No hay "Deselect All" en modo selección
`RecordsStandaloneView.swift:190-194` — toggle entre Select All y Deselect All:
```swift
ToolbarItem(placement: .topBarTrailing) {
    let allSelected = recordsViewModel.selectedRecordIDs.count ==
        recordsViewModel.groupedRecords.flatMap(\.records).count
    Button(allSelected ? L10n.Export.deselectAll : L10n.Export.selectAll) {
        if allSelected {
            recordsViewModel.deselectAll()
        } else {
            recordsViewModel.selectAll()
        }
    }
}
```
**Nota:** `L10n.Export.deselectAll` ya existe en L10n.swift y 6 locales. No necesita creación.

### BUG-31: DraftService no actualiza MerchantMemory al aprobar
`DraftService.swift:~192` — después de crear la transacción en `approveDraft()`, añadir:
```swift
// Update Merchant Memory
if !draft.note.trimmingCharacters(in: .whitespaces).isEmpty,
   let subcategory = transaction.subcategory {
    let merchantService = MerchantMemoryService(modelContext: context)
    merchantService.updateMemory(
        merchantRaw: draft.note,
        subcategory: subcategory,
        wasCorrection: false
    )
}
```
**Nota:** InboxDraft usa `note: String` (no `cachedNote`). También añadir la misma lógica en `bulkApprove()` para consistencia.

### BUG-32: Bulk subcategory selector hardcodeado a `.expense`
`InboxBulkActionsSheet.swift:182` — detectar tipo de drafts seleccionados:
```swift
// Reemplazar: transactionType: .expense
// Con:
transactionType: selectedDrafts.allSatisfy {
    $0.subcategory?.safeCategory.isIncome == true
} ? .income : .expense
```
**Nota:** InboxDraft no tiene `cachedIsIncome`. Usar `subcategory?.safeCategory.isIncome`. Si selección es mixta, default a `.expense` (muestra más opciones).

### BUG-35: SplashScreen timer nunca se invalida
`SplashScreenView.swift:133` — almacenar timer y limpiar en onDisappear:
1. Añadir `@State private var particleTimer: Timer?`
2. Cambiar `Timer.scheduledTimer(...)` → `particleTimer = Timer.scheduledTimer(...)`
3. Añadir `.onDisappear { particleTimer?.invalidate() }` al view

### BUG-36: swipeActions en ScrollView no funciona
`NotificationsSettingsView.swift:387-395` — `.swipeActions` requiere `List`, no funciona en `VStack`/`ScrollView`. Reemplazar por `.contextMenu` que funciona en cualquier container:
```swift
// Reemplazar .swipeActions block con:
.contextMenu {
    if let onDelete = onDelete {
        Button(role: .destructive) { onDelete() } label: {
            Label(L10n.Notifications.delete, systemImage: "trash")
        }
    }
}
```

### BUG-38: Voice permission request ignora resultado del callback
`ProfileView.swift:480` — manejar resultado del callback para `.undetermined` (voz):
```swift
// Reemplazar: AVAudioApplication.requestRecordPermission { _ in }
// Con:
AVAudioApplication.requestRecordPermission { granted in
    DispatchQueue.main.async {
        if !granted {
            voiceInputEnabled = false
            permissionDeniedType = L10n.Settings.voiceInputEnabled
            showPermissionDeniedAlert = true
        }
    }
}
```
`ProfileView.swift:~584` — manejar resultado del callback para `.notDetermined` (imagen):
```swift
// Reemplazar: PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
// Con:
PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
    DispatchQueue.main.async {
        if status == .denied || status == .restricted {
            imageInputEnabled = false
            permissionDeniedType = L10n.Settings.imageInputEnabled
            showPermissionDeniedAlert = true
        }
    }
}
```

### BUG-39: Import success message hardcodeado en español
`ImportIntroSheet.swift:616` — cambiar string hardcodeada por L10n:
```swift
// Reemplazar: message: "\(createdCount) registros importados correctamente."
// Con: message: L10n.Import.recordsImported(createdCount)
```
**Paso previo:** Crear key `L10n.Import.recordsImported` en L10n.swift + 6 Localizable.strings:
- es: `"%d registros importados correctamente."`
- en: `"%d records imported successfully."`
- de/fr/it/pt: traducciones correspondientes

### BUG-40: StoreKitManager no reactivo en SubscriptionView
`SubscriptionView.swift:16` — cambiar `private var` a `@State`:
```swift
// Reemplazar: private var store = StoreKitManager.shared
// Con: @State private var store = StoreKitManager.shared
```

---

## Bugs diferidos a batch 5+ (requieren más trabajo)

- **BUG-7/8/13/18:** Transfers sin par ID (requiere `transferPairID` en modelo — cambio sistémico)
- **BUG-11:** Transfer categories buscan por nombre español (requiere flag en Category model)
- **BUG-22:** BudgetAlertTracker cleanup incompleto (bajo impacto, UserDefaults crece lento)
- **BUG-23:** Spending calculation duplicada (refactor, no rompe funcionalidad)
- **BUG-34:** Cuenta default en onboarding (requiere diseño UX + localizaciones)

---

## Verificación

1. `/verify-ios` — build limpio
2. `/test-smart` — tests existentes pasan
3. Actualizar RELEASE-REVIEW.md — marcar 9 bugs como `[x]`

## Orden de ejecución

1. Leer archivos necesarios (en paralelo)
2. Crear keys L10n faltantes (deselectAll, recordsImported) + 6 Localizable.strings
3. Aplicar todos los edits (agrupados por archivo)
4. `/verify-ios`
5. `/test-smart`
6. `/commit-one`
