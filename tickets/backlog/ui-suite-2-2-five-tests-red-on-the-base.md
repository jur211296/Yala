---
id: ui-suite-2-2-five-tests-red-on-the-base
status: backlog
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
