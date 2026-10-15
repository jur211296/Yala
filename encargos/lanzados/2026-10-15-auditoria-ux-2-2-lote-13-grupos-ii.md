# Auditoría UX 2.2 · lote 13: Grupos II: gastos y saldar cuentas

> **ALCANCE ESTRICTO:** solo los flujos del lote 13. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 13: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 13).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 13 · Grupos II: gastos y saldar cuentas (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 13.1 | Añadir un gasto de grupo | FAB del detalle · FAB de la lista › Nuevo gasto · menú de la tarjeta · FAB del Panel › Grupo | `GroupExpenseComposerView` → `GroupExpenseFormView` (importe, descripción, divisa, fecha, «Pagado por X y dividido…» con igual / % / importes / partes, cuenta, subcategoría) → «¿Registrar también en tu Yala personal?» → `GroupExpenseSuccessView` | `V/Groups/GroupExpenseFormView.swift`, `GroupExpenseComposerView.swift`, `GroupSplitEditorCard.swift`, `GroupExpenseSuccessView.swift` | `GroupsSmoke`, `GroupExpenseSuccess` |
| 13.2 | Ver, editar y borrar un gasto de grupo | Fila en Registros del grupo · menú contextual | `GroupExpenseDetailSheet` → Editar → `GroupExpenseFormView`; borrar con diálogo «Eliminar» | `V/Groups/GroupExpenseDetailSheet.swift`, `GroupRecordsView.swift` | `GroupsSmoke` |
| 13.3 | Apuntar deudas de antes (saldos iniciales) | Miembros › «Saldos iniciales» (dueño) · diálogo tras aprobar a alguien | `GroupOpeningBalanceFormView`, `GroupOpeningBalanceDetailSheet` | `V/Groups/GroupOpeningBalanceFormView.swift` | no |
| 13.4 | Convertir un borrador de la Bandeja en gasto de grupo | Bandeja › borrador › «Convertir a gasto compartido» | `InboxDraftEditSheet` → `GroupPickerSheet` → `GroupExpenseFormView` | `V/Inbox/InboxDraftEditSheet.swift`, `V/Groups/GroupPickerSheet.swift` | `InboxConvertToGroup` |
| 13.5 | Completar en la Bandeja un gasto o pago de grupo | Fila de la Bandeja creada por el puente | `GroupExpenseDraftFinalizationSheet` / `GroupSettlementDraftFinalizationSheet` | `V/Inbox/GroupExpenseDraftFinalizationSheet.swift`, `GroupDraftFinalizationScaffold.swift` | no |
| 13.6 | Ver quién debe a quién y las estadísticas del grupo | Pestañas Saldos y Estadísticas · barra de saldo | `GroupBalancesView` («¡Están al día!», «Deudas pendientes»), `GroupStatsView` | `V/Groups/GroupBalancesView.swift`, `GroupStatsView.swift`, `SG/GroupBalanceService.swift` | parcial (`AdaptiveNavigation`) |
| 13.7 | Saldar una deuda | Saldos › deuda › «Liquidar» | `SettlementFormView` («Registrar pago», cuenta o «Ninguna — finalizar después») → pendiente → el otro confirma ✓ o rechaza ✗ | `V/Groups/SettlementFormView.swift`, `GroupBalancesView.swift` | no |
| 13.8 | Responder a un cambio de importe de un pago | Bandeja › fila de aviso | `GroupSettlementAmountChangeSheet` («Cambió el monto» → «Ajustar a X» / «Dejar en Y») | `V/Inbox/GroupSettlementAmountChangeSheet.swift` | `SettlementAmountChangeNotice` |
| 13.9 | Compartir el resumen del grupo como imagen | Ajustes del grupo › resumen | `GroupShareableSummarySheet` → hoja de compartir | `V/Groups/GroupShareableSummarySheet.swift` | `GroupsSmoke` |
| 13.10 | Reflejar los gastos de grupo en mis cuentas (puente) | Grupos › engranaje · Ajustes del grupo › «Integración personal» | `GroupsGlobalSettingsView` → `BridgeActivationSheet` («Empezar desde ahora» / «Importar todo el historial») / `BridgeDeactivationSheet` | `V/Groups/GroupsGlobalSettingsView.swift`, `BridgeActivationSheet.swift`, `SG/GroupTransactionBridge.swift` | parcial (`GroupsSmoke`, solo abre) |

**Visto en el código:**
- Desde el Panel sin grupos, el formulario de gasto se abre solo tras crear el primer grupo, sin explicarlo.
- Borrar un gasto solo dice «Eliminar»: no avisa de que desaparece para todos ni de que se borra el registro personal.
- Confirmar y rechazar un pago son solo iconos ✓/✗, y rechazar no pide confirmación.
- Vocabulario mezclado: «Liquidar», «Registrar pago», «Salda pagos».
- El educativo avisa de pasada de que el gasto «también lo registramos en tu cuenta personal automáticamente».
- 13.10: la hoja dice «tu cuenta de grupos» y el interruptor «mis cuentas personales».
- No hay forma manual de enlazar un gasto de grupo con un registro personal ya existente.

**Tickets abiertos del lote:** `bridge-virtual-only-currency-mismatch-is-silent`,
`settlement-direction-edited-after-approval-leaves-the-bank-stale`, `group-balance-service-shares-not-deduped`,
`debt-simplification-nondeterministic-ties`, `settlement-amount-change-notice-archived-row-reads-as-a-rejected-payment`,
`groups-in-group-search`.
**Cards de 2.2 que lo cambian:** «Yala IA entiende Grupos como un contenedor aparte de lo personal», «Seguimiento de
deudas personales» (cuidar que no choque con las deudas de grupo).

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L13-1, L13-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 13 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L13.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L13-k-antes.png`, `L13-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
**No esperes la elección de Jürgen.** Cuando termines, `xcrun simctl shutdown all` y cierra normal con /cerrar-total. Frank junta las decisiones después y las guarda en las cards para la fase de implementación.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- La moneda «S/» frente a «PEN» es una preferencia del usuario: nunca la pongas como opción A/B/C.
- Capturas de HOY (de esta sesión) y maquetas reales en el simulador para cada propuesta visual.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 (Frank, 2026-10-15, auto-contestado: sesión autónoma)

- **Base:** la rama nació de `origin/2.1` (a10168931), no de 2.2; se recolocó sobre `origin/2.2` (a4a85f29a) antes de cualquier commit. `git log origin/2.2..HEAD` vacío. PR contra 2.2.
- **Simulador:** iPhone 17 Pro iOS 27.0 (46287CFE), Yala Dev, español de Perú, modo oscuro; seeds y args `-uitest-*` de los XCUITests de Grupos (`grupos`, `grupos-invitado`, `-uitest-seed-settlement-amount-change`). Fuera del simulador antes de las 9:00 Lima.
- **Formato:** el de los lotes 10–12 (informe.md + `datos-lote-13.json` + `render.py` al HTML acumulado + `variantes-L13.html` + cards por script).
- **Qué cuenta como bug claro:** texto falso o mal escrito para quien lo lee, un destino roto, un botón que no hace nada, una cifra que no cuadra. Cambiar qué se pide, en qué orden o cómo se ve → card de Jürgen.
- **Sin backend real:** el simulador no tiene Supabase; lo que solo existe contra el servidor (guardar de verdad un gasto con el canal vivo, que el otro confirme) se audita por código y se dice.
- **Tickets abiertos del lote:** no se rehacen; si una mejora los cubre, se cita.
- **Vocabulario:** «Liquidar / Registrar pago / Salda pagos» se propone unificar (card), no se toca: es copy en 16 idiomas y decisión de producto.
