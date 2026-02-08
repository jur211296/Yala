---
description: Detecta patrones legacy y sugiere APIs modernas de iOS 26
allowed-tools: Grep, Glob, Read
argument-hint: "[archivo.swift o directorio]"
---

Escanea código Swift para encontrar patrones legacy y proponer modernización con APIs de iOS 26+.

## PASO 1: DETERMINAR ALCANCE

Si hay argumento ($ARGUMENTS):
- Si es archivo: escanear ese archivo
- Si es directorio: escanear todos los .swift del directorio

Si no hay argumento:
- Escanear archivos modificados (git diff)

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

### B. Concurrencia Legacy
| Legacy | Moderno |
|--------|---------|
| `DispatchQueue.main.async {` | `@MainActor` o `MainActor.run {` |
| `DispatchQueue.global().async {` | `Task { }` o `Task.detached { }` |
| Completion handlers | `async/await` |
| `DispatchGroup` | `TaskGroup` |

### C. @available Innecesarios
- Target es iOS 26+ → cualquier `@available(iOS XX, *)` donde XX <= 26 es innecesario
- Buscar: `@available\(iOS (1[0-9]|2[0-6]),`

### D. iOS 26 Liquid Glass
| Sin Liquid Glass | Con Liquid Glass |
|------------------|------------------|
| `.background(Material.thin)` | `.glassEffect()` |
| Custom toolbar separators | `ToolbarSpacer(.fixed, placement:)` |
| Manual translucent backgrounds | `.glassEffect()` |

### E. SwiftData Patterns
| Legacy | Moderno |
|--------|---------|
| `@Query` en vistas complejas | ViewModel con fetch manual |
| `try? context.save()` | `do { try context.save() } catch { ... }` |

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
