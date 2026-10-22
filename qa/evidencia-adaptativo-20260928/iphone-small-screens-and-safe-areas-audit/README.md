# Evidencia · iphone-small-screens-and-safe-areas-audit (2026-09-28)

Capturas antes y después del paso 3 del carril adaptativo: las pantallas del recorrido en el iPhone más pequeño (SE)
y el más grande (Pro Max), con el texto del sistema en tamaño por defecto (`large`) y en el máximo de accesibilidad
(AX5, `accessibility-extra-extra-extra-large`), y con el teclado abierto en los formularios.

## Cómo se sacaron

- Simuladores del carril, iOS 27.0, por UDID: `YalaLane-Adapt-iPhone-SE` (`AF88C006…`) y
  `YalaLane-Adapt-iPhone-ProMax` (`A918242C…`). Corridas en cola con `qa/scripts/sim-lock.sh`, y **ninguna con Cola A
  viva** a partir de las 18:14.
- Un XCUITest temporal (`ZZSmallScreenCaptureUITests`, borrado antes del commit) recorría las pantallas con
  `-uitest-seed grupos` y guardaba la pantalla en el host. El tamaño de texto se ponía con
  `xcrun simctl ui <UDID> content_size …`. Con Pro, salvo la suscripción, que se captura sin Pro porque es el muro de
  pago.
- «Antes» es `2.1` en `f1589562`, compilado desde un worktree aparte con el mismo guion; «después», el árbol del PR.
- JPG a 320 px de ancho. Nombre: `<dispositivo>-<tamaño>__<nn>-<pantalla>_<fotograma>.jpg`. El fotograma 1 es la
  pantalla al llegar; los siguientes, tras deslizar hacia arriba. `_0-teclado…` es el formulario con el teclado
  abierto; `…-scroll` es tras arrastrar por encima del teclado.

| nn | Pantalla | nn | Pantalla |
|---|---|---|---|
| 01 | Panel | 09 | Perfil |
| 02 | Registros | 10 | Bandeja |
| 03 | Detalle de registro | 13 | Suscripción (muro de pago) |
| 04 | Nuevo registro (con y sin teclado) | 14 | Nuevo presupuesto, con teclado |
| 05 | Planificación | 15 | Nueva cuenta, con teclado |
| 06 | Detalle de presupuesto | 16 | Éxito tras guardar un registro |
| 07 | Grupos | 17 | Borrador de la Bandeja y éxito tras aprobarlo |
| 08 | Detalle de grupo | | |

## Lo que se comprobó

- **Tamaño por defecto, sin cambios fuera de lo arreglado.** Comparación píxel a píxel de los PNG originales (fuzz
  2 %, sin la franja inferior del sistema): **35 de 52 fotogramas idénticos en el SE y 29 de 50 en el ProMax.** Los
  demás, revisados uno a uno:
  - **Cambian a propósito** (lo arreglado): Nuevo registro con teclado y, en el SE, las dos pantallas de éxito.
  - **Ruido de animación, de menos de 3000 px:** el punto «Hoy» del gráfico del Panel, la chispa de la suscripción,
    el cursor de los formularios con teclado, la entrada de las pantallas de éxito del ProMax y 28 px en el Perfil.
  - **Scroll:** el desplazamiento tras deslizar y la barra de pestañas, que el sistema minimiza o no al hacer
    scroll. Pasa igual en el Perfil, que no se tocó.
  Nuevo registro **sin** teclado sale idéntico en los dos iPhone.
- **Nuevo registro con teclado, en el ProMax:** el «antes» ya se salía unos 2 pt por arriba. Ahora arranca bajo la
  barra y se puede desplazar esos 2 pt.
- **En el SE (normal y AX5) y el ProMax (AX5)**, lo arreglado se ve en las capturas: ver la tabla del ticket.

## Lo que el guion no pudo capturar

- **Éxito tras guardar y tras aprobar, en el SE a AX5.** En el «después» se llega a «Cuenta» y a «Guardar» (fotogramas
  `04`), pero el XCUITest no consigue tocar el chip «Subcategoría», que queda a la derecha en una fila de
  desplazamiento horizontal. La Bandeja tiene otro problema, y ese sí es del producto: su ticket propio. Las dos
  pantallas de éxito arregladas se ven en el SE a tamaño normal y en el ProMax a AX5.
- **La guía de primeros pasos**: los recorridos se apagan bajo `-uitest`.
- **Las tarjetas de planes de la suscripción**: la configuración de StoreKit cuelga solo del `Run` del scheme, así
  que en test no cargan productos. Lo demás de la pantalla sí se ve.
- `promax-default__16-exito-registro_aviso-primer-gasto.jpg` es la corrida en la que, tras guardar, el Panel enseñó el
  aviso «¡Listo! Creaste tu primer gasto» en vez de la pantalla de éxito. Es un fallo previo; tiene su ticket.
