# Calentamiento, batería y scroll al volver a Yala — iPhone 14, 26-nov-2026

Diagnóstico pedido por Jürgen el 26-nov a las 08:39 (Lima). Al cambiar de app y volver a Yala varias veces, el teléfono
se calienta y el scroll se siente lento. Esta sesión mide y propone: no cambia código de la app. La instrumentación
temporal que se usó se revirtió antes del PR.

## Resumen en cinco líneas

1. **Volver a Yala la deja 16-25 s con el hilo principal al 100 %** (16.004 movimientos): cada vuelta recalcula el Panel
   entero (y Estadísticas, Registros, Grupos e Informes si se abrieron), aunque nada haya cambiado. El scroll que se hace
   en ese rato se congela de 12 a 20 s seguidos.
2. **Quieta, sin tocar nada, Yala gasta 35-38 % de un núcleo** en cualquier pantalla: el punto que late en la gráfica de
   tendencia del Panel es una animación infinita que obliga a SwiftUI a repintar y a recalcular el cristal en cada
   fotograma, aunque el Panel no se vea. Apagando solo ese pulso: **0,3 %**.
3. **iOS mató a Yala dos veces en segundo plano** (vigilante de 10 s, `0x8BADF00D`) porque el trabajo de la vuelta seguía
   ocupando el hilo al irse a otra app; y registró **9 avisos de abuso de CPU** (`cpu_resource`, «más de 50 % de CPU
   durante 180 s») en Yala Dev entre el 24 y el 26-nov. La vuelta siguiente a un cierre es un arranque en frío.
4. **El costo no crece con los ciclos** (no hay fuga de tareas ni de observadores que se sumen): es el mismo trabajo
   completo, repetido en cada vuelta. La memoria sí sube ~25 MiB por vuelta (238 → 363 MiB en 5 ciclos).
5. **Con dos cambios simulados en el mismo iPhone** (sin pulso y sin recarga al volver) la vuelta pasa de ~33 s de CPU
   en 36 s a ~1,5 s en 20 s, el reposo de 38 % a 0,3 %, y el impacto de energía al volver de 25,2 a 5,9 (en reposo,
   de 1,87 a 0,04).

## Método

### Dispositivo y entorno

- iPhone 14 de Jürgen («iPhone de JURGEN», iPhone14,7, iOS 27.2.1), **por cable a la Max**, desbloqueado y con bloqueo
  automático en «Nunca». Al 100 % de batería y cargando: el estado térmico se lee como tendencia, no como el de un uso
  sin cable (Jürgen pidió seguir con cable, 09:05).
- Mac: la Max, Xcode con `xcrun xctrace` 27, `devicectl`, Device MCP (CLI `device-mcp-cli`).
- Sin simulador en ninguna medición.

### Las dos Yala medidas

| App | Qué es | Base | Para qué |
|---|---|---|---|
| **Yala 2.3 (11) de TestFlight** (`com.jurgenschmidt.yala`) | La app publicada en TestFlight, sin símbolos (no hay archivo del build 11 en la Max ni en la Mini) | 0 movimientos, 2 cuentas, 1 presupuesto, 1 pago planificado, 1 borrador, 733 filas de tipo de cambio, 0 grupos | El costo fijo de volver, sincronización incluida |
| **Yala Dev, copia de perfilado** (`com.jurgenschmidt.yala.dev`) | `origin/2.3` en `b5c6e98c5` (el commit del build 11), configuración `Release-Dev` optimizada (whole-module) con `DEBUG` encendido de forma temporal — `Release-Dev` no compila sin `DEBUG` (`CloudSyncDebugView`, `iCloudSyncSettingsView`) | Almacén de pruebas `YalaModel-UITest`: **16.004 movimientos** (2016-2026), 9 cuentas, 24 presupuestos, 34 pagos planificados, 11 borradores, 13 categorías, 20 etiquetas, 5.123 filas de tipo de cambio, 0 grupos | Lo que crece con los datos; símbolos y marcas propias |

Sesgo conocido de la copia de perfilado: con `DEBUG` corren los `print` de diagnóstico; son una fracción pequeña de las
muestras (no aparecen en el top de ninguna ventana). Se abre con `-uitest -uitest-skip-onboarding` (sin reset): ese
almacén no sincroniza con la nube, así que la sincronización solo se mide en la de TestFlight.

Los conteos se midieron copiando los almacenes del App Group con `devicectl` y contando con `sqlite3`.

### Cómo se condujo

Un guion desde la Mac (`scripts/ciclos.sh`, `scripts/pantallas.sh`):

- **Irse y volver sin relanzar**: `devicectl device process launch <otra app>` y luego `… <Yala>`; medido que el pid de
  Yala no cambia. Fuera, 5-30 s según una secuencia fija (8, 22, 12, 30, 5, 18, 25, 10, 15, 28 s). No hay app de banco
  en el iPhone 14: se alternó con Safari, Ajustes, Notas, Calculadora y Mapas.
- **Scroll rápido**: en A y B2, `device-mcp-cli scroll` (consulta el árbol de accesibilidad en cada gesto, lo que añade
  CPU a la app: en A, `axauditd` subió al 17 %); desde C, `device-mcp-cli swipe` por coordenadas en 90 ms, sin consultar
  accesibilidad: 6 flicks abajo y 6 arriba en ~1,8 s.
- **Marcas temporales** (`os_signpost` `app.yala.perf/temp-rendimiento` y, en la pasada H, `print` por consola): vuelta a
  primer plano, aviso de cambio remoto, `dataVersion` (con el fichero y la línea de quien lo sube), recargas y cálculos
  del Panel, Estadísticas y Grupos, foto de widgets. **Revertidas antes del PR.**
- **Dos interruptores temporales** por argumento de lanzamiento, para medir el «después» en el mismo iPhone:
  `-perfTempSinPulso YES` (no arranca el pulso de la gráfica) y `-perfTempSinRecargaAlVolver YES` (el Panel, Estadísticas
  y Registros no recargan al volver y Spotlight no se reindexa). **Revertidos antes del PR.**

### Pasadas (hora de Lima)

| Pasada | Hora | App y datos | Instrumentos | Escenario |
|---|---|---|---|---|
| A | 08:47-08:57 | TestFlight, casi vacía | Activity Monitor (todos los procesos), Thermal State, Hitches | 10 ciclos irse/volver + scroll en el Panel |
| B | 09:08-09:18 | Yala Dev 16 k | — (Instruments no llegó a engancharse: «Cannot find process for provided pid») | 10 ciclos; sin traza, pero iOS dejó un `cpu_resource` a las 09:12 |
| B2 | 09:19-09:30 | Yala Dev 16 k, lanzada por Instruments | Time Profiler, os_signpost, Hitches, Thermal State | 10 ciclos + scroll en el Panel |
| C | 09:36-09:41 | Yala Dev 16 k, abierta normal | Activity Monitor, Thermal State, Hitches | 10 ciclos; **iOS la mató a las 09:38:44** y el resto corrió sobre la app vacía: contaminada, solo vale el cierre |
| D | 09:48-09:54 | Yala Dev 16 k, lanzada por Instruments | Time Profiler, os_signpost, Hitches, Thermal State | 3 rondas: irse 10 s, volver y scroll rápido en Panel, Registros, Estadísticas (Resumen, Tendencias, Distribución), Pagos planificados, Grupos y Bandeja |
| E | 09:56-10:00 | Yala Dev 16 k | Time Profiler, Hitches | Reposo: 30 s quieta en Panel (arriba y con la tendencia a la vista), Registros, Más, Panel |
| F | 10:02-10:06 | Yala Dev 16 k, abierta normal | Activity Monitor, Thermal State | 8 ciclos; **iOS la mató a las 10:04:32** al sexto |
| G | 10:11-10:15 | Yala Dev 16 k + `-perfTempSinPulso` + `-perfTempSinRecargaAlVolver` | Time Profiler, Hitches, Thermal State | Reposo 30 s + 6 ciclos |
| H | 10:25-10:29 | Igual que G, con consola | Consola (`devicectl --console`) | 6 ciclos: quién sube `dataVersion` y quién pide cada recálculo |
| I | 10:29-10:33 | Yala Dev 16 k | SwiftUI | Reposo 20 s + 2 ciclos |
| J1 / J2 | 10:32-10:36 / 10:36-10:39 | Yala Dev 16 k / con los dos interruptores | Power Profiler | Reposo 45 s + 3 ciclos |

Las trazas completas (`.trace`, 35-150 MB cada una) no van al repo: quedan en
`~/Claude/entregas/2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14/trazas/` de la Max. En `datos/` van los
extractos numéricos y en `scripts/` los guiones que los sacan.

## Mediciones

### 1. Volver a Yala, ciclo por ciclo

**Yala Dev 16 k (B2), ms de hilo principal en cada segundo tras volver** (`datos/B2.matriz_vuelve.json`):

| Ciclo | Fuera | Bloque continuo ≥ 90 % | CPU del hilo principal en los 36 s siguientes |
|---|---|---|---|
| 1 | 8 s | 20 s | 33,0 s |
| 2 | 22 s | 17 s | 32,3 s |
| 3 | 12 s | 23 s | 33,2 s |
| 4 | 30 s | 16 s | 31,6 s |
| 5 | 5 s | 19 s | 32,8 s |
| 6 | 18 s | 25 s | 34,4 s |
| 7 | 25 s | 16 s | 32,5 s |
| 8 | 10 s | 18 s | 31,6 s |
| 9 | 15 s | 24 s | 34,6 s |
| 10 | 28 s | 17 s | 32,6 s |

No crece con los ciclos: es el mismo trabajo completo cada vez. Reparto de los 24 s siguientes a volver, sumando los 10
ciclos (`datos/B2.volver24.txt`): **recálculo del Panel 65 %**, reindexado de Spotlight 7,8 %, animación continua 6,7 %,
widgets, tasas y sincronización < 1 % cada uno.

**Yala Dev abierta normal, sin Instruments (F)** (`datos/F_cpu_memoria_por_ciclo.txt`): 6,8-7,6 s de CPU en los ~8 s de
cada vuelta (86-95 % de un núcleo), y **10-14 s de CPU con otra app delante** en los ciclos 2-4. Memoria al volver:
238 → 241 → 266 → 319 → 340 MiB, y 363 MiB antes del cierre del vigilante.

**Yala de TestFlight casi vacía (A)** (`datos/A_cpu_por_ventana.txt`): quieta delante 1,4 %, en fondo 1,2 %, los 2 s
de volver 24 %, scroll 34 % (inflado por la herramienta de accesibilidad). Memoria estable en 56-57 MiB. Sin datos, volver
cuesta poco: el problema crece con el historial.

### 2. Reposo: la animación que no para

`datos/E_reposo_por_pantalla.txt`, Yala Dev 16 k quieta, hilo principal:

| Pantalla delante | Hoy | Con `-perfTempSinPulso` (G) |
|---|---|---|
| Panel arriba | 38,1 % | **0,3 %** |
| Panel con la tendencia a la vista | 35,6 % | — |
| Registros | 34,9 % | — |
| Más | 35,4 % | — |

El 90-92 % de esas muestras cuelga de `ViewGraphDisplayLink.displayLinkTimer` (el reloj de animación de SwiftUI), con
`GlassEffectLayout` / `GlassContainer` en 12-14 %. Con Más delante sigue evaluándose
`TrendChartView.liveAnchorOverlay(proxy:)` en cada fotograma (`datos/E_que_se_anima_en_reposo.txt`): el Panel está
montado detrás y su pulso no se detiene.

### 3. Scroll rápido por pantallas (D)

`datos/D_por_pantalla.txt` y `datos/D_quien_ocupa_el_hilo_por_pantalla.txt`. Tras cada vuelta, con Estadísticas y
Registros ya abiertos una vez, el hilo principal está ocupado por el trabajo de otras pantallas mientras se hace scroll
en la que se ve:

| Pantalla con scroll | Hilo principal | Quién lo ocupa |
|---|---|---|
| Panel | 100 % | Estadísticas recalculando (50 %), foto de widgets (33 %), Spotlight (13 %), Registros (13 %) |
| Registros | 99 % | **cálculo del Panel (54 %)**, widgets (21 %) |
| Estadísticas › Tendencias | 100 % | cálculo del Panel (49 %), salud financiera (46 %), Estadísticas (31 %) |
| Estadísticas › Distribución | 51-97 % | animación (28 %), Distribución (17 %), Sankey (9 %) |
| Pagos planificados | 41-66 % | animación (22 %) |
| Grupos (sin grupos) | 13-85 % | presupuestos (14 %) |
| Bandeja | 73-100 % | cálculo del Panel (30 %), animación (16 %) |

Con el hilo al 100 % la app no pinta: el instrumento de tirones registra uno solo, largo, al final (2,0 s en el Panel de
la ronda 2). En B2, **los peores tirones fueron congelamientos de 12,2 a 19,8 s** durante el scroll que sigue a volver
(6 de 10 ciclos), con 2,8 tirones por segundo de scroll en total y una mediana de 57 pasadas fuera de pantalla por
fotograma (máximo 152). En la Yala de TestFlight casi vacía la mediana ya era de **65 pasadas fuera de pantalla** por
fotograma del Panel: el costo de render del cristal, las sombras y los recortes no depende de los datos.

Estadísticas tardó ~10 s en pasar del esqueleto a las cifras la primera vez (observado en pantalla a las 09:45).

### 4. Calor

| Pasada | Estado térmico |
|---|---|
| A (TestFlight, casi vacía) | Nominal 4 min 24 s → **Fair** desde las 08:52 hasta el final |
| B2, C, D, F, G (Yala Dev 16 k) | **Serious** de principio a fin |

Entre A y B2 corrió la pasada B (Yala Dev 16 k, 09:08-09:18) sin traza: es la que llevó el teléfono de Fair a Serious;
no se sabe el minuto exacto. Serious es el penúltimo nivel de iOS (después viene Critical) y es cuando el sistema empieza
a bajar la frecuencia. Con el cable puesto el teléfono suma algo de calor de carga; la comparación entre A y B2 se hizo
con el mismo cable.

### 5. Cierres y avisos de iOS

Copiados con `devicectl device copy from --domain-type systemCrashLogs`:

| Fecha y hora | Tipo | Qué dice |
|---|---|---|
| 26-nov 09:38:44 | `0x8BADF00D`, en segundo plano | «scene-update watchdog transgression … exhausted real (wall clock) time allowance of 10.00 seconds». Hilo principal en `SpotlightIndexService.desiredEntries` → `Account.keepsHistory` |
| 26-nov 10:04:32 | `0x8BADF00D`, en segundo plano | Mismo vigilante. Hilo principal en `PanelViewModel.performCalculation` → `calculateAccountPeriodExpenses` → `AccountSpendingLogic.spentByAccount` |
| 24-nov 14:14, 14:27, 19:35 · 25-nov 03:42, 04:26, 09:42 · 26-nov 09:12, 09:49, 09:59 | `cpu_resource` (Yala Dev, builds 7, 8, 9 y 11) | «90 seconds cpu time over 90-178 seconds (50-100 % cpu average), exceeding limit of 50 % cpu over 180 seconds» |

El aviso de las 09:12 salió de la pasada B, en la que Instruments **no** estaba enganchado: el consumo no es un efecto de
medir. Los del 24-25 son de sesiones de QA anteriores con Yala Dev.

### 6. Qué dispara cada recálculo (H, consola)

Con los dos interruptores puestos, la consola registró en 6 vueltas: **ningún recálculo al volver** y ningún aviso de
cambio remoto. El único recálculo vino de `PanelView.swift:1070` («tirar para actualizar»), disparado por el flick hacia
abajo del propio guion estando arriba del todo: un gesto que una persona también hace, y que cuesta un recálculo
completo de ~7 s. Al arrancar, `AppBootstrapper.swift:806` sube `dataVersion` y el Panel recalcula (7,0 s).

### 7. Energía (J1 contra J2, Power Profiler)

`datos/J_energia.txt`. Impacto de energía medio de Yala por segundo (la escala de Instruments), misma base de 16 k,
45 s de reposo y 3 ciclos:

| Ventana | Hoy (J1) | Sin pulso y sin recarga al volver (J2) |
|---|---|---|
| Reposo en el Panel | CPU 1,87 · pantalla 1,96 | CPU **0,04** · pantalla 2,00 |
| 10 s tras volver | CPU 25,15 · pantalla 1,56 | CPU **5,90** · pantalla 1,56 |
| Con otra app delante | CPU 3,73 | CPU **0,30** |

El consumo de batería del sistema (`%/h`) sale en 0 porque el teléfono estaba cargando: por eso se compara el impacto
por proceso. La GPU no se atribuye a Yala (el render lo hace `backboardd`).

### 8. SwiftUI: cuántas actualizaciones de vista (I)

`datos/I_swiftui_actualizaciones.txt`. Con el Panel quieto: **5.691 actualizaciones de SwiftUI por segundo**, casi todas
efectos de opacidad y escala animados (`_OpacityEffect`, `_ScaleEffect` a ~145-149 por segundo, el ritmo de una
animación a 60 Hz) que se propagan por los contenedores (`_VStackLayout`, `_ZStackLayout`, `SystemScrollView`…). En los
10 s tras volver: 8.793 por segundo, con el texto y los estilos de las tarjetas que se repintan con el recálculo.

### 9. Lo que se comprobó y se descartó

| Sospecha | Resultado |
|---|---|
| Tareas, timers u observadores que se acumulan con cada vuelta | **Descartada**: la CPU por vuelta es la misma en el ciclo 1 y en el 10 (A, B2) |
| `AppPreferences` relee todo en cada escritura de `UserDefaults` | **Descartada** como causa: no aparece en ninguna ventana (< 0,1 %) |
| `WidgetCenter.reloadAllTimelines` en cada vuelta | **Descartada** como causa de calor: corre al irse (`YalaApp.swift:257`, `flushPendingUpdate`), ~0,7 s por salida con 16 k, y una vez al arrancar |
| Bucle «guardado → aviso remoto → pendientes → `dataVersion` al volver» | **No confirmada** en el almacén de pruebas (H: cero avisos). Sin medir con la nube real |
| Sincronización con la nube al volver | **Menor**: en la Yala de TestFlight, volver cuesta 24 % durante ~2 s; no aparece en los perfiles. Sin medir con historial grande en la nube |
| Formateadores creados en `body` | **Descartada**: no aparecen en el top de ninguna ventana |
| Red al volver | **Sin medir** con el instrumento Network (ver «Lo que no se midió») |

## Causas raíz, ordenadas por impacto medido

Las coordenadas son de `origin/2.3` (`b5c6e98c5`).

1. **Cada vuelta a primer plano recarga y recalcula las pantallas montadas, sin mirar si algo cambió.**
   `Yala/App/Views/Panel/PanelView.swift:522-524` (`onChange(of: scenePhase)` → `.active` →
   `viewModel.reloadAndRecalculate()`), y el mismo molde en `Statistics/DetailContainerView.swift:306`,
   `Records/RecordsStandaloneView.swift:171`, `Groups/GroupsContainerView.swift:469`, `Groups/GroupDetailView.swift:248`
   y `Reports/FinancialReportView.swift:143`. La card zpgm (`PanelReloadFreshness`) solo puso la firma de frescura en el
   `onAppear`; este camino quedó fuera. Evidencia: B2 (16-25 s al 100 % por vuelta, 65 % del Panel), D (pantallas ocultas
   recalculando durante el scroll de otra), G/H (sin esa recarga, 0 recálculos al volver y ~1,5 s de CPU en 20 s).
2. **Un recálculo del Panel cuesta 7 s (solo) a 12-16 s (compitiendo) en el hilo principal, de una vez.**
   `Yala/App/ViewModels/PanelViewModel.swift:3199` `performCalculation()`, síncrono (solo la lectura va por tramos). En
   el bloqueo de 12,3 s del ciclo 10 de B2 (`datos/B2_ciclo10_bloqueo_12s.txt`): tendencia (`calculateTrendData`,
   `:1542`) 43 %, salud financiera (`FinancialScoreCalculator.calculate` / `calculateRhythm`, que ordena todos los
   movimientos) 37 %, presupuestos (`calculateBudgetsWidget`, `:2843` → `BudgetsViewModel.filterTransactions`, `:719`:
   cada uno de los 24 presupuestos recorre los 16 mil movimientos) 27 %, y leer `TransactionItem.date` de SwiftData 40 %
   repartido dentro de todos. Por eso cualquier disparador —volver, tirar para actualizar, un guardado— congela la app.
3. **El pulso de la gráfica de tendencia anima sin fin y obliga a repintar toda la app cada fotograma.**
   `Yala/App/Views/Panel/TrendChartView.swift:394` (`onAppear` → `pulseAnimate = true`) y `:461-467`
   (`.animation(.easeInOut(duration: 1.4).repeatForever(...))` dentro del `.chartOverlay`). Cada fotograma invalida el
   grafo de SwiftUI y el cristal (`GlassEffectLayout`) se vuelve a calcular. Evidencia: E (35-38 % en reposo en todas las
   pantallas, 90 % en el reloj de animación) contra G (0,3 %). Con el Panel montado detrás, el pulso sigue aunque no se vea.
4. **Lo que arranca al volver sigue en el hilo principal al irse, y iOS mata la app.** Dos `0x8BADF00D` en segundo plano
   hoy. Uno dentro del reindexado de Spotlight (`Yala/App/AppBootstrapper.swift:2568` →
   `Services/Spotlight/SpotlightIndexService.swift:132` `desiredEntries`, que lee todos los movimientos con sus
   relaciones en cada vuelta, ~1,8 s con 16 k) y otro dentro de `PanelViewModel.performCalculation`. Quien vuelve a Yala
   y se va al banco a los pocos segundos la encuentra cerrada en la vuelta siguiente: arranque en frío, que cuesta más.
5. **En segundo plano sigue gastando.** F: 10-14 s de CPU con otra app delante; B2: 46 % sostenido en fondo (con
   Instruments; en F, sin él, también). Son los recálculos en vuelo y el reloj de animación. Es lo que miden los 9 avisos
   `cpu_resource` de iOS.
6. **Render caro también sin datos.** Mediana de 57-65 pasadas fuera de pantalla por fotograma del Panel (máximo 152),
   también en la Yala de TestFlight vacía; la mitad de sus tirones dicen «render caro». Cristal, sombras y recortes por
   tarjeta. Es el costo de fondo del scroll aunque se arreglen 1-5.
7. **La memoria sube ~25 MiB por vuelta** (F: 238 → 363 MiB en 5 ciclos). Causa sin aislar; lo más probable es la
   relectura completa de movimientos en cada recarga (Panel, Spotlight) que deja vivas las filas de SwiftData.

## Lotes propuestos

Propuesta, no cards: Jürgen decide qué se encola. Cada lote se mide después con los mismos guiones (`scripts/`), en el
mismo iPhone 14 y con el mismo almacén de 16 k.

### Lote 1 — Volver no recalcula lo que no cambió (primero; el mayor impacto)

1. Panel: en `.active`, `reloadOnAppearIfStale()` (la firma de `PanelReloadFreshness`) en vez de
   `reloadAndRecalculate()` (`PanelView.swift:524`).
2. Estadísticas, Registros, Grupos, detalle de grupo e Informes: el mismo cambio, con su propia firma
   (`DetailContainerView.swift:306`, `RecordsStandaloneView.swift:171`, `GroupsContainerView.swift:469`,
   `GroupDetailView.swift:248`, `FinancialReportView.swift:143`).
3. Una pantalla oculta no recalcula al volver: lo marca como pendiente y calcula al aparecer.
4. Spotlight: reindexar solo si cambió algo desde la última vez (contador de guardados), no en cada vuelta
   (`AppBootstrapper.swift:2568`).
5. Pin: un test de cableado que prohíba `reloadAndRecalculate()` a pelo dentro de un `onChange(of: scenePhase)`.

**Mejora esperada** (medida con los interruptores, G): de ~33 s de CPU en los 36 s siguientes a volver a ~1,5 s en 20 s
(−95 %); el scroll tras volver deja de congelarse. **Cómo se mide:** `scripts/pasada.sh` con 10 ciclos sobre Yala Dev
16 k (Time Profiler + Hitches): bloque ≥ 90 % tras volver = 0 s, ningún tirón > 250 ms.

### Lote 2 — Sin animaciones infinitas fuera de la vista (rápido, impacto grande en reposo)

1. Pulso de la tendencia: que dé un par de latidos y se detenga, o que solo anime con la gráfica visible
   (`TrendChartView.swift:394`, `:461-467`); mantener «Reducir movimiento».
2. Detener toda animación `repeatForever` cuando su pestaña no se ve (`\.isRootPageShown`) o la app no está activa.
3. Barrido de las otras animaciones infinitas (`SkeletonView.sweep`, `FABStackView`, `YalaSpark`, `GroupCaptureChrome`,
   `VoiceListeningPanel`): confirmar que se paran al ocultarse.
4. Sacar el resumen para VoiceOver (`spokenSummary`) y el mapeo de puntos del `body` que se repinta (precalcularlos).
5. Pin: test que prohíba `repeatForever` sin una condición de visibilidad.

**Mejora esperada** (G): reposo de 35-38 % a ~0,3 % de un núcleo. **Cómo se mide:** pasada E (30 s quieta en Panel,
Registros y Más) → < 2 %; Power Profiler en reposo (J1 contra J2).

### Lote 3 — No morir en segundo plano

1. Al pasar a `.background`, cancelar o pausar los recálculos y el reindexado en vuelo (ya hay `setBackground`; hoy no
   corta un `performCalculation` ya empezado).
2. Spotlight fuera del hilo principal (contexto propio) y por tramos.
3. Tirar para actualizar: sin recálculo completo si nada cambió (firma).
4. Medir el arranque en frío tras un cierre (Panel listo en < 3 s con 16 k).
5. Revisar en Sentry y en los `.ips` de TestFlight si hay `0x8BADF00D` en segundo plano en producción.

**Mejora esperada:** cero cierres del vigilante en 10 ciclos con salidas a los 2-5 s de volver. **Cómo se mide:** guion
de ciclos con fuera = 3 s y `devicectl … systemCrashLogs` sin `Yala-*.ips` ni `cpu_resource` nuevos.

### Lote 4 — El recálculo del Panel deja de bloquear

1. `performCalculation` por tramos que cedan el hilo (como ya hace la lectura), o fuera del hilo principal sobre
   valores copiados (no sobre `@Model`).
2. Presupuestos: un solo recorrido de los movimientos para los 24 (índice por fecha/categoría) en vez de uno por
   presupuesto (`BudgetsViewModel.filterTransactions`).
3. Salud financiera: `calculateRhythm` sin ordenar todos los movimientos; reusar los días ya agrupados.
4. Leer `date`, `amount`, `account` y `category` de cada `TransactionItem` una vez por recálculo (como
   `FlujoMotorMesEntrada.movimientos`) y pasar valores, no modelos.
5. Que cada recálculo cancelable pueda abandonarse al pasar a segundo plano sin dejar el hilo ocupado.

**Mejora esperada:** el recálculo completo de 7 s pasa a pasos de < 50 ms (sin congelar) y su total baja por los
recorridos repetidos (estimación, no medida). **Cómo se mide:** marcas `Panel.performCalculation` (intervalo) y
`potential-hangs` del Time Profiler al arrancar y al tirar para actualizar: ningún bloqueo > 250 ms.

### Lote 5 — Render del scroll (cristal, sombras, recortes)

1. Medir por tarjeta del Panel cuántas pasadas fuera de pantalla añade (Hitches › renders) y quitar las sombras sin
   `shadowPath` equivalente.
2. Agrupar el cristal de cada barra en un `GlassEffectContainer` y evitar cristal dentro de filas que se desplazan.
3. Filas de Registros: la sombra propia de `ListRowCardModifier` en cada fila es una pasada por fila.
4. `compositingGroup`/`drawingGroup` donde el contenido es estático.
5. Objetivo: mediana < 20 pasadas fuera de pantalla por fotograma.

**Mejora esperada:** menos de 0,5 tirones por segundo de scroll (hoy 2,8). **Cómo se mide:** pasada D (3 rondas por
pantalla) con Hitches; mediana y máximo de pasadas fuera de pantalla.

### Lote 6 — Memoria por vuelta (investigar primero)

1. Allocations en 10 ciclos para aislar qué crece (~25 MiB por vuelta).
2. Comprobar si las recargas completas dejan vivas las filas de SwiftData (contexto que no se resetea).
3. Corregir lo que aparezca y fijarlo con un test de memoria por ciclo si es posible.

**Cómo se mide:** Activity Monitor en 10 ciclos: memoria estable (± 10 MiB) tras el ciclo 2.

**Orden recomendado:** 1 → 2 (los dos son cambios chicos y juntos quitan casi todo el calor) → 3 → 4 → 5 → 6.

## Lo que no se midió, y por qué

- **Network**: no se corrió. La vuelta en la Yala de TestFlight cuesta 24 % durante ~2 s y la sincronización no aparece
  en los perfiles; el almacén de 16 k no sincroniza. Si tras los lotes 1-2 queda calor con la nube real, es lo siguiente.
- **Allocations / Leaks**: no se corrió; la memoria se midió con Activity Monitor (lote 6).
- **La Yala de TestFlight con historial grande**: el iPhone 14 tiene la cuenta de pruebas casi vacía. La Yala real de
  Jürgen vive en su iPhone personal.
- **Sin cable**: Jürgen pidió seguir con cable; los estados térmicos incluyen la carga.

## Archivos

- `datos/`: extractos por pasada (CSV de eventos con hora de Lima, matrices por segundo, perfiles por ventana, marcas).
- `scripts/`: los guiones de conducción y de análisis (Python sobre los XML de `xctrace export`).
