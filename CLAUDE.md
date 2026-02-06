# Yala (iOS)

## Decisiones Recientes (TTL: hasta cierre de fase)

Esta sección contiene decisiones de diseño tomadas en la fase actual del ROADMAP.
Al cerrar la fase, este contenido se archiva en DECISIONS.md.

[Aquí irán decisiones temporales con formato: [FECHA] Decisión breve]

## Producto
Yala es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack
- Swift, SwiftUI
- Persistencia: SwiftData
- Proyecto: .xcodeproj
- Scheme principal: Yala
- Unit tests: YalaTests
- UI tests: YalaUITests
- **Target iOS 26+** - SIEMPRE usar APIs nativas de iOS 26 (Liquid Glass, ToolbarSpacer, etc.)
- **Simulador estándar: iPhone 17 Pro** (SIEMPRE usar este para builds, tests y simulación)

## iOS 26 Liquid Glass (OBLIGATORIO)
**SIEMPRE preferir APIs nativas de iOS 26 para mantener la app moderna y actualizada.**

Ejemplos de APIs a usar:
- `ToolbarSpacer(.fixed, placement: .topBarTrailing)` para crear grupos glass separados en toolbars (⚠️ placement es OBLIGATORIO)
- `.glassEffect()` para chips, barras flotantes y elementos translúcidos
- Nuevos estilos de NavigationBar con morphing automático
- Cualquier API nueva que reemplace patrones legacy

**Regla:** Si existe una API de iOS 26 que mejore la integración con el sistema, USARLA en lugar de soluciones manuales.

## SwiftData (fuente de verdad)
El ModelContainer se configura via `SwiftDataConfiguration` con estas entidades:
Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment, ScheduledPayment, InboxDraft, MerchantMemory, NotificationItem

## Divisas (Single Source of Truth)
**Archivo:** `Yala/Utils/CurrencyUtils.swift` → enum `CurrencyCode`

Para agregar una nueva divisa (ej: ARS - Peso Argentino), solo edita el enum `CurrencyCode`:

```swift
enum CurrencyCode: String, CaseIterable {
    case ars = "ARS"  // 1. Añadir case

    var flag: String {
        case .ars: return "🇦🇷"  // 2. Añadir bandera
    }

    var symbol: String {
        case .ars: return "$"  // 3. Añadir símbolo
    }

    var localizedName: String {
        case .ars: return L10n.Currency.ars  // 4. Usar key de localización
    }

    var aliases: [String] {
        case .ars: return ["ARS", "PESO ARGENTINO", "AR$"]  // 5. Aliases para normalización
    }

    var fallbackRateToUSD: Double {
        case .ars: return 875.0  // 6. Tasa fallback (solo cuando no hay API)
    }

    var regionCodes: [String] {
        case .ars: return ["AR"]  // 7. Códigos ISO de región
    }
}
```

**Luego añadir la key de localización** en `Localizable.strings`:
```
"currency.ars" = "Peso argentino";
```

**Todo lo demás es automático:**
- `ExchangeRateService.supportedSymbols` → deriva de `CurrencyCode.allRawValues`
- `CurrencyConverter.fallbackRates` → deriva de `CurrencyCode.fallbackRates`
- `normalizeCurrencyCode()` → usa `CurrencyCode.aliases`
- `detectCurrencyFromRegion()` → usa `CurrencyCode.regionCodes`
- `currencyInfo()` → usa propiedades del enum

## Flujo de trabajo optimizado
**Referencia completa:** `.planning/WORKFLOW.md`

### Flujo estándar
```
/next → [Shift+Tab] → /review-plan → /plan-ready → /session-start
     → Implementar → /verify-ios → /test-smart → /commit-one
     → /pre-deploy-check → /session-end → /compact → /clear
```

### Comandos clave por fase
| Fase | Comandos |
|------|----------|
| Orientación | `/next` |
| Planificación | `Shift+Tab` (Plan Mode), `/review-plan`, `/plan-ready` |
| Análisis | `/analyze-impact`, `/parallel-search` |
| Verificación | `/verify-ios`, `/test-smart`, `/pre-deploy-check` |
| Commits | `/commit-one` |
| Contexto | `/context-snapshot`, `/compact`, `/clear` |
| Captura | `/idea` |

**Regla QA-SCENARIOS:** Cada funcionalidad nueva DEBE tener sus escenarios de prueba documentados en `.planning/QA-SCENARIOS.md` ANTES del commit.

## Estrategia de Testing
Usar el comando apropiado según el tipo de cambio:

| Tipo de cambio | Comando | Cuándo |
|----------------|---------|--------|
| Cambio puntual en modelo/servicio | `/test-smart` | Detecta y corre solo tests relevantes |
| Cambio en UI (Views) | No hay tests UI | Solo /verify-ios |
| Trabajo completo antes de commit | `/test-ios` | Corre todos los tests |
| Después de merge o refactor grande | `/test-ios` + `/uitest-ios` | Validación completa |

**Tests disponibles:**
- `FilterServiceTests` - Lógica de filtrado
- `CalculatorTests` - Cálculos financieros
- `TagTests` - Operaciones con tags
- `TrendProcessingTests` - Procesamiento de tendencias
- `TrendGroupingTests` - Agrupación de tendencias
- `NewTransactionViewModelTests` - ViewModel de transacciones (35 tests)
- `BudgetsViewModelTests` - ViewModel de presupuestos (11 tests)
- `InboxViewModelTests` - ViewModel de bandeja de entrada (10 tests)

## Reglas de cambio
- Evitar refactors grandes si no son necesarios para el feature actual
- No introducir dependencias nuevas sin justificación
- Mantener separación clara entre UI, lógica y capa SwiftData

## Reglas de Corrección de Errores

**CRÍTICO: Búsqueda exhaustiva de patrones**
- Cuando corrijas un error, SIEMPRE busca TODAS las instancias del mismo patrón en el archivo/proyecto
- Usar `grep` o búsqueda sistemática ANTES de declarar el fix completo
- NO confiar ciegamente en "BUILD SUCCEEDED" - verificar que todos los casos fueron corregidos
- Ejemplo: Si corriges `#Predicate { $0.name == definition.prop }`, buscar TODOS los `#Predicate` similares

**Desconfianza sana del build cache:**
- El build de CLI puede usar cache mientras Xcode recompila desde cero
- Si el usuario reporta errores después de "BUILD SUCCEEDED", el problema es real
- Limpiar build si hay discrepancia: `xcodebuild clean`

## Patrones de Código Obligatorios

### Manejo de Errores (NUNCA silenciar errores)
```swift
// ❌ MAL - Error silenciado, pérdida de datos sin diagnóstico
try? context.save()
guard let items = try? context.fetch(descriptor) else { return }

// ✅ BIEN - Error visible y diagnosticable
do {
    try context.save()
} catch {
    print("ServiceName: Error saving: \(error)")
}

let items: [Model]
do {
    items = try context.fetch(descriptor)
} catch {
    print("ServiceName: Error fetching: \(error)")
    return
}
```

### Force Unwraps (NUNCA usar `!` sin validación previa)
```swift
// ❌ MAL - Crash en producción
let firstChar = text.first!
let index = array.lastIndex(of: item)!

// ✅ BIEN - Manejo seguro
guard let firstChar = text.first else { return }
guard let index = array.lastIndex(of: item) else { return }
```

### Seguridad de API Keys
- NUNCA hardcodear API keys en código fuente
- SIEMPRE usar `Secrets.xcconfig` (ignorado por git)
- SIEMPRE leer keys desde `Info.plist` via `Bundle.main.object(forInfoDictionaryKey:)`
- SIEMPRE validar que la key existe antes de usarla
- Si falta key, lanzar error descriptivo (no fallback silencioso)

### Logs en Producción
```swift
// ❌ MAL - Log siempre visible
print("User data: \(sensitiveData)")

// ✅ BIEN - Solo en debug
#if DEBUG
print("Debug info: \(nonSensitiveData)")
#endif
```

### SwiftData Relaciones
- SIEMPRE definir `@Relationship(inverse:)` en relaciones bidireccionales
- Verificar cascadas de eliminación (`deleteRule`)
- Usar `@MainActor` en servicios que manipulan `ModelContext`

### ViewModel Pattern (para eliminar @Query de vistas)
Patrón estándar para migrar vistas de `@Query` a ViewModel con carga manual de datos:

**Estructura base del ViewModel:**
```swift
@MainActor
@Observable
final class MiViewModel {
    private var modelContext: ModelContext?
    private(set) var items: [MiModelo] = []

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    func loadData() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<MiModelo>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            items = try context.fetch(descriptor)
        } catch {
            print("MiViewModel: Error loading: \(error)")
        }
    }
}
```

**Uso en la Vista:**
```swift
struct MiView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MiViewModel()

    var body: some View {
        List(viewModel.items) { item in ... }
            .onAppear { viewModel.setContext(modelContext) }
    }
}
```

**Refresh después de sheets:**
```swift
.sheet(item: $itemToEdit) { item in
    EditItemSheet(item: item)
}
.onDismiss {
    viewModel.loadData()  // Recargar datos al cerrar sheet
}
```

**Dos estrategias según complejidad:**
1. **ViewModel propio**: Para vistas complejas con múltiples @Query o lógica de negocio
2. **Parámetros del padre**: Para vistas hijas simples que reciben datos ya cargados
```swift
// Vista hija recibe datos como parámetros let (no @Query)
struct ChildView: View {
    let items: [MiModelo]  // Datos pasados por el padre
    let categories: [Category]
}
```

**Compatibilidad API con computed properties:**
```swift
// Mantener la misma API interna mientras se migra
private var items: [MiModelo] { viewModel.items }
```

## Control de Ejecución de Comandos

**Patrón fundamental después de implementar código:**
1. Mostrar resumen de cambios realizados
2. Sugerir el siguiente paso (típicamente /verify-ios)
3. DETENERSE y esperar instrucción del usuario
4. NO ejecutar verificaciones o commits automáticamente

**Optimización de comandos Git:**
- Ejecutar cada comando git de lectura (status, diff, log) UNA SOLA VEZ
- Guardar el output en variable
- Reutilizar ese output para todo el análisis posterior
- NUNCA ejecutar el mismo comando git múltiples veces
- NUNCA ejecutar comandos git en paralelo
- SIEMPRE ejecutar comandos git de forma secuencial

**Prevención de corrupción de git index:**
- Un solo comando git a la vez
- Esperar que termine completamente antes del siguiente
- No crear shells en background para operaciones git
- No matar shells que están ejecutando comandos git

## Design System (OBLIGATORIO para cambios UI)
**Antes de modificar cualquier vista, LEER:** `.planning/UI-PATTERNS.md`

Reglas críticas:
- SIEMPRE usar tokens de `DS.Spacing`, `DS.Radius`, `DS.Typography` - NUNCA valores hardcodeados
- SIEMPRE hacer filas completas clicables con `Button` + `contentShape(Rectangle())`
- SIEMPRE usar colores semánticos (`Color.yalaCard`, `Color.electricIndigo`, etc.)
- SIEMPRE usar componentes estándar: `YalaPrimaryButton`, `YalaEmptyState`, `YalaSectionHeader`, etc.

**Mantenimiento de UI-PATTERNS.md:**
- Cuando el usuario mencione una regla o patrón UI importante, PROPONER agregarlo a UI-PATTERNS.md
- Preguntar: "¿Quieres que agregue esta regla a UI-PATTERNS.md para que siempre se respete?"
- Si el usuario confirma, actualizar el archivo en la sección correspondiente

## Brand Voice (OBLIGATORIO para textos)
**Antes de escribir cualquier texto visible al usuario, LEER:** `.planning/BRAND-VOICE.md`

Reglas críticas:
- SIEMPRE usar tono cercano y conversacional ("tú"), como un amigo experto
- SIEMPRE usar español neutro (evitar regionalismos muy locales)
- NUNCA usar tono negativo o regañar - proponer soluciones y celebrar logros
- SIEMPRE preferir términos simples: "gasto" no "transacción", "dinero" no "plata"
- Emojis moderados (1-2 máx) solo cuando aporten significado positivo

**Mantenimiento de BRAND-VOICE.md:**
- Cuando el usuario defina nuevo copy o ajuste el tono, PROPONER actualizarlo
- Mantener el glosario de términos sincronizado con la UI

## System Files Structure
- CLAUDE.md: Operational memory (current context)
- .planning/PROJECT.md: Product definition and constraints
- .planning/ROADMAP.md: Phased delivery plan
- .planning/STATE.md: Living memory of progress and decisions
- .planning/DECISIONS.md: Architectural decisions record
- .planning/UI-PATTERNS.md: Design system rules and UI patterns (OBLIGATORIO para UI)
- .planning/BRAND-VOICE.md: Tono, estilo y mensajes de marca (OBLIGATORIO para textos)
- .planning/MARKETING.md: Estrategia de marketing y posicionamiento
- .claude/commands/: Automation macros
- .claude/sessions/: Session logs (git-ignored)
