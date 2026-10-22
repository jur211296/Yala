# Implementar ticket paso 10: groups-account-association-in-storage-row

## Contexto
Cola del rediseño. Pasos 0–9 + mitad 2 del 5 en `2.1` (último #139). Este es el **paso 10** — **[adv]**. Necesita 2, 3 y 9. El «equipo» usa la asociación; el paso 12 lo necesita.

Decisiones: sección **«Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)»** del ticket + índice `docs/sessions/2026-09-09-desbloqueo-decisiones-rediseno-sesiones.md`. **Mandan.** (preguntar qué hacer con filas puenteadas; identidad completa, no hash.)

MODO AUTÓNOMO HASTA TERMINAR: review adversarial, gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: elige lo más seguro alineado con Decisiones y regístralo. Device-QA CloudKit → `tickets/qa/`.

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle — una vez.

No lanzar el paso 12 ni invite al cerrar — Jürgen pausa entre pasos.

## Que se pide
1. Leer Decisiones → ADR → matriz → ticket → runbook (este paso).
2. Asociación de cuenta de grupos en la fila de storage; criterios del ticket + Decisiones.
3. Un PR a `2.1`; marcar matriz/coverage; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Paso 12 salvo lo mínimo. Invite-on-mirrored (ticket aparte). Wipe de prod.

## Como se sabe que esta bien
Criterios del ticket + Decisiones; review adversarial hecha; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — el árbol de decisiones, resuelto antes de escribir (2026-09-11)

Las de producto ya las contestó Jürgen (sección «Decisiones de Jürgen» del ticket). Lo que sigue son
las de INGENIERÍA que el ticket deja abiertas, resueltas midiendo y con la medición al lado.

**D1 · ¿Dónde vive el enlace «dormido»? NO en un campo nuevo de `TransactionItem`.**
El ticket dice «conservando su `splitExpenseID` **dormido**». Medido, dejar ese puntero puesto ATRAPA
el dinero: `NewTransactionView.resolveBridgedPointer` (`:158-181`) calcula
`bridgedPointerResolves = found || !GroupChannelFreshness.isFresh(zone:)`; tras desasociar no hay filas
`Split*` ⇒ `found = false` **y** la zona no es fresca ⇒ `true` ⇒ Borrar y Duplicar DESHABILITADOS sobre
un gasto que ya no existe. Es el bug `qa_groups-tx-fantasma-al-borrar-gasto-de-grupo` por la puerta de
atrás, y `LegacyGroupsRetirement` (`:66-72`) ya lo documenta como la razón de conservar la fila del grupo.
Y el barredor tampoco lo arregla después: `OrphanedBridgedTxSweeper.zoneIsSweepable` (`:254-262`) exige
`verdicts[zone]`, que se construye de filas vivas ⇒ zona sin filas = no candidata.
Un campo nuevo en `TransactionItem` tampoco: ese modelo vive en el container CloudKit personal, y un
field key nuevo exige deploy a Production (incidente `isOpeningBalance`, 4 días de sync muerto).
⇒ **El enlace dormido va FUERA del modelo**, en un almacén propio con el molde de
`GroupsPendingBridgeIntent` (UserDefaults, namespace `groups.*`, sin TTL). La TX queda liberada como
cualquier transacción personal —los tres punteros a `nil`, molde `LegacyGroupsRetirement.Action`—.

**D1-bis · y lo que se guarda NO es un puntero a la fila, porque no existe tal puntero.** Medido:
`TransactionItem` **no tiene identidad propia serializable** — ni `id`, ni un UUID estable (`syncID` es
opcional y solo lo puebla el born-cloud o el backfill de migración: en una sesión privada es `nil`). Sin
ancla, «devolverle el puntero a ESA fila» no se puede escribir sin inventar una (un `PersistentIdentifier`
persistido, o una huella por importe+fecha+cuenta, que es exactamente el ancla-por-contenido que ya dio
un incidente de identidad colapsada en este repo). Y el campo nuevo que daría el ancla cuesta un deploy
de schema a CloudKit **Production** del container personal: sin él, el mirror rechaza el record entero y
el sync personal muere para todo el parque (incidente `isOpeningBalance`).

⇒ Lo que se guarda es el **conjunto de gastos y liquidaciones conservados, sellado con el `sub` de la
cuenta** que se fue. Con eso, re-asociar la MISMA cuenta cumple lo que el AC persigue —**cero
duplicados**: el bridge no vuelve a crear la transacción de un gasto que el usuario decidió conservar— y
asociar OTRA no toca nada, porque el sello no casa. **Lo que NO se recupera, y se declara:** el ENLACE.
El movimiento conservado sigue siendo un movimiento personal normal, editable y borrable; editar el gasto
en el grupo ya no lo actualiza. El AC dice QUÉ («0 duplicados»), y esta es la mitad que se puede cumplir
sin un ancla inventada ni una dependencia de deploy; queda con ticket propio por si Jürgen quiere el
enlace de vuelta (`groups-reassociation-does-not-restore-the-bridge-link`).

**D2 · Polaridad de cada una de las dos salidas.** Son las dos que ya existen, no una tercera:
- **Conservar** = la del BARREDOR sobre la TX de cuenta real (libera los tres punteros, preserva monto,
  fecha, cuenta, subcategoría, nota y tags) + borrar el espejo VIRTUAL de sistema. Es la polaridad que
  `LegacyGroupsRetirement` eligió, y por la misma razón: el freeze dejaría fantasmas permanentes que
  nadie podrá limpiar, porque la zona se queda sin canal.
- **Quitar** = `unbridge*` (borra real y virtual), que es lo que el ticket llama «el `unbridge*` de hoy».

**D3 · Qué se guarda como identidad.** Correo (`CloudAuthService.capturedEmail()`) + proveedor
(`storedProvider()`) + `kind` (`AccountKindService.current`) + `sub` (`currentUserID`), los cuatro en
claro. El `sub` es el que decide «¿es la MISMA cuenta?» al re-asociar; el correo es lo que hace la fila
inequívoca. **Ambigüedad NUEVA resuelta:** con Apple, `capturedEmail()` puede ser `nil` (Apple solo
entrega el correo en el PRIMER sign-in de ese Apple ID). Se elige lo más seguro: se guarda lo que haya
y la fila degrada a «Cuenta de Apple» sin inventar un correo. Nunca se muestra el `sub`.

**D4 · Dónde se persiste.** iCloud-KV del Apple ID por `OwnerKeyValueStore` (molde `CloudBeacon`, para
que viaje al 2.º móvil y sobreviva a «Restaurar desde iCloud») **y** espejo en `UserDefaults` para las
lecturas de arranque sin iCloud. Las keys de UserDefaults van en `groups.*` para que
`DataWipeService.removeGroupsDomainPreferenceKeys` se las lleve en el handover; las de iCloud-KV se
limpian explícitamente al desasociar y al cerrar sesión (§5 del ADR: el equipo se mueve junto).

**D5 · Qué NO entra, y por qué.** El **cableado** de «Migrar a la nube» (promover la asociada a
`complete`) es de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`, que es ticket propio
por decisión del paso 3 y así lo dice la celda «C · migrar» de la matriz. Este paso entrega el DATO
(`isAssociatedGroupsAccount`) que esa puerta necesita, no su reordenación del flujo.
