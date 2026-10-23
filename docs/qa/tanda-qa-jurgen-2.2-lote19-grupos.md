# Tanda de QA · 2.2 · lote 19 decidido (Grupos: administrar, archivar, eliminar y salir)

Barrido acotado a las once cards de esta sesión (2026-10-21). Revisadas 11: **10 cerradas** con evidencia en el
simulador (XCUITest del flujo real o pasada con capturas) y **1 para el iPhone**: hacer o quitar administrador en un
grupo de la nube, que necesita el servidor desplegado y dos teléfonos. Tiempo: ~40 min de pruebas.

**Build:** el del PR de este lote (Yala Dev contra staging para L19-3, tras desplegar `g22_01`). L19-3 en la nube
bloquea solo esa función, no el lanzamiento del resto.

## Lo que pasó a done

| Card | Motivo | Evidencia |
|---|---|---|
| L19-4 quitar a quien debe | XCUITest, «Saldar primero» pulsado + capturas | `GroupsLote19DecididoUITests#test_removeMemberWithDebt_offersSettleFirst`; `antes/despues-03-quitar-con-deuda` |
| L19-5 archivar o eliminar | capturas + XCUITest de la tarjeta | `#test_deleteIsEnabled_whenTheOnlyBalanceIsRoundingResidue`; `antes/despues-06-ajustes-abajo` |
| L19-6 presupuesto en su hoja | XCUITest + captura | `#test_budgetSheet_previewsSpendingAgainstTheTypedLimit_andSaves`; `antes/despues-07-presupuesto` |
| L19-7 opciones con ejemplo y lápiz | capturas (copy decidido, 16 idiomas, paridad en verde) | `antes/despues-04-ajustes-arriba`, `despues-05-ajustes-medio` |
| L19-8 aviso con Deshacer | XCUITest (Deshacer devuelve el grupo) + captura | `#test_archiveWithOnlyRoundingResidue_noDebtWarning_noticeAndUndo`; `despues-09-tras-archivar` |
| L19-9 grupo archivado lo dice | XCUITest + capturas | `#test_archivedGroup_showsTheBanner_andTheListKeepsItsDebt`; `despues-11-detalle-archivado`, `despues-12-lista-con-archivado` |
| L19-10 eliminar bloqueado / residuo | XCUITest + unitarios con mutantes muertos + review adversarial | `#test_blockedDelete_namesTheDebt_andSeeBalancesOpensBalances`, `GroupRoundingResidueLogicTests` (2 mutantes); `antes/despues-13-eliminar-saldado` |
| L19-11 salir o eliminar con la cifra | XCUITest, «Saldar primero» pulsado + capturas | `#test_leaveWithDebt_offersSettleFirst`; `antes/despues-16-salir-con-deuda`, `despues-14-eliminar-dialogo` |
| L19-13 grupos que no se pudieron dejar | XCUITest + captura | `#test_batchLeaveResult_offersOpeningEachGroupsSettings`; `antes/despues-17-salir-de-varios` |
| L19-14 desasociar | XCUITest de las dos salidas + captura | `GroupsAssociationRowUITests` (ids intactos); `antes/despues-18-desasociar` (sin gastos que conservar en la semilla: la cifra no sale) |

## Lo que se queda

| Card | Qué lo retiene |
|---|---|
| L19-3 hacer / quitar administrador | Servidor sin desplegar (`g22_01` + Worker, card a Jürgen) y **dos dispositivos**: el rol cambia en el servidor y el otro teléfono lo ve al sincronizar. En el simulador no hay servidor; lo cubren `GroupChangeRoleBackendTests` y el banco SQL (80 comprobaciones, 8 mutantes). |

## Guion de L19-3 (tras desplegar `g22_01` y el Worker en staging)

Build: Yala Dev contra staging, en dos iPhones con cuentas distintas. ~5 min.

1. En el teléfono A, crea un grupo de la nube e invita al B por enlace; acepta su solicitud en Miembros.
2. En A: Miembros › «…» junto a B › «Hacer administrador». Lee la confirmación y toca «Hacer administrador».
   Esperado: la fila de B lleva la insignia «Administrador».
3. En B: vuelve a la lista, abre el grupo (al abrirlo se trae lo nuevo) y entra en Miembros. Esperado: B se ve como «Administrador» y
   puede tocar «Presupuesto del grupo».
4. En B: «…» junto a A (quien creó el grupo) › «Quitar como administrador» › confirmar.
   Esperado: «Quien creó el grupo siempre es administrador: no se le puede quitar el rol.» y A sigue siéndolo.
5. En A: «…» junto a B › «Quitar como administrador» › confirmar. Esperado: la insignia desaparece en A y, al volver a abrir
   el grupo, en B.

Capturas: `/Users/jur/Claude/worktrees/_capturas/2026-10-21-lote-decidido-2-2-12-grupos-administrar/` y
`~/Claude/entregas/Yala--lote-decidido-2-2-12-grupos-administrar/capturas/`.
