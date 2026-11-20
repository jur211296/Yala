---
id: 2026-11-20-flujo-de-caja-fluidez
status: done
priority: high
area: "cash-flow-plan, reports-comparative"
created: 2026-11-20
updated: 2026-11-20
source: "pedido de Jürgen del 20-nov-2026, con vídeo en su iPhone (encargo «Flujo de caja y Comparativa fluidos»)"
---

# Flujo de caja y Comparativa: sin rebote arriba, sin recálculos de más y con la marca de cambio siempre

Jürgen: «En flujo de caja tenemos mucha lentitud y hay un "rebote" horrible en la parte superior», también en la
Comparativa y al viajar a otras páginas con filtros; y en la Comparativa «no hay un chip de variación con un color».

## Hecho cuando

- Lanzar la lista hasta un borde y soltarla no la deja rebotando sola, en las dos pestañas.
- Volver a Flujo de caja (chip, otra pestaña, «Ver en Registros» y vuelta) no repite el cálculo entero si nada cambió,
  y los números no cambian.
- La Comparativa no calcula mientras no se ve.
- La marca de cambio de cada fila sale aunque «Mostrar variaciones» esté apagado.

## Resolución (2026-11-20)

- **Rebote.** Su descripción: «cuando bajas bastante y scrolleas rápido hasta el título, se queda como pegado ahí
  rebotando». Reproducido en el simulador con `YalaUITests/FlujoDeCajaFluidez/FlujoFluidezMedicionUITests.test_rebote`
  y medido en el vídeo fotograma a fotograma: la barra de pestañas se encogía y desplegaba sin parar y la lista saltaba
  ~88 pt cada ~1,2 s; el Panel, con el mismo gesto, no. Causa: el scroll de Reportes iba dentro de un `VStack` con la
  guía de la Comparativa encima. Ahora el scroll es la raíz y la guía va dentro (molde `StatsGuideSlot`); después del
  arreglo, un solo movimiento y quieta, como el Panel.
- **Lentitud.** `CashFlowPlanViewModel.recalculate(firma:)` solo recalcula si cambia `FlujoRecalculoFirma` (revisión del
  plan, `dataVersion`, guardados de SwiftData, nº de movimientos, pagos, cuentas, categorías, divisa, grupos, día) o hay
  cambios sin guardar; lo que guarda el propio cálculo no cuenta. La Comparativa queda pendiente mientras no se ve y
  calcula al aparecer (`FlujoFluidezLogica`). Medido con 10 años de datos: volver a Flujo de caja, de ~930 ms a ~100 ms.
- **Marca de cambio.** Ya existía desde el 18-nov; con «Mostrar variaciones» apagado no salía. Decisión de Jürgen: en la
  Comparativa no depende de ese ajuste (filas, «Te quedó», columna «Cambio» y chips de con qué comparar).
- Pruebas: `YalaTests/FlujoDeCajaFluidez/` (firma, números iguales con y sin firma, cableado, Comparativa sin el ajuste).
