---
description: Auditoría de performance — fetches sin límite, body pesado, lazy, re-renders
allowed-tools: Grep, Glob, Read
argument-hint: "[archivo o directorio — default: archivos modificados]"
---

Auditoría de performance para detectar patrones costosos en código Swift/SwiftUI.

## ALCANCE

Si hay argumento ($ARGUMENTS):
- Si es `all`: escanear TODO el proyecto (Yala/App/ + Yala/Services/ + Yala/Utils/)
- Si es archivo/directorio: escanear ese path específico

Si no hay argumento: escanear archivos .swift modificados (git diff).

Para scan completo pre-release usar: `/perf-check all`

## PASO 1: FETCHES SIN LÍMITE

```
Grep: FetchDescriptor en archivos .swift
```

Para cada FetchDescriptor encontrado:
- Verificar si tiene `fetchLimit` definido
- Si NO tiene límite y la entidad puede tener muchos registros (TransactionItem, InboxDraft): WARNING
- Excepción: fetches que necesitan TODOS los registros para cálculos (balances, totales)

## PASO 2: BODY DE VIEWS PESADO

Para archivos en Views/:
- Buscar `var body: some View` y medir complejidad del body
- Detectar lógica de negocio dentro de body:
  ```
  Grep: \.filter\(|\.map\(|\.reduce\(|\.sorted\( dentro de body
  ```
- Detectar cálculos repetidos (computed properties llamadas en body que hacen trabajo pesado)
- Detectar `ForEach` sin `id:` explícito (re-renders innecesarios)

## PASO 3: LISTAS SIN LAZY

```
Grep: ScrollView.*\{[^}]*ForEach en archivos de Views/
Grep: VStack.*\{[^}]*ForEach en archivos de Views/
```

Si hay ForEach dentro de ScrollView+VStack sin usar LazyVStack → WARNING
- Todas las celdas se renderizan de golpe
- Debería ser LazyVStack para listas con >20 items potenciales

## PASO 4: RE-RENDERS EXCESIVOS

### A. Computeds costosos llamados múltiples veces
```
Grep: var.*:.*\{ en archivos de Views/ (computed properties)
```
Si un computed que hace .filter/.map/.sorted se usa más de una vez en body → extraer a let

### B. @State/@Binding innecesarios
Buscar `@State` de tipos complejos (arrays, objetos) que podrían causar re-renders cascada.

### C. .onChange sin debounce
```
Grep: \.onChange\( en archivos de Views/
```
Si el onChange dispara trabajo pesado (fetch, cálculo) sin debounce → WARNING

## PASO 5: ANIMACIONES COSTOSAS

```
Grep: withAnimation en archivos .swift
Grep: \.animation\( en archivos .swift
```

- Animaciones en listas largas sin `.animation(.default, value:)` específico → re-anima todo
- `.animation(nil)` faltante en elementos que no deberían animarse

## PASO 6: MEMORY

### A. Closures sin [weak self]
```
Grep: Task\s*\{[^}]*self\. en archivos .swift (sin [weak self])
```
- En ViewModels/Services: closures de larga vida sin [weak self] → retain cycle potencial
- Excepción: Task {} en Views (SwiftUI maneja el ciclo de vida)

### B. Imágenes sin downsampling
```
Grep: UIImage\(data: en archivos .swift
```
- Si cargan imágenes grandes sin resize → memory spike

## REPORTE

```
## Perf Check — [N] archivos

| Check | Estado | Count |
|-------|--------|-------|
| Fetches sin límite | ✓/✗ | N |
| Body pesado | ✓/✗ | N |
| Listas sin Lazy | ✓/✗ | N |
| Re-renders (computeds) | ✓/✗ | N |
| onChange sin debounce | ✓/✗ | N |
| Animaciones costosas | ✓/✗ | N |
| Retain cycles | ✓/✗ | N |

### Issues (archivo:línea — descripción)
[Lista priorizada por impacto]

### Veredicto: OK | N ISSUES
```

## REGLAS
- FetchDescriptor sin fetchLimit en TransactionItem es SIEMPRE warning (puede haber miles)
- Lógica en body es WARNING, no crítico (SwiftUI tiene optimizaciones internas)
- LazyVStack faltante solo importa si la lista puede tener >20 items
- Solo reportar problemas REALES, no optimizaciones prematuras
