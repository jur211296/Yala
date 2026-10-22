---
id: joiner-flag-residuals-cosmetic-and-service-guard
status: backlog
priority: low
area: groups
created: 2026-09-05
updated: 2026-10-08
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

## Y un tercero, que sí se intentó y se DESHIZO · 2026-09-05

**`AppBootstrapper`, el cleanup de «me expulsaron del grupo».** Se alineó con el resolvedor canónico y
la review adversarial de la misma sesión lo tumbó: la pregunta que ese guard hace es **por fila**
(«¿existe una fila mía expulsada?») y el resolvedor singular contesta otra («¿la fila canónica de la
zona está expulsada?»). En una zona con dos filas del mismo humano divergen, y aquí divergir cuesta
caro en las dos direcciones:

- canónica `active` + gemela `removed` ⇒ el cleanup legítimo deja de correr (lo que ya pasa hoy);
- canónica `removed` + gemela `active` ⇒ `performRemovedSelfCleanup` **borra el grupo** con sus
  gastos, shares y liquidaciones, y emite tombstones al backend. Sobre un grupo al que el usuario
  acaba de re-unirse.

Se revirtió al `#Predicate` original, con el motivo escrito junto a la línea y declarado en el
allowlist de `GroupJoinerIdentityConsumerTests`.

**Para alinearlo bien ya existe media pieza:** `GroupExpenseService.resolveAllCurrentUserMembers`
(la variante plural, creada el 5-sep para `updateCurrentUserDisplayName`) contesta la pregunta por
fila. Lo que falta es la otra mitad, y **es una decisión, no código**: qué hacer cuando una fila mía
está expulsada y otra activa. Borrar el grupo es irreversible; no borrarlo deja el grupo puesto. Esa
la toma Jürgen.

## Decisión Jürgen (2026-09-06)

**Manda la fila activa: no se borra nada.** Elegida entre eso y «manda la fila canónica de la zona».
Motivo, tal como se le puso delante y ratificó: borrar el grupo con sus gastos es irreversible y dejarlo puesto de más es un aviso. Regla: el
cleanup de «me expulsaron» corre **solo si ninguna fila mía en esa zona está `active`**; se contesta
con `resolveAllCurrentUserMembers` (la variante plural) y se fija por test el caso de las dos filas en
las dos direcciones. Con esto el tercer residual deja de esperar y se alinea junto con los dos badges.

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

## Medido en 2.1 (triage 2026-10-08)

- Siguen con el flag pelado: el badge de `GroupMemberRow`, `MemberPickerView`, las dos ramas de `InviteLinkService` y el guard `cannotRemoveSelf` de `GroupService.removeMember`.
- `GroupSplitSelectorView` ya no lee el flag. El reparto vive ahora en `GroupSplitEditorCard` (`96f214220`, 2026-10-04), cuyo `memberName` repite el mismo `if member.isCurrentUser` pelado.
- `AppBootstrapper` (bloque «Removed-self») sigue con el `#Predicate` original y el comentario que remite a este ticket: la decisión del 2026-09-06 («solo si ninguna fila mía está `active`», con `resolveAllCurrentUserMembers`) está tomada y sin implementar.

Triage 2026-10-08: abierto · low → low · `GroupMemberRow`, `GroupSplitEditorCard`, `MemberPickerView`, `InviteLinkService` (×2) y `GroupService.removeMember` siguen leyendo `isCurrentUser` a pelo, y el cleanup de expulsado de `AppBootstrapper` sigue sin la regla que Jürgen decidió el 2026-09-06.
