---
id: 2026-11-25-ui-nocturna-intermitentes
status: done
priority: high
area: "qa, ci, estadisticas, registros, panel, grupos"
created: 2026-11-25
updated: 2026-11-25
source: "Análisis de las tandas de UI en rojo del 25-nov (PR #1173); Jürgen pidió encolar los lotes a las 7:22 (Lima)"
---

# UI nocturna: cuatro pruebas intermitentes (Restablecer del Panel, convertir a grupo, cambiar categoría y chip del año pasado)

Cuatro pruebas de interfaz que el análisis del 25-nov marcó como intermitentes. Medidas una a una, solo una lo era de
verdad; de las otras, una escondía un fallo de la app y otra dependía del día del mes.

## Causas

- **Chip del año pasado** (`UXAudit22Lote11y16UITests.test_statistics_picksTheComparisonWithTheTwoChips`, rojo 3/3 el
  25-nov). **Fallo real de la app.** En Estadísticas › Resumen, al tocar «Con noviembre de 2025» la frase de encima pasaba
  a «Comparado con el 1–25 de noviembre de 2025», pero el chip resaltado seguía siendo «Con el mes anterior» (también para
  VoiceOver). Reproducido en local 1 de 1, así que no era el runner lento. Con el consejo de TipKit movido fuera de los
  chips el síntoma se invertía (chip al día, frase vieja): no es el consejo, es el selector que no se repinta entero.
  Tendencias ya lo tenía medido el 12-nov y lo tapaba rehaciendo el selector con `.id(sessionState.comparisonMode)`
  («causa sin aislar»). El Resumen opción B del 24-nov no cambió el tiempo de carga: lo que cambió es qué pieza se queda
  vieja.
- **Cambiar categoría** (`RecordsLote8UITests.test_changeSubcategory_marksTheCurrent_andUndoesFromTheNotice`, rojo los
  días 10, 13 y 25-nov). El 10 y el 25 la semilla `minimal` pone una transferencia arriba de Registros, y a una
  transferencia el menú no le ofrece «Cambiar categoría» (subcategoría de sistema). Reproducido en local el 25-nov, con
  vídeo: el menú trae Editar, Duplicar y Eliminar. Es la misma causa que encontró el lote de los rojos reales en otras dos
  pruebas. El 13-nov fue otro mensaje («La hoja no se titula…»): la hoja tardó más de 5 s.
- **Convertir a grupo** (`PersonalToGroupConversionUITests`, los dos casos, rojo 3/3 el 22, 23 y 24-nov con «El detalle
  no ofrece «Editar»»). En local pasa (1 de 1 antes del cambio). El log del CI del 24-nov enseña un `swipeUp` de media
  pantalla y luego los dos toques a la fila sintetizados sin que se abra ninguna hoja: la fila quedaba donde cayera, y
  `isHittable` da `true` también bajo una barra. Causa probable, no confirmada (el CI no guarda el vídeo de la UI).
- **Restablecer del Panel** (`PanelSectionsConfigResetUITests.test_reset_asksFirst…`). 3 de sus 4 rojos fueron el
  arrastre, no la alerta, y el último (22-nov) corrió sobre un commit sin el arreglo de ese día. Desde el arreglo, las
  nocturnas del 23, 24 y 25-nov no lo tienen en rojo.

## Arreglo

- Chip: Resumen y Distribución rehacen el selector atado al modo (`.id(sessionState.comparisonMode)`), como Tendencias.
  Cambio de la app, fuera del `toca:` del encargo, mínimo.
- Cambiar categoría: elige el primer GASTO de la lista (por la etiqueta, molde de `RecordsLote8BUITests`) y espera la
  hoja 10 s.
- Convertir a grupo: lleva la fila del «Bus» a la franja central con arrastres cortos antes de tocarla. Además, a la
  cuarentena con dueño y salida (ver abajo), porque el arreglo no se pudo comprobar contra el fallo.
- Panel: la alerta se espera por su título y por su botón, no `app.alerts.firstMatch`.
- Encontrado en el gate: `UXAudit22Lote08UITests.test_twoDeletionsInARow_undoBringsBothBack` borraba «la primera fila»;
  hoy, día 25, era una pata de transferencia, que se borra con la otra, y el aviso contaba «3 registros» y no «2». Mismo
  arreglo (el primer gasto). Fichero fuera del `toca:` del encargo.

## Verificación (Mini, simulador iPhone 17 Pro, iOS 27.2, 25-nov)

- Antes, sin cambios: Panel ✓, convertir a grupo ✓ ✓, cambiar categoría ✗, chip ✗ (los dos con el mensaje del CI).
- Después, 5 repeticiones seguidas de cada una: Panel 5/5, convertir 5/5, cancelar la revisión 5/5, cambiar categoría
  5/5, chip 5/5.
- Gate: build 2/2, unit 40 suites (213 pruebas), interfaz 13 clases (45 casos; el rojo de Lote 08 arreglado y su clase
  5/5), índice 29/29.

## Cuarentena

Los dos casos de `PersonalToGroupConversionUITests` entran en `qa/cuarentena.json` (dueño Frank, salida el 2026-12-09
o antes con tres nocturnas verdes seguidas): el arreglo no pudo comprobarse contra el fallo, que en local no sale.
