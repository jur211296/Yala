# Yala 2.3: «Cuánto puedo gastar hoy», el cupo diario vivo desde el presupuesto restante

Pedido de Jürgen (2026-11-03): si de noche se acaba la cola de 2.2, se lanza lo más prioritario de 2.3 en una rama nueva.

0. Rama 2.3: si no existe `origin/2.3`, créala desde `origin/2.2` actualizado (después de TestFlight 2.2) y súbela. Todo lo de este encargo va en un PR contra 2.3, nunca contra 2.2. Si 2.2 todavía tiene PRs abiertos con auto-merge pendiente, crea igual la rama desde lo que ya está en 2.2 y anótalo en el PR.
1. Card del tablero: «"Cuánto puedo gastar hoy": cupo diario vivo desde el presupuesto restante». Léela entera y sigue su alcance.
2. Diseño: si la card no fija el diseño, propone 2 o 3 variantes con capturas en el PR, implementa la que recomiendes detrás de una sola vista y deja las otras como propuesta para que Jürgen elija. No bloquees esperando.
3. Tests de la lógica del cupo y capturas en iPhone y iPad. Textos en los idiomas de la app.
4. Card a in qa con el link del PR. Squash auto-merge en 2.3 si el gate pasa.

Textos para Jürgen en español neutro latinoamericano.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass, 2026-11-04 00:50 Lima)

1. **Rama 2.3**: no existía; se creó desde `origin/2.2` (último merge: TestFlight 2.2 (7)). Quedaban PRs abiertos contra 2.2 con auto-merge pendiente (cuatro de octubre, atascados): no entran en 2.3. Se anota en el PR.
2. **Fórmula**: por presupuesto. Cupo de hoy = (límite − gastado del período fuera de hoy) ÷ días que faltan con hoy − gastado hoy. «Fuera de hoy» incluye lo ya apuntado para días posteriores del período (comprometido). Así cupo × días − hoy = «Te quedan» de la fila. Reusa `BudgetsViewModel.calculateSpending` (misma regla que Planificación y Panel) y `BudgetPeriodInterval`.
3. **Sin cupo que enseñar** cuando el período no está en curso, el límite es 0 o el presupuesto ya estaba agotado antes de hoy (la fila ya dice «Te pasaste por»). Si hoy te pasas del cupo del día: «Hoy te pasaste por S/ X», en rosa.
4. **Mes financiero**: Yala no tiene día de cobro configurable; el mes es el de calendario (con el calendario del usuario). Fuera de alcance.
5. **Varios presupuestos**: cada uno tiene su cupo; no se suma (los filtros se solapan y sumarlos contaría doble).
6. **Gratis o Pro**: gratis. Sale de presupuestos que ya existen (los gratis también) y es el gancho de paridad con Mi Hormiga.
7. **Diseño (la card no lo fija)**: variante A implementada —«Hoy puedes gastar S/ X» en cada fila del widget Presupuestos del Panel (tamaños mediano y grande) y en el detalle del presupuesto, donde sustituye al «Puedes gastar S/ X al día» estático (dos cifras por día distintas en la misma tarjeta se contradirían)—, detrás de una sola vista (`DailyAllowanceLine`). Variantes B (tarjeta propia «Hoy puedes gastar» arriba del Panel) y C (solo en la lista de Presupuestos) quedan como propuesta con maqueta en el PR.
8. **Widget pequeño del Panel**: no lleva el cupo (dos líneas por presupuesto, no cabe).
9. **Textos**: claves nuevas en los 16 locales.
