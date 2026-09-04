---
id: panel-defaults-four-sections-four-widgets
status: backlog
priority: high
area: panel
created: 2026-09-04
source: encargo del owner 2026-09-04 — investigación medida en 2.1 @ 070d76b1 (7 lentes + 14 refutadores)
---

# El Panel de un usuario nuevo arranca con cuatro secciones y cuatro widgets

## Qué cambia para el usuario

Hoy quien instala Yala por primera vez abre el Panel y se encuentra **siete secciones y nueve
widgets encendidos**. El encargo es que arranque mucho más simple:

| | Qué se ve al instalar |
|---|---|
| **Secciones** | Cuentas · Tendencias · Planificación · Últimos registros |
| **Fuera del arranque** | Salud financiera · Distribución · Herramientas |
| **Widgets** | Tendencias **en grande** · Pagos planificados y Presupuestos **pequeños**, emparejados en una fila · Últimos registros |
| **Nada más** | Los otros nueve widgets nacen apagados |

**Nada se borra.** Todo lo que queda fuera sigue en la app y se recupera desde el botón de la barra
superior del Panel —el icono de cuadrícula, «Configurar Panel»— que está siempre a la vista
(`PanelView.swift:221-231`, identificador `panel_sections_config`).

## El mapa exacto

Lo que pediste, traducido a lo que el código llama cada cosa. Medido en
`Yala/Resources/es-419.lproj/Localizable.strings`:

| Lo que dijiste | Nombre en pantalla | Identificador | Dónde |
|---|---|---|---|
| «la gráfica de Tendencias» | **Tendencias** (:765) | `trend` / `tendencia_saldo` | sección Tendencias |
| «planificados» | **Pagos planificados** (:776) | `scheduledPayments` / `pagos_planificados` | sección Planificación |
| «presupuestos» | **Presupuestos** (:775) | `budgets` / `presupuestos` | sección Planificación |
| «últimos registros» | **Últimos registros** (:771) | `latestRecords` / `ultimos_registros` | sección homónima |

Ojo con la coincidencia de nombres: **«Tendencias» se llama igual la sección y su widget**, y
«Últimos registros» también. En el ticket, sección y widget van siempre etiquetados.

## Lo que hay que tocar, y por qué no es una línea

### 1. Ocultar no es omitir

La lista que se guarda por sección **es de orden, no de pertenencia**. Un widget que no aparece en
ella no desaparece: se anexa al final y **se muestra**.

```
758:  for type in sectionTypes where !seen.contains(type.rawValue) {
759:      orderedRaw.append(type.rawValue)
```
(`Yala/App/ViewModels/PanelViewModel.swift`, `buildOrderedRawWidgets`)

⇒ La única forma de apagar un widget es meter su identificador en la lista de **ocultos**
(`panel<Sección>Hidden`), que es lo que resta `activeWidgets(in:)` en `:707`. El atajo intuitivo
—«borro los que sobran del orden»— no oculta nada. Es exactamente el patrón que ya usa el
predeterminado actual de Distribución: la lista de orden lleva los seis, y tres van en ocultos
(`AppPreferences.swift:805-818`).

### 2. El tamaño no vive donde vive el resto

Orden y ocultos viven en `AppPreferences` y **viajan por iCloud**. El tamaño S/M/L **no**: vive en
un almacén aparte, `panel_widget_configs_v1`, que es local del dispositivo y que
`setupDefaultsForNewUser()` no toca.

Ese almacén **solo se escribe cuando el usuario mueve el selector de tamaño a mano**
(`PanelViewModel.swift:820` es el único llamador de `WidgetConfigManager.save()`). Mientras nadie
lo toque no existe, y en cada arranque el tamaño se recalcula de la tabla
`WidgetConfig.defaultConfigs()` (`WidgetConfigManager.swift:76`).

Estado de los cuatro tamaños pedidos, medido en `Yala/App/Models/WidgetModels.swift`:

| Widget | Hoy | Pedido | ¿Hay que tocar? |
|---|---|---|---|
| Tendencias | `.small` (:111) | **grande** | **Sí** — y `.large` está soportado (:68) |
| Presupuestos | `.small` (:119) | pequeño | No, ya está |
| Pagos planificados | `.small` (:120) | pequeño | No, ya está |
| Últimos registros | `.medium` (:118) | — | No: es su único tamaño |

⇒ **El cambio de tamaño es una línea**, y los otros dos ya vienen puestos. Además `budgets` y
`scheduledPayments` están atados por un pair-sync (`PanelViewModel.swift:822`) que garantiza «ambos
pequeños o ninguno», así que la fila emparejada se sostiene sola.

### 3. «Restablecer» hoy hace lo contrario de lo que promete

```
918:  appPreferences?.setOrder([], for: kind)
919:  appPreferences?.setHidden([], for: kind)
```
(`PanelViewModel.swift`, `resetSectionPreferences`)

Vaciar las dos listas hace caer el render al fallback del punto 1: **todos** los widgets de la
sección encendidos. Hoy eso casi coincide con el predeterminado, y por eso nadie lo ha notado. Con
los nuevos predeterminados, tocar «Restablecer» en Tendencias devolvería los tres widgets — justo
lo contrario del encargo. **Entra en alcance** (decisión del owner, abajo).

### 4. Dos claves que hoy no llegan a escribirse

`panelSectionsHidden = []` (`AppPreferences.swift:827`) y `panelTendenciasHidden = []` (`:800`) son
hoy **no-ops**: el `didSet` corta con `guard oldValue != …` y el valor ya era `[]`. Con el cambio
pasan a llevar contenido y sí se escribirán —también a iCloud—. Importa porque la presencia de esas
mismas claves en iCloud es lo que `PanelPreferencesMigration.hasRemotePanelPreferences()` (`:127`)
usa para distinguir «instalación nueva» de «dispositivo nuevo de alguien que ya venía». No lo rompe
—escribirlas es justo lo que hace un usuario real al configurarse—, pero hay que verificarlo.

## Decisiones del owner (2026-09-04)

1. **Alcance: solo instalaciones nuevas.** No se re-siembra a quien ya tiene la app; conserva su
   Panel. No hace falta centinela nuevo.
2. **Cuentas sigue arrancando plegada.** Hoy `panelAccountsCollapsed` nace en `true`
   (`AppPreferences.swift:647`), así que al abrir se ve la cabecera «Tu panorama» con el saldo total
   y las tarjetas de cuenta aparecen al desplegar. Se deja como está: no se siembra esa preferencia.
3. **«Restablecer» pasa a devolver los nuevos predeterminados**, no «enciéndelo todo».
4. **El tamaño grande alcanza también a quien nunca tocó el selector**, por lo del punto 2. Se acepta
   a cambio de no acoplar la siembra al almacén antiguo — que además es el que detecta «instalación
   fresca», y tocarlo ahí sería frágil.

## Riesgos medidos

**El parpadeo del arranque, y es el gordo.** En una instalación nueva **con cuenta iCloud**, la
siembra se aplaza hasta después de `forceFetchAndWait(timeout: 15)` (`AppBootstrapper.swift:223`,
siembra en `:239`) para no pisar configuración que aún esté bajando. Durante esa ventana —hasta 15
segundos— no hay preferencias, y sin preferencias **todo se ve**. Hoy pasa desapercibido porque el
predeterminado actual es casi «todo visible»; con este cambio el usuario nuevo vería el Panel
completo y luego se le encogería a cuatro widgets delante de los ojos. **Hay que resolverlo dentro
de este ticket** (opciones: pintar el Panel en esqueleto hasta que la siembra decida, o adelantar la
decisión cuando no hay nada remoto que esperar).

**Tendencias queda con un solo widget.** El engranaje de preferencias de esa sección **seguirá
apareciendo**, porque `hasMultipleWidgets` cuenta los widgets del catálogo, no los visibles
(`WidgetType+PanelSection.swift:57-59`). Es correcto —desde ahí se recuperan los otros dos— pero
conviene verlo en pantalla antes de darlo por bueno.

**El widget de Tendencias en grande ocupa fila completa**, porque `trend` está en
`fullWidthOnlyTypes` (`WidgetConfigManager.swift:95-97`). Es lo esperado. Cuidado con lo contrario:
si se quedara en `.small` siendo el único de su sección, se pintaría como media tarjeta huérfana
(`:124-126`).

**Lo que un usuario nuevo deja de ver respecto a hoy:** Salud financiera (su puntuación desaparece
del arranque; es además la única sección cuyo cálculo se ahorra al ocultarla), flujo de efectivo,
promedio diario, las dos tortas, gastos por naturaleza y tipo de cambio.

**Ocultar Herramientas no ahorra la descarga de tipos de cambio**: `updateExchangeRateDataIfNeeded`
tiene guarda de frescura, no de visibilidad. No bloquea nada, pero que no se venda como ahorro.

## Cómo se verifica

- Los dos tests que clavan los predeterminados de hoy **se ponen rojos y hay que reescribirlos**:
  `freshInstall_seedsPP2_07Defaults` (`YalaTests/PanelPreferencesMigrationTests.swift:120`) y
  `setupDefaultsForNewUser_overwritesWithOpinionatedDefaults` (`:160`). Fijan valor por valor las
  tres listas de orden, las de ocultos y `panelSectionsHidden == []`.
- Añadir un pin nuevo: «un usuario nuevo ve exactamente cuatro secciones y cuatro widgets», que hoy
  no existe en ninguna suite.
- Añadir un pin de «Restablecer devuelve el curado», que tampoco existe.
- Simulador, instalación limpia **con y sin cuenta iCloud** — son dos caminos distintos de siembra y
  el parpadeo solo aparece en uno.
- `qa/coverage-index.json`: actualizar el área del Panel en el mismo commit.

## Fuera de alcance

- **`marketing/`** — las capturas de la ficha de App Store y el pool del post diario enseñan el
  Panel actual, incluidos widgets que quedarán ocultos. Hay que re-capturarlas, **pero eso es de
  Lola**: yo no entro ahí. Va como encargo aparte.
- **Mover el tamaño a las preferencias sincronizadas.** Que el tamaño no viaje entre dispositivos del
  mismo usuario es un hueco real y anterior a este ticket. Se anota, no se arregla aquí.
- **Re-sembrar a usuarios existentes** (decisión 1).
- **Retirar widgets del catálogo.** Se ocultan, no se eliminan.

---

## Análisis técnico

### Corrección al riesgo #1 del cuerpo — medida el 2026-09-04

El cuerpo dice que el parpadeo de 15 s golpea al usuario nuevo. **Medido: para el usuario nuevo
canónico es teórico.** El Panel no existe en el árbol de vistas hasta que termina el onboarding
(`ContentView.swift:177`, `if hasCompletedOnboarding && isInitialCheckDone`), y antes van splash de
2,5 s + Welcome + 8 pasos de onboarding. La ventana se cierra mientras el usuario teclea su nombre.

**Pero la protección es frágil y hay dos caminos donde el parpadeo sí es real:**

1. **Borrado remoto con la app ya abierta** — `DataWipeService` borra las 8 claves *y* el centinela;
   `rebootstrapAfterSwap` (`AppBootstrapper.swift:949-953`) re-corre el paso 8.5 con el Panel a la
   vista. Hasta 15 s enseñando todo.
2. **Restauración en un móvil nuevo desde una copia de 1.x** — llega sin blob y sin claves en iCloud,
   así que cae en la rama de instalación nueva y se le siembran los predeterminados. Contradice la
   decisión 1 del owner («solo instalaciones nuevas»), y el código no distingue ese caso.

Y la protección se rompe sola el día que alguien acorte el onboarding o le añada un «saltar»: no hay
ni un test que la sostenga. **⇒ Se arregla, pero por la vía barata, no por la cara.**

### La causa raíz, y por qué cambia el plan

El problema no es *cuándo* se siembra. Es que **«no hay preferencias» se renderiza como «enséñalo
todo»**: con la lista vacía, `buildOrderedRawWidgets` anexa el catálogo entero
(`PanelViewModel.swift:758-760`) y `panelSectionsHidden` vacío deja las 7 secciones.

Si los predeterminados viven también en la **ruta de lectura** —no solo en la de escritura— el
parpadeo desaparece por construcción en los cuatro caminos, **y de paso «Restablecer» pasa a
devolver el curado gratis**, que es la decisión 3 del owner. Hay precedente del patrón en el mismo
fichero: `resolvedReorderableSections` (`AppPreferences.swift:742-749`) ya hace exactamente esto con
el orden de secciones (`storedKinds.isEmpty ? defaults : storedKinds`).

### Cinco superficies definen hoy «lo que ve un usuario nuevo»

| # | Dónde | Qué define |
|---|---|---|
| 1 | `AppPreferences.setupDefaultsForNewUser()` :793-828 | Orden + ocultos de 3 secciones |
| 2 | `WidgetConfig.defaultConfigs()` — `WidgetModels.swift:106-124` | Tamaños (+ `isVisible` ya muerto) |
| 3 | Auto-sanado de `buildOrderedRawWidgets` :747-762 | «lista vacía ⇒ enseña todo» |
| 4 | Orden de declaración del enum — `WidgetType+PanelSection.swift:17-23` | Orden y anclaje de secciones |
| 5 | Dos `.medium` a pelo — `PanelViewModel.swift:717` y `:797` | Tamaño cuando falta el widget |

Dos incoherencias **ya vivas**, no introducidas por este ticket: los `isVisible` de #2 no se leen
(`activeWidgets` fuerza `true` en `:711-715`), y el fallback `.medium` de #5 **no es un tamaño legal
para `trend`**, cuyos soportados son `[.small, .large]` (`WidgetModels.swift:67`).

### Archivos involucrados

| Archivo | Cambio | Impacto |
|---------|--------|---------|
| `Yala/App/Models/PanelDefaults.swift` | **Crear** — SSOT de predeterminados | Alto |
| `Yala/App/Services/AppPreferences.swift` | Modificar — lectura resuelta + seed sin literales | Alto |
| `Yala/App/Models/WidgetModels.swift` | Modificar — `defaultConfigs()` se deriva de la SSOT | Medio |
| `Yala/App/ViewModels/PanelViewModel.swift` | Modificar — reset curado, tamaños, fallbacks | Alto |
| `Yala/App/Services/PanelPreferencesMigration.swift` | Modificar — sembrar ya si no hay cuenta iCloud | Bajo |
| `Yala/App/Views/Panel/PanelSectionsConfigView.swift` | Modificar — deja de duplicar el reset | Medio |
| `Yala/App/Views/Panel/PanelSectionPreferencesSheet.swift` | Modificar — un solo punto de entrada | Bajo |
| `Yala/Resources/*.lproj/Localizable.strings` (16) | Modificar — copy de «Restablecer» | Bajo |
| `YalaTests/PanelPreferencesMigrationTests.swift` | Modificar — 2 tests caen | Medio |
| `YalaTests/PanelSectionPreferencesTests.swift` | Modificar — 1 test cae, 2 a revisar | Medio |
| `qa/coverage-index.json` | Modificar — **el gate está ciego aquí** | Alto |

### Modelo de datos

Ninguno. No se toca SwiftData: todo son preferencias en `UserDefaults` + iCloud KV.

### Dependencias

- **iCloud KV** — las 8 claves del Panel sincronizan (`SessionPreferenceKeys.swift:83-86`); el blob de
  tamaños **no**. El merge las trata por presencia, no por contenido
  (`PreferenceMergeLogic.swift:139-142`), así que escribir la lista curada no rompe la detección de
  «usuario existente en móvil nuevo» (`hasRemotePanelPreferences`, presencia con `object(forKey:)`).
- **El gate del arranque** — `MigrationGateLogic.shouldWaitForCloudKit`: sin cuenta iCloud devuelve
  `.runNow`; **con cuenta iCloud y sin datos agota los 15 s siempre** (dicho en
  `iCloudSyncService.swift:481-487`), que es justo el caso del usuario nuevo.

## Plan de implementación

### Incrementos (orden de ejecución)

1. **La SSOT** — `PanelDefaults`: secciones ocultas, orden + ocultos por sección, y tamaño por widget
   saneado contra `supportedSizes`. Tipo puro: sin `UserDefaults`, sin UI, testeable solo.
   - Archivos: `Yala/App/Models/PanelDefaults.swift` (nuevo)
   - Tests: que el mapa cumpla el encargo (4 secciones, 4 widgets); que **ningún tamaño quede fuera
     de `supportedSizes`** — el pin que hoy falta y que deja pasar el `.medium` ilegal.

2. **Predeterminados en la lectura** — `order(for:)` / `hidden(for:)` y un `resolvedSectionsHidden`
   devuelven el curado mientras `panelPrefsMigratedV2 == false`. El discriminador es **el centinela,
   no «la lista está vacía»**: vacío es un estado legítimo del usuario.
   - Archivos: `AppPreferences.swift`
   - Tests: sin sembrar y con el centinela apagado, el Panel ya resuelve 4 secciones y 4 widgets;
     con el centinela encendido y listas vacías, respeta al usuario y no impone el curado.

3. **La siembra consume la SSOT, y llega antes cuando puede** — `setupDefaultsForNewUser()` pierde
   los literales; y si no hay cuenta iCloud se siembra en el `init` en vez de esperar al paso 8.5
   (mismo predicado que `MigrationGateLogic` ya usa para decidir `.runNow`).
   - Archivos: `AppPreferences.swift`, `PanelPreferencesMigration.swift`
   - Tests: los dos de `PanelPreferencesMigrationTests` que caen, reescritos contra la SSOT; uno
     nuevo del camino sin iCloud, que **hoy no existe** (no hay ni un test del camino diferido).

4. **El tamaño** — `defaultConfigs()` se deriva de la SSOT (`trend` → `.large`) y los dos `.medium` a
   pelo pasan por `PanelDefaults.size(for:)`.
   - Archivos: `WidgetModels.swift`, `PanelViewModel.swift`
   - Tests: revisar `widgetSize_defaultsMediumWhenUnknown` (`PanelSectionPreferencesTests.swift:307`)
     y `setWidgetSize_persistsForSupportedTypes` (`:330`), que asumen el `.medium` fijo.

5. **Restablecer, un solo camino** — hoy el cuerpo del reset está **duplicado** en
   `PanelViewModel.swift:918-919` y `PanelSectionsConfigView.swift:167-168`, y el segundo ni cancela
   el debounce ni limpia el borrador. Un único punto de entrada que aplique la SSOT en sus dos ejes
   (listas + tamaños) y al que llamen los tres botones.
   - Archivos: `PanelViewModel.swift`, `PanelSectionsConfigView.swift`, `PanelSectionPreferencesSheet.swift`
   - Tests: `resetSectionPreferences_cancelsPendingAndWritesDefaults`
     (`PanelSectionPreferencesTests.swift:250`) cae entero — sus cuatro asserts esperan «todo
     visible». Reescribir contra el curado y añadir el mismo pin para el botón del sheet, que hoy no
     tiene ninguno.

6. ~~**El copy**~~ — **fuera del plan por decisión 7 del owner.** No se tocan los 16 idiomas.

7. **Destapar el gate** — `panel-dashboard-logic` cubre 20 ficheros de vistas del Panel pero **ninguno
   de los cinco que definen los predeterminados**: `WidgetModels.swift`, `WidgetConfigManager.swift`,
   `PanelPreferencesMigration.swift`, `WidgetType+PanelSection.swift` y el `PanelDefaults` nuevo no
   los cubre **ningún área del índice**. Tocarlos hoy **no dispara ni un XCUITest**. Es el mismo fallo
   que en agosto dejó pasar el rediseño del Panel que rompió siete suites.
   - Archivos: `qa/coverage-index.json` (mismo commit que el código, por la regla anti-drift)
   - Tests: `bash qa/validate-coverage.sh`

### Riesgos

- **El reset se propaga por iCloud.** Hoy «Restablecer» manda `""` a los demás dispositivos y cada uno
  lo lee como «vuelve al default». Con la lista curada pasa a ser una **escritura material y opinada
  que pisa** lo que el usuario tenga en el iPad. El mecanismo no cambia; lo que cambia es cuánto
  duele. **Decidir si el reset debe seguir siendo `synced`.**
- **`-uitest-reset` no borra el centinela del Panel** (`AppBootstrapper.swift:624-682` no lo incluye).
  En un simulador que ya corrió tests, la siembra **no vuelve a correr**: verificar los nuevos
  predeterminados exige borrar la app, o añadir la clave a ese bloque. Sin esto, el XCUITest que
  escribamos daría verde sin probar nada — el patrón que ya nos costó un día de CI ciego.
- **Incremento 2 toca la ruta caliente del render** (`order(for:)`/`hidden(for:)` corren por sección y
  por frame). Mantener el resuelto barato: sin recomputar el curado en cada llamada.
- **No tocar el camino de actualización.** `migration_invalidJSON_writesEmpty`
  (`PanelPreferencesMigrationTests.swift:198`) fija que al actualizar se escribe `[]`. Actualizar no
  es restablecer: preservar lo del usuario no es imponerle el curado. Dejarlo comentado para que
  nadie «unifique» ese `?? []` con la SSOT.
- **`PanelDashboardUITests.swift:78` y `:86`** dan por hecho que la sección Planificación existe y su
  toggle nace encendido. Con este mapa sobreviven, pero quedan atados a la decisión: si algún día
  Planificación sale del arranque, caen.

### Decisiones del owner sobre el plan (2026-09-04)

5. **«Restablecer widgets de X» NO des-oculta la sección.** Restablecer widgets restablece widgets;
   la visibilidad de la sección es otra palanca y otro botón.
   **Consecuencia de implementación:** el curado de Distribución conserva su reparto interno actual
   (Categorías + Subcategorías + Necesidades encendidos; Top categorías, Top subcategorías y
   Etiquetas apagados) y se apaga **la sección entera** vía `panelSectionsHidden`. Así
   `isSectionEffectivelyEmpty(.distribucion)` sigue siendo falso y ese botón **ni siquiera aparece**
   — el caso raro se evita en vez de resolverse. Si algún día el curado apagara los seis widgets de
   Distribución, el botón reaparecería y esta decisión volvería a morder: no hacerlo.
6. **El reset sigue sincronizando** a los demás dispositivos. Se acepta que pise con una opinión: un
   «Restablecer» debe significar lo mismo en todos los dispositivos del usuario.
7. **El copy no se toca.** «Restablecer disposición original» se queda, y el incremento 6 sale del
   plan: no se tocan los 16 ficheros de idiomas. Queda anotado como residual conocido que el botón
   ahora también apaga widgets, y que `widget.resetLayout` sirve a dos botones con semántica
   distinta.

### Estimación

- Incrementos: **6** (el 6 salió del plan por decisión del owner; se conserva la numeración para que
  las referencias del cuerpo no se desalineen).
- Complejidad: **media-alta** — el código es poco y localizado, pero toca la ruta de render, la
  sincronización por iCloud y una red de pruebas que hoy está ciega justo aquí.
- Lo barato: incrementos 1, 3, 4 y 7. Lo que exige cuidado: 2 y 5.

### Residuales conocidos (no se arreglan aquí)

- El botón «Restablecer disposición original» pasa a apagar widgets además de recolocarlos, y su
  clave `widget.resetLayout` sirve a dos botones con semántica distinta. Decisión 7: se acepta.
- El tamaño de los widgets no viaja entre dispositivos del mismo usuario (el blob local no
  sincroniza). Anterior a este ticket.
- Una restauración en móvil nuevo desde una copia de 1.x cae en la rama de instalación nueva y
  recibe los predeterminados, aunque la decisión 1 diga «solo instalaciones nuevas». El código no
  distingue ese caso; con el incremento 2 ya no parpadea, pero sigue siendo un cambio para alguien
  que no es nuevo.
