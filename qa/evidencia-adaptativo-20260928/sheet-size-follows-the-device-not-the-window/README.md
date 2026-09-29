# Evidencia · sheet-size-follows-the-device-not-the-window (2026-09-28/29)

Capturas antes y después del paso 4 del carril adaptativo: tres hojas con detent medio en el iPhone más grande, en
el iPad a pantalla completa y en el iPad con la ventana de Yala estrechada.

## Cómo se sacaron

- Simuladores del carril, iOS 27.0, por UDID: `YalaLane-Adapt-iPhone-ProMax` (`A918242C…`) y
  `YalaLane-Adapt-iPad-Pro-13` (`AE7C6D3F…`, creado en esta sesión con la receta del §6.2). Corridas en cola con
  `qa/scripts/sim-lock.sh`; sin Cola A viva. Texto del sistema en tamaño por defecto.
- Un XCUITest temporal (`ZZSheetSizeCaptureUITests`, borrado antes del commit) lanzaba con `-uitest-seed grupos` y Pro,
  abría cada hoja y guardaba la pantalla en el host.
- «Antes» es `2.1` en `435bd8eb`; «después», el árbol del PR. El mismo runner de test para los dos: el del «antes»
  se sustituyó por el recompilado, porque un XCUITest no enlaza el código de la app.
- **Ventana estrecha** (`11`-`13`): en Ajustes del iPad simulado, Multitarea y gestos → **Apps en ventanas**. El
  test arrastra la esquina inferior derecha de la ventana hasta el 40 % del ancho. Con eso la app pasa a pestañas
  abajo, que es el tamaño compacto.
- JPG a 320 px de ancho. Nombre: `<dispositivo>__<nn>-<hoja>.jpg`.

| nn | Hoja | Detent pedido |
|---|---|---|
| 01 | Detalle de registro (Registros → fila) | medio |
| 02 | Selector de fecha de Nuevo registro (chip «Hoy») | medio y grande |
| 03 | Selector de período de Presupuestos («Este mes») | medio |
| 11-13 | Las mismas tres, con la ventana del iPad estrechada; `…-registros`, `…-panel` y `…-presupuestos` son la pantalla antes de abrir la hoja | |

## Lo que se comprobó

Comparación píxel a píxel de los PNG originales, antes contra después (umbral 2 %):

| Dónde | Resultado |
|---|---|
| iPhone Pro Max, las tres hojas | **Idénticas.** 01 y 02 difieren en ~6.200 px, todos en la barra de inicio del sistema (y 2829-2844); 03, cero |
| iPad a pantalla completa, las tres hojas | **Idénticas, grandes como hoy.** 01 y 03, cero; 02, 830 px en el punto «Hoy» animado del gráfico de fondo |
| iPad en ventana estrecha, antes de abrir la hoja | **Idénticas** (0, 0 y 1.038 px de animación): mismo ancho de ventana en las dos corridas |
| iPad en ventana estrecha, la hoja | **Cambia, que es el arreglo.** Antes, las tres salían a toda la altura con fondo opaco; ahora salen con los detents de iPhone (medio) y el fondo transparente de una hoja parcial |

## Lo que no se pudo capturar

- **iPhone Duo abierto**: no hay simulador del Duo en esta Mac (hace falta Xcode 27.1). Queda en
  `iphone-duo-native-app`.
- **Mac** (`isiOSAppOnMac`): no se ejecutó; el test unitario fija que en Mac las hojas siguen siendo grandes con
  cualquier tamaño de ventana.
