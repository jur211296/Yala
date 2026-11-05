---
id: uitests-leave-the-onboarding-marked-as-seen-through-contentview
status: backlog
priority: low
area: testing
created: 2026-11-04
updated: 2026-11-04
source: "partido de `appstorage-onboarding-desarma-el-aislamiento-de-tests` (decisión de Jürgen, 2026-11-04, opción A)"
---

# Los XCUITest dejan el onboarding marcado como visto en el simulador, a través de `ContentView`

Es la mitad de XCUITest del ticket `appstorage-onboarding-desarma-el-aislamiento-de-tests`, que se cerró por lo que
pedía su encargo: que una corrida de **YalaTests** no deje la bienvenida marcada. Esa mitad quedó medida y blindada
(red de proceso en `YalaTests/TestSimulatorJanitor.swift`). Esta no se tocó porque vive en `ContentView.swift`, que
la sesión de la bienvenida estaba cambiando en paralelo.

## Lo que queda

Los `@AppStorage("hasCompletedOnboarding")` y `@AppStorage("hasShownWelcomeChooser")` de `ContentView` escriben en
`UserDefaults.standard` del proceso de la app, también bajo `-uitest`. El seam de arranque
(`UITestEphemeralDefaults.applyOnboardingAlreadySeen`) las purga y las registra en el dominio de registro, que tiene
MENOS prioridad que el persistente, así que:

- dentro de una corrida, una asignación a `false` (cancelar el paso 1, el wipe remoto sin saltar onboarding) gana al
  `true` temporal y desarma el aislamiento a mitad de camino;
- después de la corrida, la clave queda escrita en el contenedor de `com.jurgenschmidt.yala.dev`, y quien abra Yala
  Dev a mano se salta la bienvenida.

El análisis completo de los escritores (las asignaciones de `ContentView`, el `@Binding` de
`ShellDataAlertsModifier` y las dos escrituras por nombre sobre `.standard`) está en el ticket del que sale; re-medir
las coordenadas antes de usarlas.

## Medido el 2026-11-04

- Una corrida completa de YalaTests (12.773 tests, scheme `Yala`) no deja ninguna de las dos claves en el plist del
  contenedor de `com.jurgenschmidt.yala`.
- En ese momento tampoco estaban en el de `com.jurgenschmidt.yala.dev`, con otra sesión corriendo XCUITest del
  Welcome en ese simulador: el seam las purga en cada arranque, así que lo que se ve depende de qué hizo el ÚLTIMO
  lanzamiento. No se ha reproducido el residuo tras una corrida concreta de XCUITest.

## Criterios de aceptación

- [ ] Tras una corrida de las suites de XCUITest del Welcome y el onboarding, las dos claves no existen en el plist del
      contenedor de Yala Dev. Medido leyendo el fichero, no con `simctl spawn defaults read` (lee otro dominio).
- [ ] La aserción queda fijada donde el escáner de `UITestSeamPersistenceIsolationTests` no llega (hoy va acotado a
      `applyUITestHooksEarly`).
- [ ] Coordinado con quien esté tocando `ContentView.swift`.
