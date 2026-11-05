# Lote P1 · Pagos planificados
toca: `Planning/`, `InboxBulkApproveSuccessView.swift`, `AppBootstrapper.swift`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial).
Lote producto (cola-2-3-propuesta.md §3 P1). Va antes de S6/S9 y no en paralelo con ellas (mismos ficheros).

Cards:
1. Pagos planificados · «Adelantar gasto» ofrece el siguiente borrador, el iPad deja el detalle vacío y el 29 de febrero (sin versión; son tres).
2. Tests · el borrador de un pago vencido no se puede alcanzar en XCUITest (sin versión).

Hecha cuando: los bugs de Adelantar gasto en iPad/29-feb quedan resueltos y el XCUITest del borrador vencido es alcanzable; tests en verde.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos (2026-11-05, base `origin/2.3`):** la card «Adelantar gasto…» enlaza TRES tickets
(`inbox-success-says-transaction-created`, `ipad-planning-chip-switch-leaves-a-detail-without-destination`,
`yearly-scheduled-payment-on-feb-29-skips-common-years`); la de tests, uno (`scheduled-due-draft-cannot-be-reached-in-uitest`).
- El primero ya está arreglado en código desde el lote 10 (18-oct, posterior al ticket): «Pagar ahora» abre el borrador
  con `payNowTitle` y al guardar vuelve al detalle sin pantalla de éxito ni «Guardar el siguiente». No tiene XCUITest.
- 29-feb, comprobado con script: `Calendar.date(from: 2027-02-29)` da el 1-mar, así que 2027 no tiene fecha; y además
  `advanceToNextDueDate` suma un año con `byAdding`, que deja el 28-feb y ya no vuelve al 29 (2032 caería el 28). La
  vuelta atrás de `ScheduledDraftOccurrenceLogic.retreat` tiene la misma deriva.
- El arranque bajo `-uitest` no procesa vencidos, y la siembra corre DESPUÉS del paso 4.

**D1 · ¿Qué se hace con el bug de «Adelantar gasto», ya arreglado?** → Se cierra con un XCUITest que lo fija (Pagar
ahora → guardar → vuelve al detalle, sin pantalla de éxito). Por qué: la card pide «con su test». Alternativa
descartada: volver a tocar el código, que ya hace lo pedido.

**D2 · 29-feb en años no bisiestos** → cae el 28-feb, y en el bisiesto siguiente vuelve al 29: el calculador acota el día
al largo del mes (como el mensual) y el avance y la vuelta atrás anual se reanclan en el mes/día del pago
(`yearlyMonth`/`yearlyDay`), como el mensual con `dayOfMonth`. Por qué: es la regla que ya sigue el mensual con el 31.
Alternativa descartada: solo arreglar el calculador; el avance seguiría corriendo el pago al 28 para siempre.

**D3 · iPad: cambiar de chip con algo abierto** → la columna de detalle vuelve a «Elige un presupuesto o un pago» al
cambiar de chip, rehaciendo el split entero con la identidad del chip. Por qué: lo abierto lo guarda el split, no la pila
del detalle (el lote 9 midió que `.id` en la pila no basta); rehacer el split es el cambio mínimo. Alternativa
descartada: mover lo abierto a un estado propio como Registros (`openRecordID`): refactor de las cuatro entradas
(dos listas y dos avisos) para el mismo resultado. Si la medida en el iPad no lo confirma, se reabre.

**D4 · Alcanzar el borrador vencido en XCUITest** → seam nuevo `-uitest-process-due-scheduled` que, tras la siembra,
procesa los vencidos como el arranque real; se combina con `-uitest-scheduled-due-today`. Por qué: un seam aparte no
cambia los tests que ya usan `-uitest-scheduled-due-today` (Estadísticas cuenta ese pago como «por pagar»). Alternativa
descartada: procesar siempre bajo `-uitest-scheduled-due-today`, que retiraría ese pago del test de Estadísticas.
