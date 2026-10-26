# Cola 2.2 · lote 12.6 Registro: voz, cámara, CSV, Apple Pay, Bandeja y favoritos (8 cards)

## Contexto
Jürgen (24-oct): seguir la cola 2.2 por lotes 12.x; el barrido estricto cierra 2.2. Ya cerraron 12.1–12.5 (PR #631 en cola), Duo, Fundido y assets X. Esta es **12.6 · Registro (voz, cámara, CSV, Apple Pay, Bandeja)**. Base: `origin/2.2`, PR contra 2.2.

Ocho cards en «lista para lanzar», versión 2.2 (la novena del listado original de favoritos de transferencia ya no está en lista: L2-14 está en in qa y el destino por Modo Nube está blocked). Léelas con `tablero ver <id>`:

1. `tablero-al-leer-un-recibo-completo-con-la-camara-cb5v` — Al leer un recibo completo con la cámara, «Guardar» sale apagado en los tests de iOS 27
2. `tablero-apple-pay-la-voz-y-la-bandeja-pueden-pon-k5jh` — Apple Pay, la voz y la Bandeja pueden poner a un gasto una subcategoría de ingreso aprendida del comercio
3. `tablero-bug-2-2-gasto-agregado-puede-decir-que-s-dx3m` — Bug 2.2 · «¡Gasto agregado!» puede decir que se apuntó algo que el puente no escribió
4. `tablero-bug-un-recibo-compartido-que-choca-con-f-fazw` — Bug · Un recibo compartido que choca con «Función Pro» se descarta
5. `tablero-esto-lei-muestra-el-gasto-con-signo-s-25-ex73` — «Esto leí» muestra el gasto con signo (S/ -251.81) en 2.2
6. `tablero-lo-importado-desde-csv-no-se-distingue-d-d4od` — Lo importado desde CSV no se distingue de lo escrito a mano y puede caer en categoría de ingreso siendo gasto
7. `tablero-registro-por-voz-onda-de-voz-y-texto-en-tjws` — Registro por voz: onda de voz y texto en vivo mientras hablas (**propuesta visual**)
8. `tablero-revisar-el-diseno-de-la-hoja-de-la-cuent-rd7z` — Revisar el diseño de la hoja de la cuenta eliminada (mover o borrar movimientos)

**No** incluir aquí la card del segmento de gráfica (propuesta A): va en sesión propia con el /spec del ticket.

## Qué se pide
1. Al empezar: mueve las ocho a «in progress» con `--agente frank`.
2. Cards 1–6 y 8 (cierra sola): arregla según «hecha cuando»; preferible tests que fijen la regresión. Criterio estricto: solo «in qa» a jurgen (con guion corto) lo grave que el simulador no valida; lo demás a done.
3. Card 7 (propuesta visual): **no merges UI inventada**. Deja 2–3 propuestas como artifact de Claude (onda + texto en vivo; sin cambiar el audio que va a la IA), con tu recomendación; mueve la card a «espera decisión» a jurgen. El resto del lote sigue y el PR puede llevar solo 1–6 y 8.
4. Card 8 (hoja cuenta eliminada): Jürgen no le gusta tanto el diseño actual. Si el cambio es mecánico de layout ya decidido en la card, impleméntalo; si hace falta elegir look, deja 2 propuestas con capturas, card en «espera decisión» a jurgen, y sigue.
5. Dudas reversibles: opción recomendada + nota en la card. Solo lo irreversible → espera decisión.
6. Tickets nuevos de lo que encuentres, con su card.
7. Capturas antes/después en `capturas/` si hay cambio visible.

## Qué NO hay que tocar
- marketing/ y Web/ (Lola).
- La card del segmento de gráfica / modelo de filtros (sesión aparte).
- Despliegues CloudKit/Supabase de producción.
- No desactivar tests ni saltarse protecciones de rama.

## Cómo se sabe que está bien
Las cards 1–6 (y 8 si se implementó) cumplen «hecha cuando» o quedan en in qa/espera con motivo; la 7 en espera decisión con propuestas; suite unit en verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si #631 (u otro) sigue en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: limpiar sims muertos / DerivedData de sesiones cerradas / cachés XcodeBuildMCP de worktrees muertos (sin preguntar); build `xcodebuild -jobs 2` sin sim booteado; un solo simulador iPhone; al cerrar apagar y borrar ese sim y DerivedData de esta sesión. Disco ~27 GB libres (<32): limpia sin preguntar antes del build.

## Ritmo
Después: 12.7 → (segmento A si sigue listo) → FAB → barrido. Ve directo; no alargues fuera de estas ocho.

## Paso 0

Decidido al empezar (2026-10-25, Frank). Asumido sin preguntar: todo reversible.

- **Las ocho cards ya estaban en «in progress» a nombre de frank** al abrir la sesión (las movió el lanzador).
- **cb5v (Guardar apagado en iOS 27):** el ticket ya está en `done` desde el 12-oct (`DraftFutureDateLogic`, `42e393c7b`, dentro de `origin/2.2`). No se toca código: se re-corre `ImageEntryReviewUITests` en el gate como evidencia y la card va a done.
- **k5jh (memoria de comercios cruza naturalezas):** el filtro sube a `MerchantMemoryService.suggest(for:isExpense:)`, un solo sitio, con el criterio de `DraftBuilder.matchesNature` (manda el tipo). Apple Pay, voz y Bandeja lo usan.
- **dx3m («¡Gasto agregado!» afirma lo que el puente no escribió):** la línea se confirma leyendo lo que quedó en el store para ese gasto (transacción real, virtual de tu parte, borrador opt-in, `bridgePending`). Si no hay rastro, se calla. Cubre los seis casos sin tocar el puente.
- **fazw (recibo compartido que choca con Pro):** la tanda se retiene mientras «Función Pro» está abierta; comprar abre el registro por imagen con ella; cerrar sin comprar la descarta como hoy. La recuperación del arranque no la vuelve a lanzar mientras se retiene.
- **ex73 («Esto leí» con signo):** se quita el signo en la tarjeta de revisión (voz y foto comparten tarjeta), como en 2.1. El color sigue marcando el ingreso. Nota en la card: el signo lo había puesto L4-14 a propósito; la Bandeja lo conserva.
- **d4od (CSV):** se arregla la naturaleza de la categoría: con dos categorías del mismo nombre gana la del signo; con solo la contraria se conserva si la subcategoría ya vive en ella (reembolso) o es de sistema (transferencias en «Otros»); si no, en modo «crear» se crea la de la naturaleza correcta. La marca de origen explícita **no** se hace aquí: pide campo nuevo en CloudKit Production y columna en la nube (fuera del lote); su único lector es el barrido one-shot del chat, y el hueco real que queda va a ticket aparte.
- **tjws (onda de voz):** solo propuestas en un artifact (3), card a «espera decisión».
- **rd7z (hoja de la cuenta eliminada):** la card no trae layout decidido: dos propuestas con capturas del antes, card a «espera decisión».
