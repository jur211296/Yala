# Lote CI 2.2 · Los 4 XCUITest en rojo de la nocturna y la novena tanda de UI
toca: `.github/workflows/`, `scripts/ci/`, `YalaUITests/` (solo los 4 tests rojos de chat, exportar, inbox y atajos de Siri)

Rama base: 2.2. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial, sim-lock).
Lote CI (backlog de Frank en el tablero, versión 2.2).

Cards:
1. CI: 4 XCUITest en rojo en la nocturna del 4-nov (chat, exportar, inbox, atajos de Siri). Fechar cada rojo contra la nocturna y separar regresiones de intermitentes; arreglar las regresiones y estabilizar los intermitentes.
2. CI: las tandas de UI 3 y 5 pasan de 80 min; toca una novena tanda. Volver a simular el reparto (9 o 10 tandas) y dejar todas por debajo del tope.

Hecha cuando: la nocturna sale en verde con los 4 tests y ninguna tanda pasa del tope; las dos cards cerradas en el tablero.
Si el arreglo también hace falta en 2.3, pregunta con `preguntar-bot` antes de decidir.

PREGUNTAR, NO SALTAR. `tablero` + cierre con la sección «Saltado o asumido sin preguntar». Termina con /cerrar-total.

## Paso 0 — decisiones

> D1 y D2 las contestó Jürgen vía el bot dueño (2026-11-05). El resto, resueltas en autónomo con la recomendación de Frank; se discuten en el PR.

**Hechos medidos.** Los 4 rojos salen del dispatch 41931406144 (4-nov 23:09 UTC). Fechados contra las nocturnas del 27-oct al 4-nov:
Exportar cae 3/3 desde la nocturna del 2-nov (verde 31-oct y 1-nov) → regresión. Inbox (fecha) y Chat (contador) solo caen en tandas que corrieron entre 00:00 y 05:00 UTC → el test corre en Lima (`TEST_RUNNER_TZ`) y la app en UTC. Siri cae al primer intento y pasa al reintento (4-nov ×2) → intermitente.
Tandas del dispatch: 3 = 91,7 min, 5 = 85,3; el paso suma ~6,5 min sobre los tiempos de test.

**D1 · ¿9 o 10 tandas, y cómo se reparte?** → 9 tandas repartidas por minutos medidos (tabla por suite; suite nueva a 46 s/caso), 3 oleadas.
Por qué: por casos, 9 deja la más larga en ~77 min de paso y 10 en ~80 (la tanda 3 se lleva suites lentas); por minutos, 9 da ~68. Descartada: 10 por minutos (~62) porque abre una cuarta oleada (+~1 h de nocturna).

**D2 · ¿Dónde se arregla la zona horaria?** → En el lanzador común (`launchForUITest`): `TZ` de la app = la del test.
Por qué: arregla la clase entera; en local no cambia nada. Descartada: tocar solo los 2 tests (deja el resto expuesto).

**D3 · Exportar: ¿test o app?** → El test. La app dice bien «Saldrá 1 registro»: el seed `minimal` cubre 7 días y «Ahorros USD» solo se mueve los días 10 y 25; el test esperaba el plural. Se espera «Saldrá».

**D4 · Siri: ¿cómo se estabiliza?** → Espera de 60 s (no 15) a la página de Yala en Atajos y cierre de Atajos en el teardown. Por qué: en el reintento el MISMO proceso de Atajos ya mostraba la página al segundo; faltaba tiempo, no la página. En un simulador recién creado de la Mac pasa a la primera (38 s).

**D5 · ¿Va también a 2.3?** → Solo 2.2, un solo PR; 2.3 recibe los arreglos cuando se integre 2.2 (contestado por el bot dueño, 2026-11-05). Sin PR aparte a 2.3.
Por qué: los 4 tests son iguales en 2.3, pero la nocturna solo corre sobre 2.2 y el `qa.yml` de 2.3 no tiene el build compartido.

**D6 · La tabla de tiempos, ¿cómo no envejece?** → `qa/ci-ui-tiempos.json` + un script que la regenera desde una nocturna (`gh run view --log`); la regla va a `.claude/rules/ci-qa.md`. Si envejece, la tanda se descompensa pero ninguna suite se queda sin correr (la última sigue siendo el complemento).
