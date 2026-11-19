Yala
# Flujo de caja: proyección inteligente con ingresos fijos y sin outliers
---
toca: Yala/App/Logic/FlujoMotorMes/,Yala/App/Logic/Calculators/CashFlowProjectionCalculator.swift,Yala/App/Logic/Calculators/ProjectedFlowBuilder.swift,Yala/App/Views/Reports/CashFlow/CashFlowOthersSheet.swift,Yala/App/Logic/FlujoProyeccionInteligente/,YalaTests/FlujoProyeccionInteligente/,tickets/backlog/2026-11-19-flujo-proyeccion-inteligente.md,tickets/done/2026-11-19-flujo-proyeccion-inteligente.md
esfuerzo: high
cierre: cierra-sola
depende:
---

Decisión de Jürgen del 19-nov (06:10, hora de Lima), ya registrada: corrige el punto P6 del replanteo del Flujo de caja. Sus palabras: «Las proyecciones deben ser inteligentes, saber según registros qué cosas son outliers y no considerarlas pero los ingresos fijos deberían aparecer. Lo mismo para gastos, si me compro un iPhone de 6000 soles pero nada más, el promedio 6m será 1000 cuando realmente es un gasto aislado, no debería considerarse en las proyecciones». Hoy, sin plan o sin línea, los ingresos no se proyectan y los gastos se proyectan por la mediana de 6 meses. Él pide que la proyección sea realista.

## Qué hacer
- Detectar en los registros los ingresos fijos o recurrentes (el sueldo, alquileres que cobra, etc., con su monto y su día típico, tolerando variaciones chicas de monto y de fecha) y proyectarlos en los meses futuros aunque no exista plan ni línea. Los pagos planificados siguen contando como hoy, sin doble conteo con lo detectado.
- Detectar outliers en ingresos y en gastos, es decir, montos aislados que no se repiten (como una compra única de S/ 6,000), y excluirlos del cálculo de la proyección. El registro real del mes en que ocurrió sigue contando en ese mes; lo que se excluye es su efecto en los meses futuros.
- Elegir un método robusto y explicable, por ejemplo recurrencia por subcategoría y por comercio, más una mediana o un recorte por percentiles con un mínimo de meses de historia. Documentar los umbrales en el código y en el cierre. Si la historia es muy corta, comportarse de forma conservadora y anotarlo.
- El detalle sigue llegando a subcategoría, que es el id base, con la categoría como agrupador.
- La hoja «Otros» (o donde se explique lo proyectado sin línea) dice en lenguaje simple qué se proyectó como fijo y qué se dejó fuera por aislado. Los textos van en su propia tabla, nunca en `Localizable.strings`, y nunca un botón debajo de otro.
- Paridad de cifras: Panel («Ver proyectado»), widget de Saldo y Tendencias usan el mismo motor, así que deben seguir dando lo mismo que Flujo de caja. Agrega un test de paridad. Si para eso tienes que tocar algo fuera del toca, anótalo y crea una card en vez de tocarlo.
- Crear el ticket `tickets/backlog/2026-11-19-flujo-proyeccion-inteligente.md` y moverlo a done al cerrar.

## Cómo entregar
- Base 2.3, un PR, sin firma de IA en commits ni en el PR. Toca solo lo declarado. Si necesitas lógica nueva, ponla en `Yala/App/Logic/FlujoProyeccionInteligente/`.
- Tests unitarios de lo nuevo en `YalaTests/FlujoProyeccionInteligente/`: sueldo fijo proyectado sin plan, iPhone aislado excluido, gasto que sí se repite incluido, sin doble conteo con pagos planificados, historia corta. El presupuesto de tests de UI es de 1 o 2 como máximo, solo si hace falta.
- El entregable para Jürgen es un artifact visual de Claude con el antes y después usando la semilla de prueba: «Al 31 de diciembre» y los meses siguientes, qué se tomó como fijo y qué quedó fuera como aislado. También capturas de Flujo de caja (iPhone 17 y SE, claro y oscuro, letra grande, iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Hay otra sesión de Yala revisando el CI. No toques `.github/workflows/`, `YalaUITests/` ni `scripts/ci/`.

## Cierre
- El modo de sesión queda fijo al arrancar. Si el trabajo está completo y el modo lo permite, cierra con `/cerrar-total`. En semi, una decisión vital se pregunta y se espera con la sesión viva. En nocturno, se hace checkpoint sin completar, mergear ni desplegar lo incompleto.
- El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en semi, con mi recomendación; se discuten en el PR)

1. **Alcance: solo lo que no tiene línea («otros»).** P6 del replanteo es «lo que no tiene línea en meses futuros». Los
   métodos que la persona elige en una línea («Promedio 6 meses», «Tendencia») siguen siendo lo que dicen; no se les
   quitan aislados. Queda anotado como «Encontrado» por si Jürgen lo quiere también ahí.
2. **Fijo, solo en ingresos** = un grupo de ingresos de «otros» (subcategoría → categoría → sin categoría; y dentro de
   un grupo que no se repite entero, un comercio por su nota canónica) que aparece con un monto dentro del ±25 % de su
   mediana en ≥ 2/3 de los meses de la ventana (nunca < 3) y sigue vivo (alguno de los 2 últimos meses o el mes en
   curso). Se proyecta con su monto (mediana) y su día típico (mediana de días). En gastos no se parte por grupos: lo
   que se repite ya entra en la mediana mensual, y partirla cambiaría cómo se compensan los gastos dentro del mes (lo
   calculé a mano sobre la paridad S6: el gasto que falta en noviembre pasaba de 40 a 90 sin que nadie lo pidiera).
3. **Aislado** = un movimiento de «otros» que no es de un fijo, mide ≥ 3× un mes típico del resto sin él (mediana de los
   meses con algo) y su grupo no tuvo otro de ≥ 50 % en otro mes. Cuenta en su mes; fuera de la mediana de los meses
   que vienen. En el mes en curso (y en uno futuro con fechado) un aislado no se come lo que falta por gastar de lo
   demás.
4. **Lo variable**: gastos por la mediana mensual sin fijos ni aislados (ventana de 6 meses completos, como hoy).
   Ingresos que varían: no se proyectan (conservador: inventar ingreso es el error caro).
5. **Historia corta** (< 3 meses completos): ni fijos ni aislados; gastos por la mediana de todo, como hoy. Ningún
   ingreso sin pago planificado.
6. **Sin doble conteo**: lo que ya llevó el fijo en el mes (real o fechado, enlazado a un pago o no) y los pagos
   programados pendientes de su grupo descuentan de lo que le falta (por comercio, solo un pendiente de monto parecido).
   Un grupo con línea no llega a la detección: su dueño es la línea.
7. **Día**: en «Ver proyectado» un fijo que llega una vez al mes se dibuja en su día (si ya pasó sin llegar, mañana,
   como un pago vencido); uno de varias veces (quincena) se reparte. El cierre del mes no cambia.
8. **Textos**: tabla propia `FlujoProyeccionInteligente.strings` en los 16 idiomas (fuera del `toca:` declarado, pero
   la tabla propia la pide el encargo; ficheros nuevos, no chocan con nadie).
9. **Rótulo de la fuente** («Estimado con tu ritmo de gasto») vive en `Localizable.strings`, fuera del toca: no se toca;
   card aparte para un rótulo que nombre también los ingresos fijos.
10. **Tests existentes** que fijaban «los ingresos sin línea no se proyectan» se actualizan si caen: el cambio de regla
    es el encargo.
