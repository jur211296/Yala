---
id: group-split-lines-recipe-lost-on-payer-or-currency-change
status: backlog
priority: low
area: "grupos, puente"
created: 2026-11-01
updated: 2026-11-01
source: "review del encargo 2026-11-01-grupos-b-puente-y-estadisticas (Grupos B · card 2)"
---

# Las líneas de tu parte se pierden si el gasto cambia de pagador o de divisa

La receta de líneas (`TransactionItem.splitLinesRaw`) vive en la pata que el puente conserva: la real si pagaste tú
(Caso A), la virtual de «Grupos» si pagó otro (Caso B). Cuando el gasto cambia de pagador, el puente borra esa pata y crea
la del otro caso, y la receta se va con ella. Con un cambio de divisa del gasto, el Caso A también borra la pata real
(borrador «la moneda cambió»); el Caso B la conserva y la receta deja de cuadrar, con su aviso en la Bandeja.

Hoy no muerde: ninguna pantalla escribe la receta hasta las cards 4-6. Cuando las haya, la persona tendría que volver a
partir su parte tras un cambio de pagador. Opciones: trasplantar la receta a la pata nueva en la misma pasada, o avisar en
la Bandeja como con el cambio de importe (D6 del ticket `grupos-tu-parte-en-lineas`).
