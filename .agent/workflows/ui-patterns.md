---
description: UI patterns and best practices for Neto development
---

# Neto UI Patterns & Best Practices

## 1. Clickable Rows - Always Use `contentShape(Rectangle())`

When creating clickable rows in Lists, NavigationLinks, or Buttons, **always add `.contentShape(Rectangle())`** to make the entire row tappable, not just the visible content.

### ✅ Correct Pattern

```swift
@ViewBuilder
private func myRow(_ item: Item) -> some View {
    HStack(spacing: 12) {
        Image(systemName: "star")
        Text(item.name)
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .contentShape(Rectangle())  // <-- ALWAYS ADD THIS
}
```

### ❌ Incorrect Pattern (Missing contentShape)

```swift
// DON'T do this - only text/icons will be tappable
private func myRow(_ item: Item) -> some View {
    HStack(spacing: 12) {
        Image(systemName: "star")
        Text(item.name)
        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    // Missing .contentShape(Rectangle())!
}
```

### When to Apply

- Any row inside a `NavigationLink`
- Any row with an `onTapGesture`
- Any `Button` label with a custom row layout
- Any row in a `List` or `ForEach`

---

## 2. Toolbar Buttons - Use Standard Components

Use the standardized button components from `StandardButtons.swift`:

### Navigation/Action Buttons → `NetoToolbarButton`

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        NetoToolbarButton(systemName: "xmark") {  // Close
            dismiss()
        }
    }
    ToolbarItem(placement: .topBarLeading) {
        NetoToolbarButton(systemName: "chevron.left") {  // Back
            dismiss()
        }
    }
    ToolbarItem(placement: .topBarTrailing) {
        NetoToolbarButton(systemName: "plus") {  // Add
            addItem()
        }
    }
}
```

### Save/Confirm Buttons → `NetoSaveButton`

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        NetoSaveButton(
            action: { saveData() },
            isDisabled: !canSave
        )
    }
}
```

### Icon Reference

| Action | Icon | Component |
|--------|------|-----------|
| Close/Cancel | `xmark` | `NetoToolbarButton` |
| Back | `chevron.left` | `NetoToolbarButton` |
| Add | `plus` | `NetoToolbarButton` |
| Reorder | `arrow.up.arrow.down` | `NetoToolbarButton` |
| Confirm Edit | `checkmark` | `NetoToolbarButton` |
| Save/Done/Continue | - | `NetoSaveButton` |

---

## 3. Row Content Structure

Standard row structure with proper spacing:

```swift
HStack(spacing: 12) {
    // Icon (optional)
    Circle()
        .fill(Color.brandPrimary)
        .frame(width: 36, height: 36)
        .overlay(
            Image(systemName: "tag")
                .foregroundStyle(.white)
        )
    
    // Text content
    VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
            .font(.body)
            .foregroundStyle(.primary)
        
        Text(item.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    
    Spacer()
    
    // Trailing indicator (for navigation)
    Image(systemName: "chevron.right")
        .font(.footnote)
        .foregroundStyle(.tertiary)
}
.padding(.horizontal, 16)
.padding(.vertical, 12)
.contentShape(Rectangle())  // <-- DON'T FORGET!
```

---

## 4. Quick Checklist for New Views

- [ ] All clickable rows have `.contentShape(Rectangle())`
- [ ] Toolbar uses `NetoToolbarButton` for navigation/actions
- [ ] Toolbar uses `NetoSaveButton` for save/confirm actions
- [ ] NavigationLinks have `.buttonStyle(.plain)` when needed
- [ ] Rows have consistent padding (typically 16 horizontal, 12-14 vertical)
- [ ] Views with custom back buttons use `.swipeBack()` modifier
- [ ] Category/subcategory icons use actual `iconName` property

---

## 5. Swipe-Back Gesture - Use `.swipeBack()` Modifier

When hiding the navigation back button with custom toolbar buttons, **always use `.swipeBack()` instead of `.navigationBarBackButtonHidden(true)`** to preserve the native iOS swipe-back gesture.

### ✅ Correct Pattern

```swift
var body: some View {
    ScrollView { ... }
        .navigationTitle("Edit Category")
        .swipeBack()  // <-- Hides back button BUT keeps swipe gesture
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
}
```

### ❌ Incorrect Pattern

```swift
// DON'T do this - disables swipe-back gesture
var body: some View {
    ScrollView { ... }
        .navigationTitle("Edit Category")
        .navigationBarBackButtonHidden(true)  // <-- Breaks swipe gesture!
        .toolbar { ... }
}
```

### How It Works

The `SwipeBackModifier` in `App/Components/SwipeBackModifier.swift`:
1. Hides the default back button
2. Re-enables `interactivePopGestureRecognizer` via a hidden UIViewController

---

## 6. Category/Subcategory Icons - Always Use Actual Icons

When displaying category or subcategory icons, **always use the actual `iconName` property** from the model, with appropriate fallbacks.

### ✅ Correct Pattern

```swift
private var subcategoryIcon: some View {
    let colorHex = record.category?.colorHex ?? "#6366F1"
    let iconName = record.subcategory?.iconName
        ?? record.category?.iconName
        ?? "tag.fill"  // Last resort fallback

    return ZStack {
        Circle()
            .fill(Color(hex: colorHex))  // Solid color, no opacity
            .frame(width: 40, height: 40)

        Image(systemName: iconName)
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)  // Always white for contrast
    }
}
```

### ❌ Incorrect Pattern

```swift
// DON'T do this - generic icons lose visual identity
Image(systemName: "tag.fill")  // Always the same!
    .foregroundStyle(Color(hex: colorHex))  // Low contrast on light colors

// DON'T do this - semitransparent backgrounds
Circle()
    .fill(Color(hex: colorHex).opacity(0.15))  // Looks washed out
```

### Icon Priority Order

1. `subcategory?.iconName` (most specific)
2. `category?.iconName` (parent fallback)
3. `"tag.fill"` (generic fallback)

### Styling Rules

| Element | Style |
|---------|-------|
| Circle background | Solid category color (no opacity) |
| Icon foreground | Always `.white` |
| Icon font | `.callout.weight(.medium)` for rows, `.system(size: iconSize * 0.4)` for widgets |

---

## 7. NetoSaveButton - Require Changes Before Enabling

For edit/detail views, **the save button should be disabled until the user makes a change**. This provides visual feedback that changes haven't been made yet.

### ✅ Correct Pattern - Edit Views

```swift
// Track initial values
private let initialName: String
private let initialColor: String

// Computed property for change detection
private var hasChanges: Bool {
    name != initialName || color != initialColor
}

// Button disabled until changes are made
NetoSaveButton(
    action: { save() },
    isDisabled: name.isEmpty || !hasChanges  // Validation + change detection
)
```

### ✅ Correct Pattern - Selection Views

```swift
// For views where user must select something
NetoSaveButton(
    action: { onContinue(selectedItem) },
    isDisabled: selectedItem == nil  // Require selection
)
```

### ✅ OK Without Disabled - Modal Actions

```swift
// For simple modal dismiss actions (date picker, tag selector, preferences)
NetoSaveButton(action: { dismiss() })  // Always enabled - just confirms/closes
```

### When to Use Each Pattern

| View Type | Disabled Logic |
|-----------|----------------|
| Edit form (CategoryDetail, TagForm) | `isEmpty \|\| !hasChanges` |
| Picker sheet (IconColorPicker) | `!hasChanges` |
| Selection sheet (ImportAccountPicker) | `selectedItem == nil` |
| Simple modal (DatePicker, Preferences) | None (always enabled) |

---

## 8. Widget Patterns

Widgets in Panel display data summaries. Follow these patterns for consistency.

### Widget Container Structure

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 0) {
        // Header
        headerView
        
        // Content (charts, bars, etc.)
        contentForSize
            .padding(.horizontal, 16)
            .padding(.bottom, 24)  // Bottom breathing room
    }
    .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .topLeading)
    .background(Color.netoCard)
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
}
```

### Widget Height Rules

| Widget Type | Height Constraint |
|-------------|-------------------|
| Chart widgets | `minHeight: 320` (natural sizing) |
| Pie widgets | `minHeight: 320` + 24pts bottom padding |
| Compact widgets | No fixed height (natural sizing) |

**Never use fixed heights that can clip content.** Use `minHeight` to prevent collapse.

### Widget Header - Title + KPI Only

Headers should be minimal: **just title and KPI value**. No subtitles.

```swift
private var headerView: some View {
    HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
            Text("Flujo de efectivo")  // Title only
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            Text(formattedKPI)  // KPI value directly
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
        }
        
        Spacer()
        
        // Optional: count badge + chevron
        HStack(spacing: 8) {
            Text("\(count) items")
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            
            if onShowDetail != nil {
                Button { onShowDetail?() } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
                }
            }
        }
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 12)
}
```

### ❌ Avoid Subtitles

```swift
// DON'T add subtitles like these:
Text("Total del periodo")    // ❌
Text("Flujo Neto")           // ❌
Text("Categoría filtrada")   // ❌
```

### Compact Widget Layout - Horizontal Bars

For compact widget variants, use CashFlow-style horizontal progress bars instead of charts:

```swift
// Each category/nature gets a bar
VStack(spacing: 12) {
    ForEach(items) { item in
        VStack(spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(formattedAmount(item.amount))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 8)
                    
                    let width = maxVal > 0 ? (item.amount / maxVal) * geo.size.width : 0
                    Capsule()
                        .fill(item.color)
                        .frame(width: max(width, 6), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
```

### Widget Size Variants

| Size | Description | Layout |
|------|-------------|--------|
| `.large` | Full chart with legend | Chart + Legend (vertical) |
| `.medium` | Summary only | Horizontal progress bars |

---

## 9. Quick Checklist for Widgets

- [ ] No fixed heights that clip content
- [ ] Uses `minHeight` for minimum size guarantee
- [ ] Header has only Title + KPI (no subtitles)
- [ ] Bottom padding of 24pts for breathing room
- [ ] Compact variant uses horizontal bars, not scaled charts
- [ ] Interactive elements have visual feedback (opacity, selection states)

---

## 10. Chart Hover Tooltips

Hover tooltips on charts use native iOS 17+ selection that works with scroll.

### Approach: `chartXSelection` + `chartOverlay`

```swift
Chart { ... }
    .chartXSelection(value: $selectedDate)  // Native tap selection
    .chartOverlay { proxy in                // Visual tooltip only
        GeometryReader { geo in
            if let activeDate = selectedDate,
               let data = findData(for: activeDate),
               let xPos = proxy.position(forX: data.date)
            {
                TooltipView(data: data)
                    .position(...)
            }
        }
    }
```

**Key points:**
- `.chartXSelection` handles tap detection natively without blocking scroll
- `.chartOverlay` only renders tooltip visuals (no gesture handling)
- Scroll works naturally, tap on chart shows tooltip

### Visual Style: Black Text + Color Dots

```swift
VStack(alignment: .leading, spacing: 4) {
    Text(dateLabel)
        .font(.caption2)
        .foregroundStyle(.secondary)
    
    HStack(spacing: 6) {
        Circle().fill(Color.brandPrimary).frame(width: 6, height: 6)
        Text(formattedAmount)
            .font(.caption2.bold())
            .foregroundStyle(.primary)  // ← Black text
    }
}
.padding(8)
.background(RoundedRectangle(cornerRadius: 8).fill(Color.netoCard).shadow(...))
```

### Date Format by Grouping

All dates use lowercase without periods:

| Grouping | Format | Example |
|----------|--------|---------|
| `.day` | `d MMM yy` | "19 dic 25" |
| `.week` | `d MMM yy` | "19 dic 25" |
| `.month` | `MMM yy` | "ene 25" |

private func formatTooltipDate(_ date: Date, grouping: TrendGrouping) -> String {
    let formatter = DateFormatter()
    formatter.locale = AppLocale.current
    switch grouping {
    case .day, .week: formatter.dateFormat = "d MMM yy"
    case .month: formatter.dateFormat = "MMM yy"
    }
    return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
}
```

---

## 11. Record Row Variants

Use consistent record row structure across views, with context-specific secondary lines.

### Full Row (DetailContainerView) → `RecordRowView`

Shows category + account, used in detailed records list:

```swift
// Secondary line: Subcategory • Account
VStack(alignment: .leading, spacing: 3) {
    Text(note)
        .font(.subheadline.weight(.medium))  // Bold note
        .foregroundStyle(.primary)
    
    Text("\(categoryName) • \(accountName)")  // Account context
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

### Compact Row (Widget/TrendsTabView) → `CompactRecordRow`

Shows category + date, used in summary contexts:

```swift
// Secondary line: Subcategory • Date (no account)
VStack(alignment: .leading, spacing: 3) {
    Text(note)
        .font(.subheadline.weight(.medium))  // Bold note
        .foregroundStyle(.primary)
    
    Text("\(categoryName) • \(formattedDate)")  // Date context
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

### Common Structure

| Element | Style |
|---------|-------|
| Note (Line 1) | `.subheadline.weight(.medium)`, `.primary` |
| Secondary (Line 2) | `.caption`, `.secondary` |
| Amount | `.subheadline.weight(.semibold)`, color by nature |
| Nature badge | Capsule with color dot + displayName |

### Nature Indicator Badge

```swift
private func natureIndicator(for nature: SubcategoryNature) -> some View {
    HStack(spacing: 4) {
        Circle()
            .fill(nature.color)
            .frame(width: 6, height: 6)

        Text(nature.displayName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(Capsule().fill(nature.color.opacity(0.1)))
}
```

### Date Format for Compact Rows

```swift
private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es")
    formatter.dateFormat = "d MMM"
    return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
}
// Output: "5 ene", "19 dic"
```

---

## 12. Chart Axis Formatting

### Y-Axis Value Format

Use uppercase 'K' for thousands, no '+' sign for positive values:

```swift
private func formatK(_ value: Double) -> String {
    let absValue = abs(value)
    if absValue >= 1000 {
        let formatted = absValue / 1000.0
        let kValue = formatted.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0fK", formatted)
            : String(format: "%.1fK", formatted)
        return value < 0 ? "-\(kValue)" : kValue
    }
    return String(format: "%.0f", value)
}
// Output: "10K", "-20K", "1.5K", "500"
```

### X-Axis Smart Dates

Use `SmartAxisHelper` for dynamic date labels that adapt to range:

```swift
// Calculate optimal date positions
let smartDates = SmartAxisHelper.calculateSmartAxisDates(from: firstDate, to: lastDate)

// Format without periods
let label = SmartAxisHelper.formatAxisLabel(for: date, startDate: firstDate, endDate: lastDate)
// Output: "ene", "feb", "15 ene" (no periods)
```

### CashFlow Independent Y-Scales

For charts with positive (income) and negative (expense) values, use independent scales:

```swift
private var dataYDomain: ClosedRange<Double> {
    let maxIncome = chartData.map { $0.income }.max() ?? 0
    let maxExpense = chartData.map { $0.expense }.max() ?? 0
    // 10% padding for visual breathing room
    let incomeTop = maxIncome * 1.1
    let expenseBottom = -maxExpense * 1.1
    return expenseBottom...incomeTop
}

Chart { ... }
    .chartYScale(domain: dataYDomain)
```

This ensures income bars fill their space proportionally and expense bars fill their space proportionally, rather than both being scaled to the larger of the two.

### CashFlow Line/Point Conditional Display

Only show LineMark and PointMark for monthly grouping:

```swift
ForEach(chartData) { data in
    // Bars always shown
    BarMark(x: .value("Date", data.date), y: .value("Income", data.income))
    BarMark(x: .value("Date", data.date), y: .value("Expense", -data.expense))
    
    // Line only for monthly view
    if grouping == .month {
        LineMark(x: .value("Date", data.date), y: .value("Net", data.net))
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
        
        PointMark(x: .value("Date", data.date), y: .value("Net", data.net))
            .symbolSize(20)
    }
}
```

---

## 13. Quick Checklist for Charts

- [ ] Y-axis uses `formatK` with uppercase 'K', no '+' sign
- [ ] X-axis uses `SmartAxisHelper` for dynamic labels
- [ ] Month abbreviations have no periods (ene, feb not ene., feb.)
- [ ] CashFlow has independent Y scales for income/expense
- [ ] Line/point marks only appear for monthly grouping
- [ ] Empty data points are filtered before rendering
- [ ] Gridlines are subtle (`.opacity(0.1)`, thin lines)

---

## 14. Currency Formatting Standard

All monetary amounts must use the standardized `NetoFormatter.currency` format.

### Format: `PEN 20,000.00` or `PEN -20,000.00`

```swift
// Standard usage (always 2 decimals)
NetoFormatter.currency(value: amount, currencyCode: currencyCode)
// Output: "PEN 20,000.00" or "PEN -20,000.00"

// With '+' sign for positive (only in CashFlow tooltip)
NetoFormatter.currency(value: amount, currencyCode: currencyCode, forceSign: true)
// Output: "PEN +20,000.00" or "PEN -20,000.00"
```

### Rules

| Rule | Description |
|------|-------------|
| Decimals | Always 2 decimals, everywhere |
| Positive values | No sign (just `20,000.00`) |
| Negative values | Minus attached to number (`-20,000.00`) |
| Currency code | 3-letter code, followed by space |
| `forceSign` | Only for CashFlow hover tooltip |

### ✅ Correct Examples

```
PEN 1,500.00     ← Positive amount
PEN -2,300.50    ← Negative amount
PEN +5,000.00    ← forceSign: true (tooltip only)
```

### ❌ Incorrect Examples

```
S/ 1,500         ← Wrong: missing decimals, wrong symbol
PEN 1500.00      ← Wrong: missing thousands separator
PEN - 1,500.00   ← Wrong: space before number
+1,500.00        ← Wrong: missing currency code
```

### Usage Guidelines

- **Don't use `decimals:` parameter** - it's been removed. Always 2 decimals.
- **Use `forceSign: true` only** in CashFlow hover tooltips.
- **All widgets, rows, charts** must use this standard format.

---

## 15. iOS 18 Native Components - Always Prefer Native

**Always use native SwiftUI iOS 18 components** for the best user experience. Custom implementations should only be used when native components don't meet requirements.

### TabView with Search Role (iOS 18+)

Use the new `Tab` type with `.search` role to add a native search button in the tab bar:

```swift
TabView(selection: $selectedTab) {
    Tab("Panel", systemImage: "rectangle.grid.2x2.fill", value: .panel) {
        PanelView()
    }

    Tab("Estadísticas", systemImage: "chart.bar.fill", value: .statistics) {
        StatisticsView()
    }

    Tab("Planificación", systemImage: "calendar", value: .planning) {
        PlanningView()
    }

    Tab("Más", systemImage: "ellipsis", value: .more) {
        MoreView()
    }

    // Search tab with .search role - automatically pinned to trailing edge
    Tab(value: .search, role: .search) {
        GlobalSearchView()
    }
}
.tint(Color.electricIndigo)
```

**Benefits:**
- Search button appears separated on trailing edge (like your reference image)
- Native liquid glass effect automatically applied
- Consistent with iOS design guidelines

### Native Searchable Modifier

Use `.searchable` for search functionality instead of custom search bars:

```swift
NavigationStack {
    ZStack {
        PanelBackgroundView()
        
        if searchText.isEmpty {
            // Empty state
            EmptySearchView()
        } else {
            // Search results
            SearchResultsList(query: searchText)
        }
    }
    .navigationTitle("Buscar")
    .navigationBarTitleDisplayMode(.inline)
}
.searchable(
    text: $searchText,
    placement: .navigationBarDrawer(displayMode: .always),
    prompt: "Buscar"
)
```

**Benefits:**
- Native keyboard with search button
- Native "X" dismiss button
- Proper keyboard management
- Consistent iOS search UX

### Native Materials (Glass Effects)

Use native SwiftUI materials for glass/blur effects:

```swift
// ✅ Correct - Native material
.background(.ultraThinMaterial)
.background(.regularMaterial)
.background(.thickMaterial)

// ❌ Incorrect - Custom blur
.background(BlurView(style: .systemMaterial))  // Don't use UIKit wrappers
.background(Color.white.opacity(0.8))          // Don't fake glass
```

### Native Tab Enum Pattern

```swift
enum AppTab: Hashable {
    case panel
    case statistics
    case planning
    case more
    case search
}
```

### Quick Reference: When to Use Native

| Feature | Native Approach | Don't Use |
|---------|-----------------|-----------|
| Tab Bar | `TabView` + `Tab` type | Custom HStack tab bars |
| Search | `.searchable` modifier | Custom TextField + keyboard handling |
| Glass Effect | `.ultraThinMaterial` | Custom blur views |
| Search Button | `Tab(role: .search)` | Custom floating buttons |
| Navigation | `NavigationStack` | Custom navigation |

### ❌ Patterns to Avoid

```swift
// DON'T create custom tab bars
HStack {
    ForEach(tabs) { tab in
        Button { ... } label: { ... }
    }
}
.background(RoundedRectangle(...).fill(.ultraThinMaterial))

// DON'T create custom search bars when native works
HStack {
    Image(systemName: "magnifyingglass")
    TextField("Buscar", text: $searchText)
    Button { ... } label: { Image(systemName: "xmark") }
}
```

### Checklist for Native Components

- [ ] Using `Tab` type (not `.tabItem` modifier) for iOS 18+
- [ ] Search uses `.searchable` modifier
- [ ] Glass effects use `.ultraThinMaterial` or similar
- [ ] No custom recreations of native iOS components
- [ ] Tab bar uses native `TabView` styling

---

## 16. Design System Tokens - Always Use `DS.*`

**Never hardcode UI values.** Always use the centralized Design System tokens from `DesignTokens.swift` (`enum DS`).

### Common Token Mappings

| Hardcoded Value | Use Instead |
|-----------------|-------------|
| `.padding(4)` | `DS.Spacing.xs` |
| `.padding(8)` | `DS.Spacing.sm` |
| `.padding(12)` | `DS.Spacing.md` |
| `.padding(16)` | `DS.Spacing.lg` / `DS.Card.paddingCompact` |
| `.padding(20)` | `DS.Spacing.xl` / `DS.Card.padding` |
| `.padding(24)` | `DS.Spacing.xxl` |
| `.cornerRadius(8)` | `DS.Radius.sm` |
| `.cornerRadius(12)` | `DS.Radius.md` |
| `.cornerRadius(16)` | `DS.Radius.lg` |
| `.cornerRadius(24)` | `DS.Radius.xl` |
| `.opacity(0.05)` | `DS.Opacity.faint` |
| `.opacity(0.1)` | `DS.Card.borderOpacity` |
| `.frame(width: 40)` (icon badge) | `DS.Icon.badgeLarge` |

### ✅ Correct Pattern

```swift
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    headerView
    contentView
}
.padding(DS.Card.padding)
.background(Color.netoCard)
.clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
        .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
)
.shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
```

### ❌ Incorrect Pattern

```swift
// DON'T hardcode values - makes global changes impossible
VStack(alignment: .leading, spacing: 12) {
    headerView
    contentView
}
.padding(20)
.cornerRadius(24)
.overlay(
    RoundedRectangle(cornerRadius: 24)
        .stroke(Color.white.opacity(0.1), lineWidth: 1)  // ❌
)
.shadow(color: Color.black.opacity(0.05), radius: 10)    // ❌
```

### Available Token Categories

| Category | Tokens | Use For |
|----------|--------|---------|
| `DS.Spacing.*` | xs, sm, md, lg, xl, xxl | Padding, spacing, gaps |
| `DS.Radius.*` | xs, sm, md, lg, xl | Corner radius |
| `DS.Opacity.*` | faint, medium, heavy | Shadows, overlays |
| `DS.Card.*` | padding, paddingCompact, radius, borderOpacity | Widget cards |
| `DS.Chip.*` | paddingH/V, spacing, dotSize, iconSize, closeButtonSize | Filter chips |
| `DS.Icon.*` | badgeSmall, badgeMedium, badgeLarge, sizeSmall/Medium/Large | Icon badges |

### Checklist for DS Tokens

- [ ] No hardcoded padding values (use `DS.Spacing.*`)
- [ ] No hardcoded corner radius (use `DS.Radius.*`)
- [ ] No hardcoded opacity values (use `DS.Opacity.*` or `DS.Card.borderOpacity`)
- [ ] Widget cards use `DS.Card.padding` and `DS.Radius.xl`
- [ ] Filter chips use `DS.Chip.*` tokens
- [ ] Icon badges use `DS.Icon.*` sizes
