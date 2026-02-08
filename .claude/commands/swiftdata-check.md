---
description: Valida modelos SwiftData contra errores comunes
allowed-tools: Grep, Glob, Read
---

Verificación específica de SwiftData para prevenir bugs de modelo y relaciones.

## PASO 1: ENCONTRAR MODELOS

Buscar todos los archivos con `@Model` en el proyecto:
```
Glob: Yala/**/*.swift
Grep: @Model
```

## PASO 2: CHECKS POR MODELO

Para cada clase @Model encontrada:

### A. Init explícito
- Verificar que tiene `init()` definido (no solo valores default)
- SwiftData requiere init explícito para funcionar correctamente

### B. Relaciones bidireccionales
- Buscar `@Relationship` en el modelo
- Verificar que CADA relación bidireccional tiene `inverse:` en al menos un lado
- Verificar que el tipo del inverse coincide

### C. Delete rules
- Verificar `deleteRule:` en cada @Relationship
- `.cascade` solo cuando el hijo no existe sin el padre
- `.nullify` cuando la relación es opcional
- `.deny` cuando no se debe eliminar si hay hijos

### D. Predicates seguros
- Buscar `#Predicate` que usen propiedades enum
- Los enums deben compararse como `.rawValue`, no directamente
- Buscar patrones: `$0.enumProp == .someCase` → debe ser `$0.enumProp == "someCase"`

### E. @MainActor en servicios
- Buscar servicios que usen `ModelContext` (Grep: `modelContext|ModelContext`)
- Verificar que la clase/struct tiene `@MainActor`

### F. Tipos soportados
- Verificar que las propiedades usan tipos soportados por SwiftData
- Arrays de @Model como relaciones (no propiedades simples)
- Transformable solo con Codable

## PASO 3: REPORTE

```
## SwiftData Check — [N] modelos

| Modelo | Init | Relaciones | DeleteRules | Predicates | MainActor |
|--------|------|------------|-------------|------------|-----------|
| Category | ✓ | ✓ | ✓ | ✓ | — |
| Account | ✓ | ⚠ falta inverse | ✓ | ✓ | — |
| ... | | | | | |

### Issues encontrados
[Lista de problemas específicos con archivo:línea]

### Veredicto: OK | N ISSUES
```

## REGLAS
- Solo verificar modelos SwiftData (@Model), no structs normales
- Relaciones unidireccionales sin inverse son válidas si son intencionales
- Servicios que solo leen (no escriben) ModelContext no requieren @MainActor estricto
