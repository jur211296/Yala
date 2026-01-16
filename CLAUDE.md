# Neto (iOS)

## Decisiones Recientes (TTL: hasta cierre de fase)

Esta sección contiene decisiones de diseño tomadas en la fase actual del ROADMAP.
Al cerrar la fase, este contenido se archiva en DECISIONS.md.

[Aquí irán decisiones temporales con formato: [FECHA] Decisión breve]

## Producto
Neto es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack
- Swift, SwiftUI
- Persistencia: SwiftData
- Proyecto: .xcodeproj
- Scheme principal: Neto
- Unit tests: NetoTests
- UI tests: NetoUITests
- **Simulador estándar: iPhone 17 Pro** (SIEMPRE usar este para builds, tests y simulación)

## SwiftData (fuente de verdad)
El ModelContainer se configura en NetoApp.swift con estas entidades:
Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment

## Flujo de trabajo obligatorio (para ahorrar tokens y reducir retrabajo)
1) Plan corto antes de editar (qué cambias y por qué)
2) Implementar mínimo que compila
3) Ejecutar /verify-ios
4) Si aplica, ejecutar tests (ver estrategia abajo)
5) Commit pequeño con /commit-one

## Estrategia de Testing
Usar el comando apropiado según el tipo de cambio:

| Tipo de cambio | Comando | Cuándo |
|----------------|---------|--------|
| Cambio puntual en modelo/servicio | `/test-smart` | Detecta y corre solo tests relevantes |
| Cambio en UI (Views) | No hay tests UI | Solo /verify-ios |
| Trabajo completo antes de commit | `/test-ios` | Corre todos los tests |
| Después de merge o refactor grande | `/test-ios` + `/uitest-ios` | Validación completa |

**Tests disponibles:**
- `FilterServiceTests` - Lógica de filtrado
- `CalculatorTests` - Cálculos financieros
- `TagTests` - Operaciones con tags
- `TrendProcessingTests` - Procesamiento de tendencias
- `TrendGroupingTests` - Agrupación de tendencias

## Reglas de cambio
- Evitar refactors grandes si no son necesarios para el feature actual
- No introducir dependencias nuevas sin justificación
- Mantener separación clara entre UI, lógica y capa SwiftData

## Design System (OBLIGATORIO para cambios UI)
**Antes de modificar cualquier vista, LEER:** `.planning/UI-PATTERNS.md`

Reglas críticas:
- SIEMPRE usar tokens de `DS.Spacing`, `DS.Radius`, `DS.Typography` - NUNCA valores hardcodeados
- SIEMPRE hacer filas completas clicables con `Button` + `contentShape(Rectangle())`
- SIEMPRE usar colores semánticos (`Color.netoCard`, `Color.electricIndigo`, etc.)
- SIEMPRE usar componentes estándar: `NetoPrimaryButton`, `NetoEmptyState`, `NetoSectionHeader`, etc.

**Mantenimiento de UI-PATTERNS.md:**
- Cuando el usuario mencione una regla o patrón UI importante, PROPONER agregarlo a UI-PATTERNS.md
- Preguntar: "¿Quieres que agregue esta regla a UI-PATTERNS.md para que siempre se respete?"
- Si el usuario confirma, actualizar el archivo en la sección correspondiente

## System Files Structure
- CLAUDE.md: Operational memory (current context)
- .planning/PROJECT.md: Product definition and constraints
- .planning/ROADMAP.md: Phased delivery plan
- .planning/STATE.md: Living memory of progress and decisions
- .planning/DECISIONS.md: Architectural decisions record
- .planning/UI-PATTERNS.md: Design system rules and UI patterns (OBLIGATORIO para UI)
- .claude/commands/: Automation macros
- .claude/sessions/: Session logs (git-ignored)
