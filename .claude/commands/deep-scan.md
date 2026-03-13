---
description: Escaneo profundo archivo por archivo buscando bugs, errores y mejoras
allowed-tools: Grep, Glob, Read, Agent
argument-hint: "[directorio — default: Yala/App/]"
---

Escaneo profundo de código Swift archivo por archivo. Usa subagentes en paralelo para máxima cobertura.

## MODO DE OPERACIÓN

Este skill lanza **3 subagentes en paralelo**, cada uno escaneando un subconjunto del código.

## PASO 1: DETERMINAR ALCANCE

Si hay argumento ($ARGUMENTS): escanear ese directorio.
Si no: escanear Yala/App/ completo.

Dividir archivos en 3 grupos para paralelizar:
- Grupo 1: Views/ (UI)
- Grupo 2: ViewModels/ + Services/ (lógica)
- Grupo 3: Models/ + Logic/ + Utils/ (datos y utilidades)

## PASO 2: LANZAR SUBAGENTES

Lanzar 3 subagentes swift-reviewer en paralelo con estas instrucciones para CADA grupo:

### Checks por archivo:

**Seguridad y Estabilidad:**
1. try? sin manejo de error → do/catch con diagnóstico
2. Force unwraps (!) sin guard previo → crash potencial
3. Índices de array sin bounds check → crash potencial
4. División por cero posible
5. Opcionales forzados en cadena (a!.b!.c!)
6. Retain cycles (closures que capturan self sin [weak self])

**Concurrencia:**
7. DispatchQueue.main.async → preferir @MainActor
8. Acceso a datos compartidos sin actor isolation
9. @MainActor faltante en ViewModels/Services que usan ModelContext
10. Race conditions en async/await

**SwiftData:**
11. @Relationship sin inverse
12. deleteRule incorrecto para la relación
13. #Predicate con enums (debe usar rawValue)
14. Fetch sin límite en colecciones potencialmente grandes

**Patrones y Mantenibilidad:**
15. Funciones > 50 líneas → candidatas a extraer
16. Archivos > 500 líneas → candidatos a separar
17. Switch sin default o sin cubrir todos los cases
18. Magic numbers (números sin contexto ni constante)
19. Código duplicado entre archivos similares
20. TODOs/FIXMEs/HACKs pendientes

**APIs Deprecated:**
21. foregroundColor → foregroundStyle
22. cornerRadius → clipShape
23. onChange firma vieja
24. @available innecesarios (target iOS 26+)

**Design System:**
25. .font(.system(size:)) → DS.Typography
26. Padding/spacing hardcodeado → DS.Spacing
27. Colores no semánticos → colores del tema

## PASO 3: CONSOLIDAR

Combinar reportes de los 3 subagentes en un solo reporte priorizado.

## REPORTE

```
## Deep Scan — [N] archivos escaneados

### Estadísticas
- Archivos escaneados: [N]
- Issues críticos: [N] (crashes, data loss)
- Issues altos: [N] (bugs probables)
- Issues medios: [N] (mejoras importantes)
- Issues bajos: [N] (limpieza, style)

### Issues Críticos (resolver ANTES de lanzamiento)
| # | Archivo:Línea | Tipo | Descripción |
|---|---------------|------|-------------|
| 1 | Service.swift:45 | Force unwrap | 'array[index]!' sin bounds check |
| 2 | ... | ... | ... |

### Issues Altos (resolver pronto)
[Tabla similar]

### Issues Medios (mejorar calidad)
[Tabla similar]

### Issues Bajos (limpieza)
[Lista simple con count por tipo]

### Archivos más problemáticos
| Archivo | Críticos | Altos | Medios | Total |
|---------|----------|-------|--------|-------|
| ... | ... | ... | ... | ... |
```

## NOTAS
- Cada subagente lee archivos COMPLETOS, no solo grep
- Priorizar reportar bugs REALES sobre style nits
- No reportar falsos positivos (try? justificado, ! después de guard, etc.)
- Este skill consume MUCHO contexto — ejecutar en sesión dedicada
- Ideal para revisiones periódicas (1x por fase o pre-release)
