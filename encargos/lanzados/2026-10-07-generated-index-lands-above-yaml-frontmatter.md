# Que `scripts/indexar_doc.py` deje el frontmatter YAML en la línea 1 y regenerar los ficheros que hoy lo tienen debajo del índice

## Contexto
Ticket `tickets/backlog/generated-index-lands-above-yaml-frontmatter.md` (léelo entero, trae las dos líneas culpables y la tabla de los 7 ficheros medidos el 2026-09-15). Card del tablero «El índice que genera indexar_doc.py cae encima del frontmatter YAML» (generated-index-lands-above-yaml-frontmatter), en «lista para lanzar», asignada a frank.
Es tooling de docs, no producto. Lo encadena Frank tras cerrar la sesión 2 del gateway de IA (PR #389, en cola de auto-merge a 2.1 con tests en curso). Esta sesión NO depende de #389.
La Mini está justa de disco (~20 GB libres) y hay otra sesión iOS viva en otro proyecto: esta sesión NO compila la app, NO arranca simuladores y NO corre XCUITest. Solo Python, docs y tickets.

## Que se pide
1. Medir de nuevo en el árbol de hoy qué ficheros con `<!-- INDICE:inicio` tienen el frontmatter por debajo del índice (la tabla del ticket es del 15-sep y puede haber cambiado).
2. Arreglar `indexar_doc.py` para que, si el fichero abre con `---`, el índice vaya después del frontmatter (y después del `# Título` que venga detrás, si lo hay). Idempotente.
3. Test o comprobación reproducible del script (con frontmatter, sin frontmatter, con título, segunda pasada sin cambios).
4. Regenerar los ficheros afectados para que el frontmatter vuelva a la línea 1, sin cambiar su contenido.
5. Lo que el ticket marca como NO medido (si `.claude/rules/git-hooks.md` recupera la carga por ruta con el frontmatter en la línea 1): compruébalo si se puede de forma barata; si no, déjalo anotado en el ticket como pendiente, sin inventar resultado.
6. Mover el ticket a done (o a qa si queda algo para Jürgen) y abrir PR a 2.1 con auto-merge.

## Que NO hay que tocar
- Nada de código de la app, del gateway ni de `marketing/`.
- No compilar, no simuladores, no XCUITest.
- No cambiar el contenido de los docs regenerados más allá de recolocar índice y frontmatter.

## Gate después del CI del PR anterior
La sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #389 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue.

## Cierre
Al terminar, `/cerrar-total` autónomo: PR en cola de auto-merge, worktree retirado si ya no hace falta, Mini limpia (sin basura de build ni cachés de XcodeBuildMCP de worktrees retirados; no hay sims que apagar), sin preguntar a Jürgen por la limpieza.

## Como se sabe que esta bien
- Ningún `.md` del repo con `<!-- INDICE:inicio` tiene frontmatter YAML por debajo del índice.
- `indexar_doc.py --apply` sobre un fichero con frontmatter lo deja en la línea 1 y una segunda pasada no cambia nada.
- PR a 2.1 en cola de auto-merge, ticket al día.

## Paso 0

Decisiones auto-contestadas (MODO AUTÓNOMO, sin nadie delante):

- **Alcance del arreglo: los dos caminos del script.** El ticket señala el de encabezados, pero el de viñetas
  exige un `# Título` tras el frontmatter: un fichero con frontmatter y sin título también acababa con el
  índice encima. Se arreglan los dos con la misma cabecera opcional.
- **Qué es frontmatter:** la primera línea es exactamente `---` y hay otro `---` de cierre. Un documento que
  abriese con una regla horizontal se confundiría; hoy no hay ninguno con índice (medido).
- **Regenerar = recolocar.** Se acepta la salida del script solo si el bloque del índice sale idéntico al que
  ya había; si alguno difiere (índice caducado o generado con flags), se mueve el bloque existente tal cual,
  para no cambiar contenido.
- **Banco:** `scripts/indexar_doc_test.sh`, junto a su script y no en `qa/scripts/` (allí dispararía build y tests en el gate, que el encargo prohíbe; y no verifica el proyecto). Ficheros temporales, sin tocar el árbol. No se engancha al
  CI en este encargo.
- **El título es un h1.** El patrón viejo tomaba un `## Sección` inicial por título; el banco lo cazó en el
  caso «con frontmatter y sin título». Se acota a `# `; medido que ningún índice del repo cambia de sitio.
- **Carga por ruta de `git-hooks.md`:** solo se mide si sale barato y sin inventar; si no, queda pendiente en
  el ticket.
- **Entrega:** sin `.swift`, pero `scripts/` y `qa/` no están en la lista de «sin nada que compilar», así que
  va por PR con auto-merge (worktree).
