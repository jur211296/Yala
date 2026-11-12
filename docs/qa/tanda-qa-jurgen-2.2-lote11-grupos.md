# Tanda de QA · 2.2 · lote 11 decidido (Grupos: gastos, saldar, saldos y el puente)

Barrido acotado a las once cards de esta sesión (2026-10-21). Revisadas 11: las 11 cerradas con evidencia, todas
probadas en el simulador (XCUITest del flujo real o pasada con capturas). **Nada se queda para el iPhone**: ninguna
toca iCloud real, inicio de sesión, dos dispositivos, compras ni notificaciones. Tiempo: ~25 min de pruebas.

**Build:** el del PR de este lote (Yala Dev vale). Nada bloquea el lanzamiento.

## Lo que pasó a done

| Card | Motivo | Evidencia |
|---|---|---|
| L13-4 borrar un gasto | XCUITest + capturas | `UXAudit22Lote13DecididoUITests#test_deleteExpense_dialogNamesTheExpense`; `antes/despues-L13-4-borrar` |
| L13-5 «Saldar», «Pagos», «Apuntar pago» | copy decidido por Jürgen + capturas | `despues-L13-5-saldos`, `despues-L13-5-apuntar-pago` (16 idiomas, paridad en verde) |
| L13-6 resumen = Saldos | test contra la opción encendida y apagada | `GroupShareableSummaryLogicTests#paymentsFollowTheGroupOption_on/off`; `antes-L13-6-resumen` (S/ 50 vs S/ 80) |
| L13-7 «Sí, registrar» registra | XCUITest + unitarios | `#test_optIn_yesRegister_asksTheAccountRightThere`, `GroupExpensePersonalOutcomeTests`; `despues-L13-7-*` |
| L13-9 «Guardar» dice qué falta | XCUITest + capturas | `#test_save_withNothingFilled_saysWhatIsMissing`, `GroupsSmokeUITests#test_groupExpenseAccountRowFollowsThePayer`; `despues-L13-9-guardar` |
| L13-10 saldos iniciales | XCUITest + capturas | `#test_balances_offerOpeningBalance_andTheFormExplainsIt`; `despues-L13-10-*` |
| L13-11 «Movido a «X»» con «Ver» | XCUITest + capturas | `#test_convertDraft_viewOpensTheGroup`, `InboxConvertToGroupUITests`; `despues-L13-11-aviso` |
| L13-12 hojas de la Bandeja | XCUITest + capturas | `#test_paymentDraft_isNamedInTheInbox`; `despues-L13-12-*`, `despues-L13-7-12-pide-cuenta` |
| L13-13 «¿Quién puso más?» | capturas | `despues-L13-13-estadisticas` |
| L13-14 reflejar en tus cuentas | XCUITest + capturas | `#test_stopReflecting_deleteAsksHowManyFirst`; `despues-L13-14-*` |
| L13-15 «¿Ya lo apuntaste?» | integración contra el bridge real, mutante muerto | `GroupExpenseLinkDraftBehaviourTests` (no duplica, no cambia importes, no enlaza si ya hay pata real o pagó otro) |

## Lo que se queda

| Card | Qué lo retiene |
|---|---|
| — | nada |

Capturas: `~/Claude/entregas/Yala--lote-decidido-2-2-11-grupos-gastos-y-saldar/capturas/`.
