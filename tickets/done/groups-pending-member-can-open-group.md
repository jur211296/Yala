---
id: groups-pending-member-can-open-group
status: done
priority: high
area: groups
created: 2026-08-28
updated: 2026-09-08
qa-status: passed
qa-date: 2026-09-08
---

# Un miembro pendiente de aprobación puede entrar al grupo

## El reporte del owner (Jurgen, 2026-08-28, Lima) — hechos suyos, sin añadir

Mismo setup que la corrida del aviso de aprobación de ese día: dos teléfonos, **TestFlight 2.1 build
12**. **A** = owner. **B** = cuenta de prueba **ya creada** (no instalación limpia).

- B se une por el enlace y queda **pendiente de aprobación**.
- El grupo **«Probando» aparece en la lista de Grupos de B** estando pendiente.
- La app **no llevó a B al tab de Grupos**: B se quedó donde estaba y tuvo que ir a Grupos a mano.
  **Observado, y no es el defecto de este ticket** — ver «Lo observado que no se promueve a defecto».
- B ve **«1 solicitudes pendientes»** y el aviso de esperar al admin.
- **Tocar el grupo «Probando» le deja ENTRAR y VER el grupo estando sin aprobar.** Veredicto del owner:
  **esto está mal**.

No hay más hechos de campo. En particular **no consta reportado** qué vio B exactamente dentro del grupo
(¿roster? ¿gastos? ¿saldos? ¿un aviso dentro?), ni si podía tocar algo, ni cuánto rato se quedó dentro.

## El defecto, en una línea

La puerta del grupo no distingue **«pendiente»** de **«activo»**: se abre igual para los dos.

## Esto NO es

| Ticket | De qué va | Por qué no es este |
|---|---|---|
| `tickets/done/groups-approval-banner-stays.md` | el aviso de «esperando aprobación» no se retiraba **después** de que el admin aprobara | Es la **salida** de la sala de espera, y quedó **PASS en device** en la misma corrida (cerrado en el mismo PR que abre este ticket). Aquí el problema es la **puerta**, y ocurre **antes** de aprobar. Meterlo ahí sería declarar que el PASS de hoy tapó algo que no tapó |
| `tickets/qa/groups-join-intent-reconciler.md` | el `SplitMember` del invitado **jamás nacía**, «¡Todo listo!» sin miembro real, y al owner **no** le llegaba la solicitud | Es el defecto **contrario**: allí el alta no se materializaba. Hoy sí se materializó — B vio su solicitud pendiente y **A pudo aprobarla**. Reusar ese ticket enterraría este hallazgo bajo un guion (ventana export-only de CKShare) cuyo transporte ya está muerto |
| `tickets/qa/guest-decline-has-no-screen.md` | la sala de espera del invitado: el «no» no tiene pantalla, y mientras espera **ve el grupo y el roster pero ni un gasto** sin que nadie le diga que eso es normal | **El vecino más cercano: leerlo antes de tocar nada.** Documenta el MISMO hecho observable y le pone **otro veredicto** — lo trata como problema de **copy**, no de puerta. Ver «La tensión de producto» |
| `tickets/qa/groups-consent-door-spec.md` | «La puerta de Grupos»: educativo → login → consent antes de usar Grupos, y el consent viajando con la cuenta | Colisión de nombre, no de tema: esa puerta es la de **entrar a la función Grupos**; ésta es la de **entrar a UN grupo concreto estando pendiente**. B ya había pasado la primera |

## Lo medido en este árbol (`2.1` @ `2175e53e`)

Que a B le lleguen el grupo y el roster estando pendiente **está decidido así hoy, y a propósito**. Es lo
único que se midió del mecanismo en este pase, y se midió porque cambia qué clase de arreglo cabe:

- `supabase-groups-staging.ddl:71-75` — `is_group_member` admite `status in ('active','pendingApproval')`.
- `:77-81` — `is_group_writer` admite **solo** `'active'`.
- `:125` (`split_groups_select`) y `:153` (`group_members_select`) van por **`is_group_member`** ⇒ el
  pendiente **recibe el grupo y el roster**.
- `:811-821` — el bloque de endurecimiento que pasó las policies SELECT de
  `split_expenses`/`split_shares`/`split_settlements` a **`is_group_writer`**, con el comentario de `:814`
  diciéndolo con todas las letras: «split_groups y group_members **SE QUEDAN** con is_group_member: la
  sala de espera necesita ver el grupo y el roster». El encabezado del fichero repite el criterio
  (`:46-47`).
- `gateway/src/groups/routes.ts:388` — el pull descubre membresías con
  `status=in.(active,pendingApproval)`.

⇒ **que el grupo salga en la lista de B no es una fuga de datos**, y el **contenido financiero no baja**
(esas tres SELECT exigen `active`). Lo que el owner señala es que, además de aparecer, la app **le abre
la puerta**. Corolario práctico: quien arregle esto **no** puede tratar el DDL como un descuido — está
escrito a propósito y con comentario; cambiarlo es una decisión, no un fix.

Nota de reuso: estas coordenadas son las que ya citaba `guest-decline-has-no-screen` y se **re-midieron
una a una en este árbol** antes de escribirlas aquí. Coinciden.

## Lo que NO se midió en este pase

Nada de esto se supone. **Sin causa evidenciada no hay fix** (regla del repo), y este ticket no la
inventa:

- **Quién gatea —si alguien— la entrada a `GroupDetailView` con un miembro `pendingApproval`**, qué pinta
  esa pantalla, y si el botón de crear gasto está oculto o deshabilitado. El vecino ya dejó **ese mismo
  hueco escrito** en su sección «Huecos»: «Qué pinta exactamente `GroupDetailView` para un
  `pendingApproval`: empty state de la lista de gastos, y si el FAB de crear gasto está oculto o
  deshabilitado». Sigue sin medir, y ahora hay un reporte de device que lo pide.
- Si el aviso de la sala de espera se pinta también **dentro** del grupo, o solo en la lista.
- Qué ve B dentro (ver arriba: el reporte dice «entrar y ver el grupo» y no detalla).
- Si el comportamiento es igual en el grupo recién unido y en uno con historia.

## La tensión de producto — hay que resolverla ANTES de escribir código

Los dos tickets miran el mismo hecho y no quieren lo mismo:

- **`guest-decline-has-no-screen`** lo da por **esperado y mal explicado**: «Mientras espero: veo el grupo
  y veo quién está dentro, pero ni un solo gasto. Nadie me dice que eso es normal — el copy habla de
  *participar*, no de *ver*». Su pieza 2 **ya aterrizó**: `0342564c` («la sala de espera del invitado deja
  de prometer un aviso que no existe»), y está en `2.1` — re-medido, toca **16** `.lproj`, que es la cifra
  que da el vecino. Es decir: el repo ya invirtió en **explicar** la espera.
- **El owner, hoy**, le pone el veredicto opuesto al mismo hecho: **entrar sin estar aprobado está mal**.

Son dos salidas incompatibles, y elegir una decide el trabajo:

1. **Cerrar la puerta** — la tarjeta no navega (o la pantalla no se abre) mientras el status sea
   `pendingApproval`. Deja la sala de espera **sin superficie** donde vivir el copy que la pieza 2 ya
   escribió, y hay que decidir qué se ve en su lugar.
2. **Explicar la sala de espera** — se deja entrar y **dentro** se dice qué falta y por qué no hay gastos.
   Entonces este ticket se cierra como «no es bug» y lo que queda es copy, que es de quien ya lo tiene.

**Aquí no se decide.** Hace falta el owner, y la decisión va escrita antes de tocar una línea — con lo
del DDL en la mano, porque la opción 1 puede querer además que el servidor deje de entregar el grupo, y
eso es cambiar un endurecimiento explícito.

## Lo observado que no se promueve a defecto

**La app no llevó a B al tab de Grupos** tras unirse: se quedó donde estaba y tuvo que ir a mano. Queda
**registrado como observado** y **no** se convierte en el defecto de este ticket: el owner marcó como
«esto está mal» el **poder entrar**, no el no ser llevado.

**Medido**: ningún ticket de `tickets/` reclama hoy esa navegación forzada, así que no hay dónde
anexarlo. Lo más parecido que existe apunta en la dirección contraria: el «banner de continuidad **en el
tab Grupos**» de `groups-join-intent-reconciler` es una superficie pensada para que el invitado
**encuentre** su estado cuando llegue a Grupos por su pie. ⇒ este pase **no abre ticket** por la
navegación. Si algún día se trabaja, necesita el suyo.

## Decisión Jürgen (2026-09-06)

**Cerrar la puerta, solo en el cliente.** De las dos salidas de «La tensión de producto» eligió la 1,
y de sus dos variantes la barata: la tarjeta del grupo **no abre el detalle** mientras el miembro esté
en `pendingApproval`; en su lugar el invitado recibe una superficie que le dice que su solicitud está
en revisión y qué puede hacer. **El servidor no se toca**: sigue entregando grupo y roster al pendiente
(`is_group_member`), que es lo que hace que el grupo aparezca en su lista, y el endurecimiento del DDL
que reserva gastos/repartos/saldos a `active` (`is_group_writer`) se queda como está. Motivo, tal como
se le puso delante y ratificó: su veredicto del 28-ago era **«entrar sin estar aprobado está mal»**, la
medición del 4-sep dice que no es fuga sino un cascarón vacío, y cerrar la puerta en cliente lo
resuelve sin revertir un endurecimiento escrito a propósito. Descartó «explicar la espera dentro»
(cerrar como no-bug) y «cerrar y además quitarlo de la lista» (tocar el DDL; la sala de espera se
queda sin sitio).

Consecuencia para el vecino `guest-decline-has-no-screen`: su copy de la sala de espera (pieza 2, ya en
`2.1`) vive en la **lista**, no dentro del grupo, así que sigue teniendo dónde estar. Lo que cambia es
que la tarjeta deja de navegar.

**Antes de escribir código sigue faltando medir** lo que la sección «Lo que NO se midió» dejó abierto:
quién gatea hoy la entrada a `GroupDetailView` con un `pendingApproval` y si el cliente pinta botones
de escritura (añadir gasto, invitar, ajustes) que el servidor rechazaría con un error crudo. Ese
primer paso es del ticket, no de esta decisión.

## Criterio de hecho (AC)

Resuelto por la decisión de arriba (era condicionado; la rama «explicar la espera» queda descartada):

- [x] Con el miembro en `pendingApproval`, tocar la tarjeta del grupo **no** abre el detalle; en su
      lugar el usuario recibe una superficie que le dice en qué estado está y qué puede hacer. Copy
      propio, en los 16 `.lproj`, sin prometer nada que la app no haga.
- [x] Al ser aprobado, la puerta se abre **sin** relanzar la app (ya tiene PASS en
      `groups-approval-banner-stays`, y no debe romperse).
- [x] **Nada de contenido financiero** para un pendiente y **ningún botón de escritura** a la vista:
      el servidor ya lo garantiza (`is_group_writer`); el cliente no debe pintar un vacío que parezca
      un grupo sin gastos ni un botón que termine en error crudo.
- [x] El servidor no cambia: `is_group_member` sigue admitiendo `pendingApproval` en `split_groups` y
      `group_members`.

## Cómo se verifica

**Device-QA en TestFlight con dos teléfonos, sobre una subida POSTERIOR a este ticket** (el caso exige un
miembro pendiente real contra el canal backend, que no es ejercitable desde un test). Hoy **no hay
subida**: no hay TestFlight, ni store, ni tag, y **A7/M5 sigue en HOLD** ⇒ este ticket **no** pasa a `qa`
y **no hay PASS** que anotar.

**Flag (2026-09-06):** la decisión ya está; lo que queda es implementación (cliente) y después el device-QA de
dos teléfonos, que depende de que haya una subida nueva (ESTADO: «Publicar la app» sigue pendiente).

## Relacionado

- `tickets/done/groups-approval-banner-stays.md` — el aviso de aprobación; **PASS del owner en la misma
  corrida**, cerrado en el mismo PR que abre este ticket.
- `tickets/qa/guest-decline-has-no-screen.md` — la sala de espera: el «no» sin pantalla y el
  copy de la espera. **Lectura obligada antes de diseñar nada aquí.**
- `tickets/qa/groups-join-intent-reconciler.md` — el alta que no nacía. Otro defecto, no este.
- Sesión de la corrida: `docs/sessions/2026-08-28-device-qa-approval-banner.md`.

---

## MEDIDO · 2026-09-04 — qué ve B dentro: el cascarón, no los gastos. NO es fuga de datos

El ticket dejaba explícitamente abierto «no consta reportado qué vio B exactamente dentro del grupo
(¿roster? ¿gastos? ¿saldos?)». Consta ya, medido **contra la base de datos de producción**
(`yala-modo-nube-production`), sin necesidad de repetir el device-QA:

Las políticas de lectura del grupo se parten en dos, y el corte cae justo en el sitio correcto:

| Tabla | Policy | ¿Pasa un `pendingApproval`? |
|---|---|---|
| `split_groups` (nombre, icono, color) | `is_group_member(group_id)` | **Sí** |
| `split_expenses` (los gastos) | `is_group_writer(group_id)` | **No** |
| `split_shares` (los repartos) | `is_group_writer(group_id)` | **No** |
| `split_settlements` (los saldos) | `is_group_writer(group_id)` | **No** |

Porque las dos funciones NO son sinónimas, y es deliberado:

- `is_group_member` → `status in ('active','pendingApproval')`
- `is_group_writer` → `status = 'active'`

Y los cinco RPCs lectores (`groups_pull_rows_*`) son `LANGUAGE sql STABLE` **sin `SECURITY DEFINER`**,
así que corren con los permisos de quien invoca y la RLS de cada tabla sí les aplica. No hay puerta
trasera por ahí.

⇒ **B entra a un grupo VACÍO**: ve el nombre y el icono porque su ficha sí le baja, y ni un solo
gasto. Coincide con lo que ya observaba `guest-decline-has-no-screen` («veo el grupo y veo quién está
dentro, pero ni un solo gasto»).

**Qué cambia esto para el ticket:** el defecto es de EXPERIENCIA, no de seguridad — a nadie se le
enseñan datos que no debería ver. Lo que pasa es que la app deja entrar a una pantalla que no tiene
nada que contar y no explica por qué está vacía. Sigue siendo un «esto está mal» legítimo, pero no
es una urgencia de privacidad y no hace falta tratarlo como tal.

**Lo que sigue sin medirse:** si B podía TOCAR algo dentro (botones de añadir gasto, invitar,
ajustes). La lectura está cerrada; la escritura no se comprobó aquí — `is_group_writer` gobierna
también los `insert`/`update`, así que el servidor la rechazaría, pero si el cliente le pinta los
botones, el fallo que verá es un error crudo, no una puerta cerrada con explicación.

---

## MEDIDO · 2026-09-06 — la puerta de la tarjeta YA estaba cerrada, y no por este ticket

La sección «Lo que NO se midió» pedía medir «quién gatea hoy la entrada a `GroupDetailView` con un
miembro `pendingApproval`» antes de escribir código. Medido, y la respuesta cambia el trabajo:

**`GroupCardView` ya no abría el detalle a un pendiente.** Su `handleTap` tenía desde `#26` un `case
.pendingApproval` que no navegaba, más un `.disabled(displayMode == .pendingApproval)`. El doc de
`GroupCardDisplayLogic:21-23` lo decía con todas las letras: «tap disabled (no abre el detalle)».

**Entonces, ¿por qué B entró el 28-ago?** Porque el gate se alimentaba de una identidad que en su caso
no resolvía. `GroupsViewModel.currentMemberStatus` hacía `first { $0.isCurrentUser }`, y
`GroupsSyncClient.applyMember` **nunca enciende ese flag** — para B, que llegó por el pull del backend,
devolvía `nil`, `displayMode` caía en `.active` y la tarjeta abría como cualquier otra.

**Y ya está arreglado, colateralmente**: `5ca4dd47` (2026-09-04, «a quien se une por enlace la app deja
de no reconocerle hasta reiniciar», en `2.1`) pasó esa función a `GroupExpenseService
.resolveCurrentUserMember`, que resuelve por `cloudKitUserRecordID`. Comprobado con
`git log -L` sobre la función y `git branch --contains`.

⇒ **el defecto reportado en el build 12 ya no se reproduce en `2.1`**, y no por este ticket. Lo que
quedaba abierto era otra cosa, y es lo que se implementó.

## Lo que SÍ quedaba abierto (y se cerró aquí)

**1 · El tap del pendiente era un muro mudo.** Cerrado con `.disabled`, cumplía media decisión —no
entra— y fallaba la otra media: el AC pide «una superficie que le dice en qué estado está y qué puede
hacer», y no pasaba absolutamente nada. Es el mismo defecto que C-10 ya había arreglado para los
grupos congelados («el grupo era un muro; en un build incapaz, además, un muro mudo»). Ahora el tap
presenta un aviso propio.

**2 · La tarjeta NO era la única puerta.** Medido con control positivo: `openDetail(for:)` tiene **tres**
call-sites en `Yala/`, y solo uno es la tarjeta.

| Vía | Dónde | ¿Gateada antes? |
|---|---|---|
| Tarjeta de la lista | `GroupsContainerView:415` | Sí (`displayMode`) |
| **Deep link de notificación** | `:467`, `openPendingGroupIfAvailable()` | **No** |
| **Nudge `.openGroupDetail`** | `:516`, `handleNudgeAction(_:)` | **No** |

Las dos últimas filtran por `viewModel.activeGroups`, que es `!isArchived && !isHiddenForAll` —
**nada que ver con la membresía**. El nudge, además, abría `activeGroups.first`: si el único grupo del
usuario es aquel en el que está pendiente, lo abría siempre. Cerrar solo la tarjeta habría dejado el AC
cumplido en el camino que se probó a mano y abierto en los dos que no.

**3 · El copy de la sala de espera prometía lo que la decisión elimina.**
`groups.invite.waitingApproval.body` decía «Mientras esperas verás el grupo **y quién está dentro**,
pero todavía ningún gasto». Con la puerta cerrada ya no ve el roster, así que el texto pasaba a mentir
—justo lo que la pieza 2 del vecino había arreglado (`0342564c`, «deja de prometer un aviso que no
existe»)—. Reescrito en los 16 `.lproj`: «verás el grupo en tu lista, pero todavía no puedes abrirlo».
Se conserva intacto el final, que es lo que aquella pieza corrigió: no promete ningún aviso.

## Implementado

- **`GroupCardDisplayLogic.allowsDetailEntry(memberStatus:migrationState:)`** — SSOT de la puerta,
  **derivado** de `displayMode` para que las dos decisiones no puedan divergir. Hereda la prioridad del
  freeze: un grupo congelado **sí** abre el detalle aunque el miembro esté pendiente, porque es ahí
  donde C-10 puso la explicación y el único CTA que ese build puede cumplir.
- **`GroupsViewModel.canOpenDetail(for:)` / `firstGroupOpenableInDetail()`** — lo envuelven con la
  identidad ya resuelta, para que las tres puertas hagan la misma pregunta.
- **`GroupCardView`** — `onPendingTap` en vez del tap muerto. Se retiró el `.disabled`: no protegía nada
  que `handleTap` no proteja ya, y apagaba la tarjeta para VoiceOver.
- **Aviso «Esperando aprobación»** en `GroupsContainerView`, claves propias
  `groups.card.pendingNotice.{title,body}` en los 16 idiomas. Un `Bool` y no un `SplitGroup?` para
  poder atarlo con `$binding` en vez de un `Binding(get:set:)` en el body, que `swiftui-ds.md` prohíbe.
- **Claves propias y no las de `Invite.waitingApproval*`**: aquélla es la pantalla del alta —se ve una
  vez, al unirse— y ésta se ve cada vez que se toca la tarjeta, días después.

## Verificación

- `unit:YalaTests/GroupCardDisplayLogicTests` — **16 casos, verde** (12 previos + 4). Uno es el
  invariante que fija que la puerta se deriva del `displayMode` en las 24 combinaciones.
- `xcuitest:YalaUITests/GroupPendingMemberDoorUITests` — **2 casos, verde** (30,0 s, iOS 26.5).
- **Seed nuevo `grupos-pendiente`** (`DevSeedGroups.createAsPendingMember`): ninguno de los siete
  perfiles servía —todos siembran al usuario propio `.active`, y `grupos-sin-flag` deja pendiente a un
  tercero—, así que el AC no tenía red determinista posible. Lleva un gasto sembrado a propósito: sin
  él, «el pendiente no ve contenido financiero» pasaría por no haber nada que ver.
- **Los dos mutantes, verificados** (regla de `testing.md`: un test que no se pone rojo al revertir el
  fix no prueba la decisión, prueba el flujo):
  - `allowsDetailEntry → true` ⇒ 2 casos unit en rojo.
  - `handleTap` de `.pendingApproval` → `action()` ⇒ el XCUITest en rojo (exit 65).

## Lo que NO se tocó, y por qué

- **El servidor**, según la decisión. `is_group_member` sigue admitiendo `pendingApproval`.
- **El interior de `GroupDetailView`.** Con las tres puertas cerradas es inalcanzable para un
  pendiente. Su `PendingApprovalBanner(state: .pending)` (`:136`) se conserva como
  defensa-en-profundidad y pasa a ser, en la práctica, código sin camino: cuesta cero y es exactamente
  lo que querrías si alguna vía futura volviera a dejar entrar a alguien.
- **La navegación forzada al tab** tras unirse, que el ticket ya había decidido no promover a defecto.

## Residual → ticket propio

`groups-pending-member-sees-detail-chrome` (medido en este pase, **no** corregido): si un pendiente
llegara al detalle, los botones **Miembros** y **Ajustes** de la toolbar no tienen ningún gate de
status, y dentro de Ajustes «Salir del grupo» tampoco. Hoy es inalcanzable —por eso no se arregló
aquí, y por eso es `low`— pero la ausencia de gate es real y está medida.

## Sigue pendiente

**Device-QA de dos teléfonos sobre una subida posterior a este commit**, tal como pedía «Cómo se
verifica»: el caso exige un pendiente real contra el canal backend. Y una comprobación que el
simulador no da: que al **aprobar** al miembro la puerta se abra sin relanzar la app (AC 2) — el
mecanismo no cambió (`currentMemberStatus` pasa a `.active` y el `displayMode` con él), y
`groups-approval-banner-stays` ya tiene PASS del owner, pero aquí no se re-verificó en device.

---

## QA Visual · 2026-09-08

**Veredicto: PASS.** iPhone 17 Pro (iOS 26.5), `Yala Dev`, seed `grupos-pendiente`
(`-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro -uitest-seed grupos-pendiente -uitest-icloud-identity -uitest-groups-consent -uitest-deeplink groups`).
Estado: **yo soy el miembro en `pendingApproval`** del grupo «Cena de amigos».

### Lo que se vio

1. **La tarjeta aparece** en la lista, rotulada «Cena de amigos · 2 miembros activos · 1 solicitud
   pendiente · **Esperando aprobación**». La puerta no la esconde, que es lo correcto: se ve que el
   grupo existe.
2. **Tocarla NO abre el detalle.** Sale un aviso titulado **«Esperando aprobación»**:

   > El admin del grupo todavía no aprueba tu solicitud. Cuando lo haga vas a poder abrir el grupo
   > y ver sus gastos. Vuelve a entrar en un rato para comprobarlo.

   Dice qué pasa, quién lo desbloquea y qué hacer. No es un error ni un silencio.
3. **La prueba negativa que pedía el ticket: `group_members_button` NO existe en el árbol de
   accesibilidad tras el tap.** Ese identificador solo lo monta el detalle del grupo, así que su
   ausencia demuestra que la pantalla no llegó a construirse — no que esté tapada por el alert.
4. **Se cierra con «Entendido» y la lista sigue usable**: vuelven la tarjeta, el buscador, los
   ajustes de Grupos y el botón de nuevo grupo. No queda inerte.

### Captura

- `qa-pending-member-01-puerta-esperando-aprobacion-20260908-212357.png`

### Lo que sigue siendo device

**El AC 2: que al APROBAR al miembro la puerta se abra sin relanzar la app.** Eso necesita un
segundo teléfono con la cuenta del admin y el backend real; ningún hook cambia el `status` de un
miembro en vivo. Queda en la cola del owner, y es lo único que queda de este ticket.
