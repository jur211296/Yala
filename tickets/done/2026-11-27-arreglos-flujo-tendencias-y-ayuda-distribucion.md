---
id: 2026-11-27-arreglos-flujo-tendencias-y-ayuda-distribucion
status: done
priority: high
area: "cash-flow-plan, estadísticas, accesibilidad, pruebas de interfaz"
created: 2026-11-27
updated: 2026-11-27
source: "encargo del 27-nov (Jürgen aprobó el lote antes del barrido de la build 12 de 2.3); card «Flujo de caja: el orden de las partidas de «otros» repite el mismo cálculo caro (34 % del motor del mes)»; ticket 2026-11-27-tendencias-enlace-al-plan-queda-bajo-la-barra; hallazgo del PR «Textos del reparto»"
---

# Arreglos pre-build 12: motor del mes en Flujo de caja, enlace en Tendencias y ayuda en Distribución

## 1. Motor del mes del flujo de caja

- **Qué cambia para la persona:** el flujo de caja calcula sus meses más rápido; las cifras no cambian.
- `FlujoMotorMes.ordenarPartidas`: la clave de orden de cada partida de «otros» (el texto de su identificador, que
  sale por reflexión) se calcula una vez por partida y no en cada comparación. Mismo comparador sobre la misma clave:
  mismo orden, desempates incluidos.
- **Medido** en el simulador de la Mini (iPhone 17 Pro, iOS 27.2), 13 meses y 16 mil movimientos, mejor de 5:
  **232,1 ms antes → 146,1 ms después (−37 %)**.
- Pruebas (`YalaTests/ArreglosPreBuild12/MotorMesOrdenPartidasTests`): paridad contra una copia congelada del orden de
  antes con 8 semillas y casos de borde (totales iguales, el mismo total por caminos distintos, categoría, subcategoría
  y sin categoría, negativos, vacía, una); paridad sobre el motor entero con 3 semillas; testigo
  `_testClavesDeOrden` = una clave por partida, también en el motor entero; medición informativa.

## 2. Tendencias: «Afinar con un plan de flujo de caja»

- **Qué cambia para la persona:** nada; el enlace ya se alcanzaba desplazando. Era la prueba. Detalle en
  `tickets/done/2026-11-27-tendencias-enlace-al-plan-queda-bajo-la-barra.md`.

## 3. Ayuda «?» de las tortas de Distribución › Gráficas

- **Medido en la base:** el «?» existía como botón con su etiqueta («Distribución por categoría», la de
  `WidgetInfoButton`) y un toque de XcodeBuildMCP abría su hoja. Lo que fallaba era su **identificador**: el de la página
  del carrusel (`distribution_page_*`, puesto en el contenedor) pisaba el suyo, así que salía como
  `distribution_page_category` y no como `widget_info_categoriesPie`. Buscado por su id, «no estaba en el árbol». Y
  `axe tap` no llegaba a NADA en ese simulador ese día (tampoco al chip de Tendencias): el «no responde al toque» del
  hallazgo apunta al instrumento, no a la app. La hipótesis del hallazgo («queda dentro del botón de la tarjeta») no se
  sostiene: la tarjeta no tiene botón ni gesto que lo envuelva.
- **Arreglo:** cada página del carrusel es un contenedor de accesibilidad (`.accessibilityElement(children: .contain)`)
  con su id; lo de dentro conserva el suyo. Las páginas se siguen encontrando por su id.
- Prueba (`YalaUITests/ArreglosPreBuild12/AyudaTortasDistribucionUITests`): en las tres tortas, el «?» es un botón con
  etiqueta e id propios, se toca, abre su hoja y no abre el detalle de la categoría ni pone un filtro. Verde (48 s).
- **Panel:** sin cambios por construcción (el cambio no toca `CategoriesPieWidget` ni el Panel). La torta de categorías
  no está en el Panel por defecto, así que no hubo prueba manual allí.

## Fuera

- `YalaUITests/Flows/TutorialVideoRecordingUITests.swift` (solo corre al grabar los vídeos de tutoriales) buscaba el título
  de la torta y las filas de la leyenda por el id heredado de la página. Con el arreglo, esas dos búsquedas dejan de
  casar: hay que ajustarlas la próxima vez que se graben esos vídeos. No estaba en el alcance del encargo.
