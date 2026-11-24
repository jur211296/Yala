---
id: 2026-11-24-propuesta-bandeja-sin-duplicados
status: done
area: "bandeja, apple pay, correo del banco, aviso del banco, conector de IA, pagos planificados"
created: 2026-11-24
updated: 2026-11-24
source: "Jürgen, 24-nov (08:10 Lima): ¿cómo evitamos duplicados en la Bandeja entre Apple Pay, correo, aviso, el conector de IA y los pagos planificados?"
---

# Propuesta: la Bandeja sin duplicados entre fuentes

## Qué se pidió
Con Apple Pay, el correo del banco y el aviso del banco conectados, que el mismo consumo no salga tres veces en la
Bandeja; que la IA no apunte encima de lo que ya está; que lo que ya es un pago planificado no suba como pendiente
nuevo y que el planificado de monto estimado tome el monto real del correo.

## Qué se entregó
Propuesta, sin cambios en la app: `docs/propuestas/bandeja-sin-duplicados/README.md` (mapa de fuentes, escenarios
medidos, tres opciones, plan en lotes y decisiones) y el artifact visual enlazado en el PR.

- Hoy ninguna fuente se cruza con otra al llegar: el mismo café por Apple Pay, correo y aviso deja tres pendientes.
  La única red es la de aprobar (mismo día, importe y cuenta), que falla con el cruce de medianoche y con la moneda
  extranjera, y que deja sin guardar la segunda compra real igual del mismo día.
- La IA no puede ver la Bandeja (solo movimientos aprobados) y su herramienta de escritura no es idempotente.
- Los pagos planificados no se cruzan con nada externo; `isVariableAmount` no se usa al llegar un correo.
- Recomendación: opción B, «un pendiente por consumo» (emparejador uno a uno entre fuentes distintas, unir solo en
  coincidencia fuerte con «Separar», preguntar en la dudosa, planificados que toman el monto real, y conector que
  consulta y usa llave de idempotencia).

## Qué sigue
Cuando Jürgen elija (decisiones al final del README y del artifact), se encolan los lotes 0 a 5 del plan. Cada lote
lleva su propio ticket.
