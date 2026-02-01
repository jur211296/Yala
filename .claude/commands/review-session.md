---
description: Revisa todo el código modificado en la sesión actual
allowed-tools: Bash, Read, Grep, Glob, Task
---

Invoca al agente swift-reviewer para revisar TODOS los archivos .swift modificados en la sesión actual.

## EJECUCIÓN

### PASO 1: Identificar archivos modificados

Obtener todos los .swift modificados desde el último commit antes de la sesión:

```bash
# Opción A: Desde el log de sesión (si existe)
SESSION_FILE=$(cat /tmp/current-session 2>/dev/null)

# Opción B: Archivos modificados (staged + unstaged)
git diff --name-only HEAD | grep '\.swift$'

# Opción C: Si ya hay commits de la sesión, desde el inicio
git diff --name-only $(git log --since="today 00:00" --format=%H | tail -1)^..HEAD | grep '\.swift$'
```

También revisar el log de edits si existe:
```bash
cat .claude/sessions/edits.log 2>/dev/null | grep '\.swift' | awk '{print $NF}' | sort -u
```

### PASO 2: Filtrar archivos relevantes

Excluir:
- Archivos generados
- Archivos de terceros/Pods
- Archivos de test (a menos que se pida explícitamente)

Incluir:
- Yala/**/*.swift (código principal)
- YalaTests/**/*.swift (solo si el usuario lo pide)

### PASO 3: Mostrar alcance

```
## Revisión de sesión

Archivos Swift modificados: [N]

1. Yala/Services/TransactionService.swift
2. Yala/ViewModels/HomeViewModel.swift
3. Yala/Views/TransactionList.swift

¿Reviso todos? (sí / solo [números] / cancelar)
```

### PASO 4: Invocar swift-reviewer

Para cada archivo (o en paralelo si son pocos):

Usar el Task tool con el agente swift-reviewer:
```
Usa el agente swift-reviewer para revisar [archivo].
Enfócate en:
1. try? sin manejo de error
2. Force unwraps (!)
3. Prints sin #if DEBUG
4. Convenciones de Design System
5. Patrones de SwiftData
```

### PASO 5: Consolidar reporte

```
╔═══════════════════════════════════════════════════════════════╗
║              REVISIÓN DE SESIÓN COMPLETADA                    ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ARCHIVOS REVISADOS: [N]                                      ║
║                                                               ║
║  RESUMEN:                                                     ║
║  ✓ [M] archivos sin problemas                                 ║
║  ⚠️  [P] archivos con advertencias                             ║
║  ✗ [Q] archivos con problemas críticos                        ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  PROBLEMAS CRÍTICOS (corregir antes de commit)                ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  TransactionService.swift:45                                  ║
║  → try? sin manejo de error                                   ║
║                                                               ║
║  HomeViewModel.swift:89                                       ║
║  → Force unwrap en optional                                   ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  ADVERTENCIAS (corregir pronto)                               ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  TransactionList.swift:120                                    ║
║  → Print sin #if DEBUG                                        ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  VEREDICTO: [LISTO | NECESITA CORRECCIONES]                   ║
╚═══════════════════════════════════════════════════════════════╝

¿Quieres que corrija los problemas críticos automáticamente? (sí/no)
```

### PASO 6: Corrección automática (si el usuario acepta)

Para cada problema crítico:
1. Leer el archivo
2. Aplicar el fix sugerido
3. Mostrar el cambio

## VARIANTES

### Solo archivos específicos
```
/review-session Services/
```
Revisa solo archivos en ese directorio.

### Incluir tests
```
/review-session --with-tests
```
Incluye YalaTests/ en la revisión.

## INTEGRACIÓN CON FLUJO

Usar antes de `/session-end`:
```
[trabajo completado] → /review-session → [corregir si hay issues] → /session-end
```

O integrarlo en `/pre-deploy-check` para revisión completa.
