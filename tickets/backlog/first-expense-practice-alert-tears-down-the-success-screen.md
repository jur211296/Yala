---
id: first-expense-practice-alert-tears-down-the-success-screen
status: backlog
priority: medium
area: "transactions, panel, presentaciones"
created: 2026-09-28
updated: 2026-10-07
source: "iphone-small-screens-and-safe-areas-audit (carril adaptativo, paso 3), visto en simulador el 2026-09-28"
---

# Al guardar el primer gasto, el aviso «¿era de prueba?» se come la pantalla de éxito

## Qué le pasa al usuario

Quien registra su primer gasto a mano no ve la pantalla de éxito («¡Listo!», «Aceptar», «Registrar otro»). El
formulario se cierra solo y el Panel enseña encima el aviso «¡Listo! Creaste tu primer gasto — Si solo fue de
prueba, puedes eliminarlo», con «Conservar» y «Era de prueba». El gasto sí se guarda.

**Visto una vez** en `YalaLane-Adapt-iPhone-ProMax` (iOS 27.0), tamaño de texto normal, con `-uitest-seed grupos`:
guion de capturas de [[iphone-small-screens-and-safe-areas-audit]], paso `test_16_exitoRegistro`. De las ocho
corridas de ese paso que llegaron a guardar, las otras siete enseñaron la pantalla de éxito. Inferido que no lo
causa aquel ticket: solo tocó la maquetación, y el camino de abajo no pasa por ella.

## Por qué pasa (inferido del código)

1. `NewTransactionView.saveTransaction()` marca el paso `.firstExpense` del checklist con un
   `PracticeCleanupItem` si aún no estaba hecho, y a continuación enseña su pantalla de éxito.
2. `PanelView` observa `SetupChecklistManager.shared.pendingPracticeCleanup` con un `.onChange` y lo consume **en
   el acto**, con el formulario todavía presentado encima.
3. `PanelSheetsModifier` enciende entonces un `.alert` en el Panel, y al presentarse desmonta la hoja del
   formulario. Es la familia de las reglas de presentaciones de `.claude/rules/swiftui-ds.md`: dos anchors ante el
   mismo momento.

Con datos sembrados solo salta si el Panel no había contado aún sus registros: `autoDetect` marca `.firstExpense`
en el `onAppear` del Panel con `viewModel.transactions.count`, y si la carga llega después, el paso sigue abierto.
Para un usuario nuevo de verdad (cero registros) debería pasar **siempre**. Sin verificar en dispositivo.

## Qué hacer

Que el Panel no consuma el aviso mientras tenga una hoja presentada: consumirlo al volver a quedar arriba (el
`onDismiss` de la hoja de Nuevo registro), o que lo presente el propio formulario después de su pantalla de
éxito. Test de la condición: arranque con seed vacío, guardar un gasto y afirmar que aparece
`transaction_success_accept` y que el aviso llega después de «Aceptar».

## 2026-10-07 · El PR #384 no lo cierra: arregla el caso con historial, no el primer gasto de verdad

Se propuso descartarlo como arreglado en el #384 (`17e0281cb`). Medido en `origin/2.1`, ese arreglo cambia **cuándo** se
ofrece «¿era de prueba?»: `SetupChecklistManager.markFirstCreation` solo lo arma si lo recién guardado es lo único de su
tipo en el store. Eso quita la alerta a quien ya tenía registros (el rojo de la QA programada), pero **no toca el
mecanismo de este ticket**: `PanelView` sigue consumiendo `pendingPracticeCleanup` en su `.onChange` en el acto
(`consumePendingPracticeCleanup`), con la hoja de Nuevo registro todavía encima. Para un usuario nuevo de verdad, con
cero registros, la alerta se sigue armando y, por el código, sigue cerrando el formulario antes de la pantalla de éxito.
Inferido del código, sin verificar en simulador. Sigue en backlog con el «Qué hacer» de arriba.

