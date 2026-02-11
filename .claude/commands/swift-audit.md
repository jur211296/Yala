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
- Grep pattern: try\? — debe ser do-catch con log
- Excepción: try? en contextos triviales documentados

### B. Force unwraps
- Grep pattern: \w\! — ignorar operadores !=, comentarios y strings
- Force unwrap sin guard/if previo es crítico

### C. Prints en producción
- Grep pattern: print\(
- Verificar contexto (5 líneas arriba) buscando #if DEBUG

### D. Valores hardcodeados (anti-DS)
- Grep pattern: \.padding\(\d — usar DS.Spacing
- Grep pattern: \.cornerRadius\( — usar DS.Radius o .clipShape
- Grep pattern: \.font\(\.system\(size: — usar DS.Typography
- Grep pattern: Color\( con hex o RGB — usar colores semánticos

### E. APIs deprecated
- Grep pattern: foregroundColor\( — usar foregroundStyle
- Grep pattern: \.cornerRadius\( — usar .clipShape(RoundedRectangle)
- Grep pattern: NavigationView — usar NavigationStack
- Grep pattern: @available innecesarios (target iOS 26+)

### F. Concurrencia
- Grep pattern: DispatchQueue\.main\.async — preferir @MainActor
- Verificar que clases con ModelContext tengan @MainActor

### G. Strings sin localizar
- Grep pattern: Text\(" con texto literal (no variable, no L10n)
- Excluir SF Symbols, formatos, y textos de debug

### H. TODOs pendientes
- Grep pattern: TODO|FIXME|HACK|XXX

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
- try? justificado (ej: optional binding en UI) es OK
- Force unwrap después de guard que valida es OK
- Prints dentro de #if DEBUG son OK
- Texto en .accessibilityLabel puede ser literal
- Solo reportar problemas REALES en archivos MODIFICADOS
