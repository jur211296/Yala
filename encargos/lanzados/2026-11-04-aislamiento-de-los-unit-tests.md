# Los unit tests dejan de ensuciar el simulador: preferencias, onboarding, espejo del App Group y SQLite
toca: `YalaTests/` (helpers de setUp y teardown, suites con `UserDefaults(suiteName:)`, el test de aislamiento del espejo de grupos), y como mucho los seams de inyección en `ContentView.swift` y `GroupsSyncClient` que los tests necesiten

Rama base: 2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la Max, con simulador.
Ola 1 de la 2.3 (lote T1 de `docs/planning/cola-2-3-propuesta.md`). En paralelo corren la bienvenida (`ContentView.swift`, `Onboarding/`, en la Mini) y el control del coste de la IA (solo `gateway/`). Si necesitas un seam en `ContentView.swift`, que sea mínimo y avísalo en el cierre, porque la bienvenida también lo toca; si choca con su trabajo, pregunta antes. No toques `gateway/`. Por esa separación de ficheros las tres sesiones pueden ir a la vez.

Objetivo: que una corrida de YalaTests no deje nada en el simulador y que ningún test lea el estado que dejó otro.

Lote de cinco cards del tablero de Yala:

1. «Cada corrida de tests unitarios deja ficheros de preferencias huérfanos en el simulador, y llena el disco poco a poco». Toda suite que crea `UserDefaults(suiteName:)` la destruye al terminar; mejor con un helper común. Cuenta los ficheros antes y después de una corrida.
2. «Una corrida de tests deja el onboarding marcado como visto en el simulador». Las dos claves de `@AppStorage` no deben escribir en el almacén persistente durante los tests.
3. «Los unit tests dejan entradas en el espejo real del App Group del simulador, y otros tests pueden leerlas». Que los tests no usen el `GroupsOutboxMirror()` real por defecto.
4. «El test que obliga al aislamiento del espejo de grupos no vigila wipeLocalGroupsDomain». El escáner también tiene que vigilar `wipeLocalGroupsDomain`.
5. «Los tests borran el fichero SQLite con la conexión todavía abierta, y eso llena el log de avisos de integridad». El teardown cierra el `ModelContainer` antes de borrar el directorio.

Hecha cuando: tras una corrida completa de YalaTests no quedan dominios de preferencias nuevos ni entradas en el App Group (lo muestras con el conteo de antes y de después), el onboarding sigue sin marcar, el log no trae avisos de integridad de SQLite, los cinco tickets pasan a `tickets/done` y `/gate` pasa.

Restricciones:
- Usa el simulador solo cuando haga falta, pidiendo turno como siempre.
- No cambies el comportamiento de la app: solo el de los tests y los seams que estos necesiten.
- Nada de despliegues a producción sin el OK de Jürgen.
- PREGUNTAR, NO SALTAR: si alguna duda bloquea o cambia el resultado, pregunta con `preguntar-bot "pregunta con opciones"`. No asumas ni te saltes nada.

Mueve las cards con `tablero`: en curso al empezar e in qa al cerrar.
El cierre trae la sección «Saltado o asumido sin preguntar».
Cierra sola: termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué base?** → `origin/2.3`, como pide el encargo. El worktree nació de `2.2`; la rama se recreó sobre `2.3` antes del primer cambio (sin commits propios que perder).
Por qué: el encargo es de la ola 1 de la 2.3. Alternativa descartada: rebasar al final, que mezclaría 27 commits de 2.2 en el PR.

**D2 · ¿Cómo se destruye cada `UserDefaults(suiteName:)`?** → Un helper común (`testDefaults(suiteName:)`, y `makeIsolatedDefaults` pasa por él) que apunta el nombre en un conserje de proceso; el conserje borra todos los dominios al salir el proceso (el `atexit` que ya arma `TestProcessGuard`), y un manifiesto en `Caches` recoge lo de un proceso que murió sin `atexit`. Las 137 llamadas se sustituyen mecánicamente y un source-scan prohíbe la llamada pelada.
Por qué: borrar al final de cada test rompe las suites que reabren el mismo nombre para simular un relanzamiento. Alternativa descartada: `removePersistentDomain` en un `defer` por test (137 sitios a mano, y el mismo riesgo). Los dominios REALES del App Group no se apuntan: no son de los tests.

**D3 · «Cerrar el `ModelContainer` antes de borrar el directorio»: ¿cómo, si SwiftData no tiene `close()`?** → El container se cierra al soltarse; el borrado se hace en `discardTestStoreDirectory(_:)`, que solo borra cuando el proceso ya no tiene ningún fd abierto dentro del directorio (`fcntl(F_GETPATH)`), y si lo tiene lo reintenta en la siguiente llamada y al salir. Un solo helper para todos los prefijos.
Por qué: es el único criterio que se puede comprobar («¿sigue abierta la conexión?») sin reestructurar 109 ficheros. Alternativas descartadas: store in-memory (cambia lo que prueban los tests on-disk) y no borrar (deja `tmp/` lleno).

**D4 · Espejo real del App Group en los tests** → El default de `outboxMirror` en `GroupsSyncClient.init` pasa a `nil` y el único constructor de producción (`.shared`) pasa `GroupsOutboxMirror()` explícito, con un source-scan que lo fija.
Por qué: mismo molde que el `attestProvider { nil }` del mismo init («default solo para tests»); la app no cambia porque `.shared` es la única construcción en `Yala/`. Alternativa descartada: un helper de tests con la firma entera del init (17 parámetros duplicados que divergirían).

**D5 · El escáner y `wipeLocalGroupsDomain`** → Cuenta las llamadas `try DataWipeService.wipeLocalGroupsDomain(` en código (no en literales ni comentarios) y exige que cada una inyecte `resetSyncState:`.
Por qué: el trait `.wipeAppGroupMirrorIsolated` protege claves del App Group, no el directorio del espejo; exigir el trait no impediría la purga real. Alternativa descartada: pedir el trait, que pasaría el guard con el espejo purgado igual.

**D6 · Onboarding marcado** → Se mide primero si la corrida de unit escribe las dos claves. Si las escribe, la protección va en el guard de proceso de los tests (capturar y restaurar `hasCompletedOnboarding`/`hasShownWelcomeChooser` en `.standard`, molde de `TestProcessGuard`), sin tocar `ContentView`.
Por qué: la bienvenida está tocando `ContentView.swift` en paralelo y el encargo pide seams mínimos ahí; un seam de almacén para `@AppStorage` cambiaría además cómo se comportan los XCUITest entre relanzamientos. Alternativa descartada: `.defaultAppStorage` volátil bajo tests en la raíz de la app.

**D6 (resuelta por Jürgen, 2026-11-04 ~20:00, opción A).** Medido: una corrida completa de YalaTests no escribe las dos claves. Se blinda la corrida de unit con la red de proceso (foto y restauración de `hasCompletedOnboarding`/`hasShownWelcomeChooser` en `.standard`) y su test; la card se cierra por el criterio del encargo; la mitad de XCUITest va a un ticket nuevo. `ContentView` no se toca.

**D7 · App Group real (encontrado al medir)** → La base deja `isProUser`, `lastUsedAccountID` y `siri_finance_snapshot` en las preferencias del App Group, y crea su `.plist`. El conserje fotografía el dominio entero al empezar (solo lo persistido, vía `CFPreferencesCopyMultiple`) y lo devuelve al salir; si el fichero no existía y queda vacío, lo borra.
Por qué: el criterio del encargo es «ni entradas en el App Group», y los escritores son servicios de producción, no tests concretos. Alternativa descartada: ampliar la lista de claves de `TestProcessGuard`, que envejece igual que su lista enumerada.
