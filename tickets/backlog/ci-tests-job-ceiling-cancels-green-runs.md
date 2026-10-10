---
id: ci-tests-job-ceiling-cancels-green-runs
status: backlog
priority: low
area: ci
created: 2026-10-10
updated: 2026-10-10
source: medido de camino en ci-warns-but-does-not-block (2026-10-10)
---

# Un runner lento agota el tope de 45 min del job `tests` y frena un PR que iba en verde

## Qué se midió (2026-10-10)

Sobre los 300 últimos runs de `qa.yml` (30-sep → 10-oct; 280 de PR y push), el job `tests` acabó
**cancelado por su tope de 45 min** 7 veces. Un check requerido cancelado bloquea el auto-merge igual
que uno en rojo.

- **Seis**, del 2 al 6-oct, eran el reintento viejo de pure-logic (`-retry-tests-on-failure`, que
  triplicaba el paso a 27-30 min). Ya está resuelto: desde `239ff023f` (6-oct) repite solo los rojos.
- **Uno**, el 10-oct (run 38036559861, push a `2.1`), fue un runner lento: `Build for testing` tardó
  **23 min** (lo normal son 13-15) y pure-logic 19, en verde. El job murió a los 47 min con
  context-based a medio correr.

De los 229 jobs `tests` verdes medidos: mediana 31 min, p90 36, máximo 43. El margen hasta 45 es de
2 min en el peor caso visto.

## Por qué importa ahora

Desde `ci-warns-but-does-not-block` (10-oct) los unit bloquean, y un flaky rescatado por
`ci-reintentar-rojos.sh` añade sus vueltas (~5 min medidos el 7-oct) a un job que ya roza el tope.
Un runner lento más un flaky rescatado darían una cancelación sobre un PR sano, que hay que
relanzar a mano.

## Qué decidir

Si el tope de PR sube (p. ej. a 55: un tope no alarga los runs verdes, solo deja acabar a los
lentos) o si se prefiere relanzar a mano. El comentario de `qa.yml` dice «El PR se queda en 45 a
propósito (es el gate; no se toca)»: cambiarlo es revisar esa decisión, no un ajuste.

## Acceptance Criteria

- [ ] Medida de nuevo la frecuencia de cancelaciones por tope desde el 7-oct (antes de decidir).
- [ ] Decidido y escrito en el comentario de topes de `qa.yml`.
