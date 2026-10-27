# QA 2.2 se cancela: tests unitarios context-based se cuelgan (~65 min)

## Contexto
El run de QA del push a la punta de 2.2 (HEAD `85c5a77`) se canceló tras ~65 min:
https://github.com/jur211296/Yala/actions/runs/40422732167

Se trabó en el paso de tests unitarios context-based. Los de lógica pura pasaron; los de UI no llegaron a correr. No hubo otro QA sobre ese HEAD, así que la punta de 2.2 quedó sin probar. No es un rojo de un test puntual: parece un cuelgue / tope de tiempo.

Ya hubo un arreglo reciente del mismo síntoma (sesión de tests/gate). El cuelgue volvió: hay que investigar si el arreglo no cubrió todos los casos, se revirtió en la cola de merge, o hay otro test context-based que se cuelga.

Card: `tablero-qa-2-2-se-cancela-tests-unitarios-contex-9y84`
Cierre: cierra-sola · esfuerzo high

## Qué se pide
1. Reproducir / leer el log del run cancelado y localizar qué test o suite context-based se queda colgada.
2. Arreglar la causa (timeout, deadlock, espera infinita, dependencia de main actor, etc.) o acotar con skip/timeout justificado si el test es flaky de infra.
3. Empujar el fix a 2.2 (PR) y re-correr QA hasta que el paso context-based no se cancele por tiempo; idealmente QA verde en la punta.
4. Si el fix es solo en CI config (timeout del job), documentarlo en el PR y asegurar que no enmascara un hang real.

## Qué NO hay que tocar
- No relanzar en paralelo otra sesión Yala.
- No tocar marketing/.
- No ampliar a un rewrite de todos los tests.

## Cómo se sabe que está bien
- PR con el arreglo.
- Un run de QA en la punta de 2.2 pasa el paso context-based (sin cancelarse ~65 min) y, si es razonable, llega a verde.
- Card a in qa o done según toque; termina con `/cerrar-total`.

## Paso 0

*Auto-contestado al arrancar (sesión lanzada, sin nadie delante).*

- **¿Hay cuelgue en context-based?** No. Medido en la API de Actions: el paso llevaba 1,8 min cuando
  el tope de 60 del job lo canceló; build (28,6) y pure-logic (30,9, todo verde) se comieron el tope.
- **¿Se revirtió el arreglo del 24-oct?** No: el tope sigue en 60. El trabajo lo volvió a alcanzar
  (nocturna 40094866869 verde a 53,5).
- **¿Arreglo en código o en CI?** Los dos. En código, el único unit que esperaba a un servicio del
  sistema (`_testReset` del testigo del Apple ID salía a CloudKit: 47 s a 6,5 min). En CI, los topes
  re-medidos (job 80, build 40, pure-logic 45) según la regla de `ci-qa.md` «el tope sigue al
  trabajo». Context-based se queda en 10: un cuelgue real sigue cortando ahí.
- **Asumido:** el ticket queda en `qa` hasta ver el job `tests` del push a 2.2 tras el merge en
  verde; la card, a «in qa».
