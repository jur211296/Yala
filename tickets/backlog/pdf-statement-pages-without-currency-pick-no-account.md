---
id: pdf-statement-pages-without-currency-pick-no-account
status: backlog
priority: low
area: image, ai
created: 2026-10-08
updated: 2026-10-08
source: banco multipágina del ticket pdf-statement-reads-only-the-first-page (2026-10-08)
---

# Las páginas de un extracto que no escriben la divisa salen sin cuenta

## Qué le pasa al usuario

Lee un estado de cuenta en PDF de varias páginas. Muchos bancos escriben «$» o «S/» solo en el resumen de la primera
página; en las de detalle, la columna de importes va sin símbolo. Desde el 2026-10-08 cada página se lee sola, así que
los movimientos de esas páginas llegan **sin divisa** y su borrador no casa con ninguna cuenta: la persona tiene que
elegir la cuenta en cada fila.

## Lo medido (2026-10-08)

- Banco `gateway/bench/results/2026-10-08-multipagina/`, extracto `stmt-us`: las páginas de detalle vuelven con
  `currency: null`, que es lo que el prompt pide cuando no hay ningún indicador (4 de 4 en la primera corrida).
- En la app, `VisionDraftFactory` → `DraftBuilder.findAccount(byCurrency:)` no encuentra cuenta sin divisa.

## Qué se podría hacer

Si otra página del MISMO PDF trajo divisa (una sola), heredarla en las que volvieron con `null`, antes de crear los
borradores. Medirlo con `stmt-us` y comprobar que no pisa una divisa que la página sí escribió.
