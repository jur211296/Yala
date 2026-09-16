---
id: detach-history-replay-can-tombstone-groups-on-next-launch
status: done
priority: high
area: "modo-nube, groups, settings"
created: 2026-09-11
updated: 2026-09-16
source: "review adversarial del paso 10 (`groups-account-association-in-storage-row`), lente de sync"
qa-status: absorbed
qa-date: 2026-09-16
qa-notes: Absorbido por device-qa-groups-account-association recorrido 8 con dos miembros reales. Firma de autor f63b2dbb en HEAD y 5 casos GroupsDetachHistoryReplayTests
---

# Desasociar borra las filas de grupos por FILAS, y el History del arranque siguiente puede convertirlas en tombstones

## El problema, en lenguaje de usuario

Suelto mi cuenta de grupos en este iPhone. Los grupos siguen en mi cuenta —eso es lo que la app me
promete— y los demás miembros no deberían notar nada. En un arranque posterior, si el canal vuelve a
mirar el historial de cambios locales antes de que nadie le diga que esas zonas ya no son suyas, esos
borrados **locales** pueden viajar al servidor y **borrar los gastos para todos los miembros del grupo**.

## Lo medido (2026-09-11, sobre el árbol del paso 10)

`CloudSessionSignOut.detachGroupsAccount` borra las filas `Split*` con `context.delete` y purga el
cursor en la MISMA transacción, con el canal ya cortado (`teardownForSignOut`) y sin credenciales. En el
proceso vivo nada sale del teléfono. El riesgo está en el SIGUIENTE arranque:

- Al re-asociar, `loadOrCreateCursor` crea un cursor virgen ⇒ `fetchHistory(after: nil, floor: nil)`
  devuelve **todo** el History, esos deletes incluidos.
- Lo único que hoy impide traducirlos a tombstones es que `backendGroupZoneIDs` sale VACÍO porque
  `drainOnce` corre ANTES del pull dentro de `syncCycleOnce`. **Es un efecto colateral del orden, no una
  defensa**: si ese primer drain lanza en cualquiera de sus cuatro fetches, el `catch` traga, no se
  escribe cursor, el ciclo sigue al pull que repuebla las zonas, y el drain siguiente sí emite.
- `purgeQueuedSplitGroupTombstones` no cubre esto: solo barre `split_groups`.

Es la misma familia que «Un gate por ZONA calculado sobre filas VIVAS es la herramienta equivocada para
un tombstone por FILA» (`docs/aprendizajes-tecnicos.md`).

## Lo que se espera

La regla de área ya dice cuál es la forma correcta: **una salida que borra lo local borra ARCHIVOS antes
del mount, nunca FILAS** (`.claude/rules/swiftdata-cloudkit.md`). El paso 9 lo hace así para sus tres
cierres (`armSignOutWipe` + `markSignOutWipeIncludesGroups`, y el boot-hook borra el trío de ficheros).
El desasociar debería usar ese mismo mecanismo —acotado al store de grupos y sin tocar lo personal— o,
si se queda con el borrado por filas, anclar el cursor al token actual DESPUÉS del borrado en vez de
purgarlo, para que el History de esos deletes quede por debajo del high-water.

Lo que NO vale es dejarlo apoyado en el orden de `syncCycleOnce`: un reordenamiento futuro de ese método
reabre el agujero sin que nadie lo note.

## Cómo se prueba

Con el andamio de `CloudSyncEngineTests` (containers on-disk con los tres stores, el History es
por-CONTAINER): desasociar con filas de grupo vivas, forzar el fallo del primer `drainOnce`, re-asociar y
**contar filas de `GroupSyncOutbox` tras el ciclo**. Con el agujero abierto salen tombstones de cada
`SplitExpense` borrado; con el arreglo, cero.


---

## Cerrado en código (2026-09-11)

**El arreglo no es ninguna de las dos vías que este ticket proponía, y el porqué está medido.** El boot-wipe
por ARCHIVOS exigiría relanzar la app, y el desasociar es un gesto in-session de Ajustes: convertirlo en
«reabre Yala» es un cambio de producto que ni el ADR ni este ticket piden. Y conservar el ancla del drain
—la alternativa que el ticket ofrecía— se implementó, se midió en la review y **se retiró**: el ancla que
sobreviviría es la del último drain ANTERIOR al desasociar, y estos deletes son POSTERIORES, así que
`fetchHistory($0.token > token)` los devuelve igual; encima clavaba `lastDrainedTxAt`, uno de los cuatro
suelos del corte de purga del History, sin canal que volviera a avanzarlo.

**Lo que se hizo:** el borrado local del dominio Grupos va **firmado con el autor del canal**
(`GroupsSyncClient.outboxSaveAuthor`). El drain descarta por autor ANTES de traducir, así que esos deletes
dejan de ser traducibles **mire el History desde donde lo mire** — no depende del cursor, ni de
`backendGroupZoneIDs`, ni del orden de `syncCycleOnce`, que era el requisito duro.

La firma vive DENTRO de `DataWipeService.deleteLocalGroupsRows`, no en los llamadores, y por eso esa función
hace SIEMPRE el `save()`: con el autor restaurado antes de un save ajeno la firma no serviría de nada. Lo que
el llamador quiera meter en la misma transacción va en `alsoDeleting`. Consecuencia buscada: **el otro
call-site, el «Empiezo de cero» del Welcome, queda cubierto por construcción** — sus deletes eran
igualmente traducibles, a tombstones de los grupos del humano anterior.

Verificado en simulador con `YalaTests/CloudSync/GroupsDetachHistoryReplayTests` (5 casos, containers
on-disk con los tres stores y History real): el escenario completo del ticket —desasociar con filas vivas,
primer drain que no ancla, re-asociar, relanzar— encola **cero escrituras**; con el agujero abierto salen
**2 tombstones de `SplitExpense`** (el grupo no cuenta: su emisión es `updateOnly`, y `SplitMember` es
pull-only). Tres mutantes verificados. La regla de área lleva la entrada nueva.

**Lo que falta:** device-QA con dos personas — recorrido 8 de
`tickets/qa/device-qa-groups-account-association.md`. **NO es simulable:** el unit test llega hasta «el
teléfono no encola la escritura»; que el servidor no la reciba y que el otro miembro no pierda sus gastos
solo se ve en device.

## QA · 2026-09-16 — cerrado como absorbido

Lo que falta es el device-QA con dos personas, y este ticket ya lo apuntaba por nombre: el **recorrido 8**
de `device-qa-groups-account-association` (desasociar, matar la app, volver a asociar y comprobar que el
otro miembro conserva sus gastos). Ese ticket sigue en la cola de device.
