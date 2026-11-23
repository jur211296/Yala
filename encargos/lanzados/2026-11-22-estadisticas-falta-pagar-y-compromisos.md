Yala
# «Lo que te falta pagar» sin ingresos ni saltados, y la nota de Compromisos igual a su hoja
---
toca: Yala/App/Views/Statistics/,Yala/App/Views/Planning/,Yala/App/Logic/Calculators/,YalaTests/FaltaPagarCompromisos/,tickets/backlog/2026-11-20-lo-que-te-falta-pagar-cuenta-ingresos-y-saltados.md,tickets/backlog/2026-11-20-hoja-y-nota-difieren-con-pagos-apuntados-a-futuro.md,tickets/backlog/2026-11-20-nota-no-recalcula-al-cambiar-tu-dinero-hoy.md,tickets/done/2026-11-20-lo-que-te-falta-pagar-cuenta-ingresos-y-saltados.md,tickets/done/2026-11-20-hoja-y-nota-difieren-con-pagos-apuntados-a-futuro.md,tickets/done/2026-11-20-nota-no-recalcula-al-cambiar-tu-dinero-hoy.md,tickets/backlog/2026-11-22-estadisticas-falta-pagar-y-compromisos.md,tickets/done/2026-11-22-estadisticas-falta-pagar-y-compromisos.md
esfuerzo: medium
cierre: cierra-sola
---

Jürgen pidió el 22-nov (15:08 Lima) encolar todo lo pendiente del backlog que esté claro o tenga decisión. Este encargo junta tickets afines.

## Tickets
- `tickets/backlog/2026-11-20-lo-que-te-falta-pagar-cuenta-ingresos-y-saltados.md`
- `tickets/backlog/2026-11-20-hoja-y-nota-difieren-con-pagos-apuntados-a-futuro.md`
- `tickets/backlog/2026-11-20-nota-no-recalcula-al-cambiar-tu-dinero-hoy.md`

## Qué hacer
«Lo que te falta pagar» de Estadísticas no cuenta ingresos planificados ni pagos saltados. La hoja y la nota de Compromisos dan lo mismo con un pago apuntado a fecha futura, y la nota se recalcula al cambiar qué cuentas son «Tu dinero hoy».

## Reglas
- Antes de tocar nada, verifica contra `origin/2.3` que cada ticket siga pasando (varios son viejos). Si uno ya no pasa o ya está hecho, muévelo a done con la evidencia y sigue con los demás.
- Si un ticket resulta ser una decisión de diseño o de producto que solo Jürgen puede tomar, no la inventes: déjalo en backlog con la pregunta y las opciones con su recomendación, y anótalo en el cierre.
- Textos nuevos en su propia tabla `.strings` (la del toca), no en Localizable.strings ni L10n.swift, en los 16 idiomas y siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
- Si hace falta tocar algo fuera del toca, toca lo mínimo y anótalo en el cierre.
- Producción (iCloud Production, Supabase prod, gateway, web publicada) no se toca: déjalo probado en desarrollo y anotado para Dan, con el OK de Jürgen.
- Nada de pago.

## Dispositivos
Antes de usar un simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre; no lo des por ocupado sin comprobarlo. En la Max puedes usar un segundo simulador si otra sesión ya usa uno (tope 2); en la Mini, 1.

## Cierre
Commits y PR sin firma de IA y sin saltarse hooks. Espera el merge real del PR en 2.3 antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo ajeno al PR, cierra y anótalo. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

Verificado contra `origin/2.3` (c6affe870): los tres tickets siguen pasando.

1. **«Lo que te falta pagar» (Estadísticas › Resumen)** → usa `FinancialScoreCalculator.pendingOccurrences`, la pieza de la nota y la hoja: solo gastos, cada ocurrencia del período, sin saltadas ni pagadas con movimiento enlazado. Lo pagado se lee con `ScheduledPaymentPaidStatusHelper` en el mismo intervalo (hasta el fin del período en curso). Consecuencia asumida: en «Este año» o un período cerrado cuenta cada ocurrencia no pagada desde la creación del pago, igual que la nota.
2. **Hoja vs nota con un pago apuntado a futuro** → de las dos salidas del ticket, se toma «restarlo de la comparación» + una línea secundaria que lo dice («Ya descontamos S/ X que apuntaste con fecha más adelante»). «Tu dinero hoy» (barra y frase) no cambia: sigue siendo la cifra del hero. Se mide igual que la nota (`asOf: .distantFuture` sobre las mismas cuentas), no solo «este mes», para que las dos den lo mismo.
3. **La nota no recalcula al cambiar «Tu dinero hoy»** → `PanelView` observa `panelMoneyAccountOverrides` junto a `includeGroupsInPanelTotal`, en un `ViewModifier` propio (la cadena del body no crece: regla del CI).
4. **Textos nuevos** → en la tabla propia de la hoja, `SaludFinancieraDetalle.strings` (ya existe, no es Localizable), 16 idiomas, español neutro también en es-ES.
5. **Fuera del toca, lo mínimo**: `Views/Panel/Sheets/SaludFinanciera/` (tickets 2), `Views/Panel/PanelView.swift` (ticket 3), `ViewModels/InsightsViewModel.swift` y `StatisticsRecalculation.swift` (pasar lo pagado), y el fixture de `InsightsToPayUntilPeriodEndTests` (pagos de una vez creados antes del período).
6. **Choque con la sesión «novedades 2.3 / nota de salud»** (también toca `Logic/Calculators`): solo se toca `InsightsCalculator.swift`; si choca al rebasar, se resuelve aquí.
