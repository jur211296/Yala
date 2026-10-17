# Traer 2.1 a 2.2

Mientras 2.1 siga recibiendo arreglos, **cada cierto tiempo se mergea `origin/2.1` dentro de `2.2`**.
La primera vez fue el 2026-10-17 (card `tablero-traer-2-1-a-2-2-merge-del-16-oct-orcj`). Cuanto más tiempo pase
entre un merge y el siguiente, más conflictos habrá y más difícil será decidir cada uno.

## Cómo

1. `git fetch origin`. Crea una rama desde `origin/2.2` y ejecuta `git merge origin/2.1`. El commit se llama «Merge 2.1 into 2.2».
2. **Nunca rebase ni force-push de `2.2`**: es historia publicada y tiene PRs mergeados encima.
3. Abre el PR contra **`2.2`**, no contra `2.1`. Justo antes de abrirlo, haz otro `git fetch`. Si `origin/2.1` se movió, mergéalo otra vez; nunca hagas rebase.

## Cómo se decide un conflicto

- **En lógica gana 2.1**: bugs, sync, datos del usuario, Novedades y TestFlight.
- **En UI gana 2.2** cuando el rediseño de la Auditoría UX ya estaba decidido.
- Si el conflicto obliga a elegir producto, se queda el comportamiento de 2.1 y la elección se anota en el PR.
- **Los conflictos que más cuestan no salen marcados.** Dos ramas pueden arreglar lo mismo de dos formas en ficheros
  distintos. Antes de compilar, revisa los ficheros que tocaron las dos ramas:
  `comm -12 <(git diff --name-only $(git merge-base origin/2.1 origin/2.2) origin/2.1 | sort) <(git diff --name-only $(git merge-base origin/2.1 origin/2.2) origin/2.2 | sort)`.
  En el primer merge, 2.2 había añadido a «Eliminar cuenta» una alerta que decía que los movimientos «quedan sin cuenta».
  2.1, en cambio, los movía o los borraba. Git fusionó las dos sin marcar conflicto.
- **Las traducciones se resuelven clave por clave.** Un bloque de `.strings` en conflicto mezcla claves que solo cambió
  una de las ramas con claves que cambiaron las dos. Solo las segundas se deciden a mano, y después se corre la suite entera:
  hay tests de 2.2 que fijan la forma de una frase (`ExternalEntriesLote15Tests`).
- `docs/TICKETS.md` se regenera desde `tickets/`. `qa/coverage-index.json` se fusiona área por área y une las notas de
  las dos ramas.

## Verificación

Compila los dos schemes y corre la suite unitaria completa, que incluye los tests de sync. Después corre los XCUITest
de las pantallas que tocaron los conflictos y haz una pasada corta en el simulador por esas mismas pantallas.
