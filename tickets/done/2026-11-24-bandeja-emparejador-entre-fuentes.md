---
id: 2026-11-24-bandeja-emparejador-entre-fuentes
status: done
area: "bandeja, apple pay, correo del banco, aviso del banco, conector de IA"
created: 2026-11-24
updated: 2026-11-24
source: "Jürgen, 24-nov (14:30 y 14:32 Lima): «vamos con todo lo recomendado» de docs/propuestas/bandeja-sin-duplicados/README.md (opción B). Lote 1 del plan, en 2.3"
---

# Bandeja: emparejador entre fuentes (lote 1, lógica pura)

## Qué se pidió
La regla que decide cuándo dos pendientes de fuentes distintas (Apple Pay, aviso del banco, correo del banco, tu IA,
Yala web) son el mismo consumo, y qué fuente manda en cada campo al unirlos. Sin interfaz: lógica pura y pruebas de
todos los escenarios del informe.

## Qué se entregó
`Yala/App/Logic/InboxMatchLogic.swift` y sus pruebas en `YalaTests/InboxMatchLogic/`. Todavía no cambia nada en la
app: el lote 2 la cablea al llegar cada borrador.

- **Dos de la misma fuente nunca se unen.** Dos cafés iguales por Apple Pay son dos cafés. Un consumo absorbe como
  mucho uno de cada otra fuente (uno a uno).
- **Fuerte (se une solo)**: mismo signo; misma cuenta, o una sin cuenta con los mismos últimos 4; misma moneda ±0,01;
  ≤ 6 h con hora en los dos, o el día de la compra o el siguiente si una fuente solo trae el día; comercio parecido.
- **Dudosa (se pregunta «¿Es el mismo gasto?»)**: una sin cuenta y nada en contra; ±3 % en la misma moneda u otra
  moneda convertida ±4 %; hasta 72 h; comercio distinto.
- **Lo ya guardado pregunta siempre** («Ya registrado»), nunca se une solo.
- **Qué manda**: importe y moneda del banco (correo, luego aviso; lo de Apple Pay queda como evidencia si difiere),
  comercio de Apple Pay, hora de Apple Pay o del aviso, cuenta de quien trae los últimos 4.
- Fuera, a propósito: grupos (decisión 7), planificados y suscripciones (lote 4), Siri, voz y fotos.

Decisiones técnicas del Paso 0, en el encargo y en el PR.

## Pruebas
`InboxMatchScenarioTests` (E1 a E10 del informe y los casos difíciles: dos compras reales iguales, reversas, cuotas,
cargo parcial, cargo partido, aviso tras un registro a mano) y `InboxMatchRuleTests` (cada campo en sus bordes, la
fuente que manda, qué borradores entran).

## Lo que queda
Lote 2 (unir al llegar, campo sincronizado y «Separar»), lote 3 (fila de la Bandeja), lote 4 (planificados).
