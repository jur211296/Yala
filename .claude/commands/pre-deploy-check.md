---
description: Checklist de calidad y seguridad antes de merge o deploy
allowed-tools: Bash(git:*), Grep, Glob, Read
---

Ejecuta una revisión sistemática de calidad antes de merge/deploy.

## PASO 1: IDENTIFICAR CAMBIOS

```bash
# Archivos modificados desde el último merge a main
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~10
```

Guardar lista de archivos .swift modificados para análisis.

## PASO 2: CHECKLIST AUTOMÁTICO

Para cada archivo .swift modificado, verificar:

### A. Manejo de errores
```
Buscar: try?
Problema: Error silenciado sin diagnóstico
```
- Grep por `try\?` en archivos modificados
- Cada `try?` debe tener justificación o ser reemplazado por do-catch

### B. Force unwraps
```
Buscar: !
Problema: Crash potencial en producción
```
- Grep por `\!` (excluyendo `!=` y comentarios)
- Cada `!` debe tener validación previa o usar guard/if let

### C. Prints en producción
```
Buscar: print( sin #if DEBUG
Problema: Logs visibles en producción
```
- Grep por `print\(`
- Verificar que estén dentro de `#if DEBUG`

### D. TODO/FIXME pendientes
```
Buscar: TODO, FIXME, HACK
Problema: Trabajo incompleto
```
- Grep por `TODO|FIXME|HACK` en archivos modificados
- Listar para decisión del usuario

### E. Credenciales hardcodeadas
```
Buscar: Patrones de API keys, passwords
Problema: Seguridad comprometida
```
- Grep por patrones sospechosos: `key.*=.*"`, `password`, `secret`, `token.*=`

## PASO 3: VERIFICACIONES DE PROYECTO

### F. QA-SCENARIOS.md actualizado
- Verificar si hay escenarios para la funcionalidad nueva
- Si no existen, listar como pendiente

### G. Tests relevantes pasan
```bash
# Solo verificar, no ejecutar (asumimos que ya corrieron)
echo "¿Tests ejecutados y pasando? (verificar con /test-smart o /test-ios)"
```

### H. Build limpio
```bash
# Verificar último estado del build
echo "¿Build verificado? (ejecutar /verify-ios si no)"
```

## PASO 4: REPORTE

```
╔════════════════════════════════════════════════════════════╗
║                    PRE-DEPLOY CHECK                        ║
╠════════════════════════════════════════════════════════════╣
║  Archivos analizados: [N]                                  ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  [✓/✗] Manejo de errores     [N try? encontrados]          ║
║  [✓/✗] Force unwraps         [N ! encontrados]             ║
║  [✓/✗] Prints producción     [N prints sin #if DEBUG]      ║
║  [✓/✗] TODOs pendientes      [N encontrados]               ║
║  [✓/✗] Credenciales          [N patrones sospechosos]      ║
║  [✓/✗] QA-SCENARIOS          [Actualizado/Pendiente]       ║
║                                                            ║
╠════════════════════════════════════════════════════════════╣
║  VEREDICTO: [LISTO PARA DEPLOY | BLOQUEADO]                ║
╚════════════════════════════════════════════════════════════╝

### Issues a resolver (si BLOQUEADO):
1. [Archivo:línea] - [Descripción del problema]
2. [Archivo:línea] - [Descripción del problema]

### Advertencias (no bloquean pero revisar):
- [Advertencia 1]
- [Advertencia 2]
```

## REGLAS
- Solo reportar problemas REALES, no falsos positivos
- `try?` en contextos donde el error es irrelevante es OK (documentar)
- `!` después de guard/if que garantiza valor es OK
- TODOs marcados como "v2" o "future" no bloquean
- Ser estricto con credenciales - siempre bloquea
