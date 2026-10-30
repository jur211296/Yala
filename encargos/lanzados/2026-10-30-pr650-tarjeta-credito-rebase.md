---
esfuerzo: high
release: no
---
# Rebasar el PR #650 de la tarjeta de crédito sobre 2.2, resolver el conflicto y poner coverage-index en verde

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Slug: `pr650-tarjeta-credito-rebase` · al cerrar → **S28tf** (`subida-testflight-2-2-5`).

## Contexto
El [PR #650](https://github.com/jur211296/Yala/pull/650) (rama `encargo/2026-10-27-tarjeta-credito-implementar`) trae la tarjeta de crédito con día de corte, facturado / por facturar y aviso antes de pagar. Tiene auto-merge desde el 27-oct, pero nunca entró: choca con origin/2.2 y el check `coverage-index` está en rojo. Lo encontró el barrido de QA 2.2 (PR #699). Si no entra, el TestFlight 2.2 (5) sale sin esa función, que está planificada para 2.2.
Card: `tablero ver tablero-la-tarjeta-con-fecha-de-corte-pr-650-lle-uvwn`. La card de la función está en «in qa» de Jürgen: `tablero ver tablero-tarjeta-de-credito-fecha-de-corte-fecha-nmtk`.

## Qué se pide
1. Tomar la rama del PR #650. Un solo fetch y rebase (o merge) sobre origin/2.2.
2. Resolver los conflictos conservando lo de la tarjeta y todo lo que entró a 2.2 desde el 27-oct. En `docs/TICKETS.md` y `qa/coverage-index.json`, conservar las entradas de ambos lados, sin duplicados.
3. Poner `coverage-index` en verde (`bash qa/validate-coverage.sh`).
4. Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests unitarios de la tarjeta y de lo que tocó el conflicto, apagar y borrar el sim. Compilar Yala y Yala Dev.
5. Empujar con `git push --force-with-lease` solo a la rama del PR. No abrir PR nuevo. Dejar el auto-merge puesto.
6. Mover la card del PR a done cuando mergee, o decir en el cierre que queda en cola.

Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Ninguna otra rama ni PR. Nada de funcionalidad nueva.
- Si el conflicto exige una decisión de diseño real, toma la opción más conservadora, documéntala en el PR y en la card, y sigue.

## Cómo se sabe que está bien
PR #650 sin conflicto, CI en verde (o en cola de merge con su CI corriendo) y la card al día.

Termina con /cerrar-total.
