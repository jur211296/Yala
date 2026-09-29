# Evidencia · ipad-sidebar-and-list-detail-for-records-and-planning (2026-09-29)

Capturas antes y después del paso 5 del carril adaptativo (fase 1): barra lateral en la raíz y lista-detalle en
Registros y Planificación.

## Cómo se sacaron

- Simuladores del carril, iOS 27.0, siempre por UDID: `YalaLane-Adapt-iPad-mini` (`8BBAB498…`),
  `YalaLane-Adapt-iPad-Pro-13` (`AE7C6D3F…`), `YalaLane-Adapt-iPhone-SE` (`8803FA85…`) y
  `YalaLane-Adapt-iPhone-ProMax` (`CDA87FB8…`). Corridas en cola con `qa/scripts/sim-lock.sh`; sin Cola A viva.
- Un XCUITest temporal (`ZZAdaptiveSplitCaptureUITests`, borrado antes del commit) lanza con `-uitest-seed realista`
  y Pro, entra por deeplink en Registros y en Presupuestos, abre la primera fila y guarda la pantalla en el host.
- «Antes» es `2.1` en `49feb13f`, compilado desde una copia limpia (`git archive HEAD`); «después», el árbol del PR.
- Texto grande: `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` (AX5).
- Nombre: `<dispositivo>__<v|h>-<nn>-<pantalla>.jpg` (`v` vertical, `h` horizontal). JPG con el lado mayor a 640 px; las comparaciones de abajo se hicieron sobre los PNG originales.

| nn | Pantalla |
|---|---|
| 01 | Panel (raíz: barra lateral o pestañas) |
| 02 | Registros |
| 03 | Registros con el primer registro abierto |
| 04 | Planificación › Presupuestos |
| 05 | Planificación con el primer presupuesto abierto |

## Lo que se comprobó

| Dónde | Resultado |
|---|---|
| iPad Pro 13, horizontal | Barra lateral con las seis páginas y Buscar, sin Más. Registros y Planificación: lista (375 pt) y detalle a la vez |
| iPad Pro 13, vertical | Pestañas arriba (el `.automatic` de Apple en vertical) con la barra lateral a un toque. Lista y detalle a la vez |
| iPad mini, horizontal | Barra lateral + lista + detalle a la vez |
| iPad mini, vertical | No caben lado a lado (744 pt): el split superpone la lista sobre el detalle vacío, y al abrir un registro o un presupuesto la retira para que se vea entero. El botón de la barra la vuelve a sacar |
| iPhone SE y Pro Max, tamaño por defecto y AX5 | **Iguales antes y después.** Diff píxel a píxel (umbral 5/255) quitando la barra de estado: 0 px en 16 de 20 pares. Los otros cuatro: un importe que la semilla genera distinto en cada arranque (`Fijos casa` 2.479 / 2.596), el punto animado «Hoy» del gráfico del Panel, y antialiasing en el texto del detalle de presupuesto del Pro Max (el mejor alineamiento es 0,0: no hay desplazamiento). La barra de pestañas sigue siendo Panel · Estadísticas · Planificación · Más · Buscar |

**Sobre las capturas de iPhone.** Se sacaron con la iteración anterior de la raíz, que ocultaba pestañas con
`.hidden(_:)`. El gate encontró que eso tumba la app cuando la pestaña oculta es la seleccionada (entrada por
invitación, shell de solo grupos) y la versión final vuelve a QUITAR las pestañas, que es el mecanismo de `2.1`: en
compacta monta exactamente la lista de pestañas de `2.1`. Las capturas del iPad sí son de la versión final; el iPhone
final lo cubren `AdaptiveNavigationUITests` en el Pro Max y las 49 suites del gate.

Lo que costó llegar ahí, por si alguien vuelve a tocar el split: ver `.claude/rules/swiftui-ds.md`, «Layout adaptativo».

## Redimensionado con un registro abierto

En `YalaLane-Adapt-iPad-Pro-13` en horizontal, con Ajustes → Multitarea y gestos → **Apps en ventanas** activado
desde el propio XCUITest temporal, y el simulador borrado antes (`simctl erase` por UDID) para que la app arranque a
pantalla completa y no con el tamaño de ventana que recordaba de la sesión anterior:

| Captura | Qué se ve |
|---|---|
| `resize__r-00-arranque-pantalla-completa` | Registros a pantalla completa (1376 pt), barra lateral |
| `resize__r-01-pantalla-completa-registro-en-columna` | Registro abierto en su columna, al lado de la lista |
| `resize__r-02-ventana-375-registro-empujado` | Esquina arrastrada al 40 %: ventana de 375 pt, **pestañas abajo** (compacta) y **el mismo registro abierto**, empujado sobre la lista con «Atrás» |

**La vuelta a ancho no se capturó.** Con la ventana estrecha centrada, el arrastre de su esquina hacia la derecha trae
Ajustes al frente en vez de ensanchar Yala (la captura sale en blanco: es Ajustes arrancando). `app.frame` viene en
coordenadas de la ventana, no de la pantalla, así que XCUITest no sabe dónde está la esquina. Guion en el ticket.

Dos trampas medidas para quien lo repita: con la app ya en ventana, un arrastre de 3 pt de la esquina la **desmaximiza**
a una ventana por defecto (706 pt); y la ventana recuerda su tamaño entre arranques, así que sin borrar el simulador
la receta no parte de pantalla completa.

## Rendimiento

Instruments (**Time Profiler**, `xctrace record --attach`) sobre Registros en `YalaLane-Adapt-iPad-Pro-13` en
horizontal, con la semilla `pesado`, barra lateral + lista + detalle a la vez. Un XCUITest temporal desplazó la lista
seis veces hacia abajo abriendo registros por el camino y seis hacia arriba; 30 s grabados.

| Medida | Valor |
|---|---|
| Cuelgues (`potential-hangs`) | **0** |
| Riesgos de cuelgue (`hang-risks`) | **0** |
| Hilo principal ocupado, media de la ventana (26 s) | 23,5 % |
| Peor segundo | 456 ms de 1000 |
| Código propio en el hilo principal | ~37 ms en total: `RecordsStandaloneView.body` (37), `DetailContainerViewModel.computeTransactionDateRange` (36, ordena todas las fechas en cada `body`; preexistente), `RecordRowView.body` (21). La búsqueda del registro abierto no aparece |

El resto es SwiftUI/UIKit dibujando. **Animation Hitches** y la plantilla **SwiftUI** no se pueden grabar en el
simulador («Hitches is not supported on this platform»): los tirones de fotogramas se miden en un iPad de verdad.
La traza no se versiona (pesa y es de la sesión).

## Lo que no se pudo capturar

- **iPhone Duo**: no hay simulador del Duo en esta Mac (Xcode 27.1). Queda en `iphone-duo-native-app`.
