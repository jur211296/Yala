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

## Causa MEDIDA (2026-09-20, desde `restore-says-no-data-when-the-icloud-import-never-settled`)

Es el **escáner**, no el invariante. Y no hizo falta bisecar: el test y el fichero que lee son
byte-idénticos a `HEAD` en ese worktree (`git diff HEAD --stat` vacío para los dos), así que el
veredicto no podía depender de aquel cambio.

El marcador del escáner es `"private static func personalStoreFileExists() -> Bool {"`
(`NeutralMountRelaunchZeroTests.swift:359`). La función **dejó de ser `private`** el 2026-09-17, en
el commit `339f78259` («feat(nube): el alta en la nube deja de pedir que cierres y reabras la app»),
y lo dice su propio docblock: `CloudSessionRetirement` la necesita para la misma pregunta desde el
otro lado. Hoy la firma es `static func personalStoreFileExists() -> Bool {`
(`Yala/Utils/SwiftDataConfiguration.swift:894`). ⇒ el `#require(source.range(of: marker))` no
encuentra nada y el fallo imprime el fichero entero, que es ese `(source → "//…` del log.

**El invariante sigue cumpliéndose**, comprobado a mano sobre el cuerpo vivo (`:894-896`): la URL
sale de una config efímera (`ModelConfiguration(databaseName`), lleva `cloudKitDatabase: .none`
explícito, y no pasa por `personalConfiguration`. Las tres aserciones del test pasarían con el
marcador corregido.

⇒ El arreglo es quitar `private ` del marcador. **Y la lección va con él**: un marcador de
source-scan que incluye un modificador de acceso se rompe con un cambio de visibilidad que no toca
el invariante — ancla por la firma que el invariante necesita, no por la que hay hoy.

Queda vivo el tercer criterio —**por qué el CI no lo canta**— y esta medición le añade el dato que
faltaba: en el PR #195 (2026-09-21) el job `tests` del CI pasó **en verde**, 32 min 12 s, con este
mismo caso rojo en local sobre el mismo árbol. ⇒ no es que el CI lo vea y lo tolere: **no lo
ejecuta**, o lo ejecuta con un filtro que no lo alcanza. Ahí es donde hay que mirar
(`.github/workflows/qa.yml`, el job `tests` y su lista de `-only-testing`).
