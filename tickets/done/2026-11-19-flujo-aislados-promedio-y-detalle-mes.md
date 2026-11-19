---
id: 2026-11-19-flujo-aislados-promedio-y-detalle-mes
status: done
priority: high
area: cash-flow
created: 2026-11-19
updated: 2026-11-19
source: encargo 2026-11-19-flujo-aislados-promedio-y-detalle-mes (decisiones de Jürgen del 19-nov: 10:09, 10:14, 10:16, 10:21, 10:24, 10:45 y 10:47, hora de Lima)
---
# Flujo de caja: aislados en las líneas por promedio, límites móviles, detalle por mes y solo fijos a futuro

Jürgen, 19-nov: «Yo quitaría los aislados, a veces son súper claros y arruinan la media. Justo en este ejemplo se nota,
dos meses ultra fuertes. […] Debería: 1. Tener tooltip útil las barras al mantener el cursor y 2. Poder apretar un mes y
que abajo en registros de noviembre, cambie a los registros de ese mes». Su ejemplo: «Fitness y actividad física» con
«Promedio 6 meses», agosto y octubre muy por encima del límite.

Más, el mismo día: que «no considerados» llegue siempre a subcategoría; que la hoja «Cálculo del monto» no esconda el
campo del monto fijo; que los límites por promedio se muevan solos cada mes (corrige el P4: «el límite es un monto fijo
sembrado al crear»); un solo «Cambiar» en el detalle de línea; y que, en los meses que vienen, fuera de las líneas solo
se proyecte lo fijo y asegurado, con la opción de no considerar una partida a futuro («exagerar significa decirle al
usuario que está mucho peor de lo que realmente está»).

## Qué cambia para quien usa Yala

- **Aislados fuera del promedio.** Una línea por promedio, último mes o tendencia deja fuera los meses que suman 3 veces
  o más lo normal de esa línea (con al menos 3 meses con datos). Fitness pasa de S/ 605 a S/ 150. Lo gastado ese mes sigue
  contando en ese mes.
- **«Cómo se calcula»** lo dice: «Promedio de los últimos 6 meses, sin agosto y octubre por ser montos aislados. Se
  actualiza solo cada mes.»
- **Límites móviles.** El límite de cada mes se calcula con los meses anteriores a ese mes; los meses que vienen usan los
  últimos meses completos. Solo «Monto fijo» deja un número quieto. Crear el plan y «Agregar línea» ya no lo congelan.
  Las líneas que el P4 congeló (solo builds de TestFlight de 2.3) vuelven a su promedio una vez.
- **Un solo «Cambiar»**, junto al límite, abre «Cálculo del monto» rediseñada: el monto grande y en vivo arriba, cuánto
  daría cada método y qué meses dejó fuera, y «Monto fijo» con su campo arriba, relleno y con el teclado, más qué meses
  cambian (por defecto, desde este mes en adelante). Abre grande en iPhone y como formulario en iPad.
- **Gráfica de 6 meses**: mantener una barra (o el puntero en iPad/Mac) enseña mes, gastado, límite, diferencia y si se
  dejó fuera por aislado; tocarla cambia la lista de abajo a ese mes, con su total, «Ver en Registros» de ese mes y
  «Volver a noviembre».
- **No considerados por subcategoría**, agrupados por categoría con su suma y plegables; lo anotado en la categoría sin
  subcategoría va en su fila; el + agrega la subcategoría, no la categoría entera.
- **Meses que vienen, con plan: solo lo fijo** fuera de las líneas (ingresos fijos y gastos que se repiten cada mes con
  monto y día parecidos). Cada partida tiene «Considerar a futuro». Si no hay nada, la hoja dice que no hay gastos fijos
  fuera del plan y el total es S/ 0. Arreglado el bug de la hoja vacía con total distinto de cero: total y lista salen de
  la misma fuente.
- Panel, widget de Saldo y Tendencias dan las mismas cifras que el flujo de caja (test de paridad ampliado).

## Decisiones tomadas en la sesión

Están en el Paso 0 del encargo (`encargos/lanzados/2026-11-19-flujo-aislados-promedio-y-detalle-mes.md`): aislados a nivel
de mes, ventana de los meses futuros, migración por coincidencia al céntimo, «solo fijos» solo con plan y en meses que
vienen, «Considerar a futuro» como preferencia local.

## Qué quedó fuera

- «Considerar a futuro» no se sincroniza entre teléfonos (preferencia local).
- Device-QA en un iPhone real: la pulsación larga y el toque de la gráfica dentro del scroll de la hoja.
