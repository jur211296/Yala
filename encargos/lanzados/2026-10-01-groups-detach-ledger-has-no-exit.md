# El libro de gastos conservados al desasociar no tiene salida

---
ticket: groups-detach-ledger-has-no-exit
modo: autonomo
cola: A
---

## Contexto
Cierre limpio de PR #318 (carril adaptativo paso 11: Yala gira a horizontal en iPhone; en cola de merge a 2.1). Cola A autónoma sigue armada; turno Cola A (alternancia A ↔ adaptativo). Una sola sesión Yala a la vez. Ticket: `tickets/backlog/groups-detach-ledger-has-no-exit.md` (medium, groups/modo-nube). Cola A = riesgo real nube/sync: aquí la persona puede quedar con un gasto de grupo sin movimiento personal para siempre (sin salida).

Medido en el ticket (2026-09-11, ampliado 2026-09-27): `GroupsDetachedBridgeLedger` guarda los gastos/liquidaciones cuyo movimiento personal se conservó al desasociar. Al re-asociar, el bridge los da por atendidos (`true`) sin recrear. Si la persona **borra a mano** ese `TransactionItem` (o un wipe masivo que conserve grupos se lo lleva — el masivo ya lo cierra `wipe-data-keeps-groups-but-drops-their-bridged-rows` retirando el libro; **queda abierto** el borrado a mano y la edición remota del `SplitExpense`), el guard sigue bloqueando y no hay forma de recuperar el movimiento.

Jürgen ordenó (2026-09-28 16:31, vigente 2026-10-01): una sola sesión Yala a la vez, alternando Cola A y carril adaptativo. Esta es Cola A. No toques simuladores `YalaLane-Adapt-*`. MODO AUTÓNOMO: elige la opción robusta / Recommended sin preguntar; no despiertes a Jürgen por preferencias reversibles. Device-QA opcional no frena merge ni `/cerrar-total`.

**Decisión de producto ya contestada (Frank, opción recomendada — no la vuelvas a preguntar):**
1. Al **borrar** el `TransactionItem` conservado, retira su entrada del libro en el mismo camino de borrado (gasto y liquidación).
2. Si el `SplitExpense` / settlement remoto **cambia** de forma que el movimiento conservado ya no corresponde, retira la entrada del libro para que el bridge vuelva a crear.
3. No añadas TTL ni UI de limpieza del libro; no cambies el veredicto `true` mientras el movimiento conservado siga vivo.
4. Cubre también el hueco del borrado masivo ya parcialmente cerrado: si el libro quedó huérfano tras un wipe que no lo retiró, el mismo retiro-al-borrar (o equivalencia al detectar ausencia del movimiento) lo cura.

## Qué se pide
Cierra el ticket `tickets/backlog/groups-detach-ledger-has-no-exit.md`.

1. **Medir primero** el hueco: conservar → re-asociar → borrar el movimiento → exigir que el bridge no recrea; mismo con edición remota si el andamio lo permite.
2. Implementa el retiro del libro en el borrado del movimiento (y en la edición remota según D2); tests unitarios del libro + bridge.
3. Gate, review adversarial acotada al libro/bridge/detach, PR a `2.1`, merge y `/cerrar-total` en autónomo.

## Qué NO hay que tocar
- Carril adaptativo / iPad / simuladores `YalaLane-Adapt-*`. No `simctl shutdown all`, `erase all` ni `killall Simulator`.
- Producción / deploy.
- Cola B (UI/UX redesign) ni Cola C deferred.
- Abrir otra sesión Yala en paralelo.
- Reabrir el wipe masivo ya cerrado en `wipe-data-keeps-groups-but-drops-their-bridged-rows` salvo para alinear el retiro del libro si falta un caso.

## Cómo se sabe que está bien
- Tras conservar + re-asociar + borrar el movimiento a mano, el bridge vuelve a crear en el ciclo siguiente.
- Edición remota del gasto (si aplica) también desbloquea.
- Mientras el movimiento conservado vive, no hay duplicado.
- Tests + CI verdes; PR mergeado a `2.1` (o en cola de auto-merge); ticket a `qa` o `done` según cobertura; residuales a ticket propio; cierre limpio con `/cerrar-total`.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge (o auto-merge en cola), board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada (ya fijada arriba).

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, con resumen corto en lenguaje de usuario; (4) acabaste un tramo sin siguiente paso claro, una vez. NO avises por test rojo que vas a reclasificar ni ruido de CI advisory.

## Paso 0

Decidido por Frank (MODO AUTÓNOMO, sin preguntas: ninguna es de producto ni de acceso).

1. **Cómo sabe el libro que el movimiento conservado sigue vivo.** El libro guarda, por cada gasto o
   liquidación conservados, el `PersistentIdentifier` de las transacciones que liberó al desasociar.
   No es un campo nuevo en `TransactionItem` (exigiría desplegar schema de CloudKit a Production, fuera
   de alcance) ni una huella por contenido.
2. **Retiro por ausencia, no por camino de borrado.** Borrar una transacción tiene decenas de caminos
   (fila, detalle, lote, cuenta, sync de otro dispositivo, wipe). En vez de engancharlos todos, el
   puente comprueba que el movimiento sigue en el store: si ya no está, retira la entrada y crea como
   siempre. Es la «equivalencia al detectar ausencia» que el encargo admite (D4) y cubre D1 y D4.
3. **El «ciclo siguiente».** Un gasto que no cambia no vuelve a pasar por el puente, así que el
   arranque revisa el libro (dentro de `retryPendingBridges`, con sus gates) y arma la intención
   durable del puente para los conservados que ya no están. La recrea el retome de esa intención.
4. **Fallar hacia el comportamiento de hoy.** Si la comprobación no puede afirmar «ya no está» —entrada
   sin identidades (libros escritos antes de este cambio, borradores conservados), identidad de OTRO
   store (store recreado y re-importado), error de fetch— el veredicto sigue siendo «atendido». Lo
   peligroso aquí es el duplicado, y eso es lo que el libro existe para evitar.
5. **Edición remota (D2).** Pasa por el mismo guard: si el movimiento ya no está, se recrea; si sigue
   vivo, no se toca (D3 y criterio «sin duplicado»). Que el movimiento conservado siga los cambios del
   gasto es el enlace, con ticket propio (`groups-reassociation-does-not-restore-the-bridge-link`).
6. **Borradores conservados** (pasaron a `.manual`): no se rastrean. Aprobar uno lo convierte en una
   transacción sin enlace, así que su ausencia no prueba nada. Residual con ticket.
7. **Añadido tras la review adversarial (3 lentes).** Con un desasociar a medias de esa cuenta el libro frena como
   antes (crear apuntaría a una zona que se vacía después). Un store personal sin transacciones es «no se sabe» (purga
   del espejo). Al encontrar el movimiento se re-ancla: por identidad se refresca la huella, por huella se toma la
   identidad nueva (store recreado). Los movimientos se decodifican aparte, para que un fallo no tire el libro entero.
   Las identidades se capturan después del `save()`. Fuera de alcance y con ticket:
   `detach-second-pass-replaces-the-conserved-ledger`, que es preexistente.
