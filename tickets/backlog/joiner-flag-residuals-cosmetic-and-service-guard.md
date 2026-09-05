---
id: joiner-flag-residuals-cosmetic-and-service-guard
status: backlog
priority: low
area: groups
created: 2026-09-05
source: residual medido al cerrar group-joiner-flag-consumers-still-narrow
---

# Al recién llegado a un grupo no se le marca «(tú)», y la red del servidor que impide auto-expulsarse no lo reconoce

## El síntoma, en lenguaje de usuario

Me uno a un grupo por enlace. Ya me llega todo el dinero a mis cuentas y ya recibo los avisos —eso
se arregló—, pero **en la lista de miembros mi nombre no lleva la marca de «yo»** hasta que cierro y
vuelvo a abrir la app. Lo mismo al repartir un gasto y al elegir quién pagó. Y si comparto el enlace
del grupo, la vista previa muestra mi nombre a secas en vez del nombre de quien invita.

## Qué queda estrecho, medido el 2026-09-05

`group-joiner-flag-consumers-still-narrow` alineó los catorce consumidores con consecuencia. Estos
cinco siguen leyendo `SplitMember.isCurrentUser` a pelo, que el pull nunca enciende:

| Consumidor | Qué se ve mal |
|---|---|
| `GroupMemberRow` (badge «(tú)») | Mi fila no se marca en la lista de miembros |
| `GroupSplitSelectorView` | Ni al repartir el gasto |
| `MemberPickerView` | Ni al elegir quién pagó |
| `InviteLinkService` (×2, la preview del enlace) | La vista previa del enlace que comparto pone mi `displayName` en vez del nombre de quien invita |
| `GroupService.removeMember` (`guard !member.isCurrentUser` → `cannotRemoveSelf`) | La red de servidor que impide echarte de tu propio grupo no te reconoce |

**Los cuatro primeros son cosméticos** y por eso esto es `low`: nada se pierde, nada se calcula mal.

**El quinto no es cosmético, pero hoy es inalcanzable.** `GroupMembersView` ya calcula `isSelf` como
la UNIÓN del flag y la identidad resuelta (`member.isCurrentUser || member.id.uuidString ==
viewModel.currentMemberID`), así que la UI no ofrece «quitar» sobre la fila propia del recién
llegado. El guard de `GroupService` es la RED por debajo — y una red que no reconoce al usuario deja
de ser red. Si algún día otra superficie llama a `removeMember` sin pasar por esa vista, se podría
auto-expulsar. Vale la pena alinearlo aunque hoy no se pueda disparar.

## Por qué NO se hizo junto con el resto

Alcance. El ticket padre pedía los consumidores con consecuencia sobre el dinero, el saldo y los
avisos, y ampliarlo a los badges habría mezclado un arreglo de dinero con polish visual en el mismo
PR. Se documenta aquí en vez de dejarlo sin escribir.

## Ojo al alinearlos

**El patrón `flag || resuelto` de `GroupMembersView` es deliberado, no un despiste.** Una zona
MIGRADA puede tener DOS filas del mismo humano con el flag puesto, y el resolvedor canónico devuelve
UNA (la de `min(joinedAt)`): comparar solo contra ella dejaría la otra fila propia con «quitar» y
«cambiar rol» a la vista. Al alinear los badges, usar la unión, no la sustitución.

Por ese mismo motivo el escáner de `GroupJoinerIdentityConsumerTests` no cubre las vistas: prohibiría
un patrón que ahí es correcto.
