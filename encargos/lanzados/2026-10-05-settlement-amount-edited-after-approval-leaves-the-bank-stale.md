# Si otra persona corrige el importe de una liquidación que ya aprobé, el Inbox me avisa y me ofrece ajustar mi cuenta (decisión A de Jürgen)

## Contexto
Ticket: `tickets/backlog/settlement-amount-edited-after-approval-leaves-the-bank-stale.md` (léelo entero; se escribió leyendo código el 28-sep y NO se reprodujo, así que re-mide las coordenadas en el árbol de hoy).
Síntoma: Ana me pagó 25 y lo aprobé en el Inbox a mi cuenta del banco. Después Ana corrige la liquidación a 30 desde otro dispositivo. Mi cuenta de grupos ya cuenta 30 (`GroupsSyncClient.applySettlement` aplica el importe remoto y `bridgeSettlement` rehace la pata virtual), pero la transacción real de mi banco sigue en 25 y nadie me avisa. La transacción real es independiente por diseño (D7 de `DraftService`) y no sigue las ediciones de la liquidación. Relacionado: `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again` (la marca de aprobación que hoy evita volver a preguntar).

Decisión de Jürgen (2026-10-04, tarjeta del tablero `tablero-decidir-si-corrigen-el-importe-de-una-li-gklg`): **A. Avisar en el Inbox. No aceptar la diferencia en silencio.** Jürgen quiere siempre lo más robusto y la mejor práctica, aunque tarde más.

## Qué se pide
1. Medir en el código de hoy qué pasa cuando llega una edición remota del importe de una liquidación ya aprobada a una cuenta real: qué se re-puentea, qué marca queda y qué ve el usuario. Si la premisa no se sostiene (por ejemplo, ya avisa), dilo en el cierre y no inventes trabajo.
2. Implementar A: cuando cambia el importe de una liquidación que ya aprobé a una cuenta real, aparece un aviso en el Inbox que dice qué cambió (quién, importe anterior y nuevo) y ofrece ajustar mi transacción al importe nuevo o dejarla como está. Ajustar cambia esa transacción real; dejarla no toca nada y el aviso se va. Que no cuente doble, que no pregunte otra vez por la misma corrección y que una segunda corrección vuelva a avisar con la cifra al día.
3. Forma del aviso: reutiliza el patrón y los componentes que ya tiene el Inbox para las aprobaciones de liquidación. Si la forma o el texto no salen claros de lo que ya existe, deja 2-3 propuestas (A/B/C) con tu recomendación y pregunta antes de implementar (es de día en Lima hasta las 21:00). Textos en los 16 locales: es-AR con voseo, es-ES con pretérito perfecto, español neutro en el resto, sin inventar plazos.
4. Tests: rojo medido antes del fix, verde después, mutantes que importen y controles (liquidación sin aprobar, aprobada sin cambio de importe, cambio que no toca el importe, segunda corrección).
5. Review adversarial con lente de datos (dinero y doble conteo) y lente de verdad del copy.
6. Hallazgos nuevos van como tickets en `tickets/backlog/`. Si aplica device-QA, guion en `tickets/qa/` y la tarjeta a `in qa`; si no, la tarjeta a `done`.
7. Si el cambio se ve en pantalla y el simulador lo alcanza, deja `capturas/antes.png` y `capturas/despues.png` en el worktree y lista las rutas en el resumen.

## Qué NO hay que tocar
- Nada del cierre de sesión, del desasociar, de «Empezar de cero» ni del drain de Grupos (eso acaba de entrar en PR #366 y otros; no lo toques).
- No cambies el principio D7: la transacción real no sigue sola las ediciones; solo cambia si el usuario lo acepta en el aviso.
- Nada de marketing/, nada de servidor ni migraciones de Supabase.

## Pipeline en la Mini (serial, obligatorio)
1. Limpiar: sims muertos, DerivedData de sesiones ya cerradas, cachés de XcodeBuildMCP de worktrees que ya no existen. Sin preguntar.
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados o con PR ya mergeado. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

Gate después del CI del PR anterior: la sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #366 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
- Con una liquidación aprobada cuyo importe cambia en remoto, el Inbox avisa con quién, el importe anterior y el nuevo, y ajustar deja el banco en el importe nuevo sin contar doble.
- Sin cambio de importe, o sin aprobación previa, el comportamiento no cambia.
- Gate verde (builds sin warnings nuevos, unit completa, XCUITest de las áreas tocadas, centinela 0), salvo rojos conocidos con ticket.
- PR abierto contra `2.1` y cierre con `/cerrar-total` en modo cola (autónomo, auto-merge, sin esperar CI). Al cerrar, la Mini queda limpia: sim apagado y borrado, DerivedData y cachés de esta sesión fuera, worktree retirado, tmux muerta.

## Paso 0 (2026-10-05, Frank)

**Premisa medida (leyendo el árbol de hoy).** Se sostiene: `applySettlement` aplica el `amount` remoto y re-puentea;
`bridgeSettlement` ve la marca (`.approved`), rehace la pata virtual con el importe nuevo, no crea borrador y no avisa.
La transacción real (sin `splitSettlementID`, D7) se queda en el importe viejo. El wire NO trae quién editó
(`recordedByMemberID` es solo CloudKit y es quien la creó), y la app iOS no edita liquidaciones.

**Decisiones.**
1. Forma: **A** de la pregunta a Jürgen (18:3x Lima): fila en Pendientes + la hoja de grupo de siempre, «Ajustar a X» y
   «Dejar en Y». El texto nombra a la otra persona del pago y al grupo, no a quien editó (el wire no lo sabe).
2. El aviso es un `InboxDraft` `.groupSettlement` pendiente, marcado por `originReasonKey` (`DraftOriginReason`
   nuevo) y enlazado a la transacción real por `approvedTransaction`. Sin campos nuevos: un campo pedía desplegar el
   schema de CloudKit (mismo motivo que la marca del ticket padre). `sourceType` se queda en `.groupSettlement` a
   propósito: una versión anterior de la app lo ve como un borrador de liquidación y su aprobación choca con la marca
   (no duplica), mientras que un `sourceType` nuevo lo leería como `.voice` y aprobarlo crearía otra transacción.
3. Referencia del importe ya revisado = `amount` de la marca (la hoja de aprobar no deja editar el importe y filtra la
   cuenta por la divisa de la liquidación). Ajustar pone la transacción real Y la marca en el importe nuevo. Dejarlo
   rechaza el aviso, que queda en Archivados como la decisión (sin él, el siguiente re-puente volvería a preguntar).
4. Un solo sitio decide (`reconcile` puro + aplicación) y se llama desde `bridgeSettlement` (todo cambio remoto pasa
   por ahí) y en frío junto a la poda existente (la transacción que llega después, duplicados de dos dispositivos).
5. Los avisos quedan fuera de todo lo que lee la marca: resolución del re-puente, sustitución de pendientes, poda en
   frío, `ensureSettlementNotAlreadyApproved`. Y `computeFreezePlan` los BORRA (no los convierte a manual): convertido,
   aprobarlo crearía una segunda transacción. Ese plan lo comparten congelar, desasociar, retirada legacy y barrido de
   huérfanos; no se edita el código del desasociar.
6. Sin «Eliminar» en el aviso (ni deslizando ni en lote): borrarlo perdería la decisión y volvería a preguntar.
7. Fuera: divisa de la transacción distinta de la de la liquidación (no hay aviso; ticket), dos marcas vivas de la
   misma liquidación (ya duplicado conocido; no hay aviso).
