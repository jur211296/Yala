# Yala

App iOS de finanzas personales (SwiftUI) para registrar y entender gastos, cuentas, presupuestos y reportes con claridad.

## Posicionamiento de Marca

**Propuesta central:** "Finanzas sin esfuerzo" - Yala elimina el tedioso registro manual de gastos.

**Significado del nombre:** "Yala" viene de "ya la hice" - sensación de logro sin esfuerzo extra.

**Target:** Perú primero, luego hispanohablantes global.

**Tono:** Cercano pero profesional. Simplicidad y confianza. Alejado del tono bancario tradicional.

**Diferenciadores clave:**
- OCR para recibos (fotos)
- Reconocimiento de voz con IA
- Atajos de iOS (Shortcuts/Siri)
- Importación CSV/Excel
- Personalización completa
- Privacidad real (datos locales + iCloud privado cifrado)

Ver `.planning/MARKETING.md` para estrategia completa.

## Stack

- **Persistencia:** SwiftData
- **ModelContainer:** `SwiftDataConfiguration.swift` (inicializado en `YalaApp.swift`)
- **Entidades:** Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment, ScheduledPayment, InboxDraft, MerchantMemory, NotificationItem
- **Design System:** `DesignTokens.swift` — namespace DS con tokens de spacing, radius, typography

## Proyecto

- **Archivo:** `Yala.xcodeproj`
- **Scheme:** Yala
- **Unit Tests:** YalaTests
- **UI Tests:** YalaUITests

## Design System (DS)

Tokens centralizados en `Yala/App/Theme/DesignTokens.swift`:

```swift
DS.Spacing.xxs  // 2
DS.Spacing.xs   // 4
DS.Spacing.sm   // 8
DS.Spacing.md   // 12
DS.Spacing.lg   // 16
DS.Spacing.xl   // 20
DS.Spacing.xxl  // 24
DS.Spacing.xxxl // 32

DS.Radius.xs, .sm, .md, .lg, .xl, .card
DS.FormRow.paddingH, .paddingV, .iconWidth
DS.ListRow.spacing, .paddingH, .paddingV, .iconSize
```

**Uso:** Reemplazar valores hardcodeados (spacing: 16, padding: 12, cornerRadius: 8) por tokens DS.

## Regla Operativa

Cambios pequenos e incrementales.

Antes de commit:
1. Ejecutar `/verify-ios`
2. Si aplica, ejecutar `/test-ios` o `/uitest-ios`
3. Commits atomicos con `/commit-one`

## Restricciones

- Evitar refactors grandes
- Evitar dependencias nuevas sin justificacion

## Prioridades de Desarrollo

1. **Automatizacion** - Transacciones recurrentes, categorizacion inteligente
2. **Insights financieros** - Mejores analiticas, predicciones, recomendaciones
3. **Sincronizacion** - iCloud sync, soporte multi-dispositivo

## Deuda Tecnica Conocida

Ver `.planning/codebase/CONCERNS.md`

---

## Research Fases Futuras

### Fase 6: Pagos Planificados

**Objetivo:** CRUD de pagos recurrentes con notificaciones y widgets.

#### Modelo SwiftData: ScheduledPayment

```swift
@Model
final class ScheduledPayment {
    var name: String
    var description: String?
    var amount: Double
    var currencyCode: String

    // Recurrencia
    var frequency: String  // weekly, biweekly, monthly, quarterly, semiannual, annual, custom
    var customIntervalDays: Int?
    var startDate: Date
    var endDate: Date?  // nil = indefinido

    // Relaciones
    var account: Account?
    var subcategory: Subcategory?
    var tags: [Tag]

    // Control
    var status: String  // active, completed, paused, cancelled
    var lastExecutionDate: Date?
    var nextOccurrenceDate: Date
    var notificationEnabled: Bool = true
    var notificationMinutesBefore: Int = 1440  // 24h

    var createdAt: Date
    var updatedAt: Date
}
```

#### Enum RecurrenceFrequency

```swift
enum RecurrenceFrequency: String, Codable {
    case weekly, biweekly, monthly, quarterly, semiannual, annual, custom
}
```

#### Calculo de proxima fecha

```swift
static func calculateNextOccurrence(from: Date, frequency: String, customDays: Int?) -> Date {
    let calendar = Calendar.current
    switch RecurrenceFrequency(rawValue: frequency) {
    case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: from)!
    case .biweekly: return calendar.date(byAdding: .weekOfYear, value: 2, to: from)!
    case .monthly: return calendar.date(byAdding: .month, value: 1, to: from)!
    case .quarterly: return calendar.date(byAdding: .month, value: 3, to: from)!
    case .semiannual: return calendar.date(byAdding: .month, value: 6, to: from)!
    case .annual: return calendar.date(byAdding: .year, value: 1, to: from)!
    case .custom: return calendar.date(byAdding: .day, value: customDays ?? 30, to: from)!
    default: return calendar.date(byAdding: .month, value: 1, to: from)!
    }
}
```

#### Archivos a crear

- `Yala/Models/ScheduledPayment.swift`
- `Yala/Services/ScheduledPaymentService.swift`
- `Yala/App/Views/Planning/ScheduledPaymentsListView.swift`
- `Yala/App/Views/Planning/ScheduledPaymentEditorView.swift`
- `Yala/App/ViewModels/ScheduledPaymentsViewModel.swift`

#### Consideraciones

- Agregar ScheduledPayment al ModelContainer en YalaApp.swift
- Integrar con BackgroundJobs para ejecucion automatica
- Widget Medium: 3 proximos pagos
- Widget Large: calendario mensual

---

### Fase 7: Registro Inteligente

**Objetivo:** Entrada de transacciones por foto (OCR) y voz (Speech).

#### Vision Framework (OCR On-Device)

```swift
import Vision

func extractTextFromReceipt(_ image: UIImage) async throws -> RecognizedReceipt {
    guard let cgImage = image.cgImage else { throw OCRError.invalidImage }

    let request = VNRecognizeTextRequest()
    request.recognitionLanguages = ["es", "en"]
    request.recognitionLevel = .accurate

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    // Parsear resultados...
}
```

**Patrones de extraccion:**
- Total: buscar lineas con "total", "subtotal" + monto
- Items: lineas con descripcion + precio (regex `\d+[.,]\d{2}`)

#### Speech Framework (On-Device)

```swift
import Speech

let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
let request = SFSpeechAudioBufferRecognitionRequest()
request.requiresOnDeviceRecognition = true  // Fuerza local

speechRecognizer.recognitionTask(with: request) { result, error in
    if let result = result {
        let text = result.bestTranscription.formattedString
        // Parsear: "gaste 50 soles en supermercado"
    }
}
```

#### Archivos a crear

- `Yala/Services/ReceiptOCRService.swift`
- `Yala/Services/SpeechTranscriptionService.swift`
- `Yala/App/Views/Transactions/SmartEntryView.swift`
- `Yala/App/Models/RecognizedReceipt.swift`

#### Decision On-Device vs Cloud

| Aspecto | On-Device | Cloud |
|---------|-----------|-------|
| Privacidad | 100% local | Datos salen |
| Latencia | 3-5s | Depende red |
| Costo | Gratis | Por uso |
| Precision OCR | 95%+ | 98%+ |
| Tamano app | +50-80 MB | +2 MB |

**Recomendacion:** On-device para ambos (Vision + Speech nativo).

#### Alternativa: WhisperKit

Si Speech nativo no es suficiente, considerar WhisperKit (on-device Whisper):
- GitHub: https://github.com/argmaxinc/WhisperKit
- Mejor precision en espanol
- +150 MB en tamano de app

---

### Fase 8: Plataforma y Polish

**Objetivo:** Widgets iOS, Shortcuts, Share Sheet, Notificaciones, Autenticacion.

#### WidgetKit (iOS 17+)

```swift
import WidgetKit
import AppIntents

struct ScheduledPaymentWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "ScheduledPaymentWidget",
            intent: PaymentWidgetIntent.self,
            provider: PaymentWidgetTimelineProvider()
        ) { entry in
            ScheduledPaymentWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PaymentWidgetTimelineProvider: AppIntentTimelineProvider {
    func timeline(for config: PaymentWidgetIntent, in context: Context) async -> Timeline<Entry> {
        // Cargar datos de SwiftData
        // Generar entries
        // Refrescar cada hora
    }
}
```

#### App Intents (Shortcuts)

```swift
import AppIntents

struct QuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registrar Gasto Rapido"

    @Parameter(title: "Monto")
    var amount: Double

    @Parameter(title: "Descripcion")
    var description: String

    func perform() async throws -> some IntentResult {
        // Crear TransactionItem
        // Guardar en SwiftData
        return .result(view: ExpenseCreatedView(...))
    }
}

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickExpenseIntent(),
            phrases: ["Registrar gasto en \(.appName)", "Gaste \(.arg())"]
        )
    }
}
```

#### UNNotification Scheduling

```swift
import UserNotifications

func schedulePaymentReminder(for payment: ScheduledPayment) {
    let content = UNMutableNotificationContent()
    content.title = "Pago: \(payment.name)"
    content.body = "Vence manana - S/ \(payment.amount)"
    content.sound = .default
    content.threadIdentifier = "scheduled_payments"

    let notificationDate = Calendar.current.date(
        byAdding: .hour, value: -24, to: payment.nextOccurrenceDate
    )!

    let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour], from: notificationDate
    )

    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let request = UNNotificationRequest(identifier: "payment_\(payment.id)", content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request)
}
```

#### Archivos a crear

**Widgets:**
- `YalaWidgets/` (nuevo target)
- `YalaWidgets/ScheduledPaymentWidget.swift`
- `YalaWidgets/BalanceWidget.swift`

**Intents:**
- `Yala/Intents/QuickExpenseIntent.swift`
- `Yala/Intents/ExecutePaymentIntent.swift`
- `Yala/Intents/AppShortcuts.swift`

**Notificaciones:**
- `Yala/Services/NotificationScheduler.swift`
- `Yala/App/NotificationDelegate.swift`

**Autenticacion:**
- `Yala/Services/AuthenticationService.swift` (LocalAuthentication framework)

#### Permisos requeridos (Info.plist)

```xml
<!-- Speech -->
<key>NSSpeechRecognitionUsageDescription</key>
<string>Para registrar gastos por voz</string>

<!-- Camera (OCR) -->
<key>NSCameraUsageDescription</key>
<string>Para escanear recibos</string>

<!-- Notifications -->
<key>NSUserNotificationsUsageDescription</key>
<string>Para recordatorios de pagos</string>

<!-- Face ID -->
<key>NSFaceIDUsageDescription</key>
<string>Para proteger tus datos financieros</string>
```

---

## Recursos

**SwiftData:**
- https://developer.apple.com/documentation/swiftdata
- https://www.hackingwithswift.com/quick-start/swiftdata/

**Vision (OCR):**
- https://developer.apple.com/documentation/vision
- https://shawnbaek.com/2021/04/11/lets-make-a-receipt-text-recognizer-with-the-apple-vision-framework/

**Speech:**
- https://developer.apple.com/documentation/speech

**WidgetKit:**
- https://developer.apple.com/documentation/widgetkit

**App Intents:**
- https://developer.apple.com/videos/play/wwdc2025/244/
- https://superwall.com/blog/an-app-intents-field-guide-for-ios-developers/

**WhisperKit (alternativa):**
- https://github.com/argmaxinc/WhisperKit

---

*Actualizado: 2026-01-15*
*Actualizar cuando el alcance del proyecto evolucione*
