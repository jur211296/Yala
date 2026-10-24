---
id: ci-tests-job-ceiling-cancels-green-runs
status: done
priority: low
area: ci
created: 2026-10-10
updated: 2026-10-24
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

- [x] Medida de nuevo la frecuencia de cancelaciones por tope desde el 7-oct (antes de decidir).
- [x] Decidido y escrito en el comentario de topes de `qa.yml`.

## Resuelto (2026-10-24)

Llegó como «los unit context-based se cuelgan en el CI de 2.2» (card `m0tx`). No se colgaban. Medido
sobre los 88 jobs `tests` de 2.2 del 18 al 24-oct:

- **Cinco cancelaciones por tope en seis días**, todas con sus pasos en verde: 39527716872,
  39678903605, 39783441806, 39832740877 y 39982719207 (45,0-48,6 min). En la última, context-based
  murió a los 1,2 min de empezar; build (21,7) y pure-logic (22,7) se habían comido el tope.
- **Context-based nunca pasó de 5,6 min** (mediana 2,9). El paso estaba sano.
- **El job verde va de 23,7 a 44,2 min** (mediana 36, p90 41,7): el máximo verde quedaba a 0,8 min
  del tope. Pure-logic corre 11 243 casos (8 963 el 6-oct) y el mismo build tarda de 10 a 22 min
  según el runner.

**Decisión:** el tope del job sube de 45 a 60 para PR (el mismo de la nocturna, que ya no tarda más
que un PR), y con él los topes de paso con el mismo margen: build 25→30 y pure-logic 30→35.
Relanzar a mano quedó descartado: la cola de auto-merge no espera a nadie. La tabla re-medida vive
en el comentario «TOPES DE TIEMPO» de `qa.yml`, y la regla en `.claude/rules/ci-qa.md`.

**Fuera, sin ticket todavía:** acelerar la suite. Cada caso cuesta ~0,12 s de runner aunque su
cuerpo tarde 0,001 s, y cada paso de test gasta ~4 min en arrancar la app anfitriona.
