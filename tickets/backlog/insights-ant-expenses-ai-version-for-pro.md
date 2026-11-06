---
id: insights-ant-expenses-ai-version-for-pro
status: backlog
priority: medium
area: "statistics, insights, pro, ai"
created: 2026-11-06
updated: 2026-11-06
card: tablero-gastos-hormiga-version-mejorada-con-ia-p-x1cc
source: "decisión de Jürgen sobre el lote de productividad 2.3 (PR #824)"
---

# Gastos hormiga: versión mejorada con IA para Pro

## Qué se decidió

Jürgen, 2026-11-06: la tarjeta **Gastos hormiga** va gratis para todos tal como salió en el PR #824 (regla fija, sin
IA: compras hasta la mediana del período que se repiten 3 veces o más). **Pro tiene además una versión mejorada con
IA.** La tarjeta gratis no se toca ni se esconde para Pro: la versión con IA se suma encima.

## Qué falta decidir (spec)

- Qué añade la IA: agrupar compras que la regla no junta (grafías distintas del mismo comercio), explicar el patrón,
  proponer cuánto ahorrar al mes, o detectar hormigas que superan la mediana.
- Dónde se ve: dentro de la misma tarjeta (bloque Pro) o como un insight aparte.
- Qué ve Free: nada nuevo, o una invitación a Pro en la tarjeta.

## Punto de partida

`AntExpensesCalculator` ya devuelve grupos, total, umbral y estimación mensual: es la entrada natural para la IA.

## Hecho cuando

Un usuario Pro ve la versión con IA de los gastos hormiga, un usuario Free sigue viendo la tarjeta gratis igual que
hoy, y la versión con IA tiene su guion de QA.
