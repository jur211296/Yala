# Evidencia · iphone-large-text-sizes-break-layouts (2026-09-28)

Capturas antes y después del paso 2 del carril adaptativo: las pantallas principales del iPhone con el texto del
sistema en tamaño por defecto (`large`) y en el máximo de accesibilidad (AX5,
`accessibility-extra-extra-extra-large`).

## Cómo se sacaron

- Simuladores del carril, iOS 27.0, por UDID: `YalaLane-Adapt-iPhone-SE` (`AF88C006…`) y
  `YalaLane-Adapt-iPhone-ProMax` (`A918242C…`).
- Un XCUITest temporal recorría las pantallas con `-uitest-seed grupos` y Pro, y guardaba la pantalla en el host.
  El tamaño de texto se ponía con `xcrun simctl ui <UDID> content_size …`. El test se borró antes del commit.
- «Antes» es `2.1` en `556f91ed`; «después», el árbol del PR. Las corridas pasaron por `qa/scripts/sim-lock.sh`.
- JPG a 320 px de ancho. Nombre: `<dispositivo>-<tamaño>__<nn>-<pantalla>_<fotograma>.jpg`. El fotograma 1 es la
  pantalla al llegar; los siguientes, tras deslizar hacia arriba.

| nn | Pantalla | nn | Pantalla |
|---|---|---|---|
| 01 | Panel | 06 | Detalle de presupuesto |
| 02 | Registros | 07 | Grupos |
| 03 | Detalle de registro | 08 | Detalle de grupo |
| 04 | Nuevo registro (gasto) · 04b transferencia | 09 | Perfil |
| 05 | Planificación | 10 | Bandeja |
| 11 | Siri y Atajos | 12 | Tutorial |

Las 11 y 12 no están en la lista del ticket: se capturaron para decidir sus topes de tamaño de texto.

## Lo que se comprobó

- **Tamaño por defecto, sin cambios visibles.** Comparación píxel a píxel de los PNG originales (fuzz 2 %, sin la
  franja del indicador de inicio): **36 de 45 fotogramas idénticos en el SE y 34 de 45 en el ProMax.** Los demás
  difieren por cosas del sistema, revisadas una a una: el desplazamiento del scroll tras deslizar (también varía en
  el Perfil, que no se tocó), el punto animado «Hoy» del gráfico del Panel, la barra de pestañas minimizada al
  hacer scroll y el buscador desplegado de Grupos.
- **AX5, ningún importe cortado.** Antes se cortaban los importes de Registros, «Últimos registros» del Panel, la
  cabecera de ingresos y gastos del Panel y de Registros, la Bandeja y las tarjetas de Grupos; el de las filas de
  presupuesto se partía carácter a carácter. Después van enteros, debajo del concepto.

## Lo que se vio y no se arregló aquí

En `tickets/backlog/large-text-leftovers-outside-the-main-iphone-screens.md`: los rótulos del selector de tipo y
de la fila de acciones de Nuevo registro, los filtros de la Bandeja, el widget pequeño de presupuestos y el eje
del gráfico de Tendencias del Panel, y la píldora «Nuevo registro» contra el borde en el SE. Ninguno tapa un botón.
