Yala
# Flujo de caja: un solo motor del mes, real con signo más lo que falta, sin doble conteo
---
toca: Yala/App/Logic/Calculators/CashFlowCalculator.swift,Yala/App/Logic/Calculators/CashFlowProjectionCalculator.swift,Yala/App/Logic/CashFlowMonthSummaryLogic.swift,Yala/App/Logic/CashFlowLineSideLogic.swift,Yala/App/Logic/CashFlowRealEstimateBarLogic.swift,Yala/App/Logic/FlujoMotorMes/,Yala/App/ViewModels/CashFlowPlanViewModel.swift,YalaTests/FlujoMotorMes/,YalaTests/CashFlowCalculatorTests.swift,YalaTests/CashFlowProjectionCalculatorTests.swift,YalaTests/CashFlowPlanViewModelTests.swift,YalaTests/FlujoAl30YEstimadoTests.swift,tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md
esfuerzo: high
cierre: cierra-sola
---

Decisiones de Jürgen del 18-nov (06:26 Lima), registradas: aceptó todo lo recomendado del análisis «Flujo de caja: replanteo» (ticket `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`, evidencia en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/`):
- P1 modelo A: mes real + lo que falta.
- P2 línea excedida: cuenta lo real y no proyecta más.
- P3 al cambiar un límite, por defecto «desde este mes en adelante».
- P4 el límite es un monto fijo, sembrado con tu promedio al crear.
- P5 se retira el saldo inicial manual: se parte del saldo de tus cuentas.
- P6 lo que no tiene línea en meses futuros: gastos por la mediana de 6 meses; los ingresos no se proyectan.
- AJUSTE OBLIGATORIO: el nivel de detalle siempre llega a SUBCATEGORÍA, que es el id base. La categoría se deriva de sus subcategorías (suma) y se muestra como agrupador, puede ser colapsable. Nunca una línea solo a nivel categoría que pierda el detalle de subcategoría.

Sesión S1 del plan del ticket (sin UI). Lee el ticket y el artifact del análisis antes de empezar.

## Qué hacer
- Una sola cuenta por mes: real con signo (las devoluciones restan) e incluyendo lo sin categoría, más lo que falta por línea, más «otros» por mediana de 6 meses (solo gastos) en futuros.
- Mes en curso desde el saldo de hoy de tus cuentas; meses pasados = real; futuros encadenan desde el cierre del anterior.
- Sin doble conteo de fechados (lo fechado después de hoy no es «real» todavía) y el promedio sin el mes a medias.
- Línea excedida: cuenta lo real y no proyecta más. Límite = monto fijo.
- Líneas al nivel de subcategoría, con la categoría derivada como suma. El gasto anotado en la categoría madre de una línea por subcategoría no se cuenta dos veces (hallazgo 10).
- Paridad con «Al 30» del Panel. Cierra los hallazgos 1 a 11 del ticket que son de motor, con un test por hallazgo usando la sonda del análisis.
- Review adversarial al final. Las vistas siguen funcionando con la API nueva; su rediseño va en las sesiones siguientes. Actualiza el ticket marcando S1 hecha (no lo muevas a done).

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (decidido al arrancar, 18-nov, modo semi)

Ficheros: el motor nuevo en `Yala/App/Logic/FlujoMotorMes/`; `CashFlowProjectionCalculator.calculate` conserva su firma y
sus tipos de salida (los ~50 consumidores siguen compilando) y delega en él; el VM le pasa cuentas, saldos y pagos.

1. **Qué entra en «real» y en los totales del mes.** Los movimientos de las cuentas que suman en el saldo del Panel
   (`PanelBalanceScopeLogic`, como «Al 30»), con signo y con lo sin categoría; fuera los ajustes de saldo y
   transferencias (`balanceAdjustmentType != nil`) y las patas de préstamo, como el resto del flujo proyectado.
   «Real» = fechado antes de mañana (`TodayCutoff`); lo de mañana en adelante es «fechado» y entra una vez, en lo que
   falta. Sin cuentas, todos los movimientos.
2. **A quién pertenece un movimiento** (por su lado: ingreso o gasto según `TransactionClassificationLogic`): la línea de
   su subcategoría; si no, la línea de su categoría; si no hay, pero la categoría tiene líneas por subcategoría, el
   «sin subcategoría» de ese grupo; si no, «otros».
3. **Lo que falta de una línea** (mes en curso y futuros): `máx(límite − real − fechado − pagos pendientes suyos, 0)`.
   Excedida (real + fechado ≥ límite): cero (P2). Una línea «pago programado» falta lo de sus pagos pendientes.
   **Hallazgo 10a:** lo anotado en la categoría madre sin subcategoría descuenta de lo que falta de las líneas por
   subcategoría de esa categoría (proporcional), nunca se suma aparte.
4. **Otros (gastos sin línea), mes en curso y futuros:** `máx(mediana de 6 meses − lo que el mes ya tiene, 0)`.
   Mediana de los 6 meses completos anteriores al mes en curso, desde el mes del primer movimiento; sin los
   movimientos de pagos programados (sus pagos pendientes se proyectan aparte). Ingresos sin línea: no se proyectan (P6).
   Se aplica también al mes en curso (P6 habla de futuros; el mes en curso con el ritmo daba el hallazgo 10b).
5. **Saldos (P5):** el saldo inicial manual se ignora (el campo se queda en el modelo, sin migración). Cierre de un mes
   pasado = saldo real de tus cuentas a fin de ese mes; mes en curso = saldo de hoy + lo que falta («Al 30»); futuros
   encadenan desde el cierre anterior. `startingBalance` de la proyección = saldo a inicio del mes en curso.
6. **Límite (P4, hallazgos 8 y 9):** el promedio de una línea se calcula con los meses completos anteriores al mes en
   curso y vale igual para el mes en curso y todos los futuros (deja de moverse solo y no mira el mes a medias). Los
   meses pasados siguen con el suyo. Convertir los límites a monto fijo es de S4/S5.
7. **Subcategoría como id base:** cada mes trae los grupos por categoría derivados como suma de sus líneas, con su
   «sin subcategoría», y cada línea por categoría trae su desglose por subcategoría siempre.
8. **Paridad con «Al 30»:** `ProjectedFlowBuilder.planRemaining` pasa a pedir al mismo motor lo que falta por mes
   (líneas + otros), y con plan deja de sumar el ritmo de lo no cubierto. Fuera de `toca:` pero imprescindible: el
   hallazgo 10 es la cifra de «Al 30» y sale de ahí. Edición mínima: la lógica vive en `FlujoMotorMes/`. Con plan, los
   dos lados salen del plan (antes, sin líneas de ingreso, el ingreso iba al ritmo).
9. **Tests viejos que fijan lo que Jürgen decidió cambiar** (real sin signo, totales planeados, saldo inicial) se
   actualizan aunque estén fuera de `toca:`; cada uno se anota en el PR.
10. **Interino hasta S2:** la fila «Empezaste con · Cambiar» sigue enseñando el saldo del plan, que ya no se usa. S2 la
    retira. Sin UI en esta sesión: no hay capturas antes/después de la app.
