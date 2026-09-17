---
id: neutral-mount-wiring-scan-is-red-on-2-1
status: backlog
priority: medium
area: "testing, modo-nube"
created: 2026-09-17
source: "medido el 2026-09-17 al correr la suite completa desde `reverse-before-mount-stays-stuck-with-an-expired-session`"
---

# `NeutralMountWiringTests` está en rojo en `2.1`, y su rojo no lo ve nadie

## Qué pasa

`NeutralMountWiringTests` → «R2 (a): el predicado NO construye un container para preguntar por el archivo» falla con
`Expectation failed` sobre el cuerpo de `SwiftDataConfiguration.swift`
(`YalaTests/CloudSync/NeutralMountRelaunchZeroTests.swift:297`).

**Es preexistente y está medido**, no inferido: se reprodujo en un **worktree limpio desde `HEAD`
(`d8884808e`)**, sin nada del ticket que lo encontró, con `-only-testing:YalaTests/NeutralMountWiringTests`
→ exit 65, `Test run with 8 tests in 1 suite failed`. Ese mismo filtro con el NOMBRE del `@Suite`
(«R2 · cableado del mount neutro y del portal (source-scan)») ejecuta **cero tests** y sale 0: `-only-testing`
filtra por el TIPO, no por el título de la suite — la trampa que ya está en `.claude/rules/testing.md`.

## Por qué importa

Es un **source-scan de cableado**, de la familia que existe precisamente porque el comportamiento que vigila no lo
puede ver ningún test normal: afirma que el predicado de instalación fresca no construye un `ModelContainer` para
preguntar por el archivo. Mientras esté rojo, nadie sabe si sigue vigilando algo o si lo que cambió fue el fichero que
lee.

## Qué hay que mirar

- El escáner acota al cuerpo entre llaves de un marcador (`body(of:in:)`). Lo más probable es que el marcador o el
  cuerpo de `SwiftDataConfiguration` se hayan movido y el escáner esté leyendo otro tramo — es decir, que el rojo sea
  del escáner y no del invariante. **Hay que medirlo antes de "arreglarlo" relajando la aserción**: si el invariante
  se rompió de verdad, relajarla lo tapa.
- Cuándo se puso rojo: `git log -S` sobre el marcador y sobre el tramo de `SwiftDataConfiguration` que lee.
- **Y por qué el CI no lo canta**, que es la mitad importante: si la nocturna pasa en verde con este caso rojo, el
  filtro del CI tiene el mismo problema de nombres.

## Criterios de aceptación

- [ ] Medido si el rojo es del escáner o del invariante, con la coordenada que lo demuestra.
- [ ] Verde en `2.1` sin relajar lo que el escáner vigila.
- [ ] Sabido por qué no salió antes.
