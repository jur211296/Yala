---
id: gate-doc-says-swift-testing-only
status: backlog
priority: low
area: qa, docs
created: 2026-09-03
updated: 2026-09-03
source: falsa alarma al leer un gate (2026-09-03)
---

# El `/gate` dice que el repo es «Swift Testing entero» y YalaUITests es XCTest

## Qué pasa

`.claude/commands/gate.md`, en su paso 2, afirma: «los marcadores `Test Suite`/`Test Case` del grep
son de XCTest y **este repo es Swift Testing entero**». Es cierto para `YalaTests`; **falso para
`YalaUITests`**, que sigue siendo XCTest.

## Lo que cuesta

Una falsa alarma, medida el 2026-09-03: al verificar el gate de un cambio, filtrar los XCUITest por
la marca de Swift Testing (`◇ Suite`) dio **0 suites arrancadas** con `TEST SUCCEEDED`, que es
exactamente la firma del modo de fallo «el filtro no casó y no se ejecutó nada». Costó una
investigación entera descubrir que las suites **sí** habían corrido: `Executed 12 tests, with 0
failures`, con la marca de XCTest.

El paso 3 del propio gate ya usa el grep correcto (incluye `Executed`), así que el comando funciona;
lo que engaña es la frase del paso 2 leída como si valiera para todo el repo.

## El arreglo

Un matiz de una línea: la afirmación vale para `YalaTests`; `YalaUITests` es XCTest y se cuenta con
`Executed N tests`.

## Por qué no se hizo en el momento

`.claude/` es lo único que el `CLAUDE.md` manda por PR aunque sea documentación, y desde el árbol
principal no hay PR. Queda para quien pueda abrirlo.
