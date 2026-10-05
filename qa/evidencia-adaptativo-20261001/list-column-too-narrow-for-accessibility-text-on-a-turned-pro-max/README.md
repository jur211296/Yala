# Evidencia · list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max (2026-10-01)

Con texto de accesibilidad (AX5) en el Pro Max girado, la columna de la lista se quedaba al ancho de un iPhone y
partía «Este mes» y el chip «Presupuestos». Ahora, donde no caben dos columnas que lean AX5, la página va con la lista
sola, como en vertical; donde caben (iPad Pro 13), la columna es más ancha.

## Cómo se sacaron

- Simuladores del carril, por UDID, uno arrancado cada vez y en cola con `qa/scripts/sim-lock.sh`:
  `YalaLane-Adapt-iPhone-ProMax`, `-iPhone-SE`, `-iPad-mini` y `-iPad-Pro-13` (iOS 27.0).
- Un XCUITest temporal (borrado antes del commit) lanza con `-uitest-seed realista`, Pro, por deeplink, y con AX5 por
  argumento (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`); captura en vertical,
  gira a horizontal y captura otra vez, y apunta los marcos del período, el chip, las barras y el «Elige un…». En
  Registros abre además el primer registro (`05-registro-abierto-h`).
- «Antes» es `2.1` en `7a9708657`, compilado en un worktree aparte; «después», el árbol del PR. Barra de estado a las
  9:41.
- Nombre: `antes|despues/<aparato>[-ax5]__<nn>-<pantalla>-<v|h>.jpg` (03 Planificación, 04 Registros, 05 registro
  abierto, 07 Grupos). JPG con el lado mayor a 640 px; los diffs se hicieron sobre los PNG originales.
  `comparativa-*.jpg`: antes a la izquierda, después a la derecha.

## Qué cambia con AX5 (medido)

| Aparato | Antes | Después |
|---|---|---|
| Pro Max girado | columna de 446 pt; «Este mes» en dos líneas (125 pt de alto contra 63 en vertical); el chip acababa en x = 470, cortado | lista sola a todo el ancho (832 pt); «Este mes» en una línea; los dos chips enteros; el registro se abre en hoja, como en vertical |
| iPad mini vertical (744) | la lista superpuesta sobre «Elige un…», que quedaba medio tapado | lista sola |
| iPad mini girado (853 junto a la barra lateral) | columna de 400; «Este mes» en dos líneas | lista sola |
| iPad Pro 13 (1032 vertical, 1096 girado) | columna de 400; «Este mes» en dos líneas | columna de 460 y detalle al lado; «Este mes» en una línea; al abrir un registro la lista se queda |
| SE | ventana compacta en las dos orientaciones | sin cambios (0 px) |

Lo que se probó y no valía, por si alguien lo intenta: ensanchar la columna en el Pro Max girado. A 520 pt pedidos el
split la midió 582 (suma la isla encima) y a 522 la puso **encima** de «Elige un…», no al lado. La de 446 de siempre
sí va al lado, pero ahí AX5 no cabe. Capturas de ese intento: no se guardaron en el repo.

## Texto por defecto: sin cambios

Diff píxel a píxel de las 27 parejas sin AX (umbral 5/255, sin la barra de estado en vertical): **23 a 0 px**. Las
otras cuatro, revisadas una a una, no son del cambio:

- tres son el orden de dos etiquetas («Urgente · Trabajo» ↔ «Trabajo · Urgente»), que cambia entre arranques —
  ticket `tag-chips-change-order-on-every-launch`;
- una es el título de Grupos en el iPad mini vertical, que sale pequeño o grande según la corrida: en otra pasada del
  «después» salió pequeño, igual que en el «antes».

Con AX5 en vertical, el Pro Max y el SE dan 0 px.
