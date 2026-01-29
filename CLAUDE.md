# Yala (iOS)

## Decisiones Recientes (TTL: hasta cierre de fase)

Esta sección contiene decisiones de diseño tomadas en la fase actual del ROADMAP.
Al cerrar la fase, este contenido se archiva en DECISIONS.md.

[Aquí irán decisiones temporales con formato: [FECHA] Decisión breve]

## Producto
Yala es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack
- Swift, SwiftUI
- Persistencia: SwiftData
- Proyecto: .xcodeproj
- Scheme principal: Yala
- Unit tests: YalaTests
- UI tests: YalaUITests
- **Simulador estándar: iPhone 17 Pro** (SIEMPRE usar este para builds, tests y simulación)

## SwiftData (fuente de verdad)
El ModelContainer se configura en YalaApp.swift con estas entidades:
Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment

## Flujo de trabajo obligatorio (para ahorrar tokens y reducir retrabajo)
1) Plan corto antes de editar (qué cambias y por qué)
2) Implementar mínimo que compila
3) Ejecutar /verify-ios
4) Si aplica, ejecutar tests (ver estrategia abajo)
5) Commit pequeño con /commit-one
6) **Actualizar QA-SCENARIOS.md** con escenarios de prueba para la funcionalidad nueva

**Regla QA-SCENARIOS:** Cada funcionalidad nueva DEBE tener sus escenarios de prueba documentados en `.planning/QA-SCENARIOS.md` ANTES del commit. Esto asegura que las validaciones manuales estén siempre listas.

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

## Patrones de Código Obligatorios

### Manejo de Errores (NUNCA silenciar errores)
```swift
// ❌ MAL - Error silenciado, pérdida de datos sin diagnóstico
try? context.save()
guard let items = try? context.fetch(descriptor) else { return }

// ✅ BIEN - Error visible y diagnosticable
do {
    try context.save()
} catch {
    print("ServiceName: Error saving: \(error)")
}

let items: [Model]
do {
    items = try context.fetch(descriptor)
} catch {
    print("ServiceName: Error fetching: \(error)")
    return
}
```

### Force Unwraps (NUNCA usar `!` sin validación previa)
```swift
// ❌ MAL - Crash en producción
let firstChar = text.first!
let index = array.lastIndex(of: item)!

// ✅ BIEN - Manejo seguro
guard let firstChar = text.first else { return }
guard let index = array.lastIndex(of: item) else { return }
```

### Seguridad de API Keys
- NUNCA hardcodear API keys en código fuente
- SIEMPRE usar `Secrets.xcconfig` (ignorado por git)
- SIEMPRE leer keys desde `Info.plist` via `Bundle.main.object(forInfoDictionaryKey:)`
- SIEMPRE validar que la key existe antes de usarla
- Si falta key, lanzar error descriptivo (no fallback silencioso)

### Logs en Producción
```swift
// ❌ MAL - Log siempre visible
print("User data: \(sensitiveData)")

// ✅ BIEN - Solo en debug
#if DEBUG
print("Debug info: \(nonSensitiveData)")
#endif
```

### SwiftData Relaciones
- SIEMPRE definir `@Relationship(inverse:)` en relaciones bidireccionales
- Verificar cascadas de eliminación (`deleteRule`)
- Usar `@MainActor` en servicios que manipulan `ModelContext`

## Control de Ejecución de Comandos

**CRÍTICO:** Consultar EXECUTION-RULES.md para saber qué comandos requieren instrucción explícita del usuario vs cuáles pueden ejecutarse automáticamente.

**Patrón fundamental después de implementar código:**
1. Mostrar resumen de cambios realizados
2. Sugerir el siguiente paso (típicamente /verify-ios)
3. DETENERSE y esperar instrucción del usuario
4. NO ejecutar verificaciones o commits automáticamente

**Optimización de comandos Git:**
- Ejecutar cada comando git de lectura (status, diff, log) UNA SOLA VEZ
- Guardar el output en variable
- Reutilizar ese output para todo el análisis posterior
- NUNCA ejecutar el mismo comando git múltiples veces
- NUNCA ejecutar comandos git en paralelo
- SIEMPRE ejecutar comandos git de forma secuencial

**Prevención de corrupción de git index:**
- Un solo comando git a la vez
- Esperar que termine completamente antes del siguiente
- No crear shells en background para operaciones git
- No matar shells que están ejecutando comandos git

## Design System (OBLIGATORIO para cambios UI)
**Antes de modificar cualquier vista, LEER:** `.planning/UI-PATTERNS.md`

Reglas críticas:
- SIEMPRE usar tokens de `DS.Spacing`, `DS.Radius`, `DS.Typography` - NUNCA valores hardcodeados
- SIEMPRE hacer filas completas clicables con `Button` + `contentShape(Rectangle())`
- SIEMPRE usar colores semánticos (`Color.yalaCard`, `Color.electricIndigo`, etc.)
- SIEMPRE usar componentes estándar: `YalaPrimaryButton`, `YalaEmptyState`, `YalaSectionHeader`, etc.

**Mantenimiento de UI-PATTERNS.md:**
- Cuando el usuario mencione una regla o patrón UI importante, PROPONER agregarlo a UI-PATTERNS.md
- Preguntar: "¿Quieres que agregue esta regla a UI-PATTERNS.md para que siempre se respete?"
- Si el usuario confirma, actualizar el archivo en la sección correspondiente

## Brand Voice (OBLIGATORIO para textos)
**Antes de escribir cualquier texto visible al usuario, LEER:** `.planning/BRAND-VOICE.md`

Reglas críticas:
- SIEMPRE usar tono cercano y conversacional ("tú"), como un amigo experto
- SIEMPRE usar español neutro (evitar regionalismos muy locales)
- NUNCA usar tono negativo o regañar - proponer soluciones y celebrar logros
- SIEMPRE preferir términos simples: "gasto" no "transacción", "dinero" no "plata"
- Emojis moderados (1-2 máx) solo cuando aporten significado positivo

**Mantenimiento de BRAND-VOICE.md:**
- Cuando el usuario defina nuevo copy o ajuste el tono, PROPONER actualizarlo
- Mantener el glosario de términos sincronizado con la UI

## System Files Structure
- CLAUDE.md: Operational memory (current context)
- .planning/PROJECT.md: Product definition and constraints
- .planning/ROADMAP.md: Phased delivery plan
- .planning/STATE.md: Living memory of progress and decisions
- .planning/DECISIONS.md: Architectural decisions record
- .planning/UI-PATTERNS.md: Design system rules and UI patterns (OBLIGATORIO para UI)
- .planning/BRAND-VOICE.md: Tono, estilo y mensajes de marca (OBLIGATORIO para textos)
- .planning/MARKETING.md: Estrategia de marketing y posicionamiento
- .claude/commands/: Automation macros
- .claude/sessions/: Session logs (git-ignored)
