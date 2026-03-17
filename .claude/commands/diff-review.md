---
description: Revisa calidad de código en un rango de commits o diff específico
allowed-tools: Bash(git:*), Grep, Glob, Read, Agent
argument-hint: "[HEAD~N o hash1..hash2 — default: HEAD~1]"
---

Revisa la calidad de código en un rango específico de commits.

## PASO 1: DETERMINAR RANGO

Si hay argumento ($ARGUMENTS):
- Si es `HEAD~N`: revisar últimos N commits
- Si es `hash1..hash2`: revisar ese rango
- Si es un solo hash: revisar ese commit específico

Si no hay argumento:
- Default: `HEAD~1` (último commit)

## PASO 2: OBTENER CAMBIOS

```bash
RANGE="$ARGUMENTS"  # o HEAD~1 si no hay argumento
FILES=$(git diff --name-only $RANGE -- '*.swift' | grep -v Tests/)
DIFF=$(git diff $RANGE -- '*.swift')
COMMITS=$(git log --oneline $RANGE)
```

Mostrar resumen:
```
## Diff Review: [rango]

Commits: [N]
Archivos Swift modificados: [N]
[lista de commits]
```

## PASO 3: ANÁLISIS POR CATEGORÍA

Lanzar 3 análisis en paralelo (usar Agent tool):

### Agente 1 — Calidad de código
Revisar el diff completo buscando:
- try? sin manejo de error (nuevos, no preexistentes)
- Force unwraps nuevos sin guard previo
- Prints fuera de #if DEBUG
- Lógica duplicada entre archivos
- Funciones nuevas >50 líneas
- Magic numbers sin constante

### Agente 2 — Patrones y consistencia
Revisar el diff buscando:
- Uso correcto de DS tokens (spacing, typography, colores)
- APIs deprecated usadas (foregroundColor, cornerRadius, NavigationView)
- @MainActor faltante en clases con ModelContext
- Strings sin L10n (Text con literal)
- Convención de nombres consistente

### Agente 3 — Tests y cobertura
Revisar:
- ¿Se añadieron funciones públicas/internal nuevas?
- ¿Hay tests correspondientes en el rango?
- Si es fix: ¿hay test de regresión?
- Si es feat: ¿hay cobertura básica?

## PASO 4: CONSOLIDAR

```
## Diff Review — [rango]

Commits: [N] | Archivos: [N] | Líneas: +[N] -[N]

### Calidad
| Check | Estado | Count |
|-------|--------|-------|
| Errores silenciados | ✓/✗ | N |
| Force unwraps | ✓/✗ | N |
| Prints producción | ✓/✗ | N |
| Funciones >50 líneas | ✓/✗ | N |
| Código duplicado | ✓/✗ | N |

### Patrones
| Check | Estado | Count |
|-------|--------|-------|
| DS tokens | ✓/✗ | N |
| APIs deprecated | ✓/✗ | N |
| Strings sin L10n | ✓/✗ | N |
| @MainActor | ✓/✗ | N |

### Cobertura
| Check | Estado |
|-------|--------|
| Funciones nuevas con test | [N]/[M] |
| Tests de regresión (fix:) | ✓/✗ |
| Tests nuevos en el rango | [N] |

### Issues (archivo:línea — descripción)
[Lista priorizada]

### Veredicto: LIMPIO | N ISSUES
```

## CASOS DE USO

```
/diff-review HEAD~5          # Revisar últimos 5 commits
/diff-review abc123..HEAD    # Desde un commit específico
/diff-review 1.0.1..HEAD     # Todo desde el último tag
/diff-review                  # Solo último commit
```

## REGLAS
- Solo reportar issues NUEVOS introducidos en el rango (no preexistentes)
- Usar el diff, no el archivo completo — foco en lo que CAMBIÓ
- Lanzar los 3 agentes en paralelo para velocidad
- Si el rango es >50 archivos, agrupar por directorio
