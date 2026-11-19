---
id: 2026-11-17-flujo-de-caja-replanteo
status: backlog
priority: high
area: cash-flow
created: 2026-11-18
updated: 2026-11-18
source: encargo 2026-11-18-flujo-de-caja-analisis-critico (pedido de Jürgen del 17-nov)
---
# Flujo de caja: replanteo del modelo y de la vista

Análisis completo, con números, capturas y maquetas: el artifact «Flujo de caja: replanteo» (link en el PR del
encargo). Evidencia en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/` (capturas `antes-*`, la sonda y su salida).

## Qué está mal (medido el 2026-11-18)

Escenario armado (`sonda/ZZSondaFlujoCajaTests.swift.txt`, salida en `sonda/salida-2026-11-18.txt`) y semilla
`rendimiento` en el simulador.

1. **Tres cifras distintas para «cómo acabo el mes» en la misma pantalla.** «Al 30 tendrías» (saldo de hoy + lo que
   falta), «Este mes te quedaría» (todo lo PLANEADO del mes) y «Si sigue así, a fin de mayo tendrías» (cadena desde el
   saldo inicial). Semilla: saldo de hoy S/ 72,181 y «a fin de mayo de 2027 tendrías S/ 24,863» (parte de «Empezaste con
   S/ 0»).
2. **El saldo inicial sin fecha se desliza al mes en curso.** `startingBalanceDate == nil` (lo normal: crear el plan no
   la pone) se aplica siempre en el mes que se está viendo hoy. Un plan creado en octubre arranca en noviembre con el
   saldo de octubre. El copy dice «se asume que es hoy», y es «el mes en curso, cada vez que abres».
3. **Mes de inicio con doble conteo.** El acumulado del mes en curso es saldo inicial (si es el de hoy, ya incluye el
   sueldo y lo gastado) + el neto planeado del mes ENTERO. Sonda: 13,517.50 + 1,700 = 15,217.50, contra 12,905 reales a
   fin de mes (2,312.50 contados dos veces).
4. **Los totales del mes usan lo planeado, también en meses cerrados y en líneas excedidas.** Octubre (semilla): «te
   quedó S/ 3,914» con freelance planeado 3,764 y llegado 1,373. Sonda: comida excedida (1,380 de 900) y el total de
   gastos sigue en 2,900.
5. **Sin categoría no existe para el plan.** `TransactionIndex` exige categoría: ni línea ni «Gastos no considerados».
   Sonda: -100 y +250 sin categoría fuera de la tabla. Rompe la regla de `ingreso-gasto.md`.
6. **Las devoluciones suman como gasto.** El índice suma magnitudes (`abs`): la devolución de +80 en Comida, en vez de
   restar 80, suma 80 (1,380 en lugar de 1,220, con el fechado del día 28 dentro). Rompe «cómo se suma: con signo».
7. **El «real» de una línea incluye lo fechado después de hoy** (sonda: +200 del día 28 ya cuenta como gastado).
8. **El mes en curso, incompleto, entra en los promedios de los meses futuros.** Comida dic = 980 (por el 1,380 a medias
   de noviembre); transporte dic = 181.25 (por los 87.50 a medias).
9. **El «límite» de una línea con promedio se mueve solo cada mes** (semilla, Hobbies: 142 este mes, 120 dic, 122 ene).
   Por eso «¿se cambia para siempre?» no tiene respuesta clara.
10. **«Falta salir» castiga de más en dos casos medidos** (escenario 2 de la sonda): línea por subcategoría con el gasto
    anotado en la categoría madre (+500 que ya estaban en el saldo) y un gasto puntual sin línea de hace 45 días que el
    ritmo reparte (+467). Falta salir 1,066.67 contra ~100 reales.
11. **Los meses futuros no proyectan «Gastos no considerados»** (`otherExpenses == nil` fuera de pasado/en curso): los
    meses que vienen son más optimistas que el actual. «Ver proyectado» del Panel sí los proyecta (ritmo).
12. **Detalle de línea incompleto:** solo los 5 últimos registros, «Ajustar monto» al final, solo montos > 0, en meses
    pasados no se puede, y el alcance se pregunta después de escribir («Solo ese mes / Ese mes y los siguientes»; no hay
    «todos los meses» salvo cambiar el método, que reescribe también los pasados).

## Tickets revisados

- `projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month`: **vigente**, medido: diciembre proyecta
  3,214.58 de gasto, de los que 150 son el mismo movimiento dos veces. Se cierra en S1/S6.
- `cash-flow-advanced-gate-never-limits-free-users`: **obsoleto**. La decisión 2 de 2.3 se tomó (A: gratis entero) y el
  lote 08 retiró `cashFlowAdvanced` (`FlujoNecesariasLote08Tests` fija que no existe). Pasar a `done`.

## Qué decide Jürgen antes de S1

En el artifact, con selector. Recomendado entre corchetes.

- **P1 · Modelo:** [A · mes real + lo que falta] / B · plan puro / C · proyección automática.
- **P2 · Línea excedida:** [cuenta lo real y no proyecta más] / sigue al ritmo del mes.
- **P3 · Alcance por defecto al cambiar un límite:** [desde este mes en adelante] / solo este mes.
- **P4 · Qué es el límite:** [un monto fijo, sembrado con tu promedio al crear] / el promedio móvil de hoy.
- **P5 · Saldo inicial manual:** [retirarlo: se parte del saldo de tus cuentas] / dejarlo como opción.
- **P6 · Lo que no tiene línea en meses futuros:** [gastos por la mediana de 6 meses; ingresos no se proyectan] / nada.

## Plan de arreglo (una vista por sesión)

| Sesión | Vista | Qué | Esfuerzo |
|---|---|---|---|
| S1 ✅ | Motor del mes (sin UI) — **hecha el 18-nov** (ver «S1 hecha» abajo) | Una cuenta por mes: real con signo y sin categoría + lo que falta por línea + «otros» por mediana. Mes en curso desde el saldo de hoy; pasados = real; futuros encadenan desde el cierre. Sin doble conteo de fechados, promedio sin el mes a medias. Paridad con «Al 30» del Panel. Review adversarial. | Alto (1 sesión larga) |
| S2 | Detalle del mes y cápsulas | Una historia: «Empezaste con · Entró · Salió · Terminas con», real y estimado distinguidos. Fuera «Empezaste con S/ 0» y las tres cifras. | Medio |
| S3 ✅ | Detalle de línea — **hecha el 18-nov** (ver «S3 hecha» abajo) | Todos los registros del mes (por día, «Ver en Registros»), límite arriba con «Cambiar», lo que falta y si sigue al ritmo, 6 meses real vs límite, aviso de gasto en la categoría madre. | Medio-alto |
| S4 ✅ | Cambiar límite — **hecha el 18-nov** (ver «S4 hecha» abajo) | Hoja única con alcance ANTES de escribir (solo este mes / desde este mes / todos), admite 0, dice qué meses cambian. Retirar `CashFlowLineConfigSheet` (inalcanzable). | Medio |
| S5 | Crear plan | Sin «¿Con cuánto empiezas?», líneas por categoría por defecto, límites fijos sembrados con el promedio. | Bajo-medio |
| S6 | Consumidores | Panel «Ver proyectado», widget de Saldo y Tendencias con la misma pieza de S1 (otros por mediana, sin doble conteo). | Medio |

Orden: S1 → S2 → S4 → S3 → S5 → S6. S1 necesita P1, P2, P4, P5 y P6 decididas.

## Encontrado y no tocado

- ~~`CashFlowLineConfigSheet` (528 líneas) no se abre desde ningún sitio~~: retirada en S4.
- Las cápsulas «Comparativa / Flujo de caja» flotan sobre las filas al desplazar y se lee el texto de detrás
  (`capturas/antes-02`).
- La línea «Combustible» de la semilla sale con el icono genérico de cuadrícula (`capturas/antes-02`).
- El texto «Si no eliges fecha, se asume que es hoy» de la hoja de saldo inicial no dice lo que hace el código (hallazgo 2).

## S1 hecha (18-nov-2026)

Motor del mes en `Yala/App/Logic/FlujoMotorMes/`; `CashFlowProjectionCalculator.calculate` conserva su firma y sus tipos
y delega en él. Decisiones del arranque: el «Paso 0» del encargo `2026-11-18-flujo-motor-del-mes`. Cierra los hallazgos
1 a 11 (un test por hallazgo en `YalaTests/FlujoMotorMes/FlujoMotorMesTests.swift`, con las cifras de la sonda) y el
ticket `projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month` para el flujo de caja y para «Ver
proyectado» con plan.

Lo que ya cambia y las siguientes sesiones tienen que saber:
- **«Ver proyectado» con plan (Panel, Tendencias, widget de Saldo) ya sale del motor** (`ProjectedFlowBuilder.planRemaining`):
  era la única forma de que «Al 30» fuera la misma cifra y de cerrar el hallazgo 10. Con plan, los dos lados salen de él
  (ingresos sin línea: no se proyectan) y lo no cubierto ya no va al ritmo. S6 queda para lo que no es el plan (sin plan
  sigue el ritmo) y para revisar las pantallas.
- **El saldo inicial manual ya no se usa.** La fila «Empezaste con · Cambiar» del detalle del mes sigue enseñando el del
  plan hasta S2. `projection.startingBalance` es el saldo real al empezar el mes en curso.
- **API nueva para S2/S3** (en `CashFlowMonth`): `openingBalance`, `realIncome`/`realExpense`, `incomeLeft`/`expenseLeft`,
  `expenseGroups`/`incomeGroups` (la categoría como suma, con `unassignedAmount` = lo anotado en la madre); en
  `CashFlowLineResult`: `datedAmount`, `pendingAmount`, `leftAmount`, `isExceeded`, `expectedAmount`, y el desglose por
  subcategoría siempre en las líneas por categoría.
- **Interino:** lo anotado en la categoría madre de líneas por subcategoría suma en el total del mes pero no se pinta en
  ninguna fila hasta S3 (aviso de gasto en la categoría madre).

## S2 hecha (18-nov-2026)

El detalle del mes cuenta una sola historia: la cifra grande es «Terminas con» (en pasado «Terminaste», en un mes que
viene «Terminarías», con «≈» si no ha cerrado) y debajo «Empezaste con · Entró · Salió», con lo que falta (estimado) bajo
lo real en el mes en curso. Si la suma no da el saldo de las cuentas (ajustes de saldo, movimientos sin cuenta, divisas),
una fila «Ajustes de saldo» lo dice. Sin cuentas que sumen, la cifra vuelve a ser lo que queda. Lógica pura en
`Yala/App/Views/Reports/CashFlow/DetalleMes/FlujoDetalleMesLogica.swift`; decisiones en el «Paso 0» del encargo
`2026-11-18-flujo-detalle-del-mes`.

- Fuera: «Empezaste con · Cambiar» (la hoja del saldo inicial ya no se abre desde la tabla), «Este mes te quedaría», «Si
  sigue así, a fin de … tendrías» y el desglose «Tienes hoy / Falta entrar / Falta salir».
- La cápsula de cada mes dice con cuánto terminas (la misma cifra grande).
- La tabla agrupa por categoría (cabecera plegable con su suma) y la fila base es la subcategoría. Una línea por categoría
  de antes enseña su desglose por subcategoría debajo; lo anotado en la madre sin subcategoría sale como fila «Sin
  subcategoría» del grupo (cierra el interino de S1 en la tabla; el aviso sigue siendo de S3).
- La barra «Comparativa / Flujo de caja» ya no deja leer las filas detrás (`safeAreaBar`).

Pendiente para S3 y siguientes: crear líneas siempre por subcategoría (hoy el armado y «Agregar línea» aún pueden crear
una línea por categoría; la tabla la enseña con su desglose).

## S4 hecha (18-nov-2026)

«Cambiar límite» en `Yala/App/Views/Reports/CashFlow/CambiarLimite/`: una hoja que pregunta primero qué meses cambian
(solo este mes / desde este mes en adelante, elegido por defecto / todos los meses), después el monto (admite 0), y
enseña «Así quedan» mes a mes antes de guardar. Decisiones del arranque: el «Paso 0» del encargo
`2026-11-18-flujo-cambiar-limite`.

- **Qué escribe cada alcance** (`FlujoCambiarLimiteLogica.escritura`, aplicado por `CashFlowPlanViewModel.cambiarLimite`):
  solo este mes = ajuste de un mes; desde este mes = cambio «desde» (los meses siguientes con ajuste propio lo conservan
  y la hoja los nombra); todos = monto fijo sin cambios «desde» ni ajustes de un mes (en un pago planificado, un cambio «desde» el primer
  mes del plan, para no desligarlo de sus pagos).
- **Meses cerrados: se puede.** En el motor un mes pasado es lo real, así que el límite solo cambia con qué se compara; la
  hoja lo dice.
- **Punto de entrada para S3:** presentar `FlujoCambiarLimiteSheet` con `FlujoCambiarLimitePeticion(lineID:monthKey:)`.
  Hoy la abre «Ajustar monto» del detalle de línea (`CashFlowCellDetailSheet`), que ya no tiene campo ni alerta de alcance.
  S3 mueve ese «Cambiar» arriba, junto al límite.
- **Retirado:** `CashFlowLineConfigSheet`, `showLineConfig` y `selectedLine` del ViewModel.
- **Pendiente para S5:** el método de la línea sigue existiendo («Cómo se calcula · Cambiar»); P4 (límite fijo sembrado
  con el promedio) lo resuelve el crear plan.

## S3 hecha (18-nov-2026)

El detalle de una línea pone arriba «Límite de noviembre · S/ X · Cambiar» (abre la hoja de S4) con «‹ mes ›» para
recorrer el plan; debajo, lo que llevas, lo que falta y, en gastos del mes en curso, si sigue al ritmo («Al ritmo de este
mes llegarías a ~S/ X», en rosa si pasa del límite; excedida: «Te pasaste por X. No se proyecta más.»). Luego «Últimos 6
meses» (barra de lo real y raya del límite de cada mes) y TODOS los registros del mes por día, con su total y «Ver en
Registros» (filtra la subcategoría o la categoría y el período del mes). Una línea por subcategoría dice su categoría
encima del nombre y avisa de lo anotado en la madre sin subcategoría. Lógica pura en
`Yala/App/Views/Reports/CashFlow/DetalleLinea/FlujoDetalleLineaLogica.swift`; decisiones en el «Paso 0» del encargo
`2026-11-18-flujo-detalle-de-linea` (variante A de tres).

- Los registros salen del reparto del motor (un dueño por movimiento) con el alcance de cuentas de la cifra: la lista
  suma lo real de la línea. Antes se filtraba por categoría a mano y una línea por categoría contaba lo de sus
  subcategorías con línea propia.
- Los seis meses salen del mismo reparto y de `resolvePlanned`, así que no dependen de los 3 meses atrás del plan.
- Fuera: la gráfica diaria (`CashFlowCellMiniChart`, sumaba magnitudes sin convertir), la tira de ±2 meses, «Últimos
  registros» (5) y «Ajustar monto» al pie.

Pendiente para S5 y siguientes: crear líneas siempre por subcategoría (sigue igual que tras S2).

