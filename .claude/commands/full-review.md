---
description: Revisión profunda completa del proyecto — build, tests, calidad, performance, l10n, a11y, DS, Apple compliance
allowed-tools: Bash(xcodebuild:*), Bash(git:*), Bash(grep:*), Bash(wc:*), Bash(diff:*), Bash(sort:*), Bash(comm:*), Bash(rm:*), Bash(touch:*), Grep, Glob, Read, Agent
---

Revisión profunda del proyecto completo. Ejecuta todas las auditorías en orden óptimo y consolida en un solo reporte.

## FASE 1: FUNDAMENTOS (secuencial, bloquean lo demás)

### 1A. Build limpio
```bash
xcodebuild clean build -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(error:|warning:|BUILD)" | head -30
```
- Si hay errores: PARAR y reportar. No tiene sentido seguir.
- Capturar: errores (N), warnings (N)

### 1B. Tests completos
```bash
xcodebuild test -scheme Yala -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO 2>&1 | grep -E "(Test Case|Tests? (passed|failed)|error:)" | tail -30
```
- Capturar: passed (N), failed (N), errores
- Si hay tests fallidos: CONTINUAR con las auditorías pero marcar como BLOQUEANTE

## FASE 2: ANÁLISIS PROFUNDO (3 agentes en paralelo)

Lanzar 3 agentes Agent en paralelo:

### Agente 1 — Código y Performance
Ejecutar en secuencia dentro del agente:

**Deep Scan** (calidad de código):
- Escanear Yala/App/ completo dividido en Views/, ViewModels+Services/, Models+Logic+Utils/
- Checks: try? sin manejo, force unwraps, bounds checks, retain cycles, concurrencia, SwiftData, funciones >50 líneas, código duplicado, APIs deprecated

**Perf Check** (performance):
- Escanear TODO: Yala/App/ + Yala/Services/ + Yala/Utils/
- Checks: FetchDescriptor sin fetchLimit, body pesado, listas sin LazyVStack, computeds costosos, onChange sin debounce, animaciones costosas, closures sin [weak self]

**SwiftData Check**:
- Todos los @Model: init explícito, @Relationship inverse, deleteRule, predicates con enums, @MainActor en servicios

### Agente 2 — UI y Accesibilidad
Ejecutar en secuencia dentro del agente:

**A11y Audit**:
- Escanear Yala/App/Views/ completo
- Checks: botones icon-only sin label, imágenes sin descripción, disabled sin hint, fonts hardcodeados, frames fijos con texto, touch targets <44pt, color como único indicador, animaciones sin reduceMotion

**DS Compliance**:
- Escanear Yala/App/Views/ completo
- Checks: typography hardcodeada, padding/spacing hardcodeado, colores no semánticos, componentes estándar vs custom, APIs deprecated

**Swift Modernize**:
- Escanear TODO: Yala/App/ + Yala/Services/ + Yala/Utils/
- Checks: SwiftUI deprecated, concurrencia legacy, @available innecesarios, oportunidades Liquid Glass

### Agente 3 — Localización, Deuda y Limpieza
Ejecutar en secuencia dentro del agente:

**L10n Check**:
- Todos los .strings en 6 idiomas
- Checks: keys faltantes entre idiomas, strings vacíos, placeholders inconsistentes, strings sin L10n en código, longitud excesiva

**Dead Code**:
- Escanear todo Yala/ (excluir Tests/)
- Checks: imports sin usar, funciones nunca llamadas, tipos sin usar, protocolos sin conformances

**TODO Scan**:
- Escanear todo Yala/ + Tests/
- Checks: TODO/FIXME/HACK/WORKAROUND, clasificar por prioridad, detectar stale >3 meses

## FASE 3: APPLE COMPLIANCE (secuencial, después de los agentes)

Verificar manualmente (no necesita agente):

**Privacy Manifest**:
- Existe PrivacyInfo.xcprivacy y declara Required Reason APIs
- Consent alert para OpenAI (voz, imagen, texto)
- 0 API keys hardcodeadas
- 0 prints fuera de #if DEBUG

**Legal**:
- URLs separadas de Privacy Policy + Terms
- Texto de suscripción claro con precio y auto-renovación
- Link a restaurar compras

## FASE 4: REPORTE CONSOLIDADO

```
## Full Review — Yala v[VERSION]
Fecha: [YYYY-MM-DD]

### Dashboard
| Área | Estado | Críticos | Altos | Medios | Bajos |
|------|--------|----------|-------|--------|-------|
| Build | ✓/✗ | N | N | — | — |
| Tests | ✓/✗ (N/M passed) | N | — | — | — |
| Calidad código | ✓/✗ | N | N | N | N |
| Performance | ✓/✗ | N | N | N | — |
| SwiftData | ✓/✗ | N | N | — | — |
| Accesibilidad | ✓/✗ | N | N | N | N |
| Design System | [A-F] score | — | N | N | N |
| APIs modernas | ✓/✗ | — | N | N | N |
| Localización | ✓/✗ | N | N | N | — |
| Código muerto | [N] candidatos | — | — | N | N |
| Deuda técnica | [N] marcadores | N | N | N | N |
| Apple compliance | ✓/✗ | N | N | — | — |

### BLOQUEANTES para release (resolver obligatoriamente)
1. [issue — archivo:línea]
2. ...

### CRÍTICOS (resolver antes de release)
1. [issue — archivo:línea]
2. ...

### ALTOS (resolver pronto)
[Lista agrupada por área]

### MEDIOS (planificar)
[Count por área, sin detalle individual]

### BAJOS (backlog)
[Count total]

### Veredicto: LISTO PARA RELEASE | BLOQUEADO por [N] items
```

## REGLAS
- Build fallido = PARAR INMEDIATAMENTE (solo reportar errores de build)
- Tests fallidos = CONTINUAR pero marcar BLOQUEANTE
- Los 3 agentes de Fase 2 SIEMPRE en paralelo para velocidad
- Solo listar individualmente issues BLOQUEANTES y CRÍTICOS — el resto como counts
- El reporte debe caber en una pantalla (no más de 60 líneas)
- Este skill consume mucho contexto — ejecutar en sesión dedicada con `/clear` previo
- Tiempo estimado: 10-15 minutos (build + tests + 3 agentes paralelos)
