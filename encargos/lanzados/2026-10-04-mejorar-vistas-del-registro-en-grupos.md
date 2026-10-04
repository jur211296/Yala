# Mejorar vistas del registro en grupos (diseño 2.1)

## Contexto
Cola de diseño 2.1 de Yala, antes del QA del lunes. Acaba de cerrar el registro por imagen (PR #353 en cola de merge a 2.1, propuesta C). Siguiente card del tablero: tablero-mejorar-vistas-del-registro-en-grupos-ix2y — «Mejorar vistas del registro en grupos». Nota de Jürgen: versión 2.1; diseño esta noche y el domingo; si el diseño no está cerrado, dejar propuestas y esperar a Jürgen. Cola: después de imagen, antes del barrido QA / TestFlight.

Arranca ya sobre origin/2.1. No esperes a que entre el PR anterior y no partas de la rama en auto-merge. Justo antes del gate, mira si el PR anterior (#353 u otro en CI hacia 2.1) sigue en CI. Si sigue, espera a que entre y rebasea una sola vez, con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Que se pide
Mejorar el diseño de las vistas dentro del registro de una transacción en grupos (detalle / edición / lo que el usuario ve al abrir un movimiento de grupo).

Si el diseño no está cerrado: captura el estado actual, deja 2–3 propuestas claras (A/B/C) con capturas o lienzo, y PARA — espera la decisión de Jürgen. No implementes hasta que elija.

Si el diseño ya está claro o Jürgen elige en esta sesión: implementa la opción elegida, con capturas antes/después en ~/Claude/worktrees/_capturas/2026-10-04-mejorar-vistas-del-registro-en-grupos/ (antes.png, despues.png y las variantes que hagan falta), abre PR a 2.1 con auto-merge cuando toque, y cierra con /cerrar-total.

Pipeline serial en Mini (norma 1 sim): limpiar → build xcodebuild -jobs 2 sin sim → boot 1 sim → tests → apagar/limpiar. No solapes swift-frontend + SpringBoard + app + UITests.

Al lanzar y al cerrar: borra solo el DerivedData de ESTA sesión y las cachés de XcodeBuildMCP de worktrees ya retirados o cuyo PR ya se mergeó. No pidas aprobación. No toques DerivedData ni cachés de un worktree vivo. Si el borrado falla, dilo en el cierre.

Al /cerrar-total: apaga el sim → erase/limpia data del device → si el PR ya mergeó o el worktree no hace falta, quita worktree + DerivedData + cachés XcodeBuildMCP de ese árbol. Deja la Mini limpia.

## Que NO hay que tocar
- No toques el barrido QA ni TestFlight (van después).
- No reabras registro por voz (#351) ni por imagen (#353) salvo rebase.
- No metas trabajo de 2.2 (revisión de uso de IA, partir nube/privado, Yala AI más que crear registros, respuesta por voz, mascota).
- No uses CloudAgent; todo en este worktree.

## Como se sabe que esta bien
- O bien: propuestas A/B/C claras con capturas/lienzo y la sesión parada esperando a Jürgen.
- O bien: diseño elegido implementado, PR a 2.1, capturas antes/después en la carpeta de capturas, tests verdes locales, /cerrar-total limpio.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **¿El diseño está cerrado?** No: la card solo dice «mejorar». ⇒ propuestas A/B/C en lienzo y parar
   hasta que Jürgen elija (la rama del encargo para este caso).
2. **¿Qué vistas entran?** Las que ve quien abre un gasto de grupo: el detalle (hoja al tocar el
   gasto), el editor y la hoja de división. Fuera: el feed, balances, liquidaciones, saldo inicial.
3. **Datos de las maquetas:** los mismos en las tres («Mercado», S/ 120, pagó Ana, tres personas a
   partes iguales), sacados del seed `grupos`.
4. **Recomendación:** por producto, no por esfuerzo → B.
5. **Qué se commitea mientras espera:** solo docs (ticket del rediseño + ticket por hallazgo + índice),
   en la rama del encargo. Sin código de producción.
6. **Hallazgo «(Tú)»:** va dentro del rediseño (las tres lo arreglan), sin ticket aparte.
7. **Elección de Jürgen (durante la sesión):** B → «B con aire» → frase tipo Splitwise tras un feedback externo →
   piezas tocables con fondo del tema. Aprobado sobre capturas del simulador. PR #354.
