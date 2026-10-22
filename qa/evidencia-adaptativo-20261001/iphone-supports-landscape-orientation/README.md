# Evidencia · iphone-supports-landscape-orientation (2026-10-01)

Paso 11 del carril adaptativo: Yala gira a horizontal en iPhone (opción A del ticket).

## Cómo se sacaron

- Simuladores del carril, por UDID: `YalaLane-Adapt-iPhone-SE` (`C248A9E8…`) y `YalaLane-Adapt-iPhone-ProMax`
  (`AACA53D7…`). Corridas en cola con `qa/scripts/sim-lock.sh`, sin Cola A viva.
- Un XCUITest temporal (borrado antes del commit) lanza con `-uitest-seed realista` (Grupos con `grupos`), Pro, por
  deeplink. En cada pantalla captura en vertical, gira el aparato a horizontal y captura otra vez.
- «Antes» es `2.1` en `10a79d448` (solo vertical); «después», el árbol del PR. Barra de estado fija a las 9:41.
- Texto grande: `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large` (AX5).
- Nombre: `antes|despues/<dispositivo>[-ax5]__<nn>-<pantalla>-<v|h>.jpg`; `-vuelta` es la captura tras volver a
  vertical. JPG con el lado mayor a 640 px; los diffs se hicieron sobre los PNG originales. Las horizontales del
  «después» están puestas derechas. `comparativa-*-horizontal.jpg`: antes a la izquierda, después a la derecha.

| nn | Pantalla |
|---|---|
| 01 | Panel |
| 02 | Estadísticas › Resumen |
| 03 | Planificación (Presupuestos) |
| 04 | Registros |
| 05 | Un registro abierto (abierto en vertical, luego girado) |
| 06 | Formulario de nuevo registro con «123» escrito (escrito en vertical, luego girado) |
| 07 | Grupos |

## Qué cambia

- **Antes:** con el aparato en horizontal, Yala se quedaba en vertical (`antes/*-h.jpg` salen en vertical).
- **Después:** Yala gira. En el **SE** sigue en ancho compacto: la barra de pestañas de siempre, con «Más». En el
  **Pro Max** girado el ancho pasa a regular y se ve lo de la fase 1: pestañas con las seis páginas y sin «Más», y en
  Planificación, Registros y Grupos la lista y el detalle a la vez («Elige un… para verlo aquí»). En el Panel, la
  cabecera en banda de la fase 2b.
- **Lo abierto no se pierde al girar:** el registro abierto sigue abierto (05) y el importe escrito sigue escrito (06),
  en los dos iPhone, en los dos tamaños de texto y al volver a vertical (`-vuelta`).

## Vertical: sin cambios

Diff píxel a píxel de las 28 parejas en vertical (umbral 5/255, sin la barra de estado): **24 a 0 px**. Las otras:

- Panel en SE y Pro Max (texto por defecto): un recuadro de ~36-54 px, el punto animado «Hoy» de la gráfica.
- Grupos en SE y Pro Max (texto por defecto): el aviso «Tus grupos te esperan» sale en el «antes» y no en el
  «después». Es un aviso con tope semanal (`NudgeService`) y salió en la primera corrida de cada simulador, que fue
  la del «antes». No depende de la orientación.

## Lo que se ve y no se arregla aquí

- **Con poco alto, las cabeceras de Registros y Estadísticas llenan casi toda la pantalla**, y con AX5 en el Pro Max
  girado la columna de la lista queda estrecha. Se llega a todo deslizando. Ticket:
  `iphone-landscape-headers-fill-the-short-screen`.
- **El «+» flotante tapa el importe** del primer presupuesto en el Pro Max girado (`promax__03-planificacion-h.jpg`).
  Es el mismo caso que en iPad: `floating-buttons-cover-row-amounts-on-ipad-landscape` (Cola B), anotado allí.

## Navegación en horizontal (XCUITest)

`YalaUITests/IPhoneLandscapeUITests`: la app sigue al aparato y se navega por cuatro páginas en horizontal; un
registro abierto en vertical u horizontal sigue abierto al girar; el formulario a medias conserva el importe. Ver el
cuerpo del PR para las corridas por UDID y el control negativo.
