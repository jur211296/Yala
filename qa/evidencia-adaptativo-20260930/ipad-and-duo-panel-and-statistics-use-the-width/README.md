# Evidencia · ipad-and-duo-panel-and-statistics-use-the-width (2026-09-30)

Paso 8 del carril adaptativo (fase 2b): el Panel y Estadísticas aprovechan el ancho.

## Cómo se sacaron

- Simuladores del carril, iOS 27.0, siempre por UDID: `YalaLane-Adapt-iPad-Pro-13` (`1CCA105A…`),
  `YalaLane-Adapt-iPad-mini` (`58107B17…`), `YalaLane-Adapt-iPhone-SE` (`B7BA0730…`) y
  `YalaLane-Adapt-iPhone-ProMax` (`02D8473F…`). Corridas en cola con `qa/scripts/sim-lock.sh`; sin Cola A viva.
- Un XCUITest temporal (borrado antes del commit) lanza con `-uitest-seed realista`, Pro y español, entra por deeplink
  en Panel y en Estadísticas, recorre Resumen, Tendencias (sin y con comparación), Registros y un registro abierto, y
  guarda la pantalla en el host.
- «Antes» es `2.1` en `e662f898a`, compilado desde una copia limpia (`git archive HEAD`); «después», el árbol del PR.
- Texto grande: `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` (AX5).
- Nombre: `antes|despues/<dispositivo>[-ax5]__<v|h>-<nn>-<pantalla>.jpg` (`v` vertical, `h` horizontal). JPG con el lado
  mayor a 640 px; las comparaciones de abajo se hicieron sobre los PNG originales.

| nn | Pantalla |
|---|---|
| 01 | Panel, arriba |
| 02 | Panel, desplazado hasta Últimos registros |
| 03 | Estadísticas › Resumen |
| 04 | Resumen desplazado |
| 05 | Tendencias sin comparación (Todo el tiempo, el período de la semilla) |
| 06 | Tendencias con comparación (Este mes) |
| 07 | Estadísticas › Registros |
| 08 | Estadísticas › Registros con el primer registro abierto |

## Lo que se ve en iPad

| Dónde | Antes | Después |
|---|---|---|
| Panel, cabecera (Pro 13 y mini, las dos orientaciones) | saldo, acciones y «Tus finanzas» uno debajo de otro, con 60 % del ancho vacío | banda de dos columnas: saldo y acciones a la izquierda, «Tus finanzas» a la derecha. En el Pro 13 horizontal, Últimos registros ya asoma en la primera pantalla |
| Panel, Últimos registros | media fila, la otra media vacía | fila entera, las cinco filas en pares |
| Resumen | una columna de 1000 pt (barras de salud de ~900 pt) | [Salud financiera · Resumen inteligente], selector a lo ancho, [Promedio diario · las cuatro cifras], [Compromisos · Por necesidad] |
| Tendencias sin comparación | todo en una columna | [Tendencia · Flujo de efectivo], [Promedio por día · Análisis del período] |
| Tendencias con comparación | [Tendencia · Comparación] y el resto en una columna | lo mismo arriba y el resto también en pares |
| Registros (chip) | el registro se abría en hoja | se abre en un panel al lado de la lista (Pro 13 y mini horizontal); en el mini vertical (744 pt) lista y panel no caben y el panel tapa la lista, con su X para volver |

## iPhone: sin diferencias

Diff píxel a píxel (umbral 5/255) quitando la barra de estado, antes contra después, en el SE y el Pro Max con texto
por defecto y AX5: **0 px en 18 de 32 pares**. Los otros catorce, uno por uno:

| Pares | Qué cambia | Por qué no es layout |
|---|---|---|
| Resumen desplazado (04), SE, Pro Max y Pro Max AX5 | la pantalla entera | el gesto de desplazar no recorre siempre lo mismo (25, 37 y 58 pt). Alineando por ese desplazamiento: **0 px** en la franja central del SE y del Pro Max; en AX5 solo los botones flotantes fijos |
| Tendencias y Registros en AX5 (05-08) | la barra de chips | la barra horizontal de chips queda desplazada distinto tras buscar el chip; el resto, igual |
| Panel (01), Pro Max | 53 × 53 px | el punto animado «Hoy» de la gráfica |
| Registros (07-08), SE | los chips de etiquetas de una fila | salen en otro orden en cada arranque: es un bug aparte, `tag-chips-change-order-on-every-launch` |
| Tendencias con comparación (06), SE y Pro Max | trazo de la curva de la comparación | la semilla fecha distinto las transacciones del mes en cada arranque |

La barra de pestañas y los flujos del iPhone los cubren además `AdaptiveNavigationUITests` en el Pro Max y las suites
del gate.

## Redimensionado

En `YalaLane-Adapt-iPad-Pro-13` horizontal, con Ajustes → Multitarea y gestos → **Apps en ventanas** (activado desde un
XCUITest temporal, porque los simuladores se recrearon hoy): `AdaptiveNavigationUITests
.test_narrowingTheWindow_onStatistics_keepsTheChipThePeriodAndTheOpenRecord` elige Tendencias y «Este mes», estrecha la
ventana (pestañas abajo, una columna) y comprueba que siguen Tendencias y «Este mes»; vuelve a ancho y siguen; abre un
registro en el panel, estrecha, y el mismo registro sale en la hoja. Verde.

## Lo que no se pudo capturar

- **iPhone Duo a medio plegar**: no hay `YalaLane-Adapt-iPhone-Duo` en esta Mac (Xcode 27.1). Las rejillas son en pares
  y un impar se queda en la columna izquierda; comprobar que ninguna tarjeta cae en el pliegue queda en
  `iphone-duo-native-app`.
