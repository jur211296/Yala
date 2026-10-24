# Arreglar los unit tests context-based que se cuelgan en el CI de 2.2 y cancelan el job a ~49 min

## Contexto
Card: tablero-los-unit-tests-context-based-se-cuelgan-m0tx (in progress, frank, v2.2, cierra-sola).
El run https://github.com/jur211296/Yala/actions/runs/39982719207 (merge del PR #607, HEAD 0d36003) se canceló en «Unit tests (YalaTests context-based)». Build y pure-logic salieron bien. El run https://github.com/jur211296/Yala/actions/runs/39985363015 (merge del #609) iba igual de lento.
Jürgen 24/10: no parar la cola porque algo espere a él; esta sesión debe cerrar sola con /cerrar-total.
Base: origin/2.2. PR abierto, no mergear a mano salvo auto-merge verde.

## Que se pide
1. Investigar por qué el job «Unit tests (YalaTests context-based)» se cuelga o tarda tanto hasta cancelarse (~49 min).
2. Arreglar la causa (timeout, test colgado, deadlock, wait infinito, etc.).
3. Verificar en local (pipeline serial Yala: limpiar → build -jobs 2 sin sim → boot 1 sim si hace falta → tests → apagar) que el suite context-based termina en tiempo razonable.
4. Abrir PR a 2.2 y dejar auto-merge si CI lo permite.
5. Cerrar con /cerrar-total. No preguntar a Jürgen.

## Que NO hay que tocar
- No tocar marketing/, clinicas, sat-lab, tmux ajenas.
- En ~/Yala del checkout de Jürgen: no tocar ni descartar Yala.xcscheme, encargos/pendientes/, ni CloudKit .ckdb.
- No CloudAgent. No inventar diseño. No secretos en logs.
- No lanzar otra sesión encima. 1 simulador a la vez.
- Al cerrar: apagar sims usados, borrar DerivedData de ESTE worktree y cachés XcodeBuildMCP de worktrees ya no existentes.

## Como se sabe que esta bien
El job de unit tests context-based de 2.2 sale verde dentro del tiempo del CI (no se cancela por timeout ~49 min), con PR a 2.2 y /cerrar-total hecho.

## Paso 0 (auto-contestado, MODO AUTÓNOMO)

- **Premisa medida y falsa: no hay cuelgue.** En los 88 jobs `tests` de 2.2 desde el 18-oct, el paso
  context-based tarda 1,8-5,6 min (mediana 2,9). En el run 39982719207 lo mató el tope de 45 min del
  JOB a los 1,2 min de empezar: build 21,7 + pure-logic 22,7 (11 243 casos, en verde a la primera).
- **Causa:** el tope de 45 se fijó el 9-oct sobre un job de 27-43 min. Hoy la suite tiene 11 243 casos
  (8 963 el 6-oct) y el job verde va de 23,7 a 44,2 min (mediana 36, p90 41,7). Cinco cancelaciones
  por tope en seis días, todas con los pasos en verde.
- **Decisión:** subir el tope de PR de 45 a 60 (el mismo de la nocturna) y los topes de paso que
  repiten el patrón: build 25→30 (máx. 22,8) y pure-logic 30→35 (máx. 24,8 + vueltas de reintento).
  Context-based se queda en 10. El encargo nombra «timeout» como arreglo posible y Jürgen pidió no
  parar la cola: relanzar a mano no es opción. Esto cierra el ticket `ci-tests-job-ceiling-cancels-green-runs`.
- **Fuera:** acelerar la suite (≈0,12 s por caso de overhead del runner, 4 min de arranque de la app
  anfitriona por paso). Es otro trabajo; queda anotado en el PR.
