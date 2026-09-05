---
id: group-joiner-flag-consumers-still-narrow
status: backlog
priority: high
area: groups
created: 2026-09-04
source: residual medido al alinear la identidad de miembro (5ca4dd47) — review adversarial de la misma sesión
---

# Al recién llegado a un grupo se le reconoce en pantalla, pero su gasto no llega a su cuenta

## El síntoma, en lenguaje de usuario

Me uno a un grupo por un enlace y la app ya me reconoce: veo el aviso de que espero aprobación y,
si me rechazan, puedo salirme. Eso se arregló el 2026-09-04.

Pero si apunto un gasto del grupo en ese rato, **no aparece en mis cuentas personales**. Aparece
más tarde, después de cerrar y volver a abrir la app — y cuando aparece, va a la cuenta genérica
«Grupos», no a la cuenta real que elegí en el formulario. Además, «Pagado por» abre en blanco en
vez de venir puesto en mí, y el saldo de la tarjeta del grupo me sale vacío.

## Por qué pasa

`5ca4dd47` alineó CINCO resolvedores de identidad con el canónico
`GroupExpenseService.selectCurrentUserMember`. Los demás consumidores del flag `isCurrentUser`
siguen estrechos, y el flag no se enciende hasta el arranque siguiente
(`GroupsSyncClient.applyMember` nunca lo escribe; el único call-site de producción de
`refreshCurrentUserFlags` está en `AppBootstrapper:526`).

Medido por la review adversarial de esa sesión, con su fichero:línea:

| Consumidor | Qué se rompe |
|---|---|
| `GroupTransactionBridge:193` y `:1048` | El puente a la transacción personal no encuentra mi member ⇒ el gasto no se refleja. Vuelve por el pull y lo repesca `GroupsPendingBridgeResume` en un arranque posterior, pero corre con `accountForCurrentUser: nil` ⇒ **cae en la cuenta virtual «Grupos»** y se pierde la cuenta real elegida |
| `GroupExpenseViewModel:155` y `:270` | «Pagado por» no viene prefijado, y elegirme a mí no enciende `isCaseA` ⇒ no se ofrece mi cuenta |
| `GroupsViewModel:258`, `:305`, `:176` | El balance de la tarjeta sale vacío y no cuento en el resumen global, mientras `currentMemberStatus` (ya alineado, `:438`) sí me reconoce ⇒ la misma tarjeta se contradice |
| `GroupsExportBuilder:174` | El CSV no marca cuál soy yo |
| `ScheduledPaymentDraftService:198` | El borrador de pago programado no me resuelve |
| `GroupService:786` (`batchHasOutstandingDebt`), `:926`, `:1279` (`eligibleGroupsForExpense`) | El grupo puede no aparecer al convertir un borrador del Inbox |

**No es una regresión**: antes tampoco funcionaban. Lo que cambia es que ahora la app *dice* que me
reconoce, así que la incoherencia se ve.

## Riesgo conocido de la vía fácil

La tentación es dar a `refreshCurrentUserFlags` un segundo call-site tras el pull, y arreglar los
trece de golpe. **La review lo señaló como el vector de mayor daño de toda la tanda:** es
device-wide (`GroupService:973` no acepta zona), hace fetch de TODOS los grupos y members, `save()`
e `incrementDataVersion` dentro del camino de sync, y arrastra el backfill heurístico de
`:1046-1085`, que adjudica `cloudKitUserRecordID` por coincidencia de `displayName` o por «único
admin / joinedAt más antiguo». Dos members con el mismo nombre visible en un grupo legacy y la
adjudicación es a otra persona.

⇒ si se toma esa vía, va con guard de zona y después del save, no dentro.

## Qué hacer

1. Decidir la vía: alinear consumidor a consumidor con `resolveCurrentUserMember` (seguro, tedioso)
   o el segundo call-site del refresh (una línea, con el riesgo de arriba).
2. Empezar por el **bridge** (`GroupTransactionBridge:193`), que es el único con consecuencia sobre
   el dinero del usuario: los demás son cosméticos o de prefill.
3. La red existe: `YalaTests/GroupIdentityResolutionAlignmentTests.swift` pinnea el criterio y
   `GroupMembersAdminUITests` + el perfil de seed `grupos-sin-flag` permiten ejercitar el estado sin
   flag desde XCUITest.

## No medido

- Si el gateway enmascara `user_id` en la propia fila mientras está `pendingApproval`. Si lo
  hiciera, la rama por `sub` no resolvería justo en el caso del recién llegado, y cualquier arreglo
  por esa vía se cerraría en falso. Se comprueba contra el servidor, no contra el repo.

---

## CONSUMIDOR Nº 14, no listado · medido el 2026-09-04

Investigando `groups-equal-split-shows-not-participating-on-peer` apareció un consumidor estrecho
que **no está en la tabla de trece de este ticket** (verificado: `grep -c GroupNotificationService`
sobre este fichero → 0):

**`Yala/Services/Groups/GroupNotificationService.swift:234`** resuelve el miembro propio con el flag
PELADO dentro de un `#Predicate`:

```swift
predicate: #Predicate { $0.groupZoneID == zoneName && $0.isCurrentUser == true }
```

y `Yala/App/Logic/GroupNotificationRecipientLogic.swift:67` abre con
`guard let me = currentMemberID else { return .skip }`.

⇒ **Sin identidad resuelta, las notificaciones de grupo se suprimen enteras.** No fallan ruidosamente:
se descartan con un `.skip` conservador, que es exactamente el modo de fallo más difícil de notar.

**Por qué importa más de lo que parece:** este consumidor da la corroboración independiente de la
causa del otro ticket. En la observación de device del 2026-08-28, B vio «No participaste» **y
además no recibió ningún aviso**. El owner separó las dos cosas («no es el problema de este
ticket»), y resultan ser **el mismo problema por dos rutas de código que no se llaman entre sí**: la
caption y la notificación cuelgan las dos de la identidad local, y las dos fallaron a la vez.

Su docblock (`:226`) dice «`isCurrentUser` is refreshed by `refreshCurrentUserFlags` (awaited) right
before this runs». Esa premisa es la que hay que comprobar al alinearlo: si el refresh se saltó
—`AppBootstrapper:521-524` lo salta entero cuando el import no está quiescente— el predicado no
encuentra a nadie y el aviso no sale.

**Al alinearlo, ojo con el `#Predicate`:** `resolveCurrentUserMember` no es traducible a SwiftData
tal cual (lee estado de sesión y de iCloud), así que aquí no vale sustituir la línea. Hay que traer
los members y resolver en memoria, o resolver el id ANTES y meterlo en el predicado como valor.
