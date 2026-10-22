---
id: groups-owner-transfer-and-leave
status: done
priority: high
area: groups
created: 2026-09-06
updated: 2026-09-23
source: decisión de Jürgen del 2026-09-06 sobre tickets/qa/groups-leave-rpc-error-10.md
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - pide otro miembro activo con su cuenta, dos telefonos
---

# El dueño de un grupo con deuda puede transferirlo y salir

## Qué le pasa al usuario

Soy el dueño de un grupo y quiero irme. «Salir» no está (soy el dueño) y «Eliminar grupo» está
deshabilitado porque hay deuda pendiente — aunque la deuda sea entre otras dos personas y no mía. Me
quedo dentro sin salida y con un aviso que me pide liquidar deudas que no son mías.

## Decisión Jürgen (2026-09-06)

**Ofrecer «Transferir y salir».** Elegida entre: (a) transferir y salir, (b) permitir eliminar con
deuda como ya se permite salir con deuda, (c) dejarlo. Motivo, tal como se le puso delante y ratificó: el RPC de transferencia **ya existe en el
servidor**, falta solo la hoja en iOS, y el grupo con sus deudas sigue vivo para los demás. Descartó (b)
porque borra deudas de terceros y es irreversible. **«Eliminar» sigue bloqueado con deuda.**

## Punto de partida (del ticket padre, NO re-medido aquí — greppear antes)

- El servidor rechaza la salida del dueño con `yala_owner_cannot_leave` (`leave_group` en
  `supabase-groups-staging.ddl`); el RPC de transferencia de propiedad existe según
  `groups-leave-rpc-error-10` («el RPC ya existe, falta UI»). **Confirmar nombre y contrato del RPC
  en el DDL de prod antes de escribir la hoja.**
- `SplitGroup.isOwner` es device-local y solo lo escribe el creador; la pantalla ya dejó de decidir con
  ese flag (arreglo del padre). La nueva acción debe usar la misma fuente de verdad server-side.
- El bloqueo de «Eliminar» mira la deuda de todo el grupo (medido en el padre). No cambia con esta
  decisión, pero el copy que acompaña al bloqueo no debe decirle al dueño que liquide deudas ajenas:
  debe ofrecerle la transferencia.

## Criterio de hecho (AC)

- [x] En la pantalla del grupo, el dueño ve «Transferir y salir» cuando hay al menos otro miembro
      **activo** ~~; elige a quién y confirma~~ **y confirma, con el nombre del heredero delante**.
      Tras el RPC, él ya no es miembro y el elegido es el dueño (para todos, tras el pull).
      ⚠️ **«Elige a quién» era una premisa falsa del ticket — ver «Lo que se midió» abajo.**
- [x] Con deuda pendiente, «Eliminar» sigue deshabilitado y el aviso ofrece la transferencia en vez
      de pedirle liquidar deudas de otros.
- [x] Si es el único miembro activo, no se ofrece transferir: se ofrece eliminar (ya existe).
- [x] Cada error del RPC tiene copy propio (mismo contrato que el padre: nunca un número crudo).
- [x] Copy en 16 `.lproj`. Unit para la lógica pura de «qué acción se ofrece» (dueño/único/deuda).
- [x] **Review adversarial** (toca membresías y sync) — tres lentes independientes.
- [ ] **device-QA con dos teléfonos** sobre una subida posterior. **Es lo único que queda.**

## Relacionados

- [[groups-leave-rpc-error-10]] — el padre, en `qa/`; ahí está la medición del `10` y del `isOwner`.

---

## Lo que se midió (2026-09-06)

### El RPC no acepta heredero: «elige a quién» era una premisa falsa del ticket

Medido **contra producción**, no contra el árbol: `transfer_group_ownership(p_group_id text) → jsonb`,
`md5(pg_get_functiondef)` = `dd3a049c793f6fe2479552ac0c7fba3f` — **idéntico** al que el DDL del árbol
declara para sí mismo, así que el molde offline no miente. **Toma un solo parámetro.** El heredero lo
elige el servidor:

```sql
order by (coalesce(role,'') = 'admin') desc, joined_at asc, member_key asc limit 1
```

⇒ **la app no puede ofrecer un selector.** El AC decía «elige a quién» porque el ticket padre anotó
«el RPC ya existe, falta UI» sin comprobar su firma. Se implementa lo que la decisión de Jürgen dice
—«Transferir y salir», con el motivo que ratificó: *el RPC ya existe en el servidor y solo falta la
hoja en iOS*— y **la hoja NOMBRA al heredero antes de confirmar**, replicando el `order by` verbatim
(`GroupOwnerExitLogic.designatedHeir`). La alternativa —añadir `p_new_owner_member_key` al RPC y
migrar producción— contradice el motivo por el que eligió esta salida, así que no se toma sin él.

**Si Jürgen quiere el selector, es trabajo de servidor y va aparte.** No bloquea lo entregado.

### Por qué no se reusó `GroupBatchLeaveLogic`

Su primera línea es `if facts.hasOutstandingDebt { return .skipHasDebt }` — correcto para el batch
«salir de todos mis grupos», que solo se ofrece con cero deudas, y **exactamente lo contrario** de lo
decidido aquí: en Ajustes la deuda es la razón por la que hay que ofrecer la transferencia.

## Lo que la review adversarial cazó, y era mío

Tres lentes independientes (lógica pura · vista · sync). Ninguno de estos se ve en un grep, y el peor
lo introducía yo al exponer la acción:

- **El ex-dueño podía borrarle el grupo al dueño recién coronado.** `transfer_group_ownership` **no
  degrada al caller** (sigue `role='admin'`) y la RLS de `split_groups` exige `is_group_admin`, no
  ownership. Si el `leave` posterior fallaba, la pantalla seguía viva con `isOwner` local en `true`
  ⇒ «Eliminar grupo» habilitado ⇒ **la escritura aterrizaba en el servidor**. Rompía el invariante que
  el propio RPC protege por escrito («nunca destruir datos de terceros»). Fix: `releaseLocalOwnership`
  baja el flag **en cuanto el transfer devuelve OK**, no al final. No encierra a nadie: sin `isOwner`
  la pantalla ofrece «Salir», que es justo lo que el servidor ya le permite.
- **El heredero podía ser YO MISMO.** El servidor descarta candidatos con `user_id <> auth.uid()` —todas
  mis filas—; el cliente usaba `resolveCurrentUserMember`, que **colapsa a una** (`min(by: joinedAt)`).
  En una zona migrada el mismo humano tiene dos filas, y la otra —con `role = "admin"`— ganaba el primer
  nivel del orden: la hoja proponía transferirme el grupo a mí. Fix: `resolveAllCurrentUserMembers`.
- **El rechazo del servidor no se auto-curaba: bucle cerrado.** `no_eligible_owner` no toca ninguna fila
  local, así que el recálculo devolvía el offer idéntico y volvía a nombrar al mismo heredero fantasma.
  Confirmar → error → mismo botón → mismo nombre, indefinidamente, con «Eliminar» en gris. Mi comentario
  afirmaba que «el botón desaparece solo»; medido, no lo hacía. Fix: `serverRefusedTransfer`.
- **Copy circular, alcanzable sin ninguna carrera.** Dueño server-side con `isOwner` local en `false` →
  toca «Salir» → el servidor lo rechaza → se reconcilia y la pantalla se repinta como dueño → el alert
  dice «puedes eliminarlo» mientras «Eliminar», en gris, dice «transfiérelo y sal». Los dos mensajes se
  remitían el uno al otro. Fix: `ownerCannotLeaveCanTransfer`.
- **Era la única salida que no avisaba de la deuda propia.** «Salir» y «Archivar» avisan; ésta callaba,
  y encima borra el histórico local del grupo — el usuario perdía de vista quién le debía sin leerlo en
  ningún momento. Fix: párrafo aparte en la confirmación.
- **Dos acciones destructivas a la vez.** «Eliminar» no estaba gateado por `isTransferring` ni al revés.
- **Regresión mía en `toggleArchive`**: se quedó llamando a `recomputeOutstandingDebt`, así que desde que
  «Eliminar» lee el offer, su botón dejaba de reaccionar.
- **`isAdmin` metía un bit que no viaja por el wire** (`isGroupOwner`, device-local) en el primer nivel
  del espejo. Ahora es `role == "admin"`, como el servidor.
- **Mis tests no cazaban el mutante que borra `joined_at asc`** — la lente lo compiló y ejecutó: los 6
  casos del heredero pasaban en verde porque el orden alfabético coincidía con el temporal. Corregidos
  a contrapelo.

También refutó dos cosas: `min(by:)` **sí** replica `ORDER BY … LIMIT 1` (el comparador es un orden
estricto débil válido), y el descarte por `memberKey == nil` es un no-op protector, no un filtro que
pueda esconder un heredero real.

## Diferido, con su motivo

- **El hueco de producto que queda, y necesita a Jürgen** → ticket propio
  [[groups-owner-debt-no-heir-dead-end]]. Dueño **con deuda y SIN heredero** (único miembro activo,
  canal CloudKit, o co-members sin cuenta) sigue sin ninguna salida: no puede salir, no puede transferir
  y no puede eliminar. Su decisión del 6-sep no cubre esa celda —descartó «permitir eliminar con
  deuda»—, así que no se inventa aquí. El hint lo NARRA con honestidad, pero no lo resuelve.
- **La secuencia transfer → leave → cleanup no es atómica desde Ajustes** → [[groups-transfer-leave-write-ahead]].
  El batch la protege con write-ahead de fase y resume; la pantalla no persiste nada. Es recuperable
  (el RPC es idempotente-suave y reintentar funciona), pero depende de que el usuario vuelva a entrar.
- **`batchFacts` tiene el mismo patrón singular que se arregló aquí** → [[groups-batch-facts-plural-identity]].
  No se toca en este ticket: es otro objeto y otra superficie.
- **`joinedAt` local está truncado a milisegundo** (`WireValueDecoder.millisFromISO` hace floor) mientras
  el servidor ordena por `timestamptz` completo. Dos altas en el mismo milisegundo pero en transacciones
  distintas podrían dar nombres distintos. Los tres escritores usan `now()` (timestamp de transacción),
  así que un import en lote empata EXACTO en ambos lados. Ventana estrecha, no cerrada.
- **`member_key asc` es collation de Postgres; `<` de Swift es orden de escalares.** No se consiguió
  construir un par alcanzable que divergiera (los `member_key` son UUID en minúscula o recordName de
  CloudKit). Anotado, no medido como bug.
- **Matiz del AC «el elegido es el dueño para todos, tras el pull» — medido, y no se cumple entero
  en la UI del heredero.** El manifest del canal (`group_capability_manifest.json`) lleva para
  `split_groups` once columnas y **`owner_user_id` NO es una de ellas** (es server-only,
  `gateway/src/groups/routes.ts:51-56`). Lo que sí viaja en `group_members` es `role`. ⇒ el heredero:
  - **gana de verdad los permisos** (server-side es el dueño, y por el pull le llega `role='admin'`,
    así que puede renombrar, archivar e invitar);
  - pero su `SplitGroup.isOwner` local **sigue en `false`**, porque el pull no escribe ese flag, así
    que **«Eliminar grupo» no le aparece** hasta que intente salir y el servidor le conteste
    `yala_owner_cannot_leave` — ahí `reconcileServerSideOwnership` lo corrige y la opción sale.
  No es una regresión de este ticket: es el latch de una dirección que el padre ya dejó anotado, y
  cerrarlo exige llevar el ownership al wire. Se dice aquí porque el AC prometía más de lo que el
  canal puede dar hoy, y el device-QA lo va a ver.

- **`already: true` no prueba «yo era el dueño y ya no»**: `transfer_group_ownership` filtra por
  `deleted = false` y `leave_group` no. Hoy inalcanzable (ningún camino del cliente emite el tombstone
  de meta), pero el `catch` de un solo caso es frágil si eso cambia.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Pide otro miembro activo con su propia cuenta, o sea dos teléfonos. La lógica la cubren los tests de `GroupOwnerExitLogic`.
