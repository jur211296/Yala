---
id: daily-allowance-how-much-can-i-spend-today
status: qa
priority: high
area: "presupuestos, panel"
created: 2026-11-04
updated: 2026-11-04
source: "tablero «Cuánto puedo gastar hoy»: cupo diario vivo desde el presupuesto restante (competencia Mi Hormiga, Lola→Frank 2026-10-26)"
---

# «Cuánto puedo gastar hoy»: el cupo del día de cada presupuesto (2.3)

## En lenguaje de usuario

Cada presupuesto en curso dice cuánto puedes gastar hoy para no pasarte: «Hoy puedes gastar S/ 15.48». Cada gasto de
hoy lo baja en lo que cuesta; si te pasas, dice «Hoy te pasaste por S/ 25.33» en rosa. Mañana se recalcula con lo que
de verdad quedó. Sale en la tarjeta de Presupuestos del Panel (tamaños mediano y grande) y en el detalle de cada
presupuesto, donde sustituye al «Puedes gastar S/ X al día» fijo.

> **Cambia el tono, 2026-11-11 (decisión 23 de la revisión 2.3).** La línea ya no dice «Hoy puedes gastar» ni «Hoy te
> pasaste por» en rosa: es una guía neutra en gris, «Quedan 5 días y S/ 400.00: unos S/ 80.00 al día», y con gasto hoy
> «Empezaste el día con S/ 400.00 para 5 días: unos S/ 80.00 al día. Hoy llevas S/ 120.00, S/ 40.00 más que eso». La
> cuenta no cambia. Lo de abajo sobre el texto y el rosa describe la versión anterior.

## La cuenta

Cupo de hoy = (límite − lo gastado en el período fuera de hoy) ÷ días que faltan con hoy − lo gastado hoy. «Fuera de
hoy» incluye lo ya apuntado para días posteriores del período. No sale con el período cerrado o sin empezar, con límite 0
o con el presupuesto ya agotado antes de hoy (la fila ya dice «Te pasaste por»). Sin día de cobro: el mes es el de
calendario. Gratis.

## Diseño

Variante A implementada (detrás de una sola vista, `DailyAllowanceLine`). B (tarjeta propia en el Panel) y C (solo en la
lista de Presupuestos), en maqueta: `qa/evidencia-cupo-diario-20261104/propuesta-B.png` y `propuesta-C.png`. Jürgen
elige; si gana B o C, es otro encargo.

## Fuera

- La tarjeta pequeña de Presupuestos del Panel (la del diseño por defecto) no lleva el cupo: dos líneas por presupuesto
  y no cabe. Si quieres verlo en el Panel por defecto, eso es la variante B.
- El widget de inicio de iOS.

## QA (simulador, sin iPhone)

Cubierto por `YalaTests/DailyAllowanceLogicTests` y `YalaUITests/DailyAllowanceUITests`. Visto bueno de diseño de Jürgen
sobre las capturas del PR.
