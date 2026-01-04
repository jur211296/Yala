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
