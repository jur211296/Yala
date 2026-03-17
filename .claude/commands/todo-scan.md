---
description: Busca y categoriza TODO, FIXME, HACK en el código con contexto y prioridad
allowed-tools: Grep, Glob, Read
argument-hint: "[directorio — default: todo el proyecto]"
---

Encuentra y categoriza todos los marcadores de deuda técnica en el proyecto.

## ALCANCE

Si hay argumento ($ARGUMENTS): escanear ese directorio.
Si no: escanear todo Yala/ (incluir Tests/).

## PASO 1: ENCONTRAR MARCADORES

```
Grep: // TODO: en archivos .swift
Grep: // FIXME: en archivos .swift
Grep: // HACK: en archivos .swift
Grep: // WORKAROUND: en archivos .swift
Grep: // TEMP: en archivos .swift
Grep: // DEPRECATED: en archivos .swift
```

Para cada marcador encontrado, capturar:
- Archivo y línea
- Tipo (TODO/FIXME/HACK/etc.)
- Texto del comentario
- Contexto: leer 3 líneas antes y después para entender qué afecta

## PASO 2: CLASIFICAR POR PRIORIDAD

### Crítico (resolver antes de release)
- FIXME en código de producción
- HACK con workarounds frágiles
- TODO que menciona "crash", "bug", "broken", "security"

### Alto (resolver pronto)
- TODO en Services/ o ViewModels/ (lógica de negocio)
- WORKAROUND con referencia a bug de framework
- Cualquier marcador que mencione "memory", "leak", "performance"

### Medio (planificar)
- TODO en Views/ (mejoras de UI)
- TODO genéricos sin urgencia

### Bajo (backlog)
- TODO en Tests/
- DEPRECATED marcadores para migración futura
- TODO cosméticos

## PASO 3: DETECTAR STALE

Para cada marcador, verificar:
- `git log -1 --format=%ai -- archivo` → fecha del último cambio
- Si el archivo no se ha tocado en >3 meses → marcador STALE (posiblemente olvidado)
- Si el TODO referencia un ticket/issue, verificar si sigue siendo relevante

## PASO 4: AGRUPAR POR ÁREA

Agrupar los marcadores por directorio/módulo:
- Views/ → UI debt
- ViewModels/ → Logic debt
- Services/ → Infrastructure debt
- Models/ → Data model debt
- Tests/ → Test debt

## REPORTE

```
## TODO Scan — [N] marcadores en [M] archivos

### Resumen
| Tipo | Count | Crítico | Alto | Medio | Bajo |
|------|-------|---------|------|-------|------|
| TODO | N | N | N | N | N |
| FIXME | N | N | N | N | N |
| HACK | N | N | N | N | N |
| Otros | N | N | N | N | N |

### Críticos (resolver antes de release)
| Archivo:Línea | Tipo | Texto |
|---------------|------|-------|
| Service.swift:45 | FIXME | Race condition en sync |

### Altos
| Archivo:Línea | Tipo | Texto |
|---------------|------|-------|

### Por área
| Área | Count | Más antiguo |
|------|-------|-------------|
| Views/ | N | [fecha] |
| ViewModels/ | N | [fecha] |
| Services/ | N | [fecha] |

### Stale (>3 meses sin tocar)
| Archivo:Línea | Tipo | Texto | Último cambio |
|---------------|------|-------|---------------|

### Veredicto: [N] marcadores — [N] críticos, [N] stale
```

## REGLAS
- No reportar marcadores en dependencias externas (solo código propio)
- Los FIXME son SIEMPRE más urgentes que los TODO
- HACK implica solución temporal que debería reemplazarse
- Un TODO sin contexto claro es un mal TODO — señalarlo
- Marcadores stale son señal de deuda olvidada — priorizar revisión
