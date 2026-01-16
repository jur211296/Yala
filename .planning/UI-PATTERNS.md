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
