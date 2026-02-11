# UI Patterns & Design System Rules

**LECTURA OBLIGATORIA antes de modificar cualquier vista.**

Este documento define los patrones UI que DEBEN respetarse en toda la app para mantener consistencia.

---

## iOS 26 Liquid Glass (PRIORIDAD MÁXIMA)

**SIEMPRE preferir APIs nativas de iOS 26 para mantener la app moderna y actualizada.**

Yala es una app iOS 26+. Esto significa que DEBEMOS usar las APIs más recientes del sistema en lugar de soluciones manuales o legacy.

### APIs Obligatorias

| Patrón Legacy | API iOS 26 | Cuándo Usar |
|---------------|------------|-------------|
| `Rectangle` divider en toolbar | `ToolbarSpacer(.fixed, placement:)` | Separar grupos de botones en toolbar |
| `Spacer()` en toolbar | `ToolbarSpacer(.flexible)` | Espacio flexible entre items |
| `.background(Color.gray.opacity(0.2))` | `.glassEffect(.regular)` | Chips, barras flotantes, elementos translúcidos |
| Custom blur effects | `.glassEffect()` variants | Cualquier efecto de profundidad |

### Ejemplo: Toolbar con Separación (Grupos Glass Separados)

```swift
// ✅ iOS 26: Grupos glass separados (cada ToolbarItem en su propia píldora)
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        HStack(spacing: DS.Spacing.md) {
            Button { } label: { Image(systemName: "checkmark.circle.fill") }
            Button { } label: { Image(systemName: "line.3.horizontal.decrease.circle.fill") }
        }
    }

    // ⚠️ CRÍTICO: ToolbarSpacer REQUIERE placement para crear grupos glass separados
    ToolbarSpacer(.fixed, placement: .topBarTrailing)

    ToolbarItem(placement: .topBarTrailing) {
        ProfileToolbarButton { }
    }
}

// ❌ MAL: ToolbarSpacer sin placement (NO crea separación visual)
ToolbarSpacer(.fixed)  // Los botones quedan en la misma píldora glass

// ❌ Legacy: Divider manual (NO usar)
HStack {
    actionButtons
    Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1, height: 20)
    ProfileToolbarButton { }
}
```

### ToolbarSpacer - Referencia Rápida

| Uso | Sintaxis |
|-----|----------|
| Separar en grupos glass | `ToolbarSpacer(.fixed, placement: .topBarTrailing)` |
| Espacio flexible | `ToolbarSpacer(.flexible, placement: .topBarTrailing)` |
| Item sin fondo glass | `.sharedBackgroundVisibility(.hidden)` en el ToolbarItem |

**Documentación:** Ver `.planning/TOOLBAR-INVESTIGATION.md` para investigación completa.

### Filosofía
> Si existe una API de iOS 26 que resuelve un problema de UI, **USARLA** en lugar de implementar soluciones manuales. Esto garantiza que la app se vea nativa, moderna, y se beneficie automáticamente de mejoras futuras del sistema.

---

## Reglas de Oro (NUNCA violar)

### 1. Áreas de Toque
- **Filas completas son clicables** - Usar `Button` con `.buttonStyle(.plain)` y `contentShape(Rectangle())`
- **Mínimo 44×44pt** para cualquier elemento interactivo (accesibilidad)
- **Chevrons** solo indican navegación, no son el área de toque

```swift
// ✅ CORRECTO: Fila completa clicable
Button(action: { ... }) {
    HStack { /* contenido */ }
}
.buttonStyle(.plain)
.contentShape(Rectangle())

// ❌ INCORRECTO: Solo texto clicable
HStack {
    Text("Label").onTapGesture { ... }
    Spacer()
}
```

### 2. Nunca Usar Valores Mágicos
- **SIEMPRE** usar tokens de `DS.Spacing`, `DS.Radius`, `DS.Typography`
- **NUNCA** escribir `.padding(16)` - usar `.padding(.horizontal, DS.Spacing.lg)`

### 3. Colores Semánticos
- **SIEMPRE** usar colores del sistema: `Color.yalaBackground`, `Color.yalaCard`, `Color.electricIndigo`
- **NUNCA** usar colores hardcodeados como `Color.blue` o `Color(hex: "...")`

---

## Design Tokens (DS)

### Spacing
| Token | Valor | Uso |
|-------|-------|-----|
| `xxs` | 2pt | Micro gaps |
| `xs` | 4pt | Gaps pequeños, padding de iconos |
| `sm` | 8pt | Spacing estándar pequeño |
| `md` | 12pt | Spacing medio |
| `lg` | 16pt | **Padding horizontal estándar** |
| `xl` | 20pt | Spacing extra |
| `xxl` | 24pt | **Entre secciones** |
| `xxxl` | 32pt | Divisores mayores |
| `xxxxl` | 48pt | Márgenes de página |
| `safeBottom` | 100pt | Bottom padding en ScrollView |

### Radius
| Token | Valor | Uso |
|-------|-------|-----|
| `xs` | 4pt | Pills pequeños |
| `sm` | 8pt | Botones, chips |
| `md` | 12pt | Inputs, contenedores |
| `card` | 14pt | **Filas de lista** |
| `lg` | 16pt | Sheets, modales |
| `xl` | 24pt | **Cards principales** |
| `full` | 9999pt | Cápsulas |

### Typography
| Token | Uso |
|-------|-----|
| `largeTitle` | Títulos de pantalla |
| `title` / `title2` | Encabezados de sección |
| `headline` | Headers de sección |
| `bodyBold` / `body` | Contenido principal |
| `label` / `labelSmall` / `labelTiny` | Etiquetas, badges |
| `subheadline` | Info secundaria |
| `caption` / `captionSmall` | Texto de soporte |
| `amountLarge` / `amount` / `amountSmall` | **Montos (fuente rounded)** |

---

## Colores

### Colores de Marca
- `Color.electricIndigo` - Acción principal, ingresos
- `Color.hotPink` - Gastos, alertas
- `Color.priorityNature` - Gastos prioritarios/esenciales (teal)

### Colores Semánticos
- `Color.yalaBackground` - Fondo de app
- `Color.yalaCard` - Fondo de tarjetas/modales
- `Color.yalaPrimaryText` - Texto principal
- `Color.yalaSecondaryText` - Texto secundario
- `DS.Colors.borderDark` - Bordes de cards (`.black.opacity(0.05)`)

### DS.Semantic — Colores de Estado
| Token | Color | Cuándo usar |
|-------|-------|-------------|
| `successBackground` | green 15% | Fondos de éxito, confirmaciones |
| `successForeground` | green | Iconos/texto de éxito |
| `warningBackground` | orange 15% | Fondos de alerta, pendientes |
| `warningForeground` | orange | Iconos/texto de alerta |
| `errorBackground` | red 15% | Fondos de error, rechazos |
| `errorBackgroundSubtle` | red 10% | Validación sutil (formularios) |
| `errorBorder` | red 20% | Bordes de campos con error |
| `errorForeground` | red | Iconos/texto de error |
| `infoBackground` | blue 10% | Banners informativos |
| `neutralBackground` | gray 10% | Chips no seleccionados, barras |
| `favoriteIcon` | yellow | Estrellas de favorito |
| `disabledForeground` | gray | Botones/textos deshabilitados |

**NO usar DS.Semantic cuando:**
- El color es decorativo (glow, sombra)
- Es `Color.secondary` (texto secundario del sistema)
- Es `Color(hex:)` dinámico (datos de categorías/tags)

### DS.Gradients — Gradientes de Marca
| Token | Colores | Cuándo usar |
|-------|---------|-------------|
| `proBadge` | [yellow, orange] | Badge Pro, YalaSpark |
| `subscription` | [orange, hotPink] | Pantalla de suscripción |
| `success` | [green, green 85%] | Animación de éxito |
| `warning` | [orange, red] | Downgrade, alertas graves |

### Regla de Montos
- **Ingresos**: `Color.electricIndigo`
- **Gastos**: `Color.hotPink`
- **Transferencias**: `Color.transferColor`

---

## Componentes Obligatorios

### Filas de Lista (RecordRowView pattern)
```swift
// Estructura obligatoria para filas de lista
Button(action: onTap) {
    HStack(spacing: DS.ListRow.spacing) {
        // Icono (40pt)
        // Contenido (Flexible)
        // Monto/Acción (Trailing)
    }
    .padding(.horizontal, DS.ListRow.paddingH)
    .padding(.vertical, DS.ListRow.paddingV)
}
.buttonStyle(.plain)
.contentShape(Rectangle())
.background(Color.yalaCard)
.cornerRadius(DS.Radius.card)
```

### Filas de Formulario (TransactionFormRow pattern)
```swift
// Estructura obligatoria para formularios
Button(action: onTap) {
    HStack(spacing: DS.FormRow.iconSpacing) {
        // Icono (28pt width)
        // Label
        Spacer()
        // Value
        // Chevron (si navega)
    }
    .padding(.horizontal, DS.FormRow.paddingH)
    .padding(.vertical, DS.FormRow.paddingV)
    .frame(minHeight: DS.FormRow.minHeight)
}
.buttonStyle(.plain)
.contentShape(Rectangle())
```

### Botones

| Tipo | Uso | Componente |
|------|-----|------------|
| Primario | Acción principal | `YalaPrimaryButton` |
| Secundario | Acciones alternativas | `YalaSecondaryButton` |
| Texto | Links, acciones terciarias | `YalaTextButton` |
| Toolbar | Navegación, cerrar | `YalaToolbarButton` |
| Guardar | Confirmación circular | `YalaSaveButton` |

### Empty States
- **SIEMPRE** usar `YalaEmptyState` para estados vacíos
- Incluir: icono (48pt), título, mensaje opcional, acción opcional
- Variantes predefinidas: `.noTransactions`, `.noResults`, `.noTags`, etc.

### Loading States
- `YalaLoadingOverlay` - Modal con overlay oscuro
- `YalaLoadingInline` - Indicador pequeño inline
- `YalaLoadingFullScreen` - Pantalla completa
- Skeletons para contenido: `WidgetSkeleton`, `LatestRecordsSkeleton`, etc.

### Badges
- `YalaBadge` - Badge genérico (filled/soft/outline)
- `YalaStatusBadge` - Estados (success/warning/error/info)
- `YalaTagBadge` - Tags de transacciones
- `YalaCountBadge` - Contadores

---

## Layouts

### Secciones
```swift
VStack(spacing: DS.Spacing.xxl) {
    // Sección 1
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        YalaSectionHeader(title: "Título")
        // Contenido
    }

    // Sección 2
    // ...
}
.padding(.horizontal, DS.Spacing.lg)
.padding(.bottom, DS.Spacing.safeBottom)
```

### Headers de Sección
- `YalaSectionHeader` - Header principal con acción opcional
- `YalaSectionHeaderCompact` - Subsección (uppercase, pequeño)

### Cards/Widgets
```swift
VStack {
    // Contenido
}
.padding(DS.Card.padding)
.background(Color.yalaCard)
.cornerRadius(DS.Radius.xl)
.overlay(
    RoundedRectangle(cornerRadius: DS.Radius.xl)
        .stroke(Color.primary.opacity(DS.Card.borderOpacity), lineWidth: 1)
)
```

---

## Estructura de Vistas Principales

### Título Nativo Animado (OBLIGATORIO)
Todas las vistas principales del TabView DEBEN usar el título nativo de iOS que se anima al toolbar al scrollear.

```swift
// ✅ CORRECTO: Título nativo con animación automática
NavigationStack {
    ZStack {
        PanelBackgroundView()

        // Contenido con ScrollView como elemento principal
        contentView
            .safeAreaInset(edge: .top) {
                // Solo chips de navegación aquí (si existen)
                navigationChipsBar
            }
    }
    .navigationTitle("Título")
    .navigationBarTitleDisplayMode(.large)
}

// ❌ INCORRECTO: Título manual que no se anima
NavigationStack {
    VStack {
        Text("Título").font(.largeTitle)  // NO hacer esto
        ScrollView { ... }
    }
}
```

### Reglas de Scroll
- **ScrollView debe ser el contenido principal** para que iOS detecte el scroll y anime el título
- **Solo chips de navegación** van en `safeAreaInset(edge: .top)` y flotan
- **Todo lo demás scrollea**: control bars, filtros, period selectors, headers de contenido
- **Empty states** dentro del ScrollView: usar padding en lugar de Spacers

```swift
// ✅ CORRECTO: Control bar scrollea con contenido
ScrollView {
    VStack(spacing: 0) {
        controlBar          // Scrollea
        periodSelector      // Scrollea
        filterChips         // Scrollea
        contentList         // Scrollea
    }
}

// ❌ INCORRECTO: Control bar fijo
contentList
    .safeAreaInset(edge: .top) {
        controlBar  // Se queda fijo - NO hacer esto
    }
```

---

## Chips de Navegación y Filtro

### Estilo Liquid Glass (OBLIGATORIO)
Todos los chips de navegación y filtro DEBEN usar el estilo liquid glass de iOS 26.

```swift
// ✅ CORRECTO: Chip con liquid glass
Button {
    selectedTab = tab
} label: {
    HStack(spacing: DS.Spacing.sm) {
        Image(systemName: tab.icon)
        Text(tab.displayName)
    }
    .padding(.horizontal, DS.Spacing.lg)
    .padding(.vertical, DS.Spacing.sm)
    .foregroundStyle(isSelected ? .white : .primary)
    .background(
        Capsule()
            .fill(isSelected ? Color.electricIndigo : Color.clear)
    )
    .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
}
.buttonStyle(.plain)

// ❌ INCORRECTO: Fondo sólido sin glass
HStack { ... }
    .background(Color.gray.opacity(0.2))  // NO hacer esto
```

### Reglas de Chips
- **Sin fondo general**: Los chips flotan sin rectángulo de fondo detrás
- **Glass effect en no seleccionados**: `.glassEffect(.regular.interactive(), in: .capsule)`
- **Clear glass en seleccionados**: `.glassEffect(.clear, ...)` para que el color sólido se vea
- **Period Selector**: Mismo estilo glass que los chips

### Chips de Filtro (FilterChipView)
- Siguen el mismo patrón visual
- Incluyen botón de clear (X)
- Muestran count cuando hay múltiples selecciones

---

## Gráficas (Charts)

### Hover/Tooltip Labels
Los tooltips de gráficas DEBEN usar posicionamiento dinámico para evitar que se corten en los bordes.

```swift
// ✅ CORRECTO: Posición dinámica basada en altura del punto
.annotation(
    position: tooltipShouldBeBelow(for: value) ? .bottom : .top,
    alignment: tooltipAlignment(for: date)
) {
    // Tooltip content
}
.offset(y: tooltipShouldBeBelow(for: value) ? -30 : -30)

// Función helper
private func tooltipShouldBeBelow(for value: Double) -> Bool {
    let range = yDomain.upperBound - yDomain.lowerBound
    guard range > 0 else { return false }
    let normalizedValue = (value - yDomain.lowerBound) / range
    return normalizedValue > 0.70  // 70% superior = tooltip abajo
}

// ❌ INCORRECTO: Posición fija que se corta
.annotation(position: .top, ...) {  // Se corta cuando punto está arriba
```

**Regla:** Si el punto está en el 70% superior del rango Y, el tooltip va debajo; si no, arriba.

**Aplica a:** TrendChartView, PeriodComparisonChartView, y cualquier chart con hover interactivo.

---

## Formularios con Campos de Texto

### Cierre de Teclado (OBLIGATORIO)
Todos los formularios con campos de texto DEBEN implementar cierre correcto del teclado.

**Requisitos:**
1. **Tap fuera del campo**: El teclado debe cerrarse al tocar cualquier área fuera del campo de texto
2. **Scroll**: El teclado debe cerrarse al scrollear
3. **Sheets/NavigationLinks**: El teclado debe cerrarse antes de abrir sheets o navegar

```swift
// ✅ CORRECTO: Implementación completa de cierre de teclado
struct MyFormView: View {
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, amount, note  // Todos los campos de texto
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                    .dismissKeyboardOnTap()  // 1. Tap fuera cierra teclado

                ScrollView {
                    // Contenido
                }
                .scrollDismissesKeyboard(.interactively)  // 2. Scroll cierra teclado
            }
            .sheet(isPresented: $showSheet) { ... }
            .onChange(of: showSheet) { _, isPresenting in
                if isPresenting { focusedField = nil }  // 3. Cierra antes de sheet
            }
        }
    }
}

// Para NavigationLinks, usar simultaneousGesture:
NavigationLink {
    DestinationView()
} label: {
    // ...
}
.buttonStyle(.plain)
.simultaneousGesture(TapGesture().onEnded { _ in focusedField = nil })
```

**Reglas clave:**
- **SIEMPRE usar `@FocusState`** con enum para múltiples campos
- **NUNCA usar solo `dismissKeyboard()`** en onChange - debe resetear el `@FocusState`
- **NavigationLinks** requieren `.simultaneousGesture` porque no tienen `isPresented` binding
- **Sheets** deben usar `.onChange(of: showSheet)` para limpiar focus state

### Auto-Focus en Formularios de Creación
Los formularios de **creación** (NO edición) DEBEN auto-posicionar el cursor en el primer campo al abrirse.

```swift
// ✅ CORRECTO: Auto-focus en primer campo (solo creación)
.onAppear {
    if !isEditing {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .name  // Primer campo
        }
    }
}

// ❌ INCORRECTO: Auto-focus en edición (el usuario quiere ver datos primero)
.onAppear {
    focusedField = .name  // NO hacer en edición
}
```

---

## Animaciones

| Tipo | Duración | Uso |
|------|----------|-----|
| `fast` | 0.15s | Taps, micro-interacciones |
| `normal` | 0.25s | Transiciones estándar |
| `slow` | 0.4s | Modales, énfasis |

```swift
.animation(.easeInOut(duration: DS.Animation.normal), value: isVisible)
```

---

## Checklist Pre-Commit (UI)

Antes de commitear cambios de UI, verificar:

- [ ] ¿Se usan APIs nativas de iOS 26 donde aplique? (`ToolbarSpacer`, `.glassEffect()`, etc.)
- [ ] ¿Todas las filas clicables usan `Button` + `contentShape(Rectangle())`?
- [ ] ¿Se usan tokens de `DS.Spacing` en lugar de valores hardcodeados?
- [ ] ¿Se usan tokens de `DS.Radius` para corners?
- [ ] ¿Se usa `DS.Typography` para fuentes?
- [ ] ¿Los colores son semánticos (`Color.yalaCard`, `DS.Semantic.*`, etc.)?
- [ ] ¿Los montos usan `amountLarge`/`amount`/`amountSmall`?
- [ ] ¿Los estados vacíos usan `YalaEmptyState`?
- [ ] ¿Los loading states usan componentes estándar?
- [ ] ¿Los botones usan componentes estándar (`YalaPrimaryButton`, etc.)?
- [ ] ¿Las vistas principales usan `.navigationTitle()` con `.large` para título animado?
- [ ] ¿Los chips de navegación/filtro usan `.glassEffect()` sin fondo general?
- [ ] ¿Solo chips de navegación están en `safeAreaInset`? (control bars deben scrollear)
- [ ] ¿Los formularios con texto implementan cierre de teclado correcto (tap, scroll, sheets)?
- [ ] ¿Se usa `@FocusState` con enum (no solo `dismissKeyboard()`) para manejar focus?
- [ ] ¿Las filas con chevron son completamente clicables (`contentShape(Rectangle())`)?
- [ ] ¿Los formularios de creación auto-focus en el primer campo?

---

## Archivos de Referencia

- **Design Tokens**: `Yala/App/Theme/DesignTokens.swift`
- **Botones**: `Yala/App/Views/Shared/StandardButtons.swift`
- **Empty States**: `Yala/App/Views/Shared/YalaEmptyState.swift`
- **Badges**: `Yala/App/Views/Shared/YalaBadge.swift`
- **Loading**: `Yala/App/Views/Shared/YalaLoadingOverlay.swift`
- **Skeletons**: `Yala/App/Views/Shared/SkeletonView.swift`
- **Section Headers**: `Yala/App/Views/Shared/YalaSectionHeader.swift`
- **Form Rows**: `Yala/App/Views/Transactions/TransactionFormRow.swift`
- **List Rows**: `Yala/App/Views/Records/Components/RecordRowView.swift`
