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

Usar el agente `test-generator`:

```
Genera tests para [archivo/clase].
1. Analizar funciones públicas e internal
2. Generar tests siguiendo patrones de YalaTests (XCTest)
3. Cubrir: happy path + edge cases (nil, vacío, límites)
4. Si ya existe suite de tests, AGREGAR al archivo existente
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

## RESTRICCIONES CRÍTICAS (CloudKit)
- NUNCA usar makeTestContext() ni ModelContainer in-memory (crash)
- Crear objetos @Model SIN insertar en contexto
- Usar MockCurrencyConverter para tests con conversión de divisas
- Framework: XCTest (Given/When/Then, naming: test_método_escenario_resultado)

## INTEGRACIÓN CON FLUJO

```
[Implementar] → /generate-tests → /test-smart → /commit-one
```
