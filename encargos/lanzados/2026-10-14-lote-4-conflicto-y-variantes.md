# Resolver el choque del PR #493 (Auditoría UX 2.2 · lote 4) con 2.2, aplicar las variantes L4-1 v1, L4-5 v2 y L4-13 v2, y dejarlo fusionado

## Contexto
El PR #493 «Auditoría UX 2.2 · lote 4: cinco bugs de la Bandeja (voz, foto, compartir)», rama `encargo/2026-10-13-auditoria-ux-2-2-lote-4-voz-foto-bandeja`, base `2.2`, tiene CI en verde pero ya no se puede fusionar: choca con `2.2` después de que entraron los lotes 5, 6 y 7 (#494, #495, #496).
Jürgen ya eligió las variantes visuales del lote 4: **L4-1 variante 1**, **L4-5 variante 2**, **L4-13 variante 2**. Las variantes están descritas en el informe `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html` (secciones l4-1, l4-5, l4-13) y en las capturas `~/Claude/worktrees/_capturas/2026-10-13-lote-4/`.
Aprendizaje de la sesión anterior: `~/Claude/tmp-frank/feedback_la_recomendacion_visual_se_mide_en_la_maqueta.md` (en L4-1, las píldoras con texto cortaban «IA»: medir en el simulador que no se corte).
Jürgen quiere tonos suaves como los del Panel («Últimos registros»), nada de tonos fuertes.

## Qué se pide
1. Trabajar sobre la rama del PR #493 (no abrir PR nuevo): `git fetch`, `git merge origin/2.2`, resolver los conflictos conservando lo que ya entró en 2.2 de los lotes 5–7 y los arreglos del lote 4.
2. Implementar L4-1 v1, L4-5 v2 y L4-13 v2.
3. Pipeline serial de la Mini: limpiar, `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador (iPhone 17 Pro), tests, apagar y borrar sus datos. Nada de solapar build con simulador.
4. Push a la misma rama, esperar CI verde y fusionar el PR #493 a 2.2 (merge commit, como los otros lotes).
5. Capturas antes/después de las tres variantes en `capturas/`.
6. DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees retirados: borrarlos al cerrar sin preguntar.

## Qué NO hay que tocar
Nada fuera del lote 4 y sus tres variantes. No tocar 2.1 ni marketing/.

## Cómo se sabe que está bien
PR #493 fusionado a 2.2, CI verde, las tres variantes visibles en capturas, sin textos cortados, simulador apagado y limpio.

## Paso 0

> Resuelto en autónomo (bypass). Lo asumido va marcado.

**D1 · Cómo se resuelve el choque** → merge de `origin/2.2` en la rama del PR #493 (sin rebase: los otros lotes entraron con merge commit). Los conflictos son solo de texto: los `.stringsdict` de 12 idiomas (los dos lados AÑADEN claves, ninguna en común → unión, verificada con `plistlib`) y una fila de `docs/TICKETS.md` (se quedan las dos).
**D2 · Un gate para dos commits** → el merge queda en el índice, las variantes se escriben encima sin añadirlas, `/gate` sella el árbol final, y salen dos commits: el merge y las variantes. El merge por separado no pasa por su propio gate: une dos árboles que ya pasaron CI y solo choca en textos (asumido).
**D3 · L4-1 v1** → «Voz» y «Foto» debajo del icono, dentro del mismo botón; «IA» y «Nuevo registro» no cambian. Se mide en el simulador que «IA» no se corte, en español y en alemán.
**D4 · L4-5 v2** → la ⓧ roja pasa a un menú «⋯» con «Descartar (va a Archivados)» y «Eliminar para siempre» (con la confirmación que ya existe para borrar). Al descartar sale «Lo moviste a Archivados · Deshacer» unos segundos. El aviso va en una capa de ventana encima de todo, porque el editor se abre desde la Bandeja, la voz, la foto y los pagos planificados, y desde la voz se vuelve al Panel (asumido). «Deshacer» devuelve el borrador a pendientes con `returnToPending`. El borrador ya archivado conserva su papelera (fuera de la variante).
**D5 · L4-13 v2, tonos suaves** → las dos pantallas de éxito usan el mismo check: círculo verde SUAVE (`DS.Semantic.successBackground`, el verde al 15 %) con el ✓ verde, sin halo, degradado ni sombra; la animación de aparición se queda. Jürgen pidió tonos como los del Panel, no el verde sólido de la maqueta (asumido). En «aprobar varios», bajo el número: «S/ 60.50 en total · Cuenta Principal». Si los aprobados tienen varias divisas, sin total; si tienen varias cuentas, sin cuenta (la cifra partida hereda la ambigüedad).
