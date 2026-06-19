---
description: Auditoría completa de calidad Swift en archivos modificados
allowed-tools: Bash(git:*), Grep, Glob, Read
---

Auditoría unificada de calidad Swift. Analiza staging area (lo que va al próximo commit).

## PASO 1: IDENTIFICAR ARCHIVOS

Obtener archivos .swift en staging area + unstaged + untracked:
```bash
FILES=$(comm -23 \
  <(sort -u <(git diff --name-only HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)) \
  <(echo ""))
SWIFT_FILES=$(echo "$FILES" | grep '\.swift$' | sort -u)
```

Si no hay archivos .swift: "No hay archivos Swift modificados. Audit N/A."

## PASO 2: CHECKS AUTOMÁTICOS

Ejecutar checks en paralelo usando Grep SOLO sobre los archivos identificados:

### A. Errores silenciados (try?)
- Pattern: `try\?`
- IGNORAR estos patrones aceptados:
  - `try? Regex(` o `try? NSRegularExpression(` — regex compilation
  - `try? Task.sleep` — cancellation-safe
  - `guard let x = try?` — optional binding pattern
  - Líneas con comentario `// A11Y-` o `// DS-` (ya auditadas)

### B. Force unwraps (!)
- Pattern: `\w!` en contexto de unwrap
- IGNORAR:
  - `!=` (not equal operator)
  - `!isEmpty`, `!isArchived`, `!contains` etc. (boolean negation)
  - `#if !` (preprocessor)
  - Líneas dentro de `guard let` / `if let` blocks (post-validation)
  - Strings y comentarios
  - `IBOutlet` / `IBAction` (Interface Builder pattern)

### C. Prints en producción
- Pattern: `print(`
- Verificar contexto: 5 líneas arriba buscando `#if DEBUG`
- IGNORAR prints dentro de `#if DEBUG` blocks

### D. Valores hardcodeados (anti-DS)
- `.padding(` con número literal — usar DS.Spacing
- `.font(.system(size:` — usar DS.Typography
- `Color(` con hex/RGB — usar colores semánticos
- IGNORAR:
  - Líneas con comentario `// A11Y-DT:` (Dynamic Type justificado)
  - Líneas con comentario `// A11Y-DM:` (Dark Mode justificado)
  - Archivos en Widgets/ (usan WDS tokens propios)
  - `.padding(0)` y `.padding(.zero)` (reset intencional)
  - `spacing: 0` en Stacks (intencional)

### E. APIs deprecated
- `foregroundColor(` → foregroundStyle
- `NavigationView` → NavigationStack
- `.overlay(Text(` o `.overlay(Image(` → `.overlay { ... }` (trailing closure)
- `.navigationBarLeading`/`.navigationBarTrailing` → `.topBarLeading`/`.topBarTrailing`
- `showsIndicators: false` en ScrollView → `.scrollIndicators(.hidden)`
- `NavigationLink(destination:` → `navigationDestination(for:)`
- IGNORAR: `.cornerRadius(` en ChartContent (BarMark, SectorMark — no es View API)

### F. Concurrencia
- `DispatchQueue.main.async` — preferir @MainActor
- `DispatchQueue.global().async` — preferir Task {} o Task.detached {}
- `DispatchGroup` → TaskGroup
- IGNORAR:
  - Dentro de funciones que hacen network calls (legítimo para dispatch back)
  - Con comentario `// dispatch:` justificando uso
  - Delays con `asyncAfter` < 0.5s en UI (timing patterns)

### G. Strings sin localizar
- `Text("` con texto literal
- IGNORAR: SF Symbols, formatos numéricos, debug text, `.accessibilityLabel`

### H. State Management
- `@State` sin `private` → debe ser `private`
- `@Observable` sin `@MainActor` → debe tener @MainActor
- `@AppStorage(` en views nuevas (post-AppPreferences) → debe inyectar `AppPreferences` vía `@Environment` y usar `appPreferences.X`
- `@AppStorage(` dentro de clase con `@Observable` → no triggerea updates, mover a `AppPreferences`
- `Binding(get:` en body → antipattern, usar `@Binding` + `.onChange`
- `AnyView(` → usar `@ViewBuilder`, `Group` o generics
- `onTapGesture {` en vez de Button → pierde accesibilidad
- `@StateObject` / `@Published` / `ObservableObject` → preferir `@Observable` + `@State`/`@Bindable`
- IGNORAR: `@State` en `#Preview`, `AnyView` en type-erased collections justificadas

### I. SwiftData / CloudKit compat
- `@Attribute(.unique)` → PROHIBIDO con CloudKit (CKError), usar índice manual
- `@Relationship` sin `inverse:` en relación bidireccional → corregir
- `@Relationship` sin `deleteRule:` explícito → especificar (`.cascade`, `.nullify`, `.deny`)
- Propiedad `@Model` sin valor por defecto (no-Optional, no inicializada) → CKError, dar default
- `@Relationship var x: Type` non-Optional → CKError, hacer Optional o dar default
- IGNORAR: propiedades Identifiable estándar (`id`), tests dentro de YalaTests/

### J. iOS 26 gotchas críticos
- `ToolbarSpacer(.fixed)` sin parámetro `placement:` → `placement` es OBLIGATORIO
- `containerRelativeFrame(.horizontal)` dentro de `ScrollView(.vertical)` con `.contentMargins` → DEADLOCK de layout (splash nunca dismissa sin crash log). Usar `onGeometryChange`.
- `NavigationView` → `NavigationStack` (deprecated, ya cubierto en E pero crítico para iOS 26)
- IGNORAR: ToolbarSpacer con placement correcto, containerRelativeFrame en ScrollView horizontal

### K. Convenciones Yala (CLAUDE.md)
- View root nueva, sheet, fullScreenCover sin `.yalaScreenBackground(_:ignoredEdges:)` → aplicar modifier
- `.background(theme.background)` o `.background(.thBackground)` directo → usar `.yalaScreenBackground()`
- Form/List con TextField/TextEditor/SecureField sin `dismissKeyboardOnTap()` → añadir desde primer commit
- `// removed`, `// TODO: cleanup tras X`, `// added for the Y flow` → comments narrando tarea/historia, eliminar (rastro va en commit msg)
- IGNORAR: comments con `// A11Y-DT:`, `// A11Y-DM:`, `// DS-`, `// WHY:` (justificaciones intencionales)

### L. TODOs pendientes
- Pattern: `TODO|FIXME|HACK|XXX`

## PASO 3: REPORTE

```
## Swift Audit — [N] archivos

| Check | Estado | Encontrados |
|-------|--------|-------------|
| A. Errores silenciados (try?) | ✓/✗ | N |
| B. Force unwraps (!) | ✓/✗ | N |
| C. Prints producción | ✓/✗ | N |
| D. Valores hardcodeados | ✓/✗ | N |
| E. APIs deprecated | ✓/✗ | N |
| F. Concurrencia | ✓/✗ | N |
| G. Strings sin L10n | ✓/✗ | N |
| H. State management | ✓/✗ | N |
| I. SwiftData / CloudKit | ✓/✗ | N |
| J. iOS 26 gotchas | ✓/✗ | N |
| K. Convenciones Yala | ✓/✗ | N |
| L. TODOs pendientes | ✓/✗ | N |

### Issues (archivo:línea — descripción)
[Lista priorizada: críticos primero, luego warnings]

### Veredicto: LIMPIO | N ISSUES
```

## REGLAS
- Solo reportar problemas REALES en archivos MODIFICADOS
- Respetar allowlist de patrones aceptados (sección IGNORAR de cada check)
- Si un patrón tiene comentario de justificación (A11Y-DT, A11Y-DM, DS-N), NO reportarlo
- Ante duda sobre si es falso positivo, leer contexto (5 líneas alrededor) antes de reportar
- Credenciales hardcodeadas (API keys, passwords, tokens) son SIEMPRE críticos — no hay allowlist
