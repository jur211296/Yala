---
id: 2026-11-23-estadisticas-resumen-opcion-b-decidir
status: done
priority: medium
area: "statistics, insights"
created: 2026-11-23
updated: 2026-11-24
source: "Jürgen, elección de la opción B en la propuesta del 23-nov (`docs/propuestas/estadisticas-resumen-2-3/`)"
---

# Estadísticas → Resumen, opción B · Decidir

Jürgen eligió el 23-nov-2026 la opción B de la propuesta: el Resumen sigue donde terminó el Panel, dice qué pide atención
hoy y lleva a su sitio.

## Hecho cuando

- Franja de salud chata con la parte que más baja la nota.
- «Para decidir hoy»: hasta tres acciones con salida a Presupuestos, Pagos planificados o Tendencias; se calla cuando no
  hay nada.
- Gastos hormiga protagonista: total grande, ritmo del mes, una fila por comercio que abre sus registros, la IA en su
  franja (Pro) y «Ver las compras» / «Ponerle un tope».
- Fila «Ir a»: Distribución, Tendencias, Registros, Presupuestos.
- Fuera: «Categoría principal», «Subcategoría principal» y la caja ancha de «Promedio diario».

## Resolución (2026-11-24)

Decidido sin consultar (sesión nocturna, Paso 0 del encargo):

- **Orden de «Para decidir hoy»**: presupuesto pasado → presupuesto al 90 % o más → lo que falta pagar → presupuesto
  entre 80 y 90 % → gasto diario que sube 5 % o más. Tres como mucho. Solo con un período que llega a hoy; en uno cerrado
  el bloque no sale. Cada acción respeta su ajuste de Smart Insights.
- **Lo que queda por día**: `BudgetRemainingLogic.perDay` con los días de `BudgetPeriodInterval` (hoy cuenta), la misma
  cuenta que la fila de Planificación.
- **Ritmo de los gastos hormiga**: «Este mes» en curso, desde el día 3 y antes del último → «A este ritmo cierras el mes
  en X»; períodos de menos de 28 días o de más de 31 → «A este ritmo, unos X al mes». Sin «≈»: en Yala esa marca solo
  dice «convertido con una tasa aproximada» (decisión 31 de 2.3).
- **Registros por comercio**: la misma clave que agrupa los gastos hormiga (`AntExpensesCalculator.groupKey`). Una
  unión de Yala IA filtra por todas sus grafías. Es efímero, como el modo duplicados: cápsula «Solo X ✕» y se quita al
  salir del chip Registros.
- **«Ponerle un tope»** abre el asistente de «Nuevo presupuesto» de Planificación (o el paywall del límite, como allí).
- **Se quedan como estaban**: el resumen con IA / la invitación a Pro, el selector Detalle | Observaciones y
  Observaciones. «Lo que te falta pagar», «Tus presupuestos» y «Distribución del gasto por necesidad» salen del Resumen:
  los dos primeros vuelven como acción; la necesidad queda en «Lo que más pesa», con su barra.

Textos nuevos en su tabla (`InsightsResumenOpcionB.strings`, 16 idiomas); `es-419` en español neutro.

Pruebas: `YalaTests/EstadisticasResumenOpcionB/` (ritmo, por día, orden y silencio, la parte que más baja la nota,
filtro por comercio y claves de una unión de IA) y los XCUITest del lote 11 reescritos
(`UXAudit22Lote11DecididasUITests`: la acción de lo que falta pagar y «Lo que más pesa»).

## QA en iPhone (opcional, no bloquea)

1. Abre Estadísticas › Resumen con «Este mes».
2. Mira que la franja de salud diga qué parte baja la nota (o «Buena nota…» si todas van bien).
3. Si sale «Para decidir hoy», toca cada acción: Presupuestos, Pagos planificados o Tendencias.
4. Toca un comercio de «Gastos hormiga»: se abre Registros con «Solo <comercio>»; la ✕ devuelve la lista entera.
5. Toca «Ponerle un tope»: se abre «Nuevo presupuesto».
