---
id: groups-account-association-in-storage-row
status: done
priority: high
area: "settings, groups, modo-nube"
created: 2026-09-09
updated: 2026-09-16
source: "ADR 2026-09-09 «Sesiones — dos ejes» §4"
qa-status: absorbed
qa-date: 2026-09-16
qa-notes: Absorbido por device-qa-groups-account-association - recorridos 1 a 7 cubren AC1 a AC6 y el bloqueo. El AC de migrar vive en settings-migrate-to-cloud-adopts-silently-instead-of-migrating
---

# Asociar, ver y desasociar la cuenta de grupos de una sesión privada, en «¿Dónde viven tus datos?»

## Lo que Jürgen quiere (ADR §4)

Un usuario con sesión privada (iCloud) puede **asociar UNA cuenta en la nube para grupos** y
desasociarla cuando quiera. Si su cuenta personal es en la nube, grupos es esa misma cuenta y no se
cambia. La asociación **se ve, se deshace y se rehace** en la fila «¿Dónde viven tus datos?» de
Ajustes, con un copy que diga exactamente qué pasa con los grupos y con los gastos que el bridge metió
en Panel.

## Lo medido (2026-09-09, árbol `3a94604e`)

- Hay UNA sesión nube por dispositivo (`CloudAuthService.shared`) compartida por personal-nube y grupos:
  «una cuenta a la vez» ya es verdad por construcción. Lo que no existe es el **gesto** ni el
  **estado** «asociada a esta sesión privada».
- La fila «Dónde viven tus datos» (`StorageSettingsView.swift`, gate `StorageRowGateLogic.isVisible`,
  `Yala/App/Logic/StorageRowGateLogic.swift:60`) hoy solo habla del almacenamiento personal (iCloud /
  nube, migrar, revertir, estado del sync).
- El sign-in de grupos entra por la pestaña Grupos (`GroupsSignInView`) y no se presenta como
  asociación; el cierre es «Cerrar sesión de grupos» en Ajustes.
- Las filas puenteadas llevan `TransactionItem.splitExpenseID`; `GroupTransactionBridge.unbridgeDeletedRemotely`
  (`GroupsSyncClient.swift:2066`) las borra cuando el gasto de grupo deja de existir en el backend.

## Decisiones tomadas en la conversación (Frank propuso, Jürgen no objetó; se ratifican con el PR)

- **Desasociar:** los grupos **se van con la cuenta** (el store local es caché de la cuenta). Las filas
  puenteadas en Panel **se quedan como movimientos personales normales** —es dinero que pasó—
  conservando su `splitExpenseID` **dormido**: re-asociar la MISMA cuenta re-enlaza en vez de duplicar;
  asociar OTRA cuenta no las toca. Borrarlas dejaría agujeros en los totales de meses cerrados.
- **Asociar una cuenta que ya es completa:** se bloquea (ticket `cloud-sign-in-discovers-account-kind`,
  fila «privada + asociar»).

## Alcance

1. **Estado:** «cuenta de grupos asociada» = hash del `sub` + proveedor + `kind`, escrito al completar
   [G] o al entrar con una `groups_only` existente desde una sesión privada, y borrado al desasociar. Es la
   señal que `session-exits-one-verb-per-session` usa para «equipo». **Viaja con la sesión privada**: se
   persiste en el iCloud-KV del Apple ID (por `OwnerKeyValueStore`, como el faro), no solo en
   `UserDefaults`, para que un segundo móvil o una restauración sepan que existe.
   **Tras «Restaurar desde iCloud»** con asociación registrada, la app ofrece entrar con esa cuenta de
   grupos (la sesión no viaja; la asociación sí).
   **«Migrar a la nube» desde una sesión privada con asociada:** la cuenta que se promueve a `complete`
   es **esa**, nunca una segunda (ADR §4: si la personal es nube, grupos es la misma cuenta).
2. **UI en «¿Dónde viven tus datos?»:** sección «Grupos» con tres estados: *sin cuenta* («Asociar una
   cuenta para grupos» → [I] → [G]), *asociada* (proveedor + nombre, «Desasociar»), y para sesión nube
   completa: «Tus grupos usan esta misma cuenta» sin acción.
3. **Desasociar:** confirmación con copy de alcance (grupos: se van de este móvil, siguen en tu cuenta;
   Panel: tus movimientos se quedan) → `pushAll` de grupos → cerrar sesión nube → vaciar `YalaGroups` →
   dejar las filas puenteadas con el enlace dormido (hoy `unbridge*` las borra: hace falta un camino
   nuevo «detach sin borrar»).
4. **Re-asociar:** [I] → si el `sub` coincide con el enlace dormido, el bridge reconcilia por
   `splitExpenseID` (sin duplicar); si es otra cuenta, las filas dormidas no se tocan y el bridge
   arranca de cero.
5. Grupos desde su pestaña sin cuenta: el CTA lleva al mismo [I] → [G] y escribe la asociación.

## Criterios de aceptación

- [ ] Sesión privada sin cuenta → asociar Google → [G] → la fila muestra la cuenta; los grupos aparecen.
- [ ] Desasociar con 3 gastos puenteados en Panel → los 3 siguen en Panel sin marca de grupo; los grupos
      desaparecen de la pestaña; la cuenta sigue viva en el backend.
- [ ] Re-asociar la misma cuenta → 0 duplicados, los 3 vuelven a estar enlazados a su gasto de grupo.
- [ ] Asociar otra cuenta → los 3 quedan como estaban; los grupos nuevos llegan limpios.
- [ ] Sesión nube completa → la sección informa y no ofrece desasociar.
- [ ] Segundo móvil del mismo Apple ID → «Restaurar desde iCloud» → tras restaurar, ofrece entrar con la
      cuenta de grupos asociada; al entrar, los grupos aparecen y el bridge re-enlaza sin duplicar.
- [ ] «Migrar a la nube» desde D → la asociada pasa a `complete` (backend), sin segunda cuenta.
- [ ] Tests: lógica de reconciliación por `splitExpenseID` (unit, con fixture que tenga filas dormidas
      y vivas); XCUITest de la fila en sus tres estados.

## Depende de

`cloud-sign-in-discovers-account-kind` · `backend-account-kind-complete-or-groups-only`.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba**, incluido el
bloque «Frank propuso, Jürgen no objetó», que queda **ratificado con matices**: lo que sigue es lo que
Jürgen contestó cuando se le preguntó de frente.

- **Al desasociar se le PREGUNTA qué hacer con las filas puenteadas del Panel.** La confirmación ofrece
  **conservarlas** (como movimientos personales normales, con el `splitExpenseID` **dormido** para poder
  re-enlazar si vuelve la misma cuenta) o **quitarlas**. O sea: **dos comportamientos**, los dos
  implementados y los dos probados. El «se quedan siempre» del bloque anterior **no** es lo decidido.
  El camino «detach sin borrar» sigue haciendo falta, y el de borrado es el `unbridge*` de hoy.
- **Se guarda la IDENTIDAD COMPLETA de la cuenta asociada** (correo tal cual, además de proveedor y
  `kind`), no un hash. La fila tiene que ser inequívoca cuando el usuario tiene varias cuentas. Queda
  sabido que eso es identidad legible en el iCloud-KV del Apple ID; el alcance §1 («hash del `sub`»)
  queda **derogado** en esa parte.
- **Desasociar con deudas pendientes: se permite y no se menciona.** Desasociar no borra el grupo ni
  salda nada, así que no hay aviso especial ni bloqueo. Copy sin caso particular.
- **Para cambiar de cuenta hay que desasociar primero.** Mientras haya una asociada, la fila solo ofrece
  «Desasociar»; no existe un «Cambiar cuenta» que haga las dos cosas de un gesto.


---

## Estado (2026-09-11) — implementado, a la espera del device-QA

En `2.1` por el PR del paso 10. Lo que hace hoy, en lenguaje de usuario: **en Ajustes → «¿Dónde viven tus
datos?» aparece una sección «Grupos»** que dice qué cuenta usa este iPhone para los grupos, deja asociar
una si no hay, y deja soltarla — preguntando antes qué pasa con los gastos de grupo que ya están en el
Panel, que es lo que Jürgen decidió el 2026-09-09.

### Lo que cambió respecto al alcance escrito arriba, y por qué

**El enlace «dormido» no es el `splitExpenseID` de la fila.** Medido: dejar ese puntero puesto con las
filas del grupo ya borradas deja el movimiento **atrapado** —`NewTransactionView.resolveBridgedPointer`
calcula que sigue siendo de grupo, así que Borrar y Duplicar quedan deshabilitados sobre un gasto que ya
no existe— y ni el barrido de huérfanas puede repararlo después, porque exige un veredicto de zona que se
construye de filas vivas. Es el mismo bug que `LegacyGroupsRetirement` documenta.

Y el ancla que haría falta para devolverlo **no existe**: `TransactionItem` no tiene identidad propia
serializable (`syncID` es opcional y en sesión privada es `nil`). El campo nuevo que la daría cuesta un
deploy de schema a CloudKit Production del container personal.

⇒ Al conservar, los tres punteros se liberan (molde del barredor) y lo que se guarda es el **conjunto de
gastos conservados, sellado con el `sub` de la cuenta**. Con eso, re-asociar la misma cuenta **no
duplica** —que es lo que el AC persigue— y asociar otra no toca nada. **Lo que no vuelve es el ENLACE**, y
está declarado en `groups-reassociation-does-not-restore-the-bridge-link`.

### Criterios de aceptación

- [x] Sesión privada sin cuenta → la sección ofrece asociar; el CTA lleva al sign-in de Grupos y al alta.
      *(XCUITest `GroupsAssociationRowUITests`; el recorrido con cuenta real, device-QA 1.)*
- [x] Desasociar con gastos puenteados → **se pregunta**, y las dos salidas están implementadas y
      probadas: conservar los gastos que pagó el usuario (liberando los punteros, así que vuelven a ser
      editables y borrables) o quitarlo todo. *(unit `GroupsAssociationDetachSweepTests`; device-QA 2.)*
- [x] Re-asociar la misma cuenta → **0 duplicados**. *(unit `GroupsDetachedBridgeLedgerTests` + el guard
      del puente; device-QA 3.)* El re-ENLACE queda en su ticket.
- [x] Asociar otra cuenta → las conservadas no se tocan; sus grupos llegan limpios. *(el sello por `sub`.)*
- [x] Sesión nube completa → informa y no ofrece desasociar. *(tabla + XCUITest de la celda F.)*
- [x] Segundo móvil del mismo Apple ID → la asociación viaja por el iCloud-KV y la fila ofrece entrar con
      esa cuenta; el empty state de Grupos dice «vuelve a tu cuenta» y no «crea una».
      *(unit; el recorrido real, device-QA 5.)*
- [ ] «Migrar a la nube» desde D → la asociada pasa a `complete`. **Este paso entrega el DATO**
      (`isAssociatedGroupsAccount` ya se sirve desde la puerta de Grupos); el cableado de esa puerta es
      `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`, ticket propio por decisión del
      paso 3 y así lo dice la celda «C · migrar» de la matriz.
- [x] Tests: unit de la tabla, del registro, del registrador, del des-puenteo y del libro (**73 casos en
      10 suites**), XCUITest de la fila en tres celdas, y **20 mutantes, 20 muertos**.

### Lo que la review adversarial cambió (tres lentes + la rule de área)

Doce defectos míos, todos corregidos. Los que cambiaban el producto:

1. **Desasociar no era durable.** El otro dispositivo del Apple ID con sesión viva reponía la asociación
   en su siguiente arranque y la desasociación se deshacía sola. Ahora `clear()` deja un **tombstone** en
   el iCloud-KV y el registrador lo respeta.
2. **El puente se soltaba antes de que la asociación estuviera escrita.** La escritura vivía en el
   `onDismiss` del sheet, y `startIfEligible` arranca el canal en el acto: si el primer pull ganaba la
   carrera, cada gasto conservado se duplicaba. La escritura se movió al callback del sign-in.
3. **`.remove` se llevaba por delante puentes de grupos de la era CloudKit**, que no son de la cuenta que
   se suelta — dinero real, en un store sin mirror que lo reponga. Ahora el barrido solo toca zonas del
   canal backend (ANY-row, la primitiva compartida).
4. **El aviso de bloqueo era el del cierre de sesión**, presentado desde la pantalla de debajo, y el
   segundo toque de «Desasociar» quedaba mudo para siempre. La sección tiene ahora su propio aviso, que
   suelta la fase al cerrarse.
5. **El CTA de asociar apostaba a un `sleep` de 350 ms.** El flag que enciende es blocker de la matriz de
   readiness: una presentación que no monta dejaba el router muerto el resto de la sesión. Ahora el
   intent va por el router sin espera, que es quien retiene la cola.
6. **Borrar `GroupBridgePreference` se exportaba a iCloud** (vive en el schema personal) y se la quitaba
   al usuario en su iPad. El desasociar ya no la toca.
7. **La sección desaparecía en `.failed` y `.waitingForLeader`**, que son estados DURABLES: quien dejaba
   una migración fallida para más adelante se quedaba sin poder desasociar.
8. **En sesión secundaria la invitada escribía su correo en la asociación del dueño.** Guard de
   secundaria en el registrador, el mismo que ya tienen sus vecinos del dominio.
9. **El sello del handover cerraba la lectura del iCloud-KV pero no la escritura**, así que el humano
   nuevo metía su correo en la cuenta de iCloud del anterior.

Y cuatro tickets que la review abrió y no entran aquí: `detach-history-replay-can-tombstone-groups-on-next-launch`
(**high**), `cloud-killswitch-hides-the-only-door-to-detach-groups` (**high**),
`groups-detach-ledger-has-no-exit`, `detach-saves-the-personal-graph-outside-the-quiescence-window` y
`detach-does-not-verify-the-cloud-session-actually-closed`.

### Lo que falta

**Device-QA con CloudKit y backend reales** — guion en `tickets/qa/device-qa-groups-account-association.md`.
No es simulable: el simulador no tiene sesión de nube, y el recorrido 5 necesita dos dispositivos.

## QA · 2026-09-16 — cerrado como absorbido

Todo lo pendiente está dentro de los recorridos de `device-qa-groups-account-association`, que sigue en la
cola de device: AC1 → recorrido 1 · AC2 → 2 · AC3 → 3 · AC4 → 4 · AC5 → 6 · AC6 y el tombstone → 5 · el aviso
propio → 7. El criterio sin marcar de «Migrar a la nube» vive en
`settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (backlog), y el guion lo excluye a propósito.

Parte de este ticket ya se vio hoy en simulador, con seams: la fila con «Desasociar» y sin «Migrar a la
nube» bajo el kill-switch (`cloud-killswitch-hides-the-only-door-to-detach-groups`, PASS).
