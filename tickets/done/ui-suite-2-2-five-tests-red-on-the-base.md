---
id: ui-suite-2-2-five-tests-red-on-the-base
status: done
priority: medium
area: testing
created: 2026-10-27
updated: 2026-10-27
source: "rojos del gate de usage-mode-full-to-groups-only-and-back (card p0iu), medidos contra la base"
---

# Cinco XCUITest en rojo en la punta de 2.2, sin relación con el cambio que los encontró

## Qué se midió el 2026-10-27

La suite `YalaUITests` completa (614 casos, iPhone 17 Pro, iOS 27.0, centinela 0: corrió sola) dio 7 rojos en la rama de
«Cómo usas Yala». Repetidos aislados, los 7 fallan igual. Corridos sobre la base `2.2` @ `4e0b6b4c7` (árbol aparte con
`git archive`, sin el cambio), **los 6 que había que comprobar fallan igual, con la misma línea**:

| Caso | Línea | Mensaje |
|---|---|---|
| `ChatMessagingLayoutUITests/test_draftDetails_opensSheet_withTheNewRecordAccountSelector` | 157 | No se montó el selector de `chat_draft_detail_account` con filas (`account_selector_row_…`). |
| `RecordsLote8BUITests/test_duplicates_removeRepeated_asksFirst_andLeavesOnePerGroup` | 117 | Sin «Fecha», ninguna fila de un grupo de días distintos dice de qué día es. |
| `UXAudit22Lote11DecididasUITests/test_needSection_explainsWhatItIsFor_andGivesAnExamplePerRow` | 83 | Falta el ejemplo de «Opcional». |
| `UXAudit22Lote11DecididasUITests/test_proObservations_withoutConsent_offerTheButtonInPlace` | 113 | Falta «Generar con IA» en Observaciones. |
| `UXAudit22Lote11DecididasUITests/test_summary_showsWhatYouStillHaveToPay_andBudgetsWithTheirAmounts` | 59 | Falta «Lo que te falta pagar». |
| `WhatsNewLaunchUITests/test_updateFrom2_0_showsTheSheetOnce` | 26 | `("Un Panel más claro") is not equal to ("Grupos")` |

El séptimo, `TransactionsCrudUITests/test_recordSelectorsOpenAtMediumDetent`, ya tiene ticket:
`record-selectors-uitest-taps-the-tags-chip-off-screen`. No se volvió a medir contra la base.

## Lo que se sabe y lo que no

- **Medido:** los seis fallan en la base, aislados, con el mismo mensaje. No son de la rama que los encontró.
- **Medido:** el de Novedades espera las tarjetas de 2.1 y la app ya enseña la hoja de 2.2 (`whatsNew.v22.panel.title`).
  El test se actualiza con `whats-new-2-2-review-before-release`, que ya lo pide en su «Hecho cuando».
- **Sin medir:** la causa de los otros cinco. El de duplicados busca un año (`20[0-9][0-9]`) en la etiqueta de la fila:
  podría ser que la fecha del mismo año no lo lleve y el test dependa del día en que corre. Es una hipótesis, no una medida.
  Los tres de `UXAudit22Lote11` comparten pantalla (Estadísticas/Informes): conviene mirarlos juntos.

## Hecho cuando

Cada uno de los cinco está verde en la punta de 2.2, o tiene su propio ticket con la causa medida.

## 2026-10-27 · Resuelto: cuatro arreglados, uno con ticket

Medido en el iPhone 17 Pro (iOS 27.0) sobre `origin/2.2` @ 279d1510b, con vídeo del `.xcresult` y la nocturna de
`qa.yml` como historial. Ninguno de los cinco era un rojo «de entorno».

| Caso | Causa medida | Qué se hizo |
|---|---|---|
| `test_needSection_…` | El ejemplo de «Opcional» cambió el 23-oct (lote 2 · B, `77f62f037`): «Gustos y caprichos.» → «Gustos y caprichos: salidas, delivery.». | El test espera el texto vigente. Verde. |
| `test_summary_showsWhatYouStillHaveToPay_…` | Depende del día: la sección cuenta los pagos que vencen dentro de «Este mes», que cierra hoy; solo salía los días en que vencía un pago de la semilla. Verde el 22-oct, rojo desde el 23. | Se lanza con `-uitest-scheduled-due-today`. Verde. La pregunta de producto (¿«falta pagar» hasta fin de mes?) va a `insights-to-pay-this-month-leaves-out-the-rest-of-the-month`. |
| `test_proObservations_withoutConsent_…` | `scrollTo` subía la píldora «Detalle \| Observaciones» hasta debajo de la barra de chips; `isHittable` seguía en `true` y el toque caía en el chip «Registros» (visto en el vídeo). Su hermano `test_proObservations_doNotAskForATap` salía **verde sin mirar Observaciones**: afirma una ausencia. | Helper `openObservations`: arrastres cortos hasta la mitad de la pantalla y comprobación de que la píldora quedó elegida (`isSelected`). Los dos, verdes. |
| `test_duplicates_removeRepeated_…` | Depende del día: el grupo de días distintos lo ponía la semilla `minimal`, que cambia con el día del mes y de la semana. Hoy no había ningún par. | La copia hecha a mano se fecha «Antier», así el grupo lo crea el test; sobra quitar «Nota». Verde, y el mutante `rowDateCaption → nil` lo pone rojo. |
| `test_draftDetails_opensSheet_…` | **Bug de producto**: en Yala IA › «Detalles», ninguna fila abre su selector. SwiftUI construye la hoja y UIKit no la presenta. Regresión entre la nocturna del 21-oct (verde) y la del 23-oct (roja). | Ticket `chat-draft-details-rows-dont-open-their-selector` (high), con lo medido y el siguiente paso (bisecar). El test se queda en rojo a propósito: es la red del bug. |
