# Grupos: «Desasociar» con el drain atascado y la sesión caducada (o sin App Attest) dice las dos causas en un solo aviso (opción B decidida)

## Contexto
Ticket `tickets/backlog/detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes.md` (léelo entero: trae el porqué medido en el código, las tres propuestas y los criterios de aceptación). Nació como pariente de `groups-stuck-drain-on-a-healthy-phone-says-try-again-later`, que ya se cerró en el PR #362 (mergeado a 2.1): ese PR le dio a Grupos su motivo propio `.groupsCaptureUnfinished` con el texto «Algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos…».

Hoy, en «Desasociar», si el drain de Grupos está atascado **y además** la sesión de grupos caducó (o el teléfono no tiene App Attest), `CloudSignOutFlowLogic.stuckCaptureVerdict` devuelve el motivo del ciclo (`lossCause`) y el aviso nombra solo esa causa. La persona arregla una, vuelve a intentarlo y le sale la segunda. En los cierres de sesión eso está bien porque su salida «Cerrar sesión y perderlos» lo resuelve todo; el desasociar no tiene esa salida (`detachGroupsAccount` pasa `lossExit: nil`, decisión de Jürgen del 2026-09-15).

**Decisión de Jürgen (2026-10-05 10:48): opción B.** Un texto propio, solo para el desasociar, que diga las dos cosas:
«Tu sesión de grupos caducó y algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. No se pierden. Entra otra vez, cierra y vuelve a abrir Yala (si sigue pasando, actualízala) y vuelve a intentarlo.»
Más **el gemelo del App Attest** (mismo esquema: la causa de App Attest con el texto que ya usa la app para ella + el atasco del drain + qué hacer), redactado con el mismo tono y criterio.

Jürgen quiere en Yala siempre lo más robusto y la mejor práctica aunque tarde más. Sin apuro. No te inclines a lo más chico.

## Qué se pide
1. Modelar el caso «dos causas» en el desasociar de forma explícita (dos motivos o una marca en el veredicto, lo que sea más limpio y testeable en la lógica pura; decide tú y deja el porqué en el Paso 0 del encargo). Cubre las dos combinaciones: drain atascado + sesión caducada, y drain atascado + sin App Attest. Si al medir aparece una tercera `lossCause` que llega al desasociar (p. ej. otra cuenta), trátala con el mismo criterio o deja ticket si su copy no es obvio.
2. Los dos textos nuevos en los 16 locales del catálogo, con la misma calidad que los vecinos (español base tal cual arriba; el resto traducido con el estilo del catálogo existente).
3. Tests en la lógica pura: rojo contra el código actual (el desasociar con las dos causas devuelve solo una), verde después. Mutantes sobre la rama nueva.
4. Actualiza el ticket con lo hecho y lo que queda; si queda device-QA, guion en `tickets/qa/` y el ticket allí.
5. Tarjeta del tablero Yala `tablero-desasociar-texto-propio-con-drain-atasca-o9re`: in progress al empezar; in qa (asignada a jurgen) si queda device-QA, o done si no. Firma `--agente frank`. Ojo: `tablero editar --nota` sustituye la nota entera; añade sin borrar lo que había.

## Qué NO hay que tocar
- Los cierres de sesión no cambian: su aviso de pérdida ya cuenta lo que el drain no capturó.
- Sin salida que pierda nada en el desasociar (decisión del 2026-09-15). Nada de «Desasociar y perderlos».
- Nada de diseño nuevo; solo el copy decidido y su gemelo. Si aparece otra decisión de UI/UX, deja propuestas en el ticket y no la decidas.
- No toques `GroupSettingsView`, `GroupDetailViewModel`, `GroupsViewModel` ni `RecalculationDebouncer` (PR #363, en cola de auto-merge a 2.1).

## Cómo se sabe que está bien
- Desasociar con drain atascado + sesión caducada (y + sin App Attest) muestra un solo aviso que nombra las dos causas y dice qué hacer para todo.
- Tests rojo→verde y mutantes muertos.
- Gate completo: builds de Yala y Yala Dev sin warnings nuevos, unit tests verdes, XCUITest de las áreas tocadas verdes (los rojos conocidos de iOS 27 como `EdgeCasesUITests.test_extremeMinimumAmountSaves` se citan con su ticket, no se arreglan aquí).
- PR a `2.1` con el parte en el cuerpo, en cola de auto-merge.
- Cierra con `/cerrar-total` autónomo, sin esperar a Jürgen salvo que haya una decisión de diseño real.

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. No se espera a que el PR anterior (#363) entre, y no se parte de su rama. Justo antes del gate, mira si #363 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Pipeline serial en la Mini y limpieza
Cola fija, sin solapar: limpiar → build con `xcodebuild -jobs 2` sin sim booteado → boot de 1 solo sim → tests → apagar y vaciar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests.
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen (no las de worktrees vivos). Si el borrado falla, dilo en el cierre.
Al cerrar: apagar y vaciar el sim que usaste, quitar el worktree si ya no hace falta, no dejar Devices apagados ni basura de build. Si creas cualquier secreto en el Llavero, dilo en el cierre.
Capturas: el aviso nuevo es visible; si puedes provocarlo en el simulador sin trucos frágiles, deja `capturas/antes.png` y `capturas/despues.png` y lista las rutas en el resumen. Si no se puede provocar de forma honesta, dilo y no inventes.

## Paso 0 (Frank, 2026-10-05)

Medido antes de decidir:
- El desasociar recibe `lossCause` + captura atascada por **dos** caminos del push-all, no uno: (1) outbox a 0 y captura atascada → `stuckCaptureVerdict` devuelve el motivo del ciclo; (2) filas vivas, el ciclo bloquea con sesión/attest y la re-captura sale atascada → `lossBlockAfterRecapture` conserva el motivo. Los dos dejan `groupsCaptureStuck` puesto en el coordinador, sin `await` entre la última captura y el retorno.
- La tercera `lossCause`, **otra cuenta**, también llega: camino (1) cuando todo lo que el drain no captura es de otra cuenta. Arreglar el drain no basta (sigue haciendo falta esa cuenta) y entrar con ella tampoco (el drain sigue atascado): son dos causas, igual que las otras. Su copy sale del mismo esquema sin decisión nueva → **se trata aquí**, no ticket.

Decisiones:
1. **Marca, no motivos nuevos.** `BlockReason` es «por qué bloqueó el push-all» y lo comparten tres gestos con ~15 `switch` exhaustivos; dos o tres cases solo-desasociar obligarían a cada uno a declarar «no llega» y abrirían la puerta a que un cierre los reciba. En su lugar, un tipo propio del aviso del desasociar, `CloudSignOutFlowLogic.DetachBlockedNotice` (`.reason(BlockReason)` | `.alsoCaptureUnfinished(LossCause)`), decidido por una función pura `detachBlockedNotice(reason:captureStuck:)`: estados imposibles fuera (la marca no puede ir con `.transient`), exhaustivo sobre `LossCause`, y testeable sin coordinador.
2. **El coordinador decide, la vista pinta.** `DetachOutcome.blockedBeforeWriting` lleva el aviso ya decidido; `releaseDetachBlock(captureStuck:)` recibe el testigo explícito en cada llamada (solo el bloqueo del push-all pasa `groupsCaptureStuck`; los demás, `false`).
3. **Los cierres no cambian.** Nada toca `stuckCaptureVerdict`, `lossBlockAfterRecapture` ni el veredicto compartido.
4. Copys: el de sesión, literal de Jürgen. El de App Attest arranca con el texto que la app ya usa para esa causa y sigue el esquema de Jürgen. El de otra cuenta, igual con el suyo. 16 locales con el estilo de sus vecinos (es-AR en voseo como `captureUnfinished`; es/pt alias copia de su base).
5. Capturas: el aviso solo sale con un drain que falla siempre + sesión caducada/sin attest; no hay forma honesta de provocarlo en el simulador sin un hook de test nuevo. Sin capturas, y sin device-QA (tampoco es provocable en un iPhone real) → ticket a `done` con la cobertura en unit tests.
