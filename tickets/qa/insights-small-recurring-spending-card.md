---
id: insights-small-recurring-spending-card
status: qa
priority: medium
area: "statistics, insights"
created: 2026-11-06
updated: 2026-11-06
card: tablero-detectar-gastos-hormiga-y-decir-cuanto-s-ea78
source: "encargo lote de productividad 2.3 (hormiga, logos, sugerencias)"
---

# Gastos hormiga: cuánto suman las compras pequeñas que se repiten

## Qué cambia para la persona

En Estadísticas › Resumen › Detalle, debajo de «Suscripciones», sale la tarjeta **Gastos hormiga**: cuánto suman las
compras pequeñas que repites, en cuántas compras, las tres que más pesan («Bus · 406 veces · S/ 6,956») y, si el
período es más largo que un mes, cuánto es al mes. Al pie dice la regla con su cifra: «Compras de hasta S/ 57 que
repites 3 veces o más en el período».

## La regla (sin IA, gratis)

- Entra un gasto real del período: no ingresos, devoluciones, transferencias, ajustes de saldo, pagos planificados ni
  las partes de Grupos que la pantalla no cuenta.
- «Pequeño» = hasta la mediana de tus gastos del período (un umbral fijo no sirve en 54 divisas).
- Se agrupa por descripción (sin mayúsculas ni signos) o, sin descripción, por subcategoría; cuenta si se repite 3 veces o más.
- Con menos de 6 gastos en el período, o sin nada repetido, no hay tarjeta.

Código: `AntExpensesCalculator`; tests `AntExpensesCalculatorTests` y `ProductividadLote23UITests`.

## Guion de QA para Jürgen (iPhone de pruebas, Yala Dev)

1. Abre **Estadísticas**. Deja el período en **Este mes**.
2. En **Resumen**, toca **Detalle** y baja hasta **Suscripciones**.
3. Debajo está **Gastos hormiga**. Mira las tres filas: ¿son de verdad tus gastos pequeños y repetidos (café, pasajes, delivery)?
4. Cambia el período a **Todo el tiempo**: la tarjeta añade «≈ S/ … al mes».
5. Responde: **¿las tres compras que nombra tienen sentido? (sí / no)** y si el tope del pie (la «compra pequeña») te parece razonable.
