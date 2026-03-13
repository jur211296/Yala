---
description: Auditoría de accesibilidad — VoiceOver, Dynamic Type, contraste, touch targets
allowed-tools: Grep, Glob, Read, Agent
argument-hint: "[archivo o directorio — default: toda la app]"
---

Auditoría completa de accesibilidad iOS para cumplimiento con Apple HIG y App Store requirements.

## ALCANCE

Si hay argumento ($ARGUMENTS): escanear ese archivo/directorio.
Si no: escanear todo `Yala/App/Views/`.

## PASO 1: VOICEOVER — Labels y Hints

### A. Elementos interactivos sin label
Buscar vistas con `Button`, `Toggle`, `Slider`, `Stepper`, `Link`, `NavigationLink` que NO tengan `.accessibilityLabel` cerca (dentro de 5 líneas).

**Prioridad ALTA:** Botones con solo icono (Image(systemName:) dentro de Button sin Text)
```
Grep: Button.*Image\(systemName
Verificar: .accessibilityLabel presente
```

### B. Imágenes informativas sin descripción
Buscar `Image(` que NO sea decorativo y NO tenga `.accessibilityLabel` ni `.accessibilityHidden(true)`.
- Iconos en listas → necesitan label
- Iconos decorativos → necesitan `.accessibilityHidden(true)`

### C. Elementos disabled sin contexto
Buscar `.disabled(` sin `.accessibilityHint` que explique por qué está deshabilitado.

### D. Agrupaciones faltantes
Buscar HStack/VStack con múltiples Text/Image que deberían leerse como una unidad:
```
.accessibilityElement(children: .combine)
```

## PASO 2: DYNAMIC TYPE

### A. Fonts hardcodeados
Buscar `.font(.system(size:` → NO escalan con Dynamic Type.
Deberían usar:
- DS.Typography tokens (ya definidos en DesignTokens.swift)
- `.font(.body)`, `.font(.headline)`, etc. (escalan automáticamente)
- `@ScaledMetric` para espaciados custom

### B. Frames fijos con texto
Buscar `.frame(height:` o `.frame(width:` cerca de Text → puede truncar con Dynamic Type grande.

### C. Imágenes que deberían escalar
Buscar Image() con `.frame(width:` fijo → considerar `@ScaledMetric` para el tamaño.

## PASO 3: TOUCH TARGETS

Buscar `.frame(width:` o `.frame(height:` con valores < 44 en contexto de Button/interactivo.
Mínimo Apple: 44x44 puntos para todos los elementos interactivos.

## PASO 4: CONTRASTE Y COLOR

### A. Color como único indicador
Buscar patrones donde el color es la ÚNICA forma de comunicar estado:
- `.foregroundStyle(.red)` / `.foregroundStyle(.green)` sin icono o texto complementario
- Gráficas sin labels textuales

### B. Respeto a Reduce Motion
Buscar `.animation(` y `withAnimation(` → verificar que haya guard para:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
```

## PASO 5: SEMANTIC TRAITS

Buscar headers/títulos sin `.accessibilityAddTraits(.isHeader)`:
- `YalaSectionHeader`, títulos de secciones, Text con .font(.headline)

## REPORTE

```
## A11y Audit — [N] archivos

### VoiceOver
| Check | Estado | Count |
|-------|--------|-------|
| Botones icon-only sin label | ✓/✗ | N |
| Imágenes sin descripción | ✓/✗ | N |
| Disabled sin hint | ✓/✗ | N |
| Agrupaciones faltantes | ✓/✗ | N |

### Dynamic Type
| Check | Estado | Count |
|-------|--------|-------|
| Fonts hardcodeados (.system(size:)) | ✓/✗ | N |
| Frames fijos con texto | ✓/✗ | N |

### Touch Targets
| Check | Estado | Count |
|-------|--------|-------|
| Targets < 44pt | ✓/✗ | N |

### Color y Motion
| Check | Estado | Count |
|-------|--------|-------|
| Color como único indicador | ✓/✗ | N |
| Animaciones sin reduceMotion | ✓/✗ | N |

### Prioridad de corrección
1. **Crítico**: Botones icon-only sin label (bloquea VoiceOver)
2. **Alto**: Fonts hardcodeados (Dynamic Type no funciona)
3. **Medio**: Touch targets pequeños
4. **Bajo**: Agrupaciones, hints, traits
```

## NOTAS
- Apple puede rechazar apps sin soporte básico de VoiceOver
- Dynamic Type es esperado en 2026 para todas las apps
- Foco en elementos INTERACTIVOS primero, decorativos después
- SF Symbols tienen labels automáticos — verificar si son apropiados
