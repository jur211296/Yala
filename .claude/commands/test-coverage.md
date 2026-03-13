---
description: Analiza cobertura de tests e identifica gaps críticos sin testear
allowed-tools: Grep, Glob, Read, Agent
---

Analiza la cobertura de tests del proyecto e identifica los gaps más críticos.

## PASO 1: INVENTARIO DE TESTS

Contar tests en cada archivo de YalaTests/:
```
Grep: func test_ en cada archivo .swift de YalaTests/
```
Listar total por archivo.

## PASO 2: INVENTARIO DE CÓDIGO TESTEABLE

### ViewModels
Listar TODOS los ViewModels (Glob: `**/ViewModels/**/*.swift` + `**/*ViewModel.swift`).
Marcar cuáles tienen tests correspondientes en YalaTests/.

### Services
Listar TODOS los Services (Glob: `**/Services/**/*.swift`).
Marcar cuáles tienen tests correspondientes.

### Calculators/Logic
Listar archivos en Logic/ y Calculators/.
Marcar cuáles tienen tests.

## PASO 3: ANÁLISIS DE RIESGO

Clasificar cada componente sin tests por riesgo:

**Riesgo ALTO** (lógica financiera, datos de usuario):
- Cualquier ViewModel/Service que toque TransactionItem, Budget, Account
- Cálculos de montos, tipos de cambio, balances
- Filtros y agrupaciones de datos

**Riesgo MEDIO** (lógica de negocio no financiera):
- Notificaciones, pagos planificados
- Importación/exportación
- Feature gates

**Riesgo BAJO** (UI helpers, formateo):
- ViewModels de selector (cuenta, subcategoría, tag)
- Settings ViewModels
- Formateo y presentación

## PASO 4: REPORTE

```
## Test Coverage Report

### Resumen
- Total tests: [N] en [M] suites
- ViewModels: [tested]/[total] ([%])
- Services: [tested]/[total] ([%])
- Logic/Calculators: [tested]/[total] ([%])

### Gaps Críticos (Riesgo ALTO — sin tests)
| Componente | Archivo | Riesgo | Lógica testeable |
|------------|---------|--------|------------------|
| ... | ... | ... | ... |

### Gaps Medios
[Tabla similar]

### Gaps Bajos
[Lista simple]

### Top 5 — Mayor impacto si se agregan tests
1. [Componente] — [razón]
2. ...
```

## PASO 5 (OPCIONAL): GENERAR TESTS

Si el usuario lo pide, invocar el agente `test-generator` para los gaps críticos.

## NOTAS
- Framework: XCTest (NO Swift Testing)
- NUNCA usar ModelContainer in-memory (crash CloudKit)
- Crear objetos @Model SIN insertar en contexto
- Usar MockCurrencyConverter para tests con conversión de divisas
- Priorizar lógica que puede testearse sin ModelContext (pura)
