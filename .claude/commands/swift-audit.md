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
- `Binding(get:` en body → antipattern, usar @Binding + .onChange
- `AnyView(` → usar @ViewBuilder, Group o generics
- `onTapGesture {` en vez de Button → pierde accesibilidad
- IGNORAR: `@State` en #Preview, `AnyView` en type-erased collections justificadas

### I. TODOs pendientes
- Pattern: `TODO|FIXME|HACK|XXX`

## PASO 3: REPORTE

```
## Swift Audit — [N] archivos

| Check | Estado | Encontrados |
|-------|--------|-------------|
| Errores silenciados (try?) | ✓/✗ | N |
| Force unwraps (!) | ✓/✗ | N |
| Prints producción | ✓/✗ | N |
| Valores hardcodeados | ✓/✗ | N |
| APIs deprecated | ✓/✗ | N |
| Concurrencia | ✓/✗ | N |
| Strings sin L10n | ✓/✗ | N |
| State management | ✓/✗ | N |
| TODOs pendientes | ✓/✗ | N |

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
