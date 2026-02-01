---
description: Invoca al agente test-generator para crear tests
argument-hint: "[archivo.swift o clase]"
---

Invoca al agente test-generator para generar tests unitarios.

## USO

```
/generate-tests Yala/Services/FilterService.swift
/generate-tests TransactionViewModel
/generate-tests  # Genera para archivos modificados sin tests
```

## EJECUCIÓN

### PASO 1: Determinar qué testear

Si hay argumento ($ARGUMENTS):
- Si es archivo: generar tests para ese archivo
- Si es nombre de clase: buscar el archivo y generar tests

Si no hay argumento:
- Buscar archivos .swift modificados
- Filtrar los que no tienen tests correspondientes
- Sugerir cuáles testear

### PASO 2: Invocar agente generador

Usar el agente `test-generator` con el Task tool:

```
Usa el agente test-generator para:
1. Analizar [archivo/clase]
2. Identificar funciones públicas a testear
3. Generar tests siguiendo patrones de YalaTests
4. Cubrir casos edge (nil, vacío, límites)
```

### PASO 3: Presentar tests generados

Mostrar:
- Código de tests generado
- Lista de casos cubiertos
- Casos NO cubiertos y por qué

### PASO 4: Preguntar ubicación

```
Tests generados para [Clase].

¿Dónde los guardo?
1. YalaTests/[Clase]Tests.swift (nuevo archivo)
2. Agregar a YalaTests/[ArchivoExistente]Tests.swift
3. Mostrar aquí sin guardar
```

## EJEMPLO DE OUTPUT

```swift
// Tests generados para: FilterService
// Cobertura estimada: 85%

import XCTest
@testable import Yala

final class FilterServiceTests: XCTestCase {

    private var sut: FilterService!

    override func setUp() {
        super.setUp()
        sut = FilterService()
    }

    func test_filter_withEmptyArray_returnsEmptyArray() {
        // Given
        let items: [TransactionItem] = []

        // When
        let result = sut.filter(items, by: .all)

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    // ... más tests ...
}

/*
Casos cubiertos:
1. Array vacío
2. Filtro por categoría
3. Filtro por fecha
4. Filtro combinado

Casos NO cubiertos:
- Concurrencia (requiere contexto adicional)
*/
```

## INTEGRACIÓN CON FLUJO

Usar cuando implementas nueva funcionalidad:
```
[Implementar] → /generate-tests → /test-smart → /commit-one
```
