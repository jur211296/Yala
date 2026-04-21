---
description: Encuentra código muerto — funciones, tipos, imports y protocolos sin usar
allowed-tools: Grep, Glob, Read, Agent
argument-hint: "[directorio — default: todo el proyecto]"
---

Detecta código muerto en el proyecto para limpieza pre-release.

## ALCANCE

Si hay argumento ($ARGUMENTS): escanear ese directorio.
Si no: escanear todo Yala/ (excluir Tests/).

## PASO 1: IMPORTS SIN USAR

Para cada archivo .swift en el alcance:
- Leer las líneas `import` del archivo
- Verificar si el módulo importado se usa en el archivo:
  - `import SwiftUI` → buscar usos de SwiftUI types (View, State, etc.)
  - `import SwiftData` → buscar @Model, ModelContext, FetchDescriptor, etc.
  - `import Charts` → buscar Chart, BarMark, etc.
  - `import WidgetKit` → buscar Widget, Timeline, etc.
  - `import StoreKit` → buscar Product, Transaction, etc.
- Imports estándar que SIEMPRE se usan: `Foundation`, `SwiftUI` en Views

## PASO 2: FUNCIONES NUNCA LLAMADAS

Lanzar 2 subagentes en paralelo:

### Agente 1 — Funciones public/internal en Services/ y Utils/
Para cada función `func nombreFuncion(` encontrada:
- Buscar `nombreFuncion(` en TODO el proyecto (excluyendo la propia definición)
- Si 0 usos → DEAD CODE candidato
- Excluir: funciones de protocolo (protocol conformance), @objc, override, init

### Agente 2 — Funciones public/internal en ViewModels/ y Logic/
Mismo proceso.

**IMPORTANTE:** No reportar como dead code:
- Funciones llamadas desde Views via `.onAppear`, `.task`, Button actions
- Funciones de protocolo (Hashable, Equatable, Codable, etc.)
- Funciones `@MainActor` que son entry points de ViewModels (loadData, etc.)

## PASO 3: TIPOS SIN USAR

Buscar `class `, `struct `, `enum ` declaraciones:
- Buscar el nombre del tipo en TODO el proyecto
- Si solo aparece en su propia declaración → DEAD CODE
- Excluir: @Model (SwiftData los usa por reflexión), tipos en App/

## PASO 4: PROTOCOLOS SIN CONFORMANCES

Buscar `protocol NombreProtocolo`:
- Buscar `: NombreProtocolo` en todo el proyecto
- Si 0 conformances → protocolo huérfano

## PASO 5: PROPIEDADES NUNCA LEÍDAS

Para propiedades `private` o `private(set)`:
- Si solo se escriben (en init o asignación) pero nunca se leen → candidata a eliminar
- Este check es SOLO para `private` — propiedades internal/public pueden usarse desde otros archivos

## REPORTE

```
## Dead Code — [N] archivos escaneados

### Resumen
| Tipo | Count |
|------|-------|
| Imports sin usar | N |
| Funciones sin llamar | N |
| Tipos sin usar | N |
| Protocolos sin conformances | N |
| Propiedades privadas sin leer | N |

### Imports sin usar
| Archivo | Import | Sugerencia |
|---------|--------|------------|
| View.swift | import Charts | Eliminar |

### Funciones sin llamar
| Archivo:Línea | Función | Visibilidad |
|---------------|---------|-------------|
| Service.swift:45 | func oldMethod() | internal |

### Tipos sin usar
| Archivo | Tipo | Declaración |
|---------|------|-------------|
| Models/Old.swift | struct LegacyItem | struct |

### Protocolos huérfanos
| Archivo | Protocolo |
|---------|-----------|

### Veredicto: LIMPIO | [N] candidatos a eliminar
```

## REGLAS
- NUNCA reportar falsos positivos — si hay duda, NO reportar
- Funciones usadas solo en tests son VÁLIDAS (no dead code)
- @Model tipos se usan por reflexión en SwiftData — nunca reportar
- Preferir false negatives sobre false positives
- Este skill es para IDENTIFICAR candidatos — el desarrollador decide qué eliminar
