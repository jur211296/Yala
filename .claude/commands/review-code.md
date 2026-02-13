---
description: Invoca al agente swift-reviewer para revisar código
argument-hint: "[archivo.swift o directorio]"
---

Invoca al agente swift-reviewer para una revisión de código siguiendo las convenciones de Yala.

## USO

```
/review-code Yala/Services/TransactionService.swift
/review-code Yala/ViewModels/
/review-code  # Revisa archivos modificados (git diff)
```

## EJECUCIÓN

### PASO 1: Determinar qué revisar

Si hay argumento ($ARGUMENTS):
- Si es archivo: revisar ese archivo
- Si es directorio: revisar todos los .swift del directorio

Si no hay argumento:
```bash
git diff --name-only HEAD | grep '.swift$'
```
Revisar archivos modificados.

### PASO 2: Invocar agente revisor

Usar el agente `swift-reviewer` con el Task tool:

```
Usa el agente swift-reviewer para revisar [archivos].
Verifica:
1. try? sin manejo de error
2. Force unwraps (!)
3. Prints sin #if DEBUG
4. Uso correcto de Design System
5. Convenciones de SwiftData
```

### PASO 3: Presentar revisión

Mostrar el reporte del revisor con:
- Problemas críticos (bloquean)
- Advertencias (corregir pronto)
- Sugerencias (opcionales)
- Veredicto final

## EJEMPLO DE OUTPUT

```
## Revisión: TransactionService.swift

### Problemas críticos
1. **Línea 45** - `try?` sin manejo
   → Cambiar a do-catch con log de error

2. **Línea 89** - Force unwrap
   → Usar guard let

### Advertencias
1. **Línea 120** - Print sin #if DEBUG

### Veredicto: APROBAR CON CAMBIOS
Corregir los 2 problemas críticos antes de merge.
```

## INTEGRACIÓN CON FLUJO

Usar después de implementar y antes de commit:
```
[Implementar] → /review-code → [Corregir] → /verify-ios → /commit-one
```
