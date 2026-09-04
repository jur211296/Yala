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
