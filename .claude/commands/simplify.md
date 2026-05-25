---
description: Simplifica y refina código recién modificado — duplicación, abstracciones, comments narrando tarea
allowed-tools: Bash(git:*), Grep, Glob, Read, Edit, Agent
---

Revisión de refinamiento sobre código recientemente modificado. Preserva funcionalidad al 100% — solo mejora claridad, consistencia y mantenibilidad.

Basado en el agente oficial `code-simplifier` de Anthropic (`/Users/jur/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-simplifier/agents/code-simplifier.md`), adaptado a las convenciones de Yala (CLAUDE.md, SWIFT-STYLE.md, UI-PATTERNS.md).

## PASO 1: IDENTIFICAR SCOPE

Obtener archivos modificados en staging + unstaged + untracked:

```bash
FILES=$(comm -23 \
  <(sort -u <(git diff --name-only HEAD 2>/dev/null; git diff --name-only 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)) \
  <(echo ""))
SWIFT_FILES=$(echo "$FILES" | grep '\.swift$' | sort -u)
```

Si no hay archivos .swift modificados: "No hay archivos para simplificar."

Mostrar resumen:
```
## Simplify — [N] archivos
[lista de archivos]
```

## PASO 2: ANÁLISIS EN PARALELO

Lanzar 3 agentes Agent en paralelo (sub-agent type general-purpose), uno por foco. Cada agente recibe la lista de SWIFT_FILES y solo lee esos archivos.

### Agente 1 — Duplicación y reusabilidad

Buscar en los archivos modificados:
- **Código repetido** (≥3 líneas similares en 2+ sitios) que podría extraerse a helper privado o computed
- **Helpers candidatos a compartir** — funciones declaradas privadas que también existen casi idénticas en otro archivo del proyecto (grep cross-file)
- **ViewModifiers extraíbles** — closures `.onScrollGeometryChange`, `.task`, `.onChange` con lógica idéntica en 2+ vistas
- **Patrones SwiftUI duplicados** — HStack/VStack con misma estructura visual en varios archivos
- **Pure-logic dentro de Views** — closures con cálculo que debería vivir en ViewModel/Logic helper

Para cada hallazgo reportar: archivo:línea, descripción breve, propuesta concreta de refactor (qué helper/modifier crear, dónde colocarlo).

NO reportar:
- Repeticiones <3 líneas (no vale la abstracción)
- Patrones boilerplate de SwiftUI necesarios (estructuras de Form, NavigationStack)
- Cosas en `#Preview` blocks

### Agente 2 — Abstracciones innecesarias y stringly-typed

Buscar en los archivos modificados:
- **Hardcoded strings** que ya tienen constante: `"defaultCurrencyCode"` → `AppPreferences.Keys.defaultCurrencyCode`, `"onboardingMode"` → `OnboardingMode.userDefaultsKey`, claves UserDefaults en raw String
- **Computeds que deberían ser @State cacheados** — computed que hace work caro y se reevalúa cada render
- **Defense en profundidad innecesaria** — guards/validaciones que ya están cubiertas upstream
- **Wrappers de 1 línea** que no aportan vs llamada directa
- **Enum cases stringly-typed** — switch sobre strings que debería ser enum
- **Try? que silencian errores reales** — preferir do/catch con log
- **Extension privadas con 1 callsite** — inline en lugar de extension

NO reportar:
- Defensa intencional documentada con comment WHY
- Wrappers que mejoran legibilidad real (ej. `Color.thPrimary` vs el cálculo)
- @MainActor que parece redundante (probablemente requerido por SwiftData)

### Agente 3 — Comments narrando tarea y claridad

Buscar en los archivos modificados:
- **Comments narrando el ticket/refactor** (regla CLAUDE.md: "Don't reference the current task, fix, or callers"): `// Sprint 2.1 fix`, `// post QA iter3`, `// tras review`, `// fix #16`, `// FU-02-cleanup`, `// added for the X flow`, `// removed Y`
- **Comments que describen WHAT y no WHY** — si el nombre del identificador ya lo dice
- **TODOs sin owner ni fecha** (deuda invisible) — si los hay, sugerir mover a Backlog
- **MARK headers vacíos** o de secciones con 0 contenido
- **Variables/funciones con nombres poco descriptivos** que dificultan lectura
- **Nested ternaries >2 niveles** — refactor a if/else o switch
- **Funciones que mezclan demasiadas responsabilidades** — split sugerido

NO reportar:
- Comments con `// A11Y-DT:`, `// A11Y-DM:`, `// DS-`: auditoría justificada, no tocar
- Comments explicando WHY hidden constraint, invariant, workaround
- Docstrings públicas (mantener)

## PASO 3: CONSOLIDAR Y APLICAR

Consolidar hallazgos de los 3 agentes en una tabla por archivo:

```
## Simplify — [N] archivos

### Resumen
| Foco | Hallazgos | Auto-aplicables |
|------|-----------|-----------------|
| Duplicación / extraíble | N | M |
| Abstracciones / strings | N | M |
| Comments y claridad | N | M |

### Issues por archivo
**path/to/File.swift**
- [línea] descripción — propuesta concreta
- ...

### Veredicto: LIMPIO | N MEJORAS PROPUESTAS
```

Para los hallazgos **auto-aplicables** (cambios mecánicos y de bajo riesgo: replace hardcoded string por constante existente, eliminar comment narrando tarea, eliminar MARK vacío), preguntar al usuario si aplicarlos automáticamente con Edit.

Para hallazgos de **decisión** (extraer helper, refactor, split de función), solo proponer — el usuario decide.

## REGLAS

- **Preservar funcionalidad SIEMPRE** — cero cambios de comportamiento.
- **Solo archivos modificados** en staging/unstaged/untracked. Nunca tocar archivos no modificados aunque tengan oportunidades de simplificación (out of scope).
- **Claridad > brevedad**: rechazar nested ternaries, one-liners densos, abstracciones sobre-ingenieradas.
- **No introducir abstracciones especulativas** ("por si más adelante…"). Solo si hay duplicación REAL >=2 sitios HOY.
- **Skipear con razón explícita** las oportunidades que crucen archivos fuera de scope: documentar el skip en el reporte ("X: shared con InsightsTabView — extracción en sprint dedicado, rompe atomicidad").
- **No declarar simplificación completa si build/tests no se ejecutan después** — sugerir `/verify-ios` + `/test-smart` post-edit.
- **A11Y/DS markers (`A11Y-DT`, `A11Y-DM`, `DS-`) son auditorías justificadas** — no tocar nunca.

## CASOS DE USO

```
/simplify           # Revisar todos los archivos modificados
```

Útil después de implementar un feature, antes de `/commit-one`. Patrón canónico del flujo Complejo en CLAUDE.md.
