# El PR #369 no mergea: el job `tests` del CI se corta por tiempo en el paso pure-logic. Encontrar el cuelgue, arreglarlo y dejar #369 mergeado en 2.1.

## Contexto
- PR #369 (https://github.com/jur211296/Yala/pull/369), rama `encargo/2026-10-05-fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason`: «Empezar de cero» separa la cifra entre cambios tuyos y de otra cuenta (decisión A de Jürgen, tarjeta n3k4). Auto-merge activo, mergeable pero BLOCKED.
- El job `tests` se canceló por tope de tiempo (~46 min) durante el paso pure-logic (advisory, continue-on-error) tres veces: run 37417460535 intentos 1 y 2 (head ba88e33) y run 37436494168 (head 7c657e9, ya con 2.1 mergeada dentro, tras #370). Los pasos context y UI no llegaron a correr. Los otros jobs (coverage-index, changes, mcp, vigía de rojos advisory) en verde.
- #367, #368 y #370 mergearon bien en el mismo período, así que la sospecha es que algo nuevo de #369 (p. ej. `FreshStartSplitCopyTests` u otro test añadido) se cuelga o espera indefinidamente en CI. No está confirmado: también hay precedentes de pure-logic cancelado por tiempo en 2.1 (10-01, 10-02, 10-05) y el PR #336 tocó ese paso. Hay un rojo conocido `SpikeR3ContainerReleaseTests` eje 4a/4b (ticket spike-r3-eje-4b-flaky-en-suite-completa).
- En local el gate de #369 pasó (unitaria 9060 casos), así que mira lo que difiere en CI (paralelismo, simulador, timeouts, orden de tests, test que espera red/Keychain/iCloud).

## Qué se pide
1. Leer los logs de los runs citados (gh run view --log / job logs) y localizar en qué test o fase se queda el paso pure-logic. Comparar con un run sano reciente de 2.1 o de #370 (duración por fase).
2. Arreglar la causa raíz en la rama del PR #369 (push a esa misma rama, para que el auto-merge existente entre). Lo más robusto y mejor práctica; nada de subir el timeout o saltar tests como parche, salvo que la causa sea de verdad de infraestructura y lo dejes justificado. Si la causa resulta ser general del CI y no de #369, arreglarla donde corresponda y dejarlo explicado.
3. Esperar el CI del PR y confirmar que #369 mergea en 2.1.
4. Si aparece algo fuera de alcance, ticket nuevo en tickets/ y tarjeta en el tablero.

## Qué NO hay que tocar
- El comportamiento y los textos de #369 ya revisados (decisión A), salvo que el cuelgue venga de ahí y haya que corregirlo.
- El formulario del PR #341.
- No desactivar ni marcar como skip tests para que pase.

## Cómo se sabe que está bien
- Causa del corte identificada y explicada en el PR (qué test/fase y por qué solo en CI).
- CI de #369 con `tests` completo (sin cancelación) y PR mergeado en 2.1.
- Tarjeta `tablero-ci-el-job-tests-del-pr-369-se-corta-por-t5ts` en done.
- Mini limpia al cerrar (simulador apagado y vaciado, DerivedData y cachés de la sesión fuera, worktree retirado).

Al terminar: /cerrar-total.

## Paso 0

*Resuelto por Frank al arrancar (sesión autónoma, sin nadie delante). Medido, no supuesto.*

**Qué pasa de verdad (medido en los logs de los tres jobs cortados y de 8 sanos).** No hay cuelgue. Un test nuevo
de #369, `FreshStartSplitCopyTests.onlyAnotherAccount_doesNotSayYours`, falla en CI en la línea 208 de forma
determinista; `-retry-tests-on-failure` con Swift Testing repite la **suite entera** hasta 3 veces (26 889 tests ≈
3 × 8 963), el paso pasa de ~13 min a 26-29 min y, con el build de ~14 min, el tope de 45 min del job lo cancela.

**Por qué solo en CI.** El simulador del runner arranca en inglés y la Mac de Jürgen en español. La línea 208 afirma
`confirmación neutra != confirmación «tuya»`, y en inglés las dos frases son idénticas («Group changes that will be
lost: 2…»): la traducción inglesa nunca dijo «your». Medido en los 16 idiomas: la 208 falla en 9 (de, en, en-GB, fr,
it, ja, nl, pl, zh-Hans) y la 207 (`!contains(lead(2))`) en japonés. Las demás aserciones negativas del fichero
aguantan en los 16.

**Decisiones.**
1. *Dónde se arregla:* en el test de #369, no en el CI. Es la causa; el reintento ×3 es el amplificador.
2. *Cómo:* sin fijar el idioma (lección del 2026-09-02 en `docs/aprendizajes-tecnicos.md`: fijarlo pinnea una
   traducción). Las dos líneas rojas comparan dos traducciones entre sí, así que se mueven a donde se miden las
   traducciones: el test que lee los `.strings` de los cuatro españoles comprueba que ahí lo neutro y lo «tuyo» SÍ
   difieren. La elección de la variante la siguen probando los `==` exactos, que valen en cualquier idioma.
3. *Ni timeout más alto ni skip:* la causa no es de infraestructura.
4. *El amplificador (un rojo, advisory o flaky, se vuelve una cancelación opaca del job):* fuera de alcance — cambia
   cómo reintenta todo el CI. Ticket nuevo con la medición y tarjeta en el tablero. Precedente medido: run
   37325431444 (2.1, 2026-10-05), un rojo flaky de `SpikeR3ContainerReleaseTests` → 26 511 tests, job cancelado.
5. *Entrega:* commit en la rama de #369 y push; el auto-merge que ya tiene lo mete al pasar `tests`.

**Ficheros:** `YalaTests/CloudSync/FreshStartSplitCopyTests.swift`, `qa/coverage-index.json` si el área lo pide, el
ticket nuevo en `tickets/backlog/` y su línea en `docs/TICKETS.md`, y este encargo.
