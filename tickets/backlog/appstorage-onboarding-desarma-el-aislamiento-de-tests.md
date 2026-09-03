---
id: appstorage-onboarding-desarma-el-aislamiento-de-tests
status: backlog
priority: medium
area: testing
created: 2026-09-02
updated: 2026-09-02
---

# Una corrida de tests deja el onboarding marcado como visto en el simulador

Esto no lo ve nadie que use la app: lo pagan los tests y quien abre Yala Dev a mano después.

Los XCUITest arrancan la app diciéndole «el onboarding y el Welcome Chooser ya están vistos»
**sin escribirlo en disco** — el valor vive en memoria y muere con el proceso. Pero durante la
corrida la propia app vuelve a asignar esas dos preferencias, y esa asignación **sí** va al disco.
El valor de disco tiene más prioridad que el temporal, así que:

- **Dentro de la misma corrida**, si lo que se escribe es `false`, gana al `true` temporal y la
  corrida se queda sin el aislamiento que se había montado — a mitad de camino y sin decir nada.
- **Después de la corrida**, la preferencia queda escrita en ese simulador. Quien arranca luego
  —el target de tests unitarios, o alguien abriendo Yala Dev a mano— se salta las dos pantallas
  de bienvenida sin haberlas visto nunca. Es exactamente la clase de rojo que parece flaky, parece
  del simulador y parece una regresión del cambio que se está revisando.

## Por qué tiene ticket propio

Hasta hoy este residual solo existía como una viñeta dentro de
`tickets/blocked/apppreferences-rewritten-on-launch.md`, que está **bloqueado esperando un QA con
dos dispositivos y la misma cuenta de iCloud** (su sección «QA pendiente»). Arreglar esto **no
necesita ningún dispositivo**: es código de la app y se comprueba con la suite. Dejarlo colgando
de un bloqueo ajeno lo congela sin motivo.

## Medido (árbol de hoy, `553b91c9`)

Todo lo de abajo está re-medido en este árbol; las coordenadas del apartado (a) de la sección de
`AppPreferences` en `docs/aprendizajes-tecnicos.md` **ya no valen** — las dos primeras siguen
siendo correctas, pero el par que señala las asignaciones a `false` apunta a otro sitio (hoy ahí
vive documentación de un detector de datos preexistentes). No se copia aquí el contenido de ese
documento a propósito: duplicarlo es como divergen.

### Las declaraciones

Solo hay **tres** `@AppStorage` de estas dos claves en todo `Yala/`:

| Coordenada | Qué es |
|---|---|
| `Yala/App/ContentView.swift:16` | `hasCompletedOnboarding` |
| `Yala/App/ContentView.swift:17` | `hasShownWelcomeChooser` |
| `Yala/App/Views/Groups/GroupReconnectView.swift:15` | `hasCompletedOnboarding` |

**Corrección respecto de lo que decía el residual heredado:** `GroupReconnectView` **no escribe**.
Sus dos únicas apariciones son la declaración (`:15`) y una lectura en un `guard` (`:69`). Es un
lector, no una fuente de contaminación. Lo que contamina está todo en `ContentView`.

Los literales `"hasCompletedOnboarding"` y `"hasShownWelcomeChooser"` de esas declaraciones
coinciden con `AppPreferences.Keys.hasCompletedOnboarding` / `.hasShownWelcomeChooser`
(`Yala/App/Services/AppPreferences.swift:1275-1276`), que son las claves que el seam purga y
registra — o sea, son la misma clave y no dos parecidas.

### Las escrituras: 18 asignaciones, todas incondicionales

En `ContentView.swift` hay **17** asignaciones directas a esas dos propiedades:

- `= true` (14): `:430`, `:665`, `:669`, `:722`, `:1244`, `:1450`, `:1469`, `:1487`, `:1502`,
  `:1526`, `:1542`, `:1578`, `:1585`, `:2064`.
- `= false` (3): `:711` (cancelar el paso 1 del onboarding), `:1248` y `:1250` (el camino de wipe
  remoto sin saltar onboarding).

La **18ª** está en otro fichero pero es la misma propiedad: `ContentView.swift:287` pasa
`$hasCompletedOnboarding` a `ShellDataAlertsModifier`, que lo recibe como `@Binding` (`:34`) y le
asigna `false` en el botón de confirmación del wipe remoto
(`Yala/App/Views/Shared/ShellDataAlertsModifier.swift:56`).

Las tres asignaciones a `false` son las que **desarman el seam a mitad de corrida**. Las catorce a
`true` no cambian nada durante la corrida —coinciden con el valor temporal— pero **materializan la
clave en disco igual**, que es la mitad que sobrevive al proceso.

Aparte, y por otro camino distinto, `ContentView` escribe la clave **por nombre y sobre
`UserDefaults.standard`** en dos sitios: `:1584` y `:1941` (dentro de
`completeOnboardingAsRestoreSkip()`, invocada desde `:1577`). Ésos ni siquiera pasan por
`@AppStorage`, así que ningún cambio de almacén los redirige.

### La cadena que hace que el residual sobreviva — verificada entera

Es el corazón del ticket, así que va paso a paso y todo leído hoy:

1. `Yala/App/YalaApp.swift:116` aplica `.defaultAppStorage(SessionDefaults.current)` a la
   jerarquía raíz. En principio ahí estaría el punto donde los `@AppStorage` podrían apuntar a un
   almacén aparte.
2. `SessionDefaults.current` (`Yala/Services/CloudSync/SessionDefaults.swift:116`) delega en
   `resolve(...)`, cuyo parámetro `isTestEnvironment` toma por defecto
   `SwiftDataConfiguration.isRunningTests || SwiftDataConfiguration.isUITesting` (`:125`).
3. La **primera** línea del cuerpo es `guard !isTestEnvironment else { return owner }` (`:127`), y
   `owner` tiene por defecto `.standard` (`:124`).

⇒ **bajo `-uitest` (y bajo los unitarios) `SessionDefaults.current` es exactamente
`UserDefaults.standard`.** El `defaultAppStorage` no redirige nada, y por tanto las 18
asignaciones caen en el mismo almacén persistente que el seam intenta mantener limpio. La cadena
se sostiene.

### Contra qué chocan

El aislamiento lo monta `UITestEphemeralDefaults.applyOnboardingAlreadySeen(_:)`
(`Yala/App/UITestEphemeralDefaults.swift`), llamada desde
`Yala/App/AppBootstrapper.swift:682` **sin pasar almacén**, o sea también sobre `.standard`. Ese
seam purga las dos claves y, si el launch pidió saltar onboarding, las pone en el **dominio de
registro** de `UserDefaults`. La cabecera de ese fichero lo dice con todas las letras: el dominio
de registro tiene **menos** prioridad que el persistente. Por eso una escritura persistente le
gana, y por eso la purga existe.

`isUITesting` solo se enciende con el argumento `-uitest` y bajo `#if DEBUG`
(`Yala/Utils/SwiftDataConfiguration.swift:197`), que es lo que pone
`XCUIApplication.launchForUITest` (`YalaUITests/Support/XCUIApplication+Yala.swift:92`).

**Un camino concreto, por lectura del código (no ejecutado):**
`YalaUITests/Flows/WelcomeChooserUITests.swift:126` lanza con `skipOnboarding: false`, así que el
seam solo purga y no registra nada; el test recorre el Welcome Chooser, que es justo donde viven
las seis asignaciones `hasShownWelcomeChooser = true` de `ContentView:1450-1542`. Al terminar, la
clave queda escrita en el simulador.

### Qué NO lo cubre hoy

`YalaTests/UITestSeamPersistenceIsolationTests.swift` pinnea el seam, pero su escáner va
**acotado al cuerpo de `applyUITestHooksEarly`** (`:601`) — es decir, comprueba que el hook no
escriba, no que nadie más lo haga. `ContentView` queda fuera de su alcance por diseño.

## Fuera de alcance

- **`GroupReconnectView`**: no escribe. Si el arreglo cambia el almacén de la clave, hay que
  mirarlo por coherencia de lectura, pero no es el defecto.
- **Los re-escritores de producción legítimos**: `OnboardingView.swift:1823` escribe la clave
  directamente sobre `.standard` cuando el usuario completa un onboarding **real**. Eso ya está
  documentado como caso conocido y aceptado en `docs/aprendizajes-tecnicos.md` (el seam deja de
  ser el escritor y lo que cubre es la purga del siguiente launch). No lo arrastres a este ticket.
- **`hasShownYalaAIOnboarding`** (declarada en `ContentView.swift:18`, asignada `false` en
  `:1249`, en el mismo bloque que dos de las tres asignaciones problemáticas): es una **tercera**
  clave que el seam no toca. No la he investigado y no afirmo nada sobre ella; queda anotada por
  vecindad, para que quien abra ese bloque no la confunda con las dos de este ticket.

## Pendiente de decidir en el `/spec`

Hay 18 sitios de asignación y un solo par de propiedades, así que la elección real es dónde poner
la comprobación: en las propiedades (un único punto, pero cambiando la forma de leerlas en toda la
vista) o en el seam (más quirúrgico, pero no impide que aparezca la asignación 19). Este ticket no
lo prejuzga. Lo que sí deja fijado es el criterio de aceptación: **tras correr las suites de
XCUITest, las dos claves no deben existir en el almacén persistente del simulador**, y esa
aserción tiene que quedar pinneada donde el escáner actual no llega.

No se ha corrido ningún build ni ninguna suite para escribir este ticket. Todo lo de arriba es
lectura del árbol `553b91c9`.
