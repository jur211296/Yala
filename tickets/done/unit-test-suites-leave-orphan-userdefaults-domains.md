---
id: unit-test-suites-leave-orphan-userdefaults-domains
status: done
priority: low
area: "testing, disco, simulador"
created: 2026-09-13
updated: 2026-11-04
source: "medido de camino en el PR-B del paso 12 (`shell-derives-from-two-session-axes`), diagnosticando ocho XCUITest rojos"
---

# Cada corrida de unit deja un `.plist` por test dentro del simulador

## Qué se midió

`UserDefaults(suiteName: "X.\(UUID())")` **crea un fichero en disco** y ese fichero no se va solo: vive
en `…/Containers/Data/Application/<app>/Library/Preferences/` del simulador, dentro del contenedor del
bundle `.dev` —que el host de unit comparte con Yala Dev—. Sin `removePersistentDomain(forName:)` en el
teardown, cada `@Test` deja el suyo.

Medido el 2026-09-13 en el contenedor de `com.jurgenschmidt.yala.dev` del iPhone 17 Pro: el listado de
`Library/Preferences` traía **miles** de ficheros `AppPreferencesTests.<UUID>.plist`. Y el reparto en el
árbol dice que no es una suite:

| | Cuenta |
|---|---|
| Ficheros de `YalaTests/` que crean `UserDefaults(suiteName:)` | **45** |
| Ficheros de `YalaTests/` que llaman a `removePersistentDomain` | **17** |

(`git grep -l` sobre `YalaTests/`, este árbol, 2026-09-13.)

## Por qué importa

1. **Disco.** El simulador es la primera víctima del disco lleno en esta Mac, y con el disco lleno
   CoreSimulator falla con errores que no mencionan el disco — el diagnóstico que ya costó 11 días una
   vez. Esto lo llena en silencio, corrida a corrida.
2. **Y es la trampa que `.claude/rules/testing.md` ya documenta**: un seam de test que PERSISTE puede
   poner rojos a los tests de otro target. Aquí no ha pasado porque los nombres llevan UUID, pero el
   mecanismo es el mismo y basta con que alguien reuse un nombre fijo.

## Qué haría falta

- Un helper compartido que cree el suite **y** registre su destrucción, en vez de 45 `makeSuite()`
  copiados. `SecondarySessionRetirementTests.makeDefaults` y los 17 que ya lo hacen son el molde.
- Y una limpieza de lo que ya está en el simulador; hoy se va solo al desinstalar la app.

## Criterios de aceptación

- [ ] Ningún fichero de `YalaTests/` crea un `suiteName` sin destruirlo. Se comprueba con el mismo
      `git grep` de arriba: las dos cuentas tienen que coincidir.
- [ ] Tras una corrida completa de `YalaTests`, el contenedor del simulador no gana ficheros en
      `Library/Preferences`. Medido, no supuesto.

## Medido en 2.1 (triage 2026-10-08)

- Re-medido con el mismo `git grep` del ticket: **59** ficheros de `YalaTests/` crean `UserDefaults(suiteName:)` y **25** llaman a `removePersistentDomain`. **35** crean suites sin destruirlas. Al abrirse el ticket eran 45 y 17: el hueco crece.
- `AppPreferencesTests.swift:27`, el caso medido, sigue sin destruir su suite.
- El contenedor del simulador no se re-midió: el triage no lo toca.

Triage 2026-10-08: abierto · medium → low · El hueco creció: 59 ficheros de YalaTests crean UserDefaults(suiteName:), 25 llaman a removePersistentDomain y 35 crean suites sin destruirlas (eran 45/17)

## Cerrado (2026-11-04)

Las 124 llamadas a `UserDefaults(suiteName:)` de `YalaTests/` pasan por `testDefaults(suiteName:)` (y `makeIsolatedDefaults`),
que apuntan el nombre en `TestSimulatorJanitor`; el conserje borra los dominios con su fichero al salir el proceso (no al
acabar el test: hay suites que reabren el mismo nombre). Las subclases (`CountingDefaults`) apuntan a mano. Los `.plist`
que nacen fuera de los helpers con prefijo `test.` (`iCloudSyncService._testReset`, en la app) se barren al salir. El
`removePersistentDomain` del `defer` NO basta: medido, vacía el dominio y deja el fichero. Lo fija
`TestSimulatorJanitorTests.ningunTestCreaUnDominioSinApuntarlo`. Limpieza única del simulador: 571 + 2.539 ficheros con UUID
borrados de los contenedores de Yala y Yala Dev.

Medición (iPhone 17 Pro de la Max, iOS 27.2, scheme `Yala`, corrida completa de YalaTests con el simulador en turno):
la base (`origin/2.3` sin tocar, instalación limpia) dejó **1.262** ficheros de preferencias, **74** directorios en
`tmp/`, el `.plist` del App Group con `isProUser`, `lastUsedAccountID` y `siri_finance_snapshot`, y **2.910** avisos
«vnode unlinked while in use»; con el arreglo (12.783 tests en verde): **0** preferencias nuevas, App Group sin claves
antes y después (leído vía `cfprefsd`: el fichero en disco va desfasado), onboarding sin marcar y **3** avisos, los del
control negativo del eje 4b del spike R3, que los provoca a propósito.
