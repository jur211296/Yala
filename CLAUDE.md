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

## SwiftData (fuente de verdad)
El ModelContainer se configura en NetoApp.swift con estas entidades:
Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment

## Flujo de trabajo obligatorio (para ahorrar tokens y reducir retrabajo)
1) Plan corto antes de editar (qué cambias y por qué)
2) Implementar mínimo que compila
3) Ejecutar /verify-ios
4) Si aplica, ejecutar /test-ios
5) Commit pequeño con /commit-one

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

## System Files Structure
- CLAUDE.md: Operational memory (current context)
- .planning/PROJECT.md: Product definition and constraints
- .planning/ROADMAP.md: Phased delivery plan
- .planning/STATE.md: Living memory of progress and decisions
- .planning/DECISIONS.md: Architectural decisions record
- .planning/UI-PATTERNS.md: Design system rules and UI patterns (OBLIGATORIO para UI)
- .claude/commands/: Automation macros
- .claude/sessions/: Session logs (git-ignored)
