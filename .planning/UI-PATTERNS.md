# UI Patterns & Design System Rules

**LECTURA OBLIGATORIA antes de modificar cualquier vista.**

Este documento define los patrones UI que DEBEN respetarse en toda la app para mantener consistencia.

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
- **SIEMPRE** usar colores del sistema: `Color.netoBackground`, `Color.netoCard`, `Color.electricIndigo`
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
- `Color.netoBackground` - Fondo de app
- `Color.netoCard` - Fondo de tarjetas/modales
- `Color.netoPrimaryText` - Texto principal
- `Color.netoSecondaryText` - Texto secundario

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
.background(Color.netoCard)
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
| Primario | Acción principal | `NetoPrimaryButton` |
| Secundario | Acciones alternativas | `NetoSecondaryButton` |
| Texto | Links, acciones terciarias | `NetoTextButton` |
| Toolbar | Navegación, cerrar | `NetoToolbarButton` |
| Guardar | Confirmación circular | `NetoSaveButton` |

### Empty States
- **SIEMPRE** usar `NetoEmptyState` para estados vacíos
- Incluir: icono (48pt), título, mensaje opcional, acción opcional
- Variantes predefinidas: `.noTransactions`, `.noResults`, `.noTags`, etc.

### Loading States
- `NetoLoadingOverlay` - Modal con overlay oscuro
- `NetoLoadingInline` - Indicador pequeño inline
- `NetoLoadingFullScreen` - Pantalla completa
- Skeletons para contenido: `WidgetSkeleton`, `LatestRecordsSkeleton`, etc.

### Badges
- `NetoBadge` - Badge genérico (filled/soft/outline)
- `NetoStatusBadge` - Estados (success/warning/error/info)
- `NetoTagBadge` - Tags de transacciones
- `NetoCountBadge` - Contadores

---

## Layouts

### Secciones
```swift
VStack(spacing: DS.Spacing.xxl) {
    // Sección 1
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
        NetoSectionHeader(title: "Título")
        // Contenido
    }

    // Sección 2
    // ...
}
.padding(.horizontal, DS.Spacing.lg)
.padding(.bottom, DS.Spacing.safeBottom)
```

### Headers de Sección
- `NetoSectionHeader` - Header principal con acción opcional
- `NetoSectionHeaderCompact` - Subsección (uppercase, pequeño)

### Cards/Widgets
```swift
VStack {
    // Contenido
}
.padding(DS.Card.padding)
.background(Color.netoCard)
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

- [ ] ¿Todas las filas clicables usan `Button` + `contentShape(Rectangle())`?
- [ ] ¿Se usan tokens de `DS.Spacing` en lugar de valores hardcodeados?
- [ ] ¿Se usan tokens de `DS.Radius` para corners?
- [ ] ¿Se usa `DS.Typography` para fuentes?
- [ ] ¿Los colores son semánticos (`Color.netoCard`, etc.)?
- [ ] ¿Los montos usan `amountLarge`/`amount`/`amountSmall`?
- [ ] ¿Los estados vacíos usan `NetoEmptyState`?
- [ ] ¿Los loading states usan componentes estándar?
- [ ] ¿Los botones usan componentes estándar (`NetoPrimaryButton`, etc.)?
- [ ] ¿Las vistas principales usan `.navigationTitle()` con `.large` para título animado?
- [ ] ¿Los chips de navegación/filtro usan `.glassEffect()` sin fondo general?
- [ ] ¿Solo chips de navegación están en `safeAreaInset`? (control bars deben scrollear)

---

## Archivos de Referencia

- **Design Tokens**: `Neto/App/Theme/DesignTokens.swift`
- **Botones**: `Neto/App/Views/Shared/StandardButtons.swift`
- **Empty States**: `Neto/App/Views/Shared/NetoEmptyState.swift`
- **Badges**: `Neto/App/Views/Shared/NetoBadge.swift`
- **Loading**: `Neto/App/Views/Shared/NetoLoadingOverlay.swift`
- **Skeletons**: `Neto/App/Views/Shared/SkeletonView.swift`
- **Section Headers**: `Neto/App/Views/Shared/NetoSectionHeader.swift`
- **Form Rows**: `Neto/App/Views/Transactions/TransactionFormRow.swift`
- **List Rows**: `Neto/App/Views/Records/Components/RecordRowView.swift`
