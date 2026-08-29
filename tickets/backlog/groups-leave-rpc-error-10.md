---
id: groups-leave-rpc-error-10
status: backlog
priority: high
area: groups
created: 2026-08-28
updated: 2026-08-28
---

# Salir del grupo falla con un error crudo («GroupsRPCError 10») y en ese teléfono no hay forma de borrar el grupo

## Reporte del owner (device, 2026-08-28, Lima)

Grupo de prueba, TestFlight **2.1 build 12**, dos teléfonos: **A** = personal, **B** = de pruebas.

1. La intención era **borrar el grupo**. No apareció ningún botón de borrar el grupo. (Puede ser lo
   normal si ese teléfono no es el dueño: el borrado es owner-only, ver Cara 2.)
2. En **A** (personal): **Salir del grupo funcionó**.
3. En **B** (de pruebas): **Salir del grupo falló**, con este alert:

   > No se ha podido completar la operación. (Error de Yala.GroupsRPCError 10.)

Eso es TODO lo que hay del device. No se anotó quién creó el grupo, cuántos miembros quedaban, ni si
B intentó otras operaciones de grupo (invitar, renombrarse) en ese momento. **No se inventa nada por
encima de esto.**

## Qué ve el usuario

Un mensaje del sistema con un número dentro. No dice qué pasó, no dice si es culpa suya, no dice si
sirve reintentar, y no ofrece nada que hacer. Y en la pantalla que produce ese mensaje tampoco está
la acción que el usuario venía a hacer (borrar el grupo), así que se queda sin salida por los dos
lados: no puede salir y no puede borrar.

## Medido en el árbol

Todo lo de esta sección está medido sobre `2.1` @ `2175e53e` (el árbol en el que se escribe el
ticket, **no** el build 12 del device). Si al retomarlo el árbol ya no es ese commit, re-medir: es un
grep, y en este repo la documentación envejece más rápido que el código.

**Nada de esto prueba la causa de ESTA corrida.** Es el mapa del terreno, no el veredicto.

### El alert es el `localizedDescription` crudo, sin copy propio

- `Yala/App/Views/Groups/GroupSettingsView.swift:667-681` — `leaveGroup()` hace
  `leaveErrorMessage = error.localizedDescription` (`:678`) y lo enseña tal cual en un alert con
  título genérico (`:150-154`, `L10n.Common.error`).
- El texto «No se ha podido completar la operación. (…)» **no existe en el repo**: no está en
  ninguno de los `Localizable.strings` (medido con grep en todo el árbol). Es la descripción por
  defecto que Foundation fabrica al puentear a `NSError` un `Error` de Swift que **no** conforma
  `LocalizedError`, y el número que imprime es el discriminante del caso.
- `GroupsRPCError` (`Yala/Services/CloudSync/Groups/GroupsMembershipClient.swift:23-45`) es un enum
  `Error, Equatable` **sin** `LocalizedError` ni `CustomNSError` (medido: no aparece en el grep de
  conformancias de todo `Yala/`). Por eso sale un número y no una frase.
- Contraste medido: `GroupServiceError` **sí** es `LocalizedError` (`GroupService.swift:1458`), y su
  caso `ownerCannotLeave` imprime «GroupService: Owner cannot leave their own group» (`:1495-1496`).
  Es decir: **el alert que vio B no puede venir del guard local** — ese habría enseñado esa frase en
  inglés, no un número. El error salió de dentro de `GroupsMembershipClient`.

### Qué caso es el 10 (contado en el árbol) y qué parte de esa lectura es inferencia

Casos del enum en **orden de declaración** (0-based), `GroupsMembershipClient.swift:24-45`:

| # | caso | origen |
|---|---|---|
| 0 | `sessionExpired` | 401, o token nil (sin request) |
| 1 | `notAuthorized` | `yala_not_authorized` |
| 2 | `invalidInvite` | `yala_invalid_invite` |
| 3 | `badInput` | `yala_bad_input` |
| 4 | `groupExists` | `yala_group_exists` |
| 5 | `invalidGroupID` | `yala_invalid_group_id` |
| 6 | `memberNotFound` | `yala_member_not_found` |
| 7 | `cannotRemoveOwner` | `yala_cannot_remove_owner` |
| **8** | **`ownerCannotLeave`** | `yala_owner_cannot_leave` |
| **9** | **`permanentRejected(code:)`** | 400 con `yala_*` desconocido |
| **10** | **`channelDisabled`** | 403 `yala_groups_disabled` (kill-switch del canal) |
| 11 | `transient(status:)` | 5xx / no-yala / transporte |
| 12 | `decoding` | 200 con body que no decodifica |

**Medido:** el orden de declaración y qué caso ocupa cada posición.

**Inferido, y sin comprobar aquí:** que el número que imprime Foundation *sea* ese índice de
declaración. El puente usa el tag del enum, y este enum tiene **dos casos con payload**
(`permanentRejected`, `transient`); conviene confirmar que el tag sigue el orden de declaración y no
una ordenación que ponga los casos con payload delante. No es una duda académica: si fuese
payload-first, la aritmética dejaría el 10 sobre **`ownerCannotLeave`**, que es justo la otra cara de
este ticket. En este entorno (docs, Linux) no hay toolchain de Swift para medirlo.

Comprobación decisiva y barata, **cuando se implemente** (es Swift, no entra en este ticket): una
aserción en `YalaTests/CloudSync/GroupsMembershipClientTests.swift` —el fichero que ya fija el
contrato del 403— del tipo `(GroupsRPCError.channelDisabled as NSError).code == 10`. Con eso el
número deja de ser interpretable.

### Cara 1 — si el 10 es `channelDisabled`: qué implicaría, y qué NO está probado

- El cliente **solo** produce `.channelDisabled` en `403` **y** con el código del envelope del
  gateway: `GroupsMembershipClient.swift:336-348`, `case 403 where GatewayErrorEnvelope.isGroupsChannelDisabled(data)`.
  Un 403 de otra procedencia (proxy, WAF, body no-envelope) cae a `.transient(status: 403)` —
  medido, y con tests que lo fijan: `GroupsMembershipClientTests.swift:255-262` y `:266-271` (este
  último usa precisamente `leaveGroup`).
- El kill-switch del servidor es **global, por deploy, no por usuario**:
  `gateway/src/groups/killSwitch.ts:116-126` rechaza con 403 `yala_groups_disabled` si
  `parseRolloutPercent(env.GROUPS_BACKEND_ROLLOUT_PERCENT) > 0` es falso, y el header del módulo
  (`:18-31`) explica por qué NO puede ser por cohorte: el bucket del cliente sale de un seed de
  instalación que jamás sale del device. Cualquier valor `> 0` ⇒ no rechaza a nadie; `0` (o
  ausente/inválido, fail-closed) ⇒ rechaza a todos. Cubre las cuatro rutas de `/groups/*`, con una
  sola excepción: `groups_forget_user` (`:104`).
- En el árbol, el percent está en `"100"` en **producción** (`gateway/wrangler.toml:166`, bloque
  `[env.production.vars]` de `:89`) y en staging (`:53`). Ojo: el `wrangler.toml` del árbol **no es
  el valor desplegado** — el flip es «editar aquí + `wrangler deploy`», así que el árbol es indicio,
  no prueba, de lo que servía el Worker el 2026-08-28.
- Los dos teléfonos, con el **mismo build de TestFlight**, pegan al **mismo** Worker: la base URL es
  de compilación (`Yala/App/Services/ProxyConfig.swift:15-21`, `DEV_BUILD` → staging, `#else` →
  producción).

⇒ **Por eso el kill global no está probado**: A acababa de salir con éxito por ese mismo canal, y con
el kill puesto habría fallado igual (el 403 no distingue devices ni usuarios). Que el número diga
«canal apagado» y que el canal estuviera apagado son dos afirmaciones distintas; hoy solo se tiene la
primera, y depende además de la inferencia del párrafo anterior.

Matiz que hay que tener a mano al reproducir: **el éxito de A tampoco prueba que el canal estuviera
encendido.** `GroupService.leaveGroup` solo llama al RPC si `routesMembershipToBackend(group)`
(`GroupService.swift:473-483`, predicado en `:86-95`: flag `groupsBackendEnabled` ON **y** la ZONA es
del canal backend, criterio ANY-row). Si en A ese predicado hubiera dado `false`, su salida habría
sido puramente **local** (`:485-512`) y habría tenido éxito sin tocar la red. No se midió en el
device cuál de los dos caminos tomó A.

### Cara 2 — el agujero de UX: último dueño, botón ausente y un `isOwner` que nadie actualiza

Esta cara no depende de qué número sea el 10: es el estado en el que el usuario se quedó.

- La pantalla decide por un solo booleano, `GroupSettingsView.swift:79-90`: **Salir** se muestra si
  `!group.isOwner` (`:79-80`, sección en `:514-538`); **Eliminar grupo** (soft-delete) se muestra si
  `group.isOwner` (`:89-90`, sección en `:542-580`, deshabilitado además con deuda pendiente, `:568`,
  con su hint en `:570-577`). No hay tercera rama: quien tenga `isOwner == false` **nunca** ve el
  borrado, y quien lo tenga `true` nunca ve la salida.
- Dado que B **sí** veía «Salir», su fila local tenía `isOwner == false`. Es deducción directa de
  `:79`, no una suposición sobre el device.
- `SplitGroup.isOwner` es **device-local y solo lo escribe quien crea el grupo**: el único
  `.isOwner = true` de producción en todo `Yala/` está en
  `GroupBackendMembershipService.swift:165` (el resto son seeds de DEV). Su propio comentario
  (`:161-164`) dice que el pull deja `isOwner` intacto A PROPÓSITO. ⇒ **ninguna transferencia de
  ownership server-side llega jamás a ese flag.**
- Lo mismo con `SplitMember.isGroupOwner`: `applyMember` (`GroupsSyncClient.swift:2598`) no lo
  escribe nunca — medido por grep (cero ocurrencias de `isGroupOwner` en ese fichero) y declarado por
  escrito en `GroupBackendMembershipService.swift:201-208`, que lo llama DEVICE-LOCAL porque el wire
  no lo lleva.
- El guard local `guard !group.isOwner else { throw GroupServiceError.ownerCannotLeave }`
  (`GroupService.swift:458`) por tanto **no protege** de nada en un teléfono que no creó el grupo:
  con `isOwner` obsoleto en `false`, el intento sale a la red y quien decide es el servidor.
- **El producto ya tiene modelada la respuesta correcta a este caso, pero en otra pantalla.**
  `GroupBatchLeaveLogic.classify` (`Yala/App/Logic/GroupBatchLeaveLogic.swift:81-88`) clasifica: no
  owner → `leave`; owner sin co-miembros activos → `deleteSolo`; owner + co-miembros en canal backend
  con heredero elegible → `transferThenLeave`; el resto → `needsDecision`. Existe el RPC
  `transfer_group_ownership` (`GroupsMembershipClient.swift:476-478`) y el flujo
  `GroupService.transferOwnershipThenLeave` (`:745-758`). **Ajustes del grupo no ofrece ninguna de
  esas salidas**: ni transferir, ni «soy el último, ciérralo», ni explicar por qué no se puede salir.

Si en esta corrida B era (o pasó a ser, tras salir A) el último miembro o el dueño server-side, lo
esperable según el mapeo del cliente sería `ownerCannotLeave` → **8**, no 10. **Por eso esta cara se
registra como el agujero de UX que el owner encontró, y NO como la causa del error 10.**

## Por qué es un solo ticket y no dos

Comparten setup (los mismos dos teléfonos, el mismo grupo, el mismo minuto), comparten pantalla
(`GroupSettingsView`) y comparten el mismo callejón sin salida para el usuario: la única acción
disponible falla con un número, y la que resolvería el problema no está. Además, la Cara 1 no se
puede cerrar sin decidir qué se le enseña al usuario en cada caso del enum, que es exactamente lo que
le falta a la Cara 2. Partirlo en dos garantiza que uno de los dos se arregle a medias.

## Hipótesis vivas (ninguna probada — no cerrar ninguna sin medir)

1. El 10 es `channelDisabled` y el Worker devolvió de verdad 403 `yala_groups_disabled` a esa
   petición. Pendiente de conciliar con el éxito de A y con el `"100"` del árbol.
2. El 10 no es `channelDisabled` porque el tag del enum no sigue el orden de declaración (casos con
   payload delante) y el caso real es otro — `ownerCannotLeave` es el candidato aritmético.
3. Algo delante del Worker devolvió un 403 con el envelope del gateway. El cliente exige el CÓDIGO,
   no el status a secas (`:336`), así que esto requiere un cuerpo con `yala_groups_disabled`.

## Qué medir la próxima vez (diagnóstico antes de tocar código)

- **Fijar el mapeo número ↔ caso** con la aserción de test citada arriba. Sin eso, todo lo demás se
  discute sobre un número interpretado.
- **Preguntarle al servidor qué publica**: `GET /config` expone `groupsBackendRolloutPercent`
  (`gateway/src/config.ts:61`), que sale del MISMO parser que el kill (`killSwitch.ts:124`) — si
  publica 0, el kill está puesto; si publica >0, no lo está. Es la comprobación directa de la
  hipótesis 1 y no necesita el device.
- **En B, con el grupo aún vivo**: intentar otra operación de grupo cualquiera (invitar, renombrarse).
  Con el kill puesto fallan TODAS las rutas `/groups/*`; si solo falla salir, el kill queda descartado.
- **Anotar quién es el dueño server-side** del grupo y cuántos miembros activos quedan, que es lo que
  separa la Cara 2 de la Cara 1.
- Si se vuelve a reproducir, capturar el alert **y** la hora: el device puede tener el percent viejo
  cacheado hasta 6 h (`RemoteFlagDecisionLogic.refreshMinInterval`), así que cliente y servidor pueden
  estar en desacuerdo durante una ventana larga.

## Distinto de (ya existen; no duplicar)

- `tickets/qa/invite-backend-stale-config.md` — el canal apagado visto desde el **enlace de
  invitación**: ahí ya se decidió que `channelDisabled` es TRANSITORIO para el usuario y se le enseña
  copy propio (`groups.invite.channelUnavailable`, vía `GroupBackendAcceptErrorLogic`). Aquí el mismo
  estado del mundo llega a **salir del grupo**, que no tiene ese tratamiento y enseña el número crudo.
  Ese ticket es el precedente de copy, no el mismo defecto.
- `tickets/in-progress/secondary-guest-exit-lock-and-outbox.md` — la salida de la **sesión secundaria**
  (invitada que se va del teléfono ajeno) y su outbox. Otro sujeto y otro flujo.
- `tickets/backlog/groups-reconnect-prune-or-rewire.md` — la maquinaria de reconexión sin emisor.
- `tickets/qa/rescue-discarded-groups-pull.md` — rescate del pull de grupos descartados.
- `tickets/qa/groups-ghost-tx-on-delete.md` — la TX fantasma que sobrevive al borrar un **gasto**
  de grupo. Ese es el bridge de gastos; este es la membresía.

## HOLD

Sin implementación: **cero Swift** en este ticket. `status` sigue `backlog`. No se toca
`qa/coverage-index.json` (no se toca código bajo `Yala/`). No inventar PASS ni declarar causa. Sin App
Store, sin tag de release, sin TestFlight.

## Acceptance Criteria

- [ ] Ningún fallo de «Salir del grupo» enseña un `localizedDescription` crudo con un número: cada
      caso de `GroupsRPCError` que pueda llegar a esa pantalla tiene copy propio que dice qué pasó y
      si sirve reintentar (el canal apagado, como en el enlace de invitación, se cuenta como
      «vuelve más tarde», no como error del usuario).
- [ ] Un teléfono que es dueño **server-side** del grupo no se queda sin salida: la pantalla ofrece
      la acción que corresponde a su situación real (transferir y salir, o cerrar el grupo si es el
      último), en vez de decidirlo solo con el `isOwner` local que únicamente escribe el creador.
- [ ] Queda fijado por test el mapeo entre el discriminante que ve el usuario y el caso del enum, de
      forma que un número en un reporte de device vuelva a ser una pista fiable.

Verificación pendiente: no hay device-QA de un fix (no hay fix). Los tres criterios se comprueban
cuando se implemente.
