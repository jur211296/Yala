---
description: Analiza el impacto de un cambio propuesto usando subagentes en paralelo
argument-hint: "[archivo o componente a modificar]"
allowed-tools: Task, Grep, Glob, Read
---

Antes de modificar código, analiza el impacto completo usando subagentes especializados.

## USO
```
/analyze-impact [archivo o componente]
```

Ejemplos:
- `/analyze-impact TransactionItem.swift`
- `/analyze-impact FilterService`
- `/analyze-impact Category model`

## EJECUCIÓN

### PASO 1: Identificar el target
- Parsear $ARGUMENTS para identificar archivo(s) o componente(s)
- Si es ambiguo, buscar primero para clarificar

### PASO 2: Lanzar análisis en paralelo

Usar el Task tool para lanzar 4 subagentes SIMULTÁNEAMENTE:

**Subagente 1 - Dependencias directas:**
```
Para el componente "$ARGUMENTS":
1. Identificar todas las clases/structs/protocols definidos
2. Buscar imports y referencias a este componente en todo el proyecto
3. Mapear: ¿Quién usa este componente directamente?

Reportar lista de archivos que dependen de esto.
```

**Subagente 2 - Dependencias inversas:**
```
Para el componente "$ARGUMENTS":
1. Leer el archivo/componente
2. Identificar qué otros componentes ESTE usa (imports, tipos)
3. Mapear: ¿De qué depende este componente?

Reportar lista de dependencias.
```

**Subagente 3 - Tests afectados:**
```
Para el componente "$ARGUMENTS":
1. Buscar tests que importan o mencionan este componente
2. Identificar mocks o stubs relacionados
3. Evaluar cobertura de tests

Reportar:
- Tests que deberían pasar/fallar si cambias esto
- Cobertura estimada
```

**Subagente 4 - UI/Views afectadas:**
```
Para el componente "$ARGUMENTS":
1. Buscar Views que usan este componente
2. Identificar flujos de navegación afectados
3. Buscar en ViewModels relacionados

Reportar:
- Pantallas que podrían verse afectadas
- Flujos de usuario impactados
```

### PASO 3: Consolidar y presentar

```
╔════════════════════════════════════════════════════════════╗
║  ANÁLISIS DE IMPACTO: $ARGUMENTS                           ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  QUIÉN USA ESTO (dependencias directas)                    ║
║  ──────────────────────────────────────                    ║
║  [N] archivos dependen de este componente:                 ║
║  - Services/OtroService.swift (usa método X)               ║
║  - ViewModels/AlgoVM.swift (usa propiedad Y)               ║
║                                                            ║
║  DE QUÉ DEPENDE ESTO                                       ║
║  ───────────────────                                       ║
║  Este componente depende de [M] otros:                     ║
║  - Foundation                                              ║
║  - SwiftData                                               ║
║  - Models/Category.swift                                   ║
║                                                            ║
║  TESTS EN RIESGO                                           ║
║  ───────────────                                           ║
║  [P] tests podrían verse afectados:                        ║
║  - ComponentTests.swift (tests directos)                   ║
║  - IntegrationTests.swift (tests indirectos)               ║
║  Cobertura actual: [Alta/Media/Baja/Sin tests]             ║
║                                                            ║
║  UI AFECTADA                                               ║
║  ──────────                                                ║
║  [Q] pantallas podrían cambiar:                            ║
║  - TransactionListView.swift                               ║
║  - DetailView.swift                                        ║
║                                                            ║
╠════════════════════════════════════════════════════════════╣
║  RESUMEN DE RIESGO                                         ║
║  ─────────────────                                         ║
║  Nivel: [BAJO | MEDIO | ALTO]                              ║
║                                                            ║
║  - Cambio afecta [N] archivos directamente                 ║
║  - [P] tests deberían validar el cambio                    ║
║  - [Q] pantallas requieren validación manual               ║
║                                                            ║
║  RECOMENDACIÓN:                                            ║
║  [Proceder con precaución / Requiere tests adicionales /   ║
║   Cambio seguro si tests pasan]                            ║
╚════════════════════════════════════════════════════════════╝
```

### PASO 4: Sugerir siguiente paso

Basado en el análisis:
- Si riesgo BAJO: "Puedes proceder. Los tests existentes deberían cubrir."
- Si riesgo MEDIO: "Sugiero ejecutar /test-smart después del cambio."
- Si riesgo ALTO: "Considera dividir el cambio o agregar tests primero."

## REGLAS
- SIEMPRE lanzar los 4 subagentes en paralelo
- Usar subagent_type: "Explore" para los subagentes
- No leer archivos completos en el contexto principal, delegar a subagentes
- El análisis debe completarse en <30 segundos
- Si el componente no existe, informar y abortar
