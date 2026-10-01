# Evidencia · iphone-large-models-use-the-extra-width (2026-10-01)

Paso 10 del carril adaptativo (fase iPhone): los iPhone grandes enseñan más sin cambiar nada de sitio.

## Cómo se sacaron

- Simuladores del carril, iOS 27.0, por UDID: `YalaLane-Adapt-iPhone-SE` (`C248A9E8…`) y
  `YalaLane-Adapt-iPhone-ProMax` (`AACA53D7…`). Corridas en cola con `qa/scripts/sim-lock.sh`, sin Cola A viva.
- Un XCUITest temporal (borrado antes del commit) lanza con `-uitest-seed realista`, Pro, por deeplink, recorre las
  pantallas y guarda la pantalla en el host.
- «Antes» es `2.1` en `f8c893cb3`, compilado con los ficheros de este cambio devueltos a su versión de `HEAD`;
  «después», el árbol del PR.
- Texto grande: `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` (AX5).
- Nombre: `antes|despues/<dispositivo>[-ax5]__<nn>-<pantalla>.jpg`. JPG con el lado mayor a 640 px; los diffs se hicieron
  sobre los PNG originales. `comparativa-promax-*.jpg`: antes a la izquierda, después a la derecha.

| nn | Pantalla | nn | Pantalla |
|---|---|---|---|
| 01 | Panel, arriba | 07 | Estadísticas › Tendencias |
| 01b | Panel, Tendencias | 07b | Tendencias, la gráfica |
| 01c | Panel, «Tus finanzas» desplegada (carrusel de cuentas) | 07c-e | Tendencias en «Este mes», con la Comparativa |
| 02-04 | Panel, desplazado | 08 | Tendencias, Flujo de efectivo |
| 05 | Registros | 09 | Estadísticas › Distribución |
| 06 | Estadísticas › Resumen | 10-12 | Planificación y Presupuestos |

## Qué cambia: el Pro Max

La gráfica de tendencia del Panel y las dos de Estadísticas › Tendencias (tendencia y Comparativa) pasan de 170 a
200 pt de alto: en el Pro Max miden ~376 pt de ancho y con 170 salían aplastadas. Lo fija `AdaptiveNavigationUITests` en el árbol de accesibilidad:
en el Pro Max el marco pasa de 195 pt; con el cálculo desactivado (mutante) se queda en 173,3 y el caso cae en rojo. El
marco de accesibilidad suma ~3,5 pt a la gráfica (173,5 en el SE). Lo demás de cada pantalla baja lo mismo; nada cambia de sitio ni de función.

## El SE: sin diferencias

Diff píxel a píxel (umbral 5/255, sin la barra de estado), antes contra después:

| | Pares a 0 px | Los demás |
|---|---|---|
| SE, texto por defecto | 10 de 18 | Panel (01-04) y Comparativa (07d): un recuadro de ~38 × 38 px, el punto animado «Hoy» de la gráfica. Distribución (09): la semilla fecha distinto las transacciones en cada arranque (Hogar 30 % → 32 %), el donut cambia de orden |
| SE, AX5 | 9 de 17 | Panel (03-04): el punto «Hoy». Tendencias (07-08): una franja a todo lo ancho de 160 px, la barra de chips, que queda desplazada distinto tras buscar el chip |

## Lo medido que NO cambia, y por qué

- **Carrusel de cuentas**: sigue a dos tarjetas en compacto. En el Pro Max tres saldrían a ~128 pt, bajo el mínimo de
  140 pt que el propio carrusel exige para cuatro en ancho, y en el SE con dos el nombre ya se corta
  («Cuenta Princ…», `antes/se__01c-panel-cuentas.jpg`). Además viene plegado por defecto.
- **Registros y Planificación**: ya enseñan más filas en el Pro Max por alto; por ancho no hay nada que añadir sin
  cambiar de sitio (`05`, `10-12`: 0 px en los cuatro tamaños).

## iPad (regresión)

`AdaptiveNavigationUITests.test_*TrendChart_growsWithTheWidth_onLargePhones` en `YalaLane-Adapt-iPad-mini`: verde, la
gráfica sigue en 170 en ancho regular.

## Lo que no se pudo capturar

- Distribución (09) en el Pro Max AX5: el chip no entra en pantalla tras diez deslizamientos de la barra. Pantalla que
  este cambio no toca.
