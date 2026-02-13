# Plan: Sistema de Temas Independientes

## Contexto

El sistema actual de colores se basa en `UIColor { traitCollection in }` que solo distingue `.light` y `.dark`. El tema "Negro" es un hack: usa `.preferredColorScheme(.dark)` + lee `UserDefaults` dentro del closure de UIColor para diferenciar dark de negro. Esto:

1. **No escala** — para nuevos temas (rosa, cyan) habría un switch gigante dentro de cada UIColor
2. **No es reactivo** — UIKit solo re-evalúa cuando cambia `traitCollection`, no cuando cambia UserDefaults
3. **Requiere `.id(userThemeRaw)`** — destruye y recrea toda la jerarquía de vistas (se ve como reinicio de app)
4. **Lee UserDefaults en hot path** — 469 usos de colores semánticos = lecturas constantes

## Objetivo

Crear un sistema de temas verdaderamente independientes donde cada tema define su paleta completa. Preparado para temas PRO futuros (rosa, cyan, etc.) sin cambios arquitecturales.

## Investigación Realizada

### Estado Actual del Sistema de Colores

**Colores semánticos adaptativos (UIHelpers.swift):**
| Color | Light | Dark | Negro (hack) |
|-------|-------|------|---------------|
| `yalaBackground` | Off-white #FAFBFF | Deep Slate #0F172A | Pure Black #000000 |
| `yalaCard` | White | Slate #1C2847 | Dark Gray #1C1C1E |
| `yalaPrimaryText` | Color.primary | Color.primary | Color.primary |
| `yalaSecondaryText` | Color.secondary | Color.secondary | Color.secondary |
| `tagChipColor` | Dark Teal #0891B2 | Neon Cyan #00F3FF | Neon Cyan #00F3FF |
| `transferColor` | UIColor.label | Slate Gray #64748B | Slate Gray #64748B |
| `toolbarIconColor` | electricIndigo | electricIndigo | electricIndigo |

**Colores de marca (estáticos, no cambian por tema):**
- `electricIndigo` (#6366F1) — brand primary
- `hotPink` (#FF0080) — expense, urgency
- `neonCyan` (#00F3FF) — digital money
- `deepSlate` (#0F172A) — dark mode bg
- `priorityNature` (#00C2CB) — teal, income
- `essentialNature` (#F59E0B) — amber
- `optionalNature` (#FB7185) — rose

**PanelBackgroundView:**
```swift
if colorScheme == .dark {
    Color.yalaBackground  // solid
} else {
    LinearGradient(financeBackgroundTop → financeBackgroundBottom)  // gradient
}
```

**Magnitud del cambio:**
- 469 usos de colores semánticos
- 63+ archivos referencian PanelBackgroundView o yalaBackground/yalaCard
- 7 archivos leen `userTheme`/`userThemeRaw`

### Arquitectura Elegida: ShapeStyle + Environment

Basado en investigación de patrones SwiftUI 2025-2026:

**Pattern: Custom ShapeStyle con `resolve(in:)`**

```swift
struct ThemeColor: ShapeStyle {
    let keyPath: KeyPath<YalaTheme, Color>
    func resolve(in env: EnvironmentValues) -> some ShapeStyle {
        env.yalaTheme[keyPath: keyPath]
    }
}

// Uso en vistas — NO necesita @Environment:
Text("Hola").foregroundStyle(.thBackground)  // se resuelve del environment
```

**Ventajas:**
- Las vistas NO necesitan declarar `@Environment(\.yalaTheme)` para colores comunes
- ShapeStyle se resuelve lazily en render time
- Cuando el tema cambia, SwiftUI re-evalúa solo las vistas que usan colores temáticos
- NO destruye la jerarquía de vistas (sin `.id()`)
- Sintaxis casi idéntica a la actual: `.foregroundStyle(.thBackground)` vs `Color.yalaBackground`

**Limitación:** Solo funciona con APIs de ShapeStyle (foregroundStyle, background, fill, stroke). Para raw `Color` (UIKit bridges, cálculos), se necesita `@Environment(\.yalaTheme)`.

## Diseño del Sistema

### 1. YalaTheme (struct con paleta completa)

```swift
struct YalaTheme: Equatable, Sendable {
    let id: String
    let displayName: String
    let baseColorScheme: ColorScheme  // Controla teclado, status bar, alerts del sistema
    let isProOnly: Bool

    // -- Fondos --
    let background: Color          // Fondo principal de la app
    let backgroundGradientTop: Color?   // Para temas con gradiente (nil = solid)
    let backgroundGradientBottom: Color?
    let card: Color                // Fondo de cards/modales
    let cardBorder: Color          // Borde sutil de cards

    // -- Texto --
    let primaryText: Color
    let secondaryText: Color

    // -- Acento y marca --
    let accent: Color              // Brand primary (botones, highlights)
    let accentSecondary: Color     // Brand secondary
    let income: Color              // Color de ingresos en gráficas
    let expense: Color             // Color de gastos en gráficas

    // -- Componentes --
    let tagChip: Color             // Color de chips de tags
    let transfer: Color            // Indicador de transferencias
    let toolbarIcon: Color         // Iconos de toolbar
    let destructive: Color         // Acciones destructivas

    // -- Indicadores financieros --
    let priorityNature: Color      // Gastos prioritarios
    let essentialNature: Color     // Gastos esenciales
    let optionalNature: Color      // Gastos opcionales
}
```

### 2. Temas Predefinidos

```swift
extension YalaTheme {
    /// Tema claro — el diseño actual "Yala blue"
    static let light = YalaTheme(
        id: "light",
        displayName: L10n.Settings.light,
        baseColorScheme: .light,
        isProOnly: false,
        background: Color(red: 0.98, green: 0.98, blue: 0.99),
        backgroundGradientTop: Color(hex: "FCFCFF"),
        backgroundGradientBottom: Color.electricIndigo.opacity(0.1),
        card: .white,
        cardBorder: Color.primary.opacity(0.05),
        primaryText: Color(.label),
        secondaryText: Color(.secondaryLabel),
        accent: .electricIndigo,
        accentSecondary: .hotPink,
        income: .priorityNature,
        expense: .hotPink,
        tagChip: Color(hex: "0891B2"),
        transfer: Color(.label),
        toolbarIcon: .electricIndigo,
        destructive: .red,
        priorityNature: Color(hex: "00C2CB"),
        essentialNature: Color(hex: "F59E0B"),
        optionalNature: Color(hex: "FB7185")
    )

    /// Tema oscuro — deepSlate con tinte azulado (el actual)
    static let dark = YalaTheme(
        id: "dark",
        displayName: L10n.Settings.dark,
        baseColorScheme: .dark,
        isProOnly: false,
        background: .deepSlate,
        backgroundGradientTop: nil,
        backgroundGradientBottom: nil,
        card: Color(red: 0.11, green: 0.16, blue: 0.28),
        cardBorder: Color.white.opacity(0.05),
        primaryText: .white,
        secondaryText: Color(.secondaryLabel),
        accent: .electricIndigo,
        accentSecondary: .hotPink,
        income: .priorityNature,
        expense: .hotPink,
        tagChip: .neonCyan,
        transfer: Color(hex: "64748B"),
        toolbarIcon: .electricIndigo,
        destructive: .red,
        priorityNature: Color(hex: "00C2CB"),
        essentialNature: Color(hex: "F59E0B"),
        optionalNature: Color(hex: "FB7185")
    )

    /// Tema negro OLED — pure black (PRO)
    static let black = YalaTheme(
        id: "black",
        displayName: L10n.Settings.negro,
        baseColorScheme: .dark,
        isProOnly: true,
        background: .black,
        backgroundGradientTop: nil,
        backgroundGradientBottom: nil,
        card: Color(UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)),
        cardBorder: Color.white.opacity(0.08),
        primaryText: .white,
        secondaryText: Color(.secondaryLabel),
        accent: .electricIndigo,
        accentSecondary: .hotPink,
        income: .priorityNature,
        expense: .hotPink,
        tagChip: .neonCyan,
        transfer: Color(hex: "64748B"),
        toolbarIcon: .electricIndigo,
        destructive: .red,
        priorityNature: Color(hex: "00C2CB"),
        essentialNature: Color(hex: "F59E0B"),
        optionalNature: Color(hex: "FB7185")
    )

    // Futuros temas PRO:
    // static let pink = YalaTheme(...)
    // static let cyan = YalaTheme(...)
}
```

### 3. ThemeManager (@Observable)

```swift
@Observable @MainActor
final class ThemeManager {
    /// Elección del usuario (persistida en AppStorage desde la vista)
    var userChoice: AppTheme = .system

    /// ColorScheme del sistema (actualizado desde Environment)
    var systemColorScheme: ColorScheme = .light

    /// Tema resuelto final
    var resolved: YalaTheme {
        switch userChoice {
        case .system:
            return systemColorScheme == .dark ? .dark : .light
        case .light:  return .light
        case .dark:   return .dark
        case .negro:  return .black
        // Futuros:
        // case .rosa:   return .pink
        // case .cyan:   return .cyan
        }
    }
}
```

### 4. Environment Integration

```swift
// EnvironmentKey
extension EnvironmentValues {
    @Entry var yalaTheme: YalaTheme = .light
}

// Inyección en YalaApp.swift
ContentView()
    .environment(\.yalaTheme, themeManager.resolved)
    .preferredColorScheme(themeManager.resolved.baseColorScheme)
    // SIN .id(userThemeRaw) — ya no es necesario
```

### 5. ThemeColor ShapeStyle (API principal)

```swift
struct ThemeColor: ShapeStyle {
    private let keyPath: KeyPath<YalaTheme, Color>

    init(_ keyPath: KeyPath<YalaTheme, Color>) {
        self.keyPath = keyPath
    }

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.yalaTheme[keyPath: keyPath]
    }
}

// Extensiones para uso directo
extension ShapeStyle where Self == ThemeColor {
    static var thBackground: ThemeColor { .init(\.background) }
    static var thCard: ThemeColor { .init(\.card) }
    static var thCardBorder: ThemeColor { .init(\.cardBorder) }
    static var thPrimaryText: ThemeColor { .init(\.primaryText) }
    static var thSecondaryText: ThemeColor { .init(\.secondaryText) }
    static var thAccent: ThemeColor { .init(\.accent) }
    static var thAccentSecondary: ThemeColor { .init(\.accentSecondary) }
    static var thIncome: ThemeColor { .init(\.income) }
    static var thExpense: ThemeColor { .init(\.expense) }
    static var thTagChip: ThemeColor { .init(\.tagChip) }
    static var thTransfer: ThemeColor { .init(\.transfer) }
    static var thToolbarIcon: ThemeColor { .init(\.toolbarIcon) }
    static var thDestructive: ThemeColor { .init(\.destructive) }
    static var thPriorityNature: ThemeColor { .init(\.priorityNature) }
    static var thEssentialNature: ThemeColor { .init(\.essentialNature) }
    static var thOptionalNature: ThemeColor { .init(\.optionalNature) }
}
```

### 6. PanelBackgroundView Simplificado

```swift
struct PanelBackgroundView: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Group {
            if let top = theme.backgroundGradientTop,
               let bottom = theme.backgroundGradientBottom {
                LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            } else {
                // Usa ThemeColor para que se resuelva del environment
                Rectangle().fill(.thBackground)
            }
        }
        .ignoresSafeArea()
    }
}
```

### 7. ThemeSettingsView (Rediseño)

Vista simplificada que muestra todos los temas como opciones:

```
┌─────────────────────────────────┐
│  🎨 Apariencia                  │
│                                 │
│  Elige cómo se ve Yala          │
│                                 │
│  ┌─────────────────────────────┐│
│  │ ○ Automático                ││
│  │   Sigue el modo de tu iPhone││
│  │─────────────────────────────││
│  │ ● Claro                     ││
│  │─────────────────────────────││
│  │ ○ Oscuro                    ││
│  │─────────────────────────────││
│  │ ○ Negro          PRO 🔒    ││
│  │─────────────────────────────││
│  │ ○ Rosa (próx.)   PRO 🔒    ││
│  │─────────────────────────────││
│  │ ○ Cyan (próx.)   PRO 🔒    ││
│  └─────────────────────────────┘│
└─────────────────────────────────┘
```

Los temas "próximamente" se muestran dimeados con badge "Próximamente" como marketing.

## Plan de Implementación (Incrementos)

### Pre-requisito: Verificar que la app compila antes de empezar

### INC-1: Infraestructura del tema (3 archivos nuevos + 1 edit)

**Crear:** `Yala/App/Theme/YalaTheme.swift`
- Struct `YalaTheme` con todas las propiedades de paleta
- Temas predefinidos: `.light`, `.dark`, `.black`
- `EnvironmentValues` extension con `@Entry var yalaTheme`

**Crear:** `Yala/App/Theme/ThemeColor.swift`
- Struct `ThemeColor: ShapeStyle` con `resolve(in:)`
- Todas las extensiones estáticas (`.thBackground`, `.thCard`, etc.)

**Crear:** `Yala/App/Theme/ThemeManager.swift`
- Clase `@Observable ThemeManager` con `userChoice`, `systemColorScheme`, `resolved`

**Editar:** `Yala/App/Views/Shared/UIHelpers.swift`
- Actualizar `AppTheme` enum: añadir referencia a `YalaTheme` en cada case
- Mantener los colores legacy temporalmente (se eliminan en INC-4)

**Verificar:** Build succeeds, tests pasan

### INC-2: Integración en YalaApp (2 archivos)

**Editar:** `Yala/App/YalaApp.swift`
- Añadir `ThemeManager` como property
- Inyectar `.environment(\.yalaTheme, themeManager.resolved)`
- Inyectar `.environment(themeManager)` para ThemeSettingsView
- Reemplazar `.preferredColorScheme(AppTheme(rawValue:)?.colorScheme)` con `.preferredColorScheme(themeManager.resolved.baseColorScheme)`
- **ELIMINAR `.id(userThemeRaw)`** — ya no es necesario
- Añadir `.onChange(of: colorScheme)` para actualizar `themeManager.systemColorScheme`

**Editar:** `Yala/App/AppBootstrapper.swift` (si aplica)
- Inicializar ThemeManager y exponerlo

**Verificar:** Build succeeds, cambiar tema no reinicia la app

### INC-3: Migrar PanelBackgroundView y componentes compartidos (5-8 archivos)

**Editar:** `Yala/App/Views/Shared/PanelBackgroundView.swift`
- Usar `@Environment(\.yalaTheme)` para decidir gradiente vs sólido
- Eliminar dependencia de `colorScheme`

**Editar:** Componentes compartidos que usan colores semánticos:
- `SectionBox.swift` — `Color.yalaCard` → `.thCard`
- `YalaPrimaryButton.swift` — colores de acento
- `YalaEmptyState.swift` — colores de texto
- `YalaToolbarButton.swift` — `toolbarIconColor`
- Otros componentes en `Views/Shared/`

**Verificar:** Build succeeds, vistas compartidas usan colores del tema

### INC-4: Migrar vistas principales — Panel (8-10 archivos)

Migrar todas las vistas de `Views/Panel/`:
- `PanelView.swift`
- `AccountCardView.swift`
- Widgets del panel (CashFlow, TopCategories, etc.)
- Cualquier vista que use `Color.yalaBackground`, `Color.yalaCard`, `Color.yalaPrimaryText`, `Color.yalaSecondaryText`

**Patrón de migración:**
```swift
// ANTES:
.foregroundStyle(Color.yalaPrimaryText)
.background(Color.yalaCard)

// DESPUÉS (ShapeStyle — no necesita @Environment):
.foregroundStyle(.thPrimaryText)
.background(.thCard)

// DESPUÉS (raw Color — solo si necesario):
@Environment(\.yalaTheme) private var theme
Color(theme.background)  // Para UIKit bridges
```

### INC-5: Migrar vistas — Statistics (8-10 archivos)

- `TrendsTabView.swift`
- `CategoriesTabView.swift`
- `RecordsTabView.swift`
- `DetailContainerView.swift`
- `RecordRowView.swift`
- Charts y gráficas

### INC-6: Migrar vistas — Settings y Profile (10-12 archivos)

- `ThemeSettingsView.swift` — **REDISEÑO completo** usando ThemeManager
- `PersonalizationSettingsView.swift`
- `ProfileView.swift`
- Todas las vistas de Settings
- `SubscriptionView.swift`

### INC-7: Migrar vistas — Transacciones e Inbox (8-10 archivos)

- `NewTransactionView.swift`
- `InboxView.swift`
- `VoiceRecordingView.swift`
- `ImageSelectionView.swift`
- Sheets de edición

### INC-8: Migrar vistas — Planning y restantes (5-8 archivos)

- `PlanningView.swift`
- Sheets, modales, y vistas restantes
- `ContentView.swift`

### INC-9: Limpieza (2-3 archivos)

**Editar:** `UIHelpers.swift`
- ELIMINAR los colores semánticos legacy (`yalaBackground`, `yalaCard`, `yalaPrimaryText`, etc.)
- ELIMINAR `negroBackground`, `negroCard`
- ELIMINAR la lógica de UserDefaults dentro de UIColor closures
- Mantener solo colores de marca estáticos (`electricIndigo`, `hotPink`, etc.)

**Editar:** `DesignTokens.swift`
- Mover `DS.Colors` a usar ThemeColor si aplica

**Verificar:** Build succeeds, grep confirma 0 usos de colores legacy

### INC-10: Localizaciones y QA

**Editar:** 6 archivos `Localizable.strings`
- Añadir keys para nuevos temas si se agregan (rosa, cyan, etc.)

**Editar:** `QA-SCENARIOS.md`
- Añadir sección de temas con escenarios:
  - Cambiar entre todos los temas sin reinicio
  - Tema "Automático" sigue light/dark del sistema
  - Temas PRO muestran paywall si no es PRO
  - Colores correctos en cada tema (background, cards, texto)
  - Widgets no se afectan por cambio de tema
  - Sheets/modales mantienen tema correcto
  - Persistencia del tema entre sesiones

## Consideraciones Importantes

### Widgets iOS (NO se migran)
Los widgets tienen su propio sistema de colores (`WidgetColors.swift`) y no pueden acceder al Environment de la app. Mantienen sus temas independientes (Yala/iOS). **No se tocan.**

### Colores de marca (NO cambian por tema)
`electricIndigo`, `hotPink`, `neonCyan` etc. son identidad de marca y NO cambian por tema. Se mantienen como `static let` en UIHelpers. Solo los **semánticos** (background, card, text, etc.) vienen del tema.

### Transición suave
Durante la migración (INC-3 a INC-8), ambos sistemas coexisten. Los colores legacy (`Color.yalaBackground`) siguen funcionando. Solo se eliminan en INC-9 cuando todas las vistas estén migradas.

### Performance
- `ShapeStyle.resolve(in:)` se evalúa solo cuando SwiftUI renderiza la vista
- No hay lecturas de UserDefaults en hot path
- `@Observable` solo invalida vistas que leen propiedades que cambiaron
- Sin `.id()` = sin destrucción de jerarquía = sin pérdida de state

### Temas futuros (Rosa, Cyan, etc.)
Para añadir un tema nuevo:
1. Definir `static let pink = YalaTheme(...)` con paleta completa
2. Añadir `case rosa` a `AppTheme` enum
3. Añadir case al switch en `ThemeManager.resolved`
4. Añadir key de localización
5. **Cero cambios en vistas** — los ShapeStyles se resuelven automáticamente

### Migración path por vista
Para cada archivo, el cambio es mecánico:
```
Color.yalaBackground    → .thBackground (ShapeStyle)
Color.yalaCard          → .thCard
Color.yalaPrimaryText   → .thPrimaryText
Color.yalaSecondaryText → .thSecondaryText
Color.brandPrimary      → .thAccent (o mantener brandPrimary si es estático)
Color.tagChipColor      → .thTagChip
Color.transferColor     → .thTransfer
Color.toolbarIconColor  → .thToolbarIcon
```

## Estimación

| Incremento | Archivos | Complejidad |
|------------|----------|-------------|
| INC-1: Infraestructura | 3 nuevos + 1 edit | Media |
| INC-2: YalaApp | 2 | Baja |
| INC-3: Shared components | 5-8 | Baja |
| INC-4: Panel | 8-10 | Media (mecánico) |
| INC-5: Statistics | 8-10 | Media (mecánico) |
| INC-6: Settings/Profile | 10-12 | Media (+ rediseño ThemeSettingsView) |
| INC-7: Transactions/Inbox | 8-10 | Baja (mecánico) |
| INC-8: Planning/restantes | 5-8 | Baja (mecánico) |
| INC-9: Limpieza | 2-3 | Baja |
| INC-10: L10n + QA | 7-8 | Baja |
| **Total** | **~60-70 archivos** | **1 sesión larga o 2-3 sesiones** |

## Referencias

- [ShapeStyle.resolve(in:) para theming](https://alexanderweiss.dev/blog/2024-12-27-the-power-of-shapestyle-for-colour-theming-in-swiftui)
- [Custom Environment Colors](https://freiwald.dev/posts/custom-environment-colors/)
- [Effortless SwiftUI Theming](https://alexanderweiss.dev/blog/2025-01-19-effortless-swiftui-theming)
- [@Entry macro for EnvironmentValues](https://nilcoalescing.com/blog/ReadingAndSettingColorSchemeInSwiftUI/)
