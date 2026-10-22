# Implementar ticket: detach-history-replay-can-tombstone-groups-on-next-launch

## Contexto
Sale del review adversarial del paso 10 (`groups-account-association-in-storage-row`, PR #140). El detach borra filas Split* por filas; en un arranque posterior el History puede convertir esos deletes locales en tombstones de servidor y borrar gastos para TODOS los miembros.

La regla de área ya dice la forma correcta: una salida que borra lo local borra ARCHIVOS antes del mount, nunca FILAS (`.claude/rules/swiftdata-cloudkit.md`). El paso 9 lo hace así para sus tres cierres (`armSignOutWipe` + `markSignOutWipeIncludesGroups`). El desasociar debería usar ese mismo mecanismo —acotado al store de grupos y sin tocar lo personal— o, si se queda con borrado por filas, anclar el cursor al token actual DESPUÉS del borrado en vez de purgarlo. NO vale apoyarse en el orden de `syncCycleOnce`.

MODO AUTÓNOMO HASTA TERMINAR: review adversarial, gate, commit, board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Ambigüedad NUEVA: elige lo más seguro alineado con el ticket y la regla de área; regístralo. Device-QA CloudKit → `tickets/qa/`.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo a reclasificar, build a reintentar, ni ruido de CI advisory.

No lanzar invite ni paso 12 al cerrar — Jürgen decide el siguiente.

## Que se pide
1. Leer ticket completo + regla swiftdata-cloudkit + cómo el paso 9 hace el wipe.
2. Cerrar el agujero: detach no puede dejar History convertible en tombstones de grupo.
3. Test del andamio `CloudSyncEngineTests` (containers on-disk): desasociar con filas vivas, forzar fallo del primer `drainOnce`, re-asociar, contar filas de `GroupSyncOutbox` tras el ciclo → cero tombstones.
4. Un PR a `2.1`; board/`TICKETS.md` al día; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Paso 12 / shell-derives salvo lo mínimo imprescindible. Invite-on-mirrored (ticket aparte). Wipe de prod. Datos personales al desasociar grupos.

## Como se sabe que esta bien
Criterios del ticket; test del andamio en verde demostrando cero tombstones tras el escenario; review adversarial; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

## Paso 0 — decisiones resueltas antes de escribir (medidas 2026-09-11)

### D1 · ¿Boot-wipe por ARCHIVOS (lo que prefiere la regla) o borrado por FILAS endurecido?

**Por FILAS, endurecido.** La regla L204 de `swiftdata-cloudkit.md` prescribe archivos-antes-del-mount
porque el peligro allí es el **espejo de CloudKit** del store PERSONAL. El store de GRUPOS monta
`cloudKitDatabase: .none` (`DataWipeService.swift:380`): no tiene espejo, y su único camino de export es
el enqueue explícito del drain. El daño aquí no es el mirror sino **el drain propio**, así que la forma
que la regla persigue —«que el History de esos deletes no sea traducible»— se puede conseguir sin
archivos.

Y el mecanismo por archivos **no es aplicable sin cambiar el producto**: `performGroupsOnlySignOutWipeIfArmed`
es un hook PRE-MOUNT (`SwiftDataConfiguration.swift:862`) y exige relanzar la app. El desasociar del paso
10 es un gesto in-session de Ajustes que deja viva la sesión privada y todo lo personal; convertirlo en
«reabre la app» es una decisión de producto que ni el ticket ni el ADR piden. El propio ticket admite la
alternativa por escrito.

### D2 · Qué se hace en su lugar: dos mitades, ninguna dependiente del orden de `syncCycleOnce`

**(A) El borrado local del dominio Grupos se FIRMA con el autor del canal** (`GroupsSyncClient.outboxSaveAuthor`).
El drain descarta por autor antes de traducir (`GroupsSyncClient.swift:623`), así que esos deletes dejan de
ser traducibles **vea el History desde donde lo vea**: no depende del cursor, ni de `backendGroupZoneIDs`,
ni del orden del ciclo. Hay precedente exacto del patrón en `GroupBackendMembershipService.saveUnderOutboxAuthor`
(`:293-303`).

**(B) se probó y se RETIRÓ. La firma es la única defensa, y es suficiente.** La primera versión conservaba
el ancla del drain (`historyTokenData`, `historyTokenStoreID`, `lastDrainedTxAt`) reseteando solo
`groupCursorsJSON`. La review adversarial (tres lentes) la tumbó con tres medidas:

- **No protege estos deletes.** El ancla que sobreviviría es la del último drain ANTERIOR al desasociar, y
  los deletes son POSTERIORES: `fetchHistory($0.token > token)` los devuelve igual. La segunda capa no
  existía.
- **Lo que evitaría no pasa.** Con las filas ya borradas, el re-barrido completo del History no emite nada
  (medido: 0 filas; el `case` de insert/update no resuelve ninguna fila viva por `PersistentIdentifier`).
  El daño de re-emitir upserts es real pero del par «cursor borrado + filas VIVAS» —medido aparte: 1 upsert
  con HLC nuevo— y lo que lo impide es que el borrado sea UNA transacción, no el ancla.
- **Y cuesta.** `lastDrainedTxAt` es uno de los cuatro suelos del corte de purga del History
  (`CloudSyncEngine.groupDrainedBoundary`). Sin canal que lo avance —tras soltar la cuenta no hay sesión—
  quedaba congelado en el instante del desasociar. Hoy es inocuo (la purga solo corre con el runtime
  personal, que es de `.cloud`), pero clavaría el corte para siempre en cuanto esa persona migrara.

⇒ El par de esta frontera sigue siendo **«filas borradas + cursor borrado», atómico** — igual que antes del
arreglo. Lo único que cambia es que ese borrado va FIRMADO. **Qué se pierde al limpiar:** la defensa queda
en una sola capa. Se acepta porque esa capa vive DENTRO del escritor (no se puede saltar por olvido), es el
mismo mecanismo de echo-suppression que usa todo el canal, y su mutante está medido.

Ventaja lateral: sin el reseteo del cursor, el cambio deja de contradecir la regla C-3 («el cursor del pull
NO se resetea… el molde correcto no es un reset externo») y no hace falta escribirle una excepción.

### D3 · ¿Alcance: solo el detach, o también «Empiezo de cero»?

**La firma va DENTRO del escritor** (`DataWipeService.deleteLocalGroupsRows`), no en el llamador. Es la
misma función que el detach ya usa, y su docblock hoy delega la garantía en el llamador («lo que sí tiene
que garantizar el LLAMADOR es que el canal backend esté cortado»): cortar el canal no impide nada en el
arranque SIGUIENTE, que es el agujero de este ticket. Metiendo la firma dentro, el otro call-site
(`wipeLocalGroupsDomain`, el «Empiezo de cero» del Welcome) queda cubierto por construcción y no queda
ningún **call-site de `deleteLocalGroupsRows`** que borre sin firmar. No es ampliar a otro objeto: es
arreglar el objeto donde vive el bug.

Precisión medida, porque la primera redacción decía «ningún camino» a secas y eso es falso: siguen borrando
filas `Split*` sin firmar `GroupZoneCacheGate.deleteCache`, `GroupService.cascadeDeleteGroupData`,
`GroupExpenseService` y `SplitGroupDeduplicationService`. Ninguno es un agujero —el primero solo actúa sobre
zonas `.cloudKitZone`, que por construcción no están en `backendGroupZoneIDs`; el segundo borra el
`SplitGroup` primero, así que la zona sale del set antes de que el drain mire; los otros dos SON el borrado
del usuario, que debe viajar— pero la frase servía de mapa y estaba mal.

El «Empiezo de cero» hereda la firma y **cambia de comportamiento**: hasta hoy sus deletes eran traducibles
a tombstones de los grupos del humano ANTERIOR. Lo que NO cambia es su cursor: en una frontera de USUARIO el
par correcto es «outbox muerto + cursor vivo ENTERO» (regla L188), y ahí no se toca.

### D4 · Riesgos descartados por medición

- Firmar con `GroupsSyncOutbox` **no** ciega al canal PERSONAL: su autor de eco es `"CloudSyncOutbox"`
  (`CloudSyncEngine.swift:1071`), distinto, así que sigue capturando lo que le toca.
- El borrado normal de UN gasto de grupo desde la UI **no** pasa por `deleteLocalGroupsRows` (esa función
  borra las 5 entidades enteras), así que la firma no silencia ningún borrado que deba viajar.
- Conservar la fila del cursor no cambia a ningún lector: `pulledGroupIDs` devuelve vacío igual (fail-closed)
  y el suelo del corte de History se vuelve más conservador, no menos.
