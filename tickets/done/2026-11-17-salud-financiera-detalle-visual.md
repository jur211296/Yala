---
id: 2026-11-17-salud-financiera-detalle-visual
status: done
priority: medium
area: "panel, salud-financiera"
created: 2026-11-17
updated: 2026-11-18
source: "Jürgen, 17-nov-2026 (20:52 Lima), con captura"
---

# La hoja de Salud financiera es puro texto que nadie lee

Al tocar la tarjeta de Salud financiera del Panel salía el anillo, «¡Vas increíble!», un párrafo que explicaba los pesos y
tres filas de texto (Presupuestos 40 %, Ritmo 25 %, Compromisos 35 %). Jürgen: «pésimo, nada de valor añadido, puro texto
que nadie leerá».

## Hecho cuando

La hoja enseña lo que hay que mirar y lleva a hacerlo: alertas vigentes, presupuestos con su barra, pagos que vienen y si
el saldo los cubre, días seguidos registrando y qué hacer para subir la nota, cada cosa con toque a su vista. Los pesos
quedan plegados en «¿Cómo se calcula?». Sin presupuestos o sin pagos, invita a crearlos. La nota no cambia de cálculo.

## Resolución (2026-11-18)

Variante A («lista de acciones») de tres propuestas. La hoja de la nota total abre grande con: la nota y sus tres partes
en cápsulas; «Para revisar» (presupuestos pasados con cuánto, pagos que no se cubren al cierre del mes, pagos vencidos,
cuentas en negativo, y los presupuestos cerca del límite en una sola fila si son varios); «Tus presupuestos» con barra y
estado, los que van peor primero; «Próximos pagos» de las dos semanas siguientes y «Al 30 de noviembre tendrías» (la cifra
del Panel); «Tu racha» con los últimos 14 días; «Para subir tu nota» (hasta dos pasos con lo que pesa cada parte); y
«¿Cómo se calcula?» plegado. Las hojas de cada parte (desde Estadísticas) no cambian.

Lógica en `Yala/App/Views/Panel/Sheets/SaludFinanciera/` (reusa `BudgetsViewModel.calculateSpending`,
`BudgetStatusCounter`, `MonthEndBalanceLogic`; los movimientos se leen por tramos). Pruebas:
`YalaTests/SaludFinancieraDetalle/` y `YalaUITests/SaludFinancieraDetalle/`.
