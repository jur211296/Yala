---
description: Auditoría completa de calidad Swift en archivos modificados
allowed-tools: Bash(git:*), Grep, Glob, Read
---

Auditoría unificada de calidad Swift. Combina checks de seguridad, patrones y convenciones en un solo pase.

## PASO 1: IDENTIFICAR ARCHIVOS

```bash
git diff --name-only HEAD~1 2>/dev/null | grep '\.swift$'
```

Si no hay diff, usar archivos del último commit. Guardar lista.

## PASO 2: CHECKS AUTOMÁTICOS

Ejecutar TODOS los checks en paralelo usando Grep sobre los archivos identificados:

### A. Errores silenciados
- Buscar `try\?` → debe ser do-catch con log
- Excepción: `try?` en contextos triviales documentados

### B. Force unwraps
- Buscar `\!` (excluyendo `!=`, `//`, `///`, strings)
- Cada `!` sin guard/if previo es crítico

### C. Prints en producción
- Buscar `print\(` fuera de `#if DEBUG`
- Verificar contexto (5 líneas arriba) para `#if DEBUG`

### D. Valores hardcodeados (anti-DS)
- Buscar `.padding(\d` o `padding(` con números literales → usar DS.Spacing
- Buscar `.cornerRadius(` → usar DS.Radius o .clipShape
- Buscar `.font(.system(size:` → usar DS.Typography
- Buscar `Color(` con hex o RGB → usar colores semánticos

### E. APIs deprecated
- Buscar `foregroundColor(` → usar foregroundStyle
- Buscar `.cornerRadius(` → usar .clipShape(RoundedRectangle)
- Buscar `NavigationView` → usar NavigationStack
- Buscar `@available` innecesarios (target iOS 26+)

### F. Concurrencia
- Buscar `DispatchQueue.main.async` → preferir @MainActor
- Verificar que clases con ModelContext tengan @MainActor

### G. Strings sin localizar
- Buscar `Text("` con texto literal (no variable, no L10n)
- Excluir SF Symbols, formatos, y textos de debug

### H. TODOs pendientes
- Buscar `TODO|FIXME|HACK|XXX`

### I. Credenciales
- Buscar patrones de API keys, passwords, tokens hardcodeados

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
| TODOs pendientes | ✓/✗ | N |
| Credenciales | ✓/✗ | N |

### Issues (archivo:línea — descripción)
[Lista priorizada: críticos primero, luego warnings]

### Veredicto: LIMPIO | N ISSUES
```

## REGLAS
- NO reportar falsos positivos
- `try?` justificado (ej: optional binding en UI) es OK
- `!` después de guard que valida es OK
- Prints dentro de `#if DEBUG` son OK
- Texto en `.accessibilityLabel` puede ser literal
- Solo reportar problemas REALES en archivos MODIFICADOS
