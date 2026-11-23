---
id: insights-ant-expenses-ai-version-for-pro
status: qa
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

## Decidido (Jürgen, 2026-11-06)

- **Dónde:** dentro de la misma tarjeta, debajo de la regla. Free no ve invitación ni nada nuevo.
- **Qué:** juntar grafías del mismo comercio + un consejo corto. Sin ahorro mensual ni hormigas sobre la mediana.
- **Datos (1A):** en privado, solo nombre + veces + total de las compras pequeñas; el permiso de Estadísticas lo dice.
- **Nube:** la IA lee todo lo que haga falta (regla para TODA la IA en la nube; `.claude/rules/ai-gateway.md`).
- **Gateway (2A):** tarea `insights.ants`, en staging; producción antes de publicar 2.3.
- **Permiso (A):** con versión; quien aceptó el texto anterior ve un botón en vez de que salga solo.

## Lo que se planteó (spec)

- Qué añade la IA: agrupar compras que la regla no junta (grafías distintas del mismo comercio), explicar el patrón,
  proponer cuánto ahorrar al mes, o detectar hormigas que superan la mediana.
- Dónde se ve: dentro de la misma tarjeta (bloque Pro) o como un insight aparte.
- Qué ve Free: nada nuevo, o una invitación a Pro en la tarjeta.

## Punto de partida

`AntExpensesCalculator` ya devuelve grupos, total, umbral y estimación mensual: es la entrada natural para la IA.

## Hecho cuando

Un usuario Pro ve la versión con IA de los gastos hormiga, un usuario Free sigue viendo la tarjeta gratis igual que
hoy, y la versión con IA tiene su guion de QA.

## Qué cambió (2026-11-06)

Pro ve, debajo de la tarjeta gratis, un bloque «Con Yala IA»: las compras que la IA juntó (la misma tienda escrita de
otra forma, con «También escrito como…»), el total de gastos hormiga con ellas juntas y un consejo de una frase. Sale
solo con el permiso aceptado (mismo techo diario que los demás textos de IA de Estadísticas). Free ve la tarjeta igual
que antes. Los permisos de IA dicen, en los 16 idiomas, que con la cuenta en la nube la IA lee todo lo que haga falta.

## Guion de QA (iPhone, Yala Dev contra staging; Pro)

1. En Yala Dev, con Pro (toggle de Ajustes de desarrollador), apunta este mes dos gastos de S/ 9 con la descripción
   «Starbucks» y dos de S/ 11 con «STARBUCKS COFFEE» (o usa dos grafías de un sitio real tuyo).
2. Abre Estadísticas › Resumen › Detalle y baja hasta «Gastos hormiga».
3. Si nunca aceptaste el permiso de IA de Estadísticas, o lo aceptaste antes de hoy: debajo de la regla sale «Junta los
   nombres parecidos con Yala IA». Tócalo, lee el permiso (debe nombrar las compras pequeñas y la nube) y acepta.
4. Debe salir «Con Yala IA» con Starbucks juntado («También escrito como «Starbucks»»), «Juntando los nombres
   parecidos: …» y un consejo de una frase. Las cifras del bloque deben cuadrar con la suma de las grafías.
5. Sal y vuelve a Estadísticas: el bloque sale sin esperar (guardado), sin «Analizando…».
6. Con un usuario Free (quita el toggle Pro): la tarjeta es la de siempre, sin bloque ni botón.
