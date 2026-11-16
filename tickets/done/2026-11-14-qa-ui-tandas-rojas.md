---
id: 2026-11-14-qa-ui-tandas-rojas
status: done
priority: high
area: "qa, xcuitest, ci"
created: 2026-11-14
updated: 2026-11-14
source: "encargo de Jürgen del 14-nov: arreglar las tandas de UI en rojo del QA de 2.3"
---

# Las seis tandas de UI en rojo del QA de 2.3

La nocturna de 2.3 del 14-nov (run 43608092892) dejó en rojo las tandas 1, 3, 6, 7, 8 y 9. El run salía verde porque
el paso de UI es `continue-on-error`. Medido con los logs de las nueve tandas y de las nocturnas del 13-nov (2.3) y del
12-nov (2.2): los siete casos que fallan sus tres vueltas fallaban igual el 13-nov y pasaban en 2.2. Son regresiones de
lo que entró en 2.3, no del runner: los siete se reproducen igual en el simulador local (iOS 27.2).

Los rojos que pasan al reintento (ver «Fuera») no ponen la tanda en rojo: `xcodebuild` sale 0.

## Causa por tanda

| Tanda | Caso | Causa | Qué se hizo |
|---|---|---|---|
| 1 | `TransactionFormDecided02UITests.test_transferFavorite_setsBothAccounts` | Test viejo: desde la decisión 69 de 2.3 la fila de favoritos solo enseña los del tipo elegido, y el test buscaba un favorito de transferencia estando en «Gasto». | El test entra por «Transferencia», con control de que antes del favorito falta algo. |
| 3 | `LargeTextSecondaryScreensUITests.test_ax3_settingsRowTitles_aOneWordTitleTakesOneLine` | Test viejo: medía con la fila «Favoritos», que la decisión 48 renombró «Registros favoritos» (ya no es de una palabra). | La fila de medida pasa a «Etiquetas». |
| 6 | `StatisticsHeroLikePanelUITests.test_statisticsHeroIsThePanelHero_inEveryTab` | **Fallo de la app.** El hueco vacío de «Buscar en Registros» (decisión 14) suma el espaciado de la pila: 43 pt bajo los chips en vez de 30. Medido: con esa línea comentada, verde. | Fallo conocido acotado a Registros + tarjeta; retirado al rebasar: el PR «Bugs de interfaz 2.3, lote 1» (#bf85633c22) lo arregló. |
| 7 | `PanelQuickActionsLargeTextUITests.test_accessibilityXXXL_everyQuickActionIsWhollyOnScreen` | **Fallo de la app.** Con AX5 el Panel se ensancha más allá de la pantalla. La sesión «Bugs de interfaz 2.3, lote 1» midió la causa real: la fila «fecha → hoy S/ … · %» bajo la gráfica de saldo, no el carrusel de cuentas. | Fallo conocido + tarjeta; retirado al rebasar: ese PR lo arregló. |
| 8 | `FormClarity23UITests.test_m1_largeText_theNoticeIsShown` | Test: con AX5 el importe cae bajo la barra de «Guardar» y el toque se lo quedaba la barra. | Se sube el formulario hasta dejar el campo encima de la barra. |
| 8 | `FormClarity23UITests.test_v3_largeText_manualEntryIsReachable` | **Fallo de la app**, el mismo de la tanda 7: el «+» flotante queda fuera de la pantalla (x = 405 en 402). | Fallo conocido + la misma tarjeta; retirado al rebasar. |
| 9 | `IPhoneLandscapeUITests.test_shortHeight_recordsHeaderLeavesTheFirstRowInView` | **Choque de diseño.** Los chips rápidos de Registros (decisión 15) dejan la primera fila 96 pt bajo la barra en el 17 Pro girado. | Fallo conocido en la última aserción + tarjeta con la pregunta para Jürgen. |

Los fallos conocidos iban con `XCTExpectFailure` acotado (bloque o `issueMatcher`), nunca el caso entero: cualquier
otro fallo del mismo caso sigue en rojo, y eran no estrictos. El arreglo de gphj y 4wqy («Bugs de interfaz 2.3, lote 1»)
aterrizó en 2.3 antes que este PR, así que al rebasar se quitaron sus tres expectativas: esos tres casos vuelven a ser
red completa. Queda solo la de c94z (tanda 9), que espera la decisión de Jürgen.

Y uno que salió al disparar el QA en la rama del PR (tanda 1, 3 de 3):
`UXAudit22Lote11y16UITests.test_statistics_picksTheComparisonWithTheTwoChips`. En la nocturna del 14-nov fallaba una
vez y pasaba al reintento; en local pasa. Carrera del test en el runner lento: tocaba el chip con el scroll aún en
movimiento y leía la frase sin esperar a que se recalculara. Ahora espera el chip quieto (`waitForSettledLayout`) y la
frase nueva.

## Tarjetas creadas

- `tablero-2-3-con-texto-al-maximo-el-panel-se-sale-gphj` (high): el Panel se sale de la pantalla con AX5.
- `tablero-2-3-hueco-de-mas-bajo-los-chips-en-estad-4wqy` (low): hueco de más bajo los chips en Registros.
- `tablero-2-3-iphone-girado-los-chips-rapidos-de-r-c94z` (medium, decide Jürgen): chips rápidos en horizontal.

## Probado

- Los siete casos en local, antes (5 rojos de 7, mismos mensajes que la nocturna) y después (7 de 7 verdes, con los
  cuatro fallos esperados registrados como tales).
- Workflow QA disparado en la rama del PR (run 43654676913): las nueve tandas con `** TEST EXECUTE SUCCEEDED **`;
  la tanda 2 tras repetirla (ver «Fuera»). Tras rebasar y quitar las expectativas de gphj y 4wqy, segundo disparo:
  resultado en el PR.

## Fuera

- Rojos que pasan al reintento en la nocturna del 14-nov (inestables, no ponen la tanda en rojo):
  `BalanceCalculatorReopenUITests`,
  `FlujoNecesariasLote08UITests.test_netSummary_capture`, `GroupsAssociationRowUITests.test_detachWithFailingWipe…`,
  `AdaptiveNavigationUITests.test_recordOpensBeside…`, `GroupOpeningBalanceMemberUITests`,
  `InboxNotificationTapUITests.test_background…`, `ProjectedFlowUITests.test_panel_projectionToggle…`,
  `AccountLinesUITests.test_savingsForm_offersLines`.
- Inestables de la tanda 2, sin tocar (este PR no los toca): en la primera corrida del PR fallaron sus tres vueltas
  `PanelSectionsConfigResetUITests.test_reset_asksFirst_cancelKeepsTheOrder_andConfirmRestoresIt` («El arrastre no
  subió Planificación encima de Tendencias») y
  `RecordsLote8UITests.test_changeSubcategory_marksTheCurrent_andUndoesFromTheNotice` («La hoja no se titula «Cambiar
  categoría»»); al repetir la tanda pasaron al reintento. RecordsLote8 ya falló sus tres vueltas el 13-nov.
  También `ExternalEntryForeignSheetUITests` (dos casos) pasó al reintento.
