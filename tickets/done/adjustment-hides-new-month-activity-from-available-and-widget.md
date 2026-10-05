---
id: adjustment-hides-new-month-activity-from-available-and-widget
status: done
priority: medium
area: "disponible del mes, widget, ajuste de cuenta"
created: 2026-10-02
updated: 2026-10-02
source: "correo a admin@yala-app.pe el 2026-10-02, asunto «Yala (E) - Contacta con nosotros: Error». Investigación, no arreglo."
cola: investigacion
---

# Tras un ajuste de cuenta, el mes nuevo no entra en «disponible» ni en el widget

## El reporte, en lenguaje de usuario

Una persona registró un ajuste de cuenta el mes pasado. Después, las transacciones del 1 de octubre sí
aparecían en la lista de transacciones, pero **no** en «disponible del mes» (ni ingresos ni gastos) y
**tampoco** en el widget. App: Yala v2.0.4 (2), iOS 26.3.1, iPhone, tema Traslúcido, locale es-CO.

El correo no se copia aquí: el repo es público. El hilo está en admin@yala-app.pe.

## Veredicto: NO se reproduce

Un ajuste registrado el mes anterior **no** esconde los movimientos del día 1 del mes siguiente, ni del
Panel ni del widget. Medido el 2026-10-02 (el propio día 2 del mes, que es el escenario del reporte).

### Qué se midió

`YalaTests/AdjustmentNewMonthVisibilityTests.swift` siembra el caso como lo crea la app y lo pasa por las
mismas llamadas que alimentan cada pantalla:

| Superficie | Llamada que se ejerce |
|---|---|
| Lista de transacciones | el fetch de todas las filas del store |
| Panel, «Disponible · Período» y las pastillas del mes | `HeroBucketsCalculator.calculate`, con `DetailPeriod.thisMonth.dateInterval()` y el mes calendario de `Calendar.current`, igual que `PanelViewModel.calculateHeroWidget` |
| Widget | `WidgetDataCache.buildPeriodSummary` con el intervalo de `.thisMonth`, igual que `buildSnapshot` |

Matriz cruzada: 3 tipos de ajuste × 2 horas del día 1 × 2 monedas de cuenta = **12 combinaciones**.

- **Tipo de ajuste:** «Ajustar por registro» al alza y a la baja (`InitialBalanceService.createAdjustment`,
  fechado el día 20 del mes anterior) y «Cambiar saldo inicial» (`setInitialBalance`).
- **Hora del día 1:** medianoche exacta, que es lo que deja el selector de fecha y el borde donde un
  `DateInterval` cerrado ya mordió otras veces, y 09:00.
- **Moneda de la cuenta:** COP y USD.

Resultado, iPhone 17 Pro con iOS 27.0, zona horaria UTC−5: **las 12 combinaciones en verde**
(`passedTests: 6`, `failedTests: 0`; cada caso recorre las dos monedas). Ingresos 1.200 y gastos 80 del día 1
entran enteros en el Panel y en el widget, con el ajuste fuera de las dos sumas.

**El test discrimina, comprobado con un mutante:** con `DetailPeriod.thisMonth` empezando un segundo tarde
—un corte de mes roto— caen exactamente los 3 casos de medianoche, con Panel y widget a 0 en las dos monedas,
y los 3 de las 09:00 siguen verdes. O sea, si el reporte fuera un bug del corte de mes, este test lo habría
visto.

### Lo que dice el código (leído en `2.1` y en el tag `v2.0.4`)

- Panel y widget excluyen **solo la propia transacción de ajuste** (`balanceAdjustmentType != nil`). Ningún
  filtro depende de la fecha del último ajuste ni de que la cuenta tenga uno.
- Crear un ajuste no toca ninguna otra fila. El formulario de nuevo movimiento nunca hereda
  `balanceAdjustmentType`: solo lo escriben `InitialBalanceService`, las transferencias y el importador CSV.
- El cálculo del Panel y del widget es el mismo en `v2.0.4` que en `2.1` en lo que importa aquí: mismo
  `DetailPeriod.thisMonth`, mismo filtro de ajustes. `2.1` añade el neteo de gastos de grupo, que no aplica.
- **Locale es-CO:** solo cambia el texto de la nota del ajuste. **Zona horaria de Colombia (UTC−5):** la
  lista y las dos superficies usan el mismo `Calendar.current`, así que no pueden poner la misma fila en meses
  distintos. Las entradas con fecha fija en UTC se revisaron: el importador CSV fija mediodía UTC, que en
  Colombia sigue siendo el mismo día.

### Qué sí esconde una fila de Panel y widget a la vez y la deja en la lista

Son comportamientos de diseño, no bugs, y cualquiera encaja con el síntoma. **Inferido, no medido en el
dispositivo de la persona:**

1. **La cuenta tiene activado «Excluir de estadísticas».** Panel y widget la saltan entera; la lista la
   enseña. El interruptor vive en la sección «Acciones» del **mismo formulario** en el que se hace el ajuste,
   así que es plausible activarlo sin querer al ajustar. Es la explicación que mejor casa con «empezó tras el
   ajuste».
2. **Los movimientos del día 1 son transferencias entre cuentas.** No cuentan como ingreso ni gasto, por
   diseño.

Y dos que explican solo una de las dos pantallas, así que no bastan por sí solas: el Panel filtrado por una
cuenta concreta (el widget no tiene ese filtro) y un período del Panel distinto de «Este mes».

## Qué faltó del reporte

Para cerrar entre las explicaciones de arriba haría falta preguntarle a la persona:

- Si la cuenta ajustada tiene activado «Excluir de estadísticas» (Cuentas → la cuenta → Acciones).
- Si los movimientos del 1 de octubre son gastos o ingresos normales, o transferencias.
- Si los movimientos de **septiembre** de esa cuenta sí salen en el Panel. Si tampoco salen, es la exclusión
  de estadísticas, y el ajuste no tiene nada que ver.
- Qué período y qué cuenta tiene seleccionados en el Panel.

## Siguiente paso

No hay ticket de arreglo: no hay bug medido. Si la persona confirma que la cuenta estaba excluida de
estadísticas sin saberlo, eso abre otra conversación de producto —si ese interruptor debe vivir junto al
ajuste, o si el Panel debería avisar de que hay cuentas fuera— y se captura entonces con `/idea`.
