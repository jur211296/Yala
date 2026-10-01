# Evidencia · iphone-landscape-headers-fill-the-short-screen (2026-10-01)

Hallazgo del paso 11 del carril adaptativo: con el iPhone girado (poco alto), las cabeceras de Registros y de
Estadísticas › Resumen se comían casi toda la pantalla. Ahora se compactan.

## Cómo se sacaron

- Simuladores del carril, por UDID: `YalaLane-Adapt-iPhone-SE` (`C248A9E8…`) y `YalaLane-Adapt-iPhone-ProMax`
  (`AACA53D7…`), en cola con `qa/scripts/sim-lock.sh` y sin Cola A viva.
- Un XCUITest temporal (borrado antes del commit) lanza con `-uitest-seed realista`, Pro, por deeplink; captura en
  vertical, gira a horizontal y captura otra vez, y apunta los marcos de la cifra, las salidas, la primera fila y la
  barra de pestañas.
- «Antes» es `2.1` en `a6b957630`; «después», el árbol del PR. Barra de estado fija a las 9:41.
- AX5: `xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`.
- Nombre: `antes|despues/<dispositivo>[-ax5]__<nn>-<pantalla>-<v|h>.jpg` (02 Estadísticas › Resumen, 04 Registros).
  JPG con el lado mayor a 640 px, horizontales puestas derechas; los diffs se hicieron sobre los PNG originales.
  `comparativa-*-horizontal.jpg`: antes a la izquierda, después a la derecha.

## Qué cambia (medido)

| Horizontal | Antes | Después |
|---|---|---|
| SE · Registros: primera fila | empieza en y = 358, bajo la barra (311) | y = 263,5: 47 de sus 66 pt sobre la barra, tocable |
| Pro Max · Registros: primera fila | asoma 19 pt sobre la barra | asoma 69 pt (centro 36 pt por encima) |
| SE y Pro Max · Estadísticas › Resumen | cinco filas apiladas; «Tu salud financiera» bajo la barra | banda: cifra a la izquierda, período y desglose a la derecha; asoma la tarjeta |

- **SE y Estadísticas en el Pro Max**: banda (cifra | período, entradas y salidas, recuento).
- **Registros en el Pro Max girado**: la lista va en columna (ancho regular) y ahí la banda no cabe; el período va al
  lado de la cifra y el desglose debajo.
- **AX5**: la banda no cabe a lo ancho y queda la pila de siempre con menos margen. Se llega deslizando, como antes.

## Vertical: sin cambios

Diff píxel a píxel de las 8 parejas en vertical (umbral 5/255, sin la barra de estado): **7 a 0 px**, incluidas las
dos del SE por defecto. La octava (Pro Max, Registros) difiere solo en una fila de la lista: el orden de dos etiquetas
(«Urgente · Trabajo» ↔ «Trabajo · Urgente»), que cambia entre arranques — ya tiene ticket,
`tag-chips-change-order-on-every-launch`.

## Lo que se ve y no se arregla aquí

- **El «+» flotante tapa el importe** de la primera fila en el iPhone girado (comparativas de Registros): es
  `floating-buttons-cover-row-amounts-on-ipad-landscape` (Cola B), anotado allí.
- **Con AX5 en el Pro Max girado la columna de la lista sigue estrecha**: ticket propio,
  `list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max`.
