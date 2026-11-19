---
id: 2026-11-19-flujo-proyeccion-inteligente
status: done
priority: high
area: cash-flow
created: 2026-11-19
updated: 2026-11-19
source: encargo 2026-11-19-flujo-proyeccion-inteligente (decisión de Jürgen del 19-nov, 06:10 Lima; corrige P6 del replanteo)
---
# Flujo de caja: proyección inteligente con ingresos fijos y sin outliers

Jürgen, 19-nov: «Las proyecciones deben ser inteligentes, saber según registros qué cosas son outliers y no
considerarlas pero los ingresos fijos deberían aparecer. Lo mismo para gastos, si me compro un iPhone de 6000 soles pero
nada más, el promedio 6m será 1000 cuando realmente es un gasto aislado, no debería considerarse en las proyecciones».

Antes (P6 del replanteo, `2026-11-17-flujo-de-caja-replanteo`): sin plan o sin línea, los ingresos no se proyectaban y
los gastos iban por la mediana de 6 meses de «otros», con todo dentro.

## Qué cambia

Pieza nueva `Yala/App/Logic/FlujoProyeccionInteligente/`, llamada desde el motor del mes (`FlujoMotorMes.calcular`), así
que flujo de caja, Panel («Ver proyectado»), Tendencias y widget de Saldo proyectan lo mismo. Solo mira lo que no tiene
línea («otros»): las líneas del plan siguen con el método que la persona eligió.

- **Ingresos fijos**: un grupo de ingresos (subcategoría → categoría → sin categoría; dentro de un grupo que varía, un
  comercio por su nota) que aparece con un monto dentro del ±25 % de su mediana en al menos 2/3 de los 6 meses completos
  (nunca menos de 3) y sigue vivo (alguno de los 2 últimos meses o el en curso). Se proyecta con su monto (mediana) y su
  día típico; en «Ver proyectado» se dibuja ese día (o mañana si ya pasó sin llegar). Lo ya cobrado en el mes, enlazado a
  un pago o no, y los pagos planificados pendientes de su grupo descuentan: no hay doble conteo.
- **Aislados** (ingresos y gastos): un movimiento de «otros» que mide al menos 3 meses típicos del lado sin él y cuyo grupo
  no tuvo otro de la mitad en otro mes. Cuenta en su mes; sale de la mediana de los meses que vienen, y en el mes en curso
  (o en un fechado futuro) no se come lo que falta por gastar del resto.
- **Gastos**: la mediana mensual de «otros» sin aislados. En gastos no se parte por grupos: lo que se repite ya está en la
  mediana. **Ingresos que varían**: no se proyectan (conservador).
- **Historia corta** (< 3 meses completos): nada fijo ni aislado; gastos por la mediana de todo, como antes, y ningún
  ingreso sin pago planificado.
- **Hoja «Otros»**: dice qué se proyecta como fijo (monto, día, en cuántos meses se vio, «Ya llegó este mes») y qué quedó
  fuera por aislado (con su mes), cómo va el resto y, con poca historia, por qué aún no se detecta nada. Textos en
  `FlujoProyeccionInteligente.strings` (16 idiomas).

## Pruebas

`YalaTests/FlujoProyeccionInteligente/`: sueldo fijo sin plan (y ya cobrado, y que se dejó de cobrar, y por comercio),
iPhone aislado (6 y 3 meses; y comprado este mes), gasto que se repite incluido, sin doble conteo con pago planificado,
historia corta; paridad Flujo de caja = Panel = widget = Tendencias con plan sin líneas y sin plan; textos en 16 idiomas.

## Fuera

- Los métodos de una línea que miran la historia («Promedio 6 meses», «Tendencia») no quitan aislados: P6 es «lo que no
  tiene línea». Si Jürgen lo quiere también en las líneas, es otro encargo.
- El rótulo de la fuente bajo «Ver proyectado» («Estimado con tus pagos planificados» en ingresos) no nombra los ingresos
  fijos: vive en `Localizable.strings`, fuera del encargo (card aparte).
