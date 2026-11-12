# Lote 2.2: widget de Grupos con saldos en solo grupos, «Marcar como pagado» en el widget y venta en otra divisa cobrada con el tipo del día del pago

Base: origin/2.2 en jur211296/Yala. Una sola sesión a la vez. Un PR, un cierre.

1. Widget de Grupos en «solo grupos» (decisión de Jürgen: A). Muestra los saldos de tus grupos como en Yala completo. Quita `.invitesToActivateFullWhenGroupsOnly()` de GroupsWidget y ajusta su test. Card: «Widget de Grupos en «solo grupos»: ¿enseña los grupos o invita a activar Yala completo?».
2. Acción en el widget de Pagos planificados (decisión: B, solo marcar pagado). Agrega un botón con App Intent que marque como pagado el pago de hoy sin abrir Yala, usando la misma lógica que «Ya lo pagué». Lleva tests y la captura del widget. No incluyas «repetir favorito». Card: «Widgets: ¿quieres acciones en el sitio…?».
3. Grupos B, venta en otra divisa (decisión: A). Cuando un pago en la moneda del grupo cubre una venta en otra divisa, se usa el tipo de cambio del día del pago y queda fijo, sin recalcular. Mira GroupReceivableCoverageLogic.swift, GroupTransactionBridge+Receivables.swift y SettlementFormView.suggestedAmount. Está hecha cuando una venta en USD pagada en PEN con el sugerido queda cobrada entera el día del pago, con un test que falla sin el cambio. Card: «Grupos B · una venta en otra divisa no se cobra con un pago en la moneda del grupo».

Todo en español neutro latinoamericano, sin ids hacia Jürgen.

Termina con /cerrar-total.


## Tarea extra del lote (bug, Jürgen 2026-11-03)
Desde la edición de un registro que entró por imagen o voz no se puede convertir a gasto compartido. Reproducir, arreglar como en un registro manual, con test y video en el PR. Mover su card a in qa.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Widget de Grupos en solo grupos.** Se quita la invitación solo de ese widget; los demás widgets de datos la conservan. La invitación a «abrir Yala sin datos» se queda (sin foto, sigue diciendo que abras Yala).
2. **«Marcar como pagado» en el widget — dónde se escribe el registro.** El intent del botón NO abre SwiftData (un segundo contenedor sobre el store de la app vació la UI en el caso de Apple Pay; por eso Apple Pay y Siri encolan en el App Group). El botón deja una petición en el App Group, el widget pinta el pago como pagado en el acto y la app crea el registro con la lógica de «Ya lo pagué → Apuntarlo ahora» la próxima vez que corre (`InboundCaptureDrain`). Asumido: el registro aterriza al abrir Yala, no en el instante del toque.
3. **Qué pago lleva el botón.** Solo el de HOY (próxima fecha = hoy) y solo si «Apuntarlo ahora» lo haría en un toque: personal, con cuenta y subcategoría, monto fijo. Compartidos y de monto variable siguen abriendo Yala. Si al drenar el pago ya avanzó de esa fecha (se apuntó o saltó desde la app), la petición se descarta para no duplicar.
4. **Venta en otra divisa.** La cobertura entre divisas solo corre con «deudas en una sola moneda» encendido en el grupo (sin esa opción el grupo muestra deudas por divisa y el pago en otra moneda no cubre nada). Conversión con el tipo del día del movimiento que cubre (la tasa de ese día, leída a su mediodía como `BalanceValuation.rateDay`), fija: un repaso posterior no la recalcula. El «Sugerido» de la liquidación pasa a usar el mismo tipo del día del pago (antes, el último), para que pagar lo sugerido cubra la venta entera. Lo más antiguo primero entre todas las divisas.
5. **Bug de imagen/voz → gasto compartido.** Se reproduce primero; el arreglo copia el camino del registro manual, sin tocar más.
6. Review adversarial para el cálculo entre divisas (financiero); para el widget de Grupos no.
