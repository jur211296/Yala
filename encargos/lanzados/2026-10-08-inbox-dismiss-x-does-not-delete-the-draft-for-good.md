---
esfuerzo: high
---
# Un gasto que descarto en la Bandeja con la x no vuelve a aparecer

## Contexto
Card del tablero `tablero-borrar-un-gasto-de-la-bandeja-de-entrada-yneu` (ready to launch, vence 2026-10-09). Reporte de Jürgen del 2026-10-08 a las 11:52 (Lima), con sus palabras:

> «cuando borro un gasto de la bandeja de entrada (la x arriba a la derecha antes de aprobar), no se está borrando definitivamente, me vuelve a aparecer»

Todavía no hay ticket. Frank miró los tickets abiertos y ninguno cubre esto: `private-exit-materialized-drafts-do-not-refresh-the-inbox` trata de un borrador que tarda en aparecer, no de uno que reaparece, y `discard-gate-proceed-leaves-the-imported-rows-behind` trata de la puerta de descarte de la activación, no de la Bandeja.

Lo que hay en 2.1 hoy (2026-10-08, `2ddb5d28e`). Son pistas, así que verifícalas en este árbol antes de tocar nada:
- La «x arriba a la derecha» es el botón `xmark.circle` de `InboxDraftEditSheet` (`Yala/App/Views/Inbox/InboxDraftEditSheet.swift`, `toolbarContent`, L378-386), y es **Rechazar**, no borrar. `rejectDraft()` (L1073) guarda los campos editados y llama a `DraftService.rejectDraft` (`Yala/Services/DraftService.swift` L638), que solo pone `status = .rejected` y lo manda a Archivados. Borrar de verdad solo existe con la papelera de un rechazado (L369-376), con el swipe (`InboxView.swift` L740-766) o con las acciones en lote. El swipe «Rechazar» de `InboxView` (L816) y `bulkReject` (L659) hacen lo mismo.

Hipótesis, de más a menos probable:
1. **Pago planificado o suscripción personal que se recrea.** `DraftService.rejectDraft` y `deleteDraft` (L676) solo saltan la ocurrencia con `skipGroupScheduledOccurrence` (L707), y esa función es un no-op salvo para `.groupScheduledExpense`. Su propio comentario lo dice: «si no, `processDuePayments` la recrea al día siguiente». Para `.scheduledPayment` y `.subscription` (`ScheduledPaymentDraftService.createDraft`, L228-237) no se salta nada y `nextDueDate` no avanza. Luego `ScheduledPaymentDraftService.hasExistingDraft` (`Yala/App/Services/ScheduledPaymentDraftService.swift` L121-148) solo cuenta los borradores `pending|approved`, así que un rechazado no bloquea y uno borrado ya no existe. `processDuePayments` corre en cada arranque (`AppBootstrapper.swift` L239) y en cada vuelta a primer plano a partir de 30 s (L2044-2047), y crea un borrador pendiente idéntico. La recreación al quitar el salto (`unskip`, L286-330) usa la misma consulta.
2. **Otro dispositivo o el canal de sync lo trae de vuelta.** En modo iCloud o nube, otro teléfono con el mismo pago corre `processDuePayments` por su cuenta y crea su propio borrador, con otro `syncID` y otro `createdAt`, así que el ancla `SyncContentAnchor.inboxDraft` (L93) no lo empareja. Ese borrador llega por el espejo como uno nuevo. Otra variante: un upsert viejo con `status_raw = pending` (`EntityEmissionMap.swift` L357, `EntityApplyMap.swift` L226) pisa el rechazo, o el borrado no llega como tombstone (`deleteMatching`, `EntityApplyMap.swift` L1057). Mira también el ticket `clock-ahead-retried-older-change-beats-the-newer-one`.
3. **Una fuente de captura sin memoria de lo descartado.** `DraftDeduplicationService` (foto: `ImageSelectionView.swift` L847; voz: `VoiceRecordingView.swift` L583) solo compara con los pendientes que se le pasan. Apple Pay y Siri no deduplican a propósito y reintentan su cola del App Group: `ApplePayDraftService.swift` L160-165 documenta que un crash entre el save y el remove reprocesa el pago. Y queda una posible falsa premisa de UX: la x archiva y no borra, así que el gasto sigue en Archivados. Si Jürgen lo ve ahí, lo que hay que arreglar es la expectativa o el copy, no el sync.

Ojo con la cola: la sesión viva `account-currency-change-leaves-scheduled-and-favorites-stale` toca `ScheduledPaymentDraftService.swift` y `DraftService.swift`. Esta sesión va después de esa, por el gate de abajo.

Para orientarte: `CLAUDE.md`, `.claude/rules/testing.md` y `docs/inbox-producto-2026-09-18.md`. Mira `~/Claude/referencias-ui/README.md` solo si el arreglo toca UI.

## Que se pide
1. Antes de nada, crea el ticket `tickets/backlog/inbox-dismiss-x-does-not-delete-the-draft-for-good.md`, o muévelo al estado que toque según las convenciones del repo. Pon en él las palabras de Jürgen tal cual, más «Qué pasa, en lenguaje de usuario» y lo medido.
2. Reproduce el bug con un test que falle con el código actual: descartar con la x un borrador → correr lo que lo recrearía (arranque o primer plano, `processDuePayments`, pull del espejo, la cola de captura) → el borrador vuelve. Debe salir rojo en 2.1 antes de tocar el código.
3. Encuentra la causa real. Confirma o descarta cada hipótesis de arriba y anótalo en el ticket. Puede haber más de una causa.
4. Arréglalo para que un borrador descartado (rechazado con la x, rechazado con swipe o en lote, o borrado) no vuelva por ninguna fuente que crea borradores: pago planificado, suscripción, pago planificado de grupo, Apple Pay, Siri y Shortcuts, voz, foto o captura (single y lista), correo y automatización, chat, puente de grupos y lo que encuentres en el árbol. También en los dos modos de sync, iCloud y nube, incluido el caso de dos dispositivos. Una prueba por fuente y por modo. Si una fuente no puede recrearlo por construcción, déjalo escrito con el porqué.
5. Lo que ya se descartó y volvió no se pierde de otra forma: el arreglo no puede borrar en masa los borradores reaparecidos que la persona aún no tocó, ni ocurrencias futuras de un pago planificado, ni un gasto real distinto que se parezca. No se borra nada que la persona no haya descartado. Fíjalo con un test de control: dos gastos idénticos reales siguen siendo dos, la siguiente ocurrencia del pago sigue llegando y un rechazado sigue pudiendo volver a pendientes desde Archivados.
6. Si el arreglo necesita una decisión de producto (por ejemplo, si la x debe seguir archivando o borrar de verdad, qué copy lleva, o si rechazar un pago planificado salta la ocurrencia o solo la pospone), decide tú la opción recomendada y sigue. Déjala escrita en el ticket y en el PR, con las alternativas y el porqué.
7. Si hay cambio visible, deja `capturas/antes.png` y `capturas/despues.png` en el worktree y pon las rutas absolutas en el cierre. Si no hay cambio visible, no hagas capturas.
8. Anota lo hecho en el ticket y muévelo según las convenciones del repo. Si queda device-QA (sobre todo el de dos dispositivos), deja el guion en `tickets/qa/`.
9. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-borrar-un-gasto-de-la-bandeja-de-entrada-yneu` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él. Usa `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- Las reglas de los borradores de grupo: los punteros `.groupExpense` siguen sin poder rechazarse ni borrarse desde la Bandeja (`blocksInboxDismissal`), y siguen igual la marca viva de una liquidación (`isLiveSettlementApprovalMark`) y el aviso de importe cambiado (`isSettlementAmountChangeNotice`).
- El «no deduplicamos» de Apple Pay y Siri: nunca perder un gasto capturado. Lo que se recuerda es el descarte, no el parecido.
- La lógica de divisas de la sesión `account-currency-change-leaves-scheduled-and-favorites-stale`.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/` (los extractores solo como lectura).
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de riesgo (datos de la persona, borrar cosas, prod), pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion. Las decisiones de producto reversibles de este arreglo van por el punto 6, a cualquier hora.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~32 GB libres el 2026-10-08, justo en el umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `account-currency-change-leaves-scheduled-and-favorites-stale` sigue en CI (si el orden de lanzamiento cambió, el del encargo lanzado justo antes que este). Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Un borrador descartado con la x no vuelve: ni al relanzar, ni al volver a primer plano, ni tras un pull de iCloud o de la nube, ni desde otro dispositivo, en ninguna fuente.
- Test que reproduce, rojo con el código de 2.1 y verde con el arreglo, más un test por fuente y modo.
- Tests de control verdes: gastos idénticos reales, siguiente ocurrencia del pago y volver a pendientes desde Archivados.
- Ticket creado y movido, con causa, decisión (si la hubo) y guion de QA si queda.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Hecho de partida (Jürgen, 13:19 Lima): el gasto que reaparecía era un **pago programado personal**.

**D1 · ¿Qué significa descartar el borrador de un pago programado?** → **Saltar esa ocurrencia** (la misma marca que «Saltar» en Planificación), en los tres orígenes: pago programado, suscripción y pago programado de grupo.
Por qué: es lo que ya hacía Grupos y lo simétrico de Planificación, donde saltar una ocurrencia rechaza su borrador; la marca viaja por iCloud y por la nube, así que el otro teléfono también la ve. Alternativas descartadas: posponer (es el bug), avanzar la próxima fecha sin marca (no se puede deshacer ni se ve en Planificación).

**D2 · ¿Qué ocurrencia salta?** → La que el borrador **tiene retenida**: la próxima fecha del pago si ya venció, o la próxima aunque no haya vencido si el borrador es un adelanto pendiente. No se salta nada si el borrador es un **duplicado viejo** de una ocurrencia que ya se pagó o ya se saltó, ni si el borrador no está pendiente (borrar un archivado no salta nada).
Por qué: la fecha del borrador puede haberla editado la persona; la próxima fecha del pago no se mueve hasta aprobar, así que es la llave fiable. Alternativa descartada: saltar la fecha del borrador (falla si se editó y con el adelanto).

**D3 · ¿La x sigue archivando o borra de verdad?** → **Sigue archivando** (Rechazar → Archivados). Sin cambio de copy ni de UI.
Por qué: el bug no era la x, era que el pago lo recreaba; con D1 el archivado no vuelve. Cambiar la x quitaría la vuelta atrás desde Archivados. Alternativa descartada: x = borrar (más destructivo, no arregla nada que D1 no arregle).

**D4 · Volver a pendientes desde Archivados** → Deshace el salto (quita la marca de esa ocurrencia). Si la app ya pasó de largo esa ocurrencia, al aprobar el borrador no se vuelve a avanzar la próxima fecha (se marca pagada esa, sin perder la siguiente).
Por qué: el control del encargo exige que un rechazado pueda volver y que la siguiente ocurrencia siga llegando; sin esto, aprobar tras volver avanzaba dos veces y se perdía un mes.

**D5 · Dos dispositivos** → Al recibir/ver una ocurrencia saltada, el borrador **pendiente** de esa misma ocurrencia que creó otro teléfono se **rechaza** (va a Archivados, recuperable), nunca se borra.
Por qué: es la misma ocurrencia que la persona ya descartó; rechazar es lo que ya hace Planificación al saltar. No se toca ningún borrador de otra fecha ni de otro pago.

**D6 · Resto de fuentes (Apple Pay, Siri, voz, foto, correo, chat, puente de grupos)** → Se auditan; solo se cambia código si alguna recrea lo descartado. Si no puede por construcción, se deja escrito con el porqué en el ticket.

**D7 · Capturas** → No hay cambio visible (D3), así que no hay capturas.

**D8 · (tras la review adversarial) ¿La próxima fecha avanza al descartar o espera al arranque?** → **Avanza al descartar** si la ocurrencia saltada es la próxima y ya venció, y el rechazado vuelve a la fecha de su vencimiento.
Por qué: esperando al arranque, «Adelantar» en la misma sesión pagaba dos veces la ocurrencia siguiente; y una fecha editada fuera del calendario no diría, al devolverlo, qué ocurrencia era. Alternativa descartada: que `createAdvancedDraft` salte primero las fechas saltadas (arregla solo uno de los dos caminos).

**D9 · Carreras de dos teléfonos sobre el mismo pago dentro de la ventana de sync** → residuales escritos en el ticket, sin código.
Por qué: cerrarlas exige unir la lista de fechas saltadas por fecha en el servidor (cambio de esquema), y no empeoran el caso de un teléfono.
