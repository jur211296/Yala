# Lote P5 · Formularios y reportes
toca: `Reports/`, `ExportWizard/`, `AccountFormViewModel.swift`, `AppRouter.swift`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial).
Lote producto (cola-2-3-propuesta.md §3 P5).

Cards:
1. En «Profundizar» de Reportes, el centro de la fila no añade la dimensión.
2. Cambiar el tamaño del texto con Exportar abierto devuelve las cuentas a «todas».
3. «No se pudo guardar» aparece aunque los cambios de la cuenta ya se ven.
4. Un aviso de la cola que no llega a enseñar nada podría dejar esperando al siguiente.

Hecha cuando: las cuatro hechas, tests en verde.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-11-05 02:55 Lima)

Base: la rama nació de `2.2`; se rehízo sobre `origin/2.3` (`742edb12a`), que es la base declarada. Sin commits propios
que perder.

1. **Profundizar (card uy2j).** `Spacer(minLength: 0)` + `.contentShape(Rectangle())` DENTRO del label de la fila de
   «Disponibles» (regla de filas de `swiftui-ds.md`). La red: `AccountCardReportsUITests` deja de tocar el «+» y toca el
   centro (el `tap()` de XCUITest cae en el centro); se comprueba con el mutante (sin el `contentShape`, rojo).
2. **Exportar y tamaño de texto (card mbj6).** El ticket es anterior al rediseño de Exportar en una pantalla
   (`ExportRecordsView`): primero se MIDE en el simulador con `simctl ui content_size`. Si sigue, se busca dónde cambia la
   identidad y se arregla ahí (que sobreviva todo el estado de la hoja, no solo las cuentas); test que lo fije. Si no se
   reproduce, se cierra con la medición.
3. **«No se pudo guardar» (card 6eno).** Default asumido: **revertir** con `context.rollback()` en el `catch` del
   `save()` de `AccountFormViewModel.saveAccount` y recargar lo cargado, para que el mensaje diga la verdad y un segundo
   «Guardar» rehaga lo escrito (el formulario conserva lo tecleado). Precedentes en el repo con el mismo razonamiento:
   `AccountRemovalService` (hoja con nada más pendiente) y la edición masiva de `RecordsViewModel`. Riesgo conocido:
   tira también cambios sin guardar de otras pantallas del `mainContext`; con autosave y un formulario modal, el hueco es
   mínimo. Test contra el store (regla L85 de `testing.md`). **Pregunta al bot a las 5:00** (excepción nocturna).
4. **Aviso de la cola que no presenta nada (card 5brw).** Primero medir con N ≥ 20 (seam de XCUITest: un intent que no
   presenta + la oferta de prueba). Si se atasca alguna vez: re-mirar la cola una vuelta después cuando el manejador no
   presentó nada, y medir después. Si no se atasca en N ≥ 20: se cierra con la medición, sin tocar el router.
5. **Evidencia**: antes/después de la card 1 (la fila) y de la card 2 (la selección tras cambiar el texto) en
   `~/Claude/entregas/<sesión>/evidencia/`. Cards 3 y 4 no se ven.
6. Un solo PR contra `2.3`, auto-merge en cola. Cobertura en `qa/coverage-index.json` en el mismo commit.
