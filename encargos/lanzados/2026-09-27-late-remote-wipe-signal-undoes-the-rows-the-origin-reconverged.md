# Un dispositivo que procesa tarde la señal de «Vaciar datos» borra lo que el de origen ya repuso

## Contexto
Tras el merge de #283 (`wipe-data-keeps-groups-but-drops-their-bridged-rows`), la review adversarial dejó este medium: `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`. El dispositivo que pulsó «Vaciar datos» pide convergencia de bridge/patas y en el arranque siguiente repone gastos y liquidaciones de grupo en lo personal. Otro dispositivo del mismo Apple ID que procesa tarde la señal (`ContentView.performLocalWipeForRemoteSync`) borra toda `TransactionItem` sin pedir convergencia. Si eso ocurre DESPUÉS de que el origen ya convergiera, el borrado tardío viaja por el espejo, se lleva las filas repuestas en el origen, y nadie vuelve a pedir la convergencia: los gastos de grupo desaparecen otra vez y ya no vuelven.

Cola A real-risk (pérdida silenciosa de filas puenteadas tras un wipe remoto tardío). Serial A: una sola sesión Yala a la vez. Device-QA de otros tickets no frena este código. Horario diurno Lima (~17:24–21:00): AskUserQuestion OK solo si hace falta acceso/secreto/dispositivo o algo demasiado grave; si no, elige la opción robusta y sigue.

## Decisión de producto (Frank, robusta — no preguntes)
El receptor de la señal de «Vaciar datos» que conserva grupos **también pide la convergencia** (misma receta que el origen tras #283: `markSettlementLegsPending` + `markPending`, o el API vigente), de modo que tras su wipe local las filas de grupo vuelven a lo personal y el espejo las propaga. No basta con asumir que «las filas le llegan por el espejo» si el receptor puede borrar después de la convergencia del origen.

Si al medir conviene complementar con antigüedad/fecha en la señal para no vaciar un dispositivo con datos personales nuevos claramente posteriores, hazlo solo si queda inseparable del arreglo y no abre un rediseño de producto; el contrato mínimo es que la promesa de #283 sobreviva al orden «origen converge → otro dispositivo procesa la señal tarde».

## Que se pide
Cierra el ticket `tickets/backlog/late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged.md`:
1. En el camino de wipe local por señal remota (`performLocalWipeForRemoteSync` / equivalente) cuando se conservan grupos, arma la misma convergencia que #283 en el origen.
2. Cubre el libro detach / claves que el wipe remoto pueda dejar en un estado que bloquee el re-puenteo, solo en lo que este camino toca (no abras `groups-detach-ledger-has-no-exit` entero salvo que quede inseparable).
3. Tests (unit + mutantes según norma del repo) que fallen sin el arreglo — idealmente el orden «origen ya convergido → wipe remoto tardío → filas vuelven».
4. Gate + review adversarial; PR a `2.1`; merge; ticket a `qa` o `done` según norma; actualizar `docs/TICKETS.md` e índice.
5. Cierra con `/cerrar-total` (worktree propio).

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- Cola B UI/UX redesign
- prod Supabase; solo local/staging si toca nube
- No relances otros encargos; no abras tickets Cola C diferidos post-2.1 salvo hallazgos inseparables del arreglo
- No reabras el alcance completo de `wipe-data-group-rows-return-only-on-the-next-cold-launch` (cuándo converger en caliente) salvo que sea inseparable

## Como se sabe que esta bien
- Tras «Vaciar datos» en el origen y convergencia, un segundo dispositivo que procesa tarde la señal no deja al parque sin los gastos/liquidaciones de grupo en lo personal: vuelven (una vez, sin duplicados) vía convergencia del receptor y/o espejo.
- Gate verde; mutantes; PR mergeado a 2.1; ticket movido; `docs/TICKETS.md` al día; `/cerrar-total` hecho.

## MODO AUTÓNOMO (override)
La regla del repo «wait for approval if >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA para este encargo. Implementa de punta a punta hasta gate/PR/merge y cierra con /cerrar-total sin preguntar si sigues. Solo AskUserQuestion real de producto/acceso si hace falta (horario diurno Lima 6:00–21:00); si no es imprescindible, elige la opción robusta/recomendada y sigue. La decisión de producto de arriba ya está tomada.

## Paso 0 (Frank, 2026-09-27)

Medido antes de decidir:
- El único receptor de la señal que borra filas es `ContentView.performLocalWipeForRemoteSync` (los otros cinco llamadores de
  `wipeAllUserData` son handover, uitest o los dos borrados de iCloud, que ya piden convergencia).
- Su borrado es `wipeAllUserData(broadcastSignal: false)` con los defaults: idéntico a `wipePersonalDataKeepingGroups` salvo
  la señal. Las dos keys de la convergencia (`fullModeActivation.*`) no están en ninguna lista de borrado, así que pedirlas
  ANTES sobrevive al reset de preferencias; lo fijo con un test sobre `.standard`.
- El libro de conservados ya lo retira `wipeAllUserData` en cualquier alcance (#283); la marca de sesión privada no se toca,
  así que la convergencia corre en el arranque siguiente aunque la persona vuelva al Welcome.

Decisiones:
1. **El receptor pide la convergencia**, antes de borrar, por una función con nombre (`DataWipeService.wipeLocallyForRemoteWipeSignal`)
   que fija `broadcastSignal: false` y delega en `wipePersonalDataKeepingGroups`. ContentView la llama; un scan fija el cableado.
2. **Doble puenteo**: con el espejo entregado, la convergencia del receptor es idempotente (drafts y virtuales delete+recreate,
   real preserve+update, liquidaciones solo sin pata). Si los dos convergen antes de cruzarse por el espejo, quedan duplicados:
   es la misma carrera que ya tiene todo gasto de grupo que llega a dos dispositivos del Apple ID. Se documenta, no se abre.
3. **Antigüedad de la señal**: NO. No es inseparable del arreglo; ticket de backlog aparte.
4. Momento: el del resto de borrados (arranque en frío siguiente). No se abre `wipe-data-group-rows-return-only-on-the-next-cold-launch`.
5. Tests: behaviour del receptor (orden «origen convergido → borrado tardío → vuelven una vez»), no-re-señal, keys sobre `.standard`,
   scan del cableado; mutantes sobre cada uno. Review adversarial (sync + dinero).

### Enmienda tras la review (Frank)
La decisión 2 era falsa: la convergencia re-puentea TODO el histórico, no un delta, y dos dispositivos que convergen antes
de cruzarse por el espejo duplican dinero de forma permanente. El receptor pide **solo si su borrado se lleva
transacciones puenteadas posteriores a la señal** (prueba de que el origen ya convergió). Receptor sin Grupos: residual con ticket.
