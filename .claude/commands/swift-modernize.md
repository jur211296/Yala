---
description: Detecta patrones legacy y sugiere APIs modernas de iOS 26
allowed-tools: Grep, Glob, Read
argument-hint: "[archivo.swift o directorio]"
---

Escanea código Swift para encontrar patrones legacy y proponer modernización con APIs de iOS 26+.

## PASO 1: DETERMINAR ALCANCE

Si hay argumento ($ARGUMENTS):
- Si es `all`: escanear TODO el proyecto (Yala/App/ + Yala/Services/ + Yala/Utils/)
- Si es archivo: escanear ese archivo
- Si es directorio: escanear todos los .swift del directorio

Si no hay argumento:
- Escanear archivos modificados (git diff)

Para scan completo pre-release usar: `/swift-modernize all`

## PASO 2: DETECTAR PATRONES LEGACY

### A. SwiftUI Deprecated
| Legacy | Moderno | Notas |
|--------|---------|-------|
| `foregroundColor(` | `foregroundStyle(` | Deprecated iOS 17+ |
| `.cornerRadius(N)` | `.clipShape(RoundedRectangle(cornerRadius: N))` | Deprecated |
| `NavigationView {` | `NavigationStack {` | Deprecated iOS 16+ |
| `.onChange(of: x) { newValue in` | `.onChange(of: x) { oldValue, newValue in` | iOS 17+ firma |
| `.onAppear { task {` | `.task {` | Más limpio |
| `@ObservedObject` | `@Bindable` (si @Observable) | iOS 17+ |
| `@StateObject` | `@State` (si @Observable) | iOS 17+ |
| `@Published` | `@Observable` macro | iOS 17+ |
| `.overlay(Content())` | `.overlay { Content() }` | Trailing closure syntax |
| `.navigationBarLeading` | `.topBarLeading` | Deprecated |
| `.navigationBarTrailing` | `.topBarTrailing` | Deprecated |
| `NavigationLink(destination:)` | `navigationDestination(for:)` | Navigation pattern |
| `showsIndicators: false` | `.scrollIndicators(.hidden)` | ScrollView modifier |
| `.tabItem { }` | `Tab("", systemImage:) { }` | iOS 18+ Tab API |
| `TextEditor()` | `TextField("", axis: .vertical)` | Soporta placeholder |
| `UIImpactFeedbackGenerator` | `.sensoryFeedback()` | SwiftUI nativo |
| `GeometryReader` | `containerRelativeFrame()` / `visualEffect()` | Cuando aplica |
| `Text("A") + Text("B")` | `Text("\(textA)\(textB)")` | Interpolación |

### B. Concurrencia Legacy
| Legacy | Moderno |
|--------|---------|
| `DispatchQueue.main.async {` | `@MainActor` o `MainActor.run {` |
| `DispatchQueue.global().async {` | `Task { }` o `Task.detached { }` |
| Completion handlers | `async/await` |
| `DispatchGroup` | `TaskGroup` |
| `Task.sleep(nanoseconds:)` | `Task.sleep(for: .seconds(N))` |

### C. Swift Syntax Legacy
| Legacy | Moderno |
|--------|---------|
| `replacingOccurrences(of:with:)` | `replacing("a", with: "b")` |
| `filter { }.count` | `count(where:)` |
| `Date()` | `Date.now` |
| `String(format: "%.2f", val)` | FormatStyle APIs |
| `if let x = x {` | `if let x {` (shorthand) |
| EnvironmentKey manual | `@Entry` macro |
| `fontWeight(.bold)` | `bold()` (respeta contexto del sistema) |

### D. @available Innecesarios
- Target es iOS 26+ → cualquier `@available(iOS XX, *)` donde XX <= 26 es innecesario
- Buscar: `@available\(iOS (1[0-9]|2[0-6]),`

### E. iOS 26 Liquid Glass
| Sin Liquid Glass | Con Liquid Glass |
|------------------|------------------|
| `.background(Material.thin)` | `.glassEffect()` |
| Custom toolbar separators | `ToolbarSpacer(.fixed, placement:)` |
| Manual translucent backgrounds | `.glassEffect()` |

### F. SwiftData Patterns
| Legacy | Moderno |
|--------|---------|
| `@Query` en vistas complejas | ViewModel con fetch manual |
| `try? context.save()` | `do { try context.save() } catch { ... }` |
| `@Attribute(.unique)` | Quitar (incompatible con CloudKit) |

### G. Design Patterns
| Legacy | Moderno |
|--------|---------|
| Custom empty states | `ContentUnavailableView` |
| `HStack { Image; Text }` | `Label("text", systemImage:)` |
| `.opacity(0.5)` para jerarquía | `.foregroundStyle(.secondary)` / `.tertiary` |
| `AnyView(...)` | `@ViewBuilder` / `Group` / generics |
| Computed property → `some View` | Extraer a `View` struct separado |

## PASO 3: REPORTE

```
## Swift Modernize — [N] archivos escaneados

### Cambios recomendados
| Archivo | Línea | Legacy | Moderno | Impacto |
|---------|-------|--------|---------|---------|
| View.swift | 45 | foregroundColor | foregroundStyle | Bajo |
| VM.swift | 89 | DispatchQueue.main | @MainActor | Medio |

### Resumen
- [N] patrones deprecated encontrados
- [N] oportunidades de modernización iOS 26
- [N] @available innecesarios

### Prioridad de migración
1. **Alta**: APIs deprecated que generan warnings
2. **Media**: Patrones legacy que funcionan pero tienen mejor alternativa
3. **Baja**: Oportunidades de Liquid Glass (cosméticas)
```

## REGLAS
- NO cambiar código automáticamente, solo reportar
- Priorizar cambios que eliminen warnings del compilador
- @available necesarios para APIs de iOS 26.x beta se mantienen
- No forzar Liquid Glass donde no aporta valor visual
- Respetar el Design System existente (DS tokens)
