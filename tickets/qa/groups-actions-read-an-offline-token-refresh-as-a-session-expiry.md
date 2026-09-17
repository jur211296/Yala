---
id: groups-actions-read-an-offline-token-refresh-as-a-session-expiry
status: qa
qa-status: needs-testing
implementation_date: 2026-09-17
priority: medium
area: "groups, sesión"
created: 2026-09-15
updated: 2026-09-17
source: "medición de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15); Jürgen decidió dejarlo para un ticket aparte"
---

# Salir de un grupo sin conexión también dice «Tu sesión caducó»

## El problema, en lenguaje de usuario

Estoy sin conexión y el token de mi sesión ya caducó. Toco «Salir del grupo» y Yala me dice «Tu sesión caducó.
Vuelve a iniciar sesión e inténtalo de nuevo.» Mi sesión está bien: lo que falla es la red. Y sin red tampoco puedo
volver a entrar.

## Lo medido (leído en el código, sin ejecutar)

> Anterior al cambio del 2026-09-17: describe el bug, no el código de hoy.

- Las acciones de grupo pasan por `GroupsMembershipClient.call(fn:args:)`. Sin token lanza
  `GroupsRPCError.sessionExpired` sin hacer la petición (el primer `guard` de `call`). Con la red caída y el token
  vigente lanza `.transient(status: -1)`.
- `CloudAuthService.accessToken()` devuelve `nil` por cualquier fallo, también cuando la renovación no llega por
  falta de red. En ese caso el SDK conserva la sesión (`SupabaseSessionRenewalContractTests`).
- Lo ve la persona al salir de un grupo (`GroupLeaveErrorLogic.classify` → `groups.errors.sessionExpired`) y al
  aceptar una invitación (`GroupBackendAcceptErrorLogic.classify` → `.sessionRequired`). Crear grupo, crear
  invitación, aprobar, expulsar, transferir la propiedad y el consentimiento pasan por el mismo `call`.
- Dos consumidores ya tratan igual los dos errores: `GroupService.isTransientRPC` y `GroupsConsentRegistrar`.

## Por qué quedó fuera del arreglo del 2026-09-15

El canal de sincronización ya separa los dos casos con `canRenewSession` (`GroupsSyncClient.sdkRemovedTheSession`).
Este cliente es otro objeto: tiene RPC de un solo intento (`create_group` y `create_group_invite`, en
`neverRetryTransient`), y para ellos un `.transient` puede significar «quizá se aplicó en el servidor». Sin token no
se envía nada, así que ese riesgo no aplica aquí, pero hay que medir qué hace cada pantalla con un `.transient`
antes de cambiar el error que recibe.

## Criterios de aceptación

- [x] Sin token y con la sesión guardada, `call` no lanza `.sessionExpired` (test), y con la sesión borrada sí
      (test en la dirección contraria).
- [x] Salir de un grupo sin red enseña «No pudimos completar tu salida del grupo…», no «Tu sesión caducó». En unit, de
      punta a punta; en iPhone, pendiente del guion de abajo.
- [x] Escrito qué hace cada consumidor de `GroupsRPCError` con el cambio, crear grupo e invitación incluidos (abajo).

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo arreglo en el canal de sincronización.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo patrón en el canal personal.
- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — otro 401 que no es una sesión caducada. Desde el
  2026-09-15 `call` ya lanza `.transient(status: 401)` con `yala_attest_required`; lo que queda aquí es el token nulo.

## Hecho el 2026-09-17

**Lo que cambia para la persona.** Sin conexión y con el token caducado, ninguna acción de Grupos dice ya «Tu sesión caducó»
ni abre el inicio de sesión. Con la sesión borrada de verdad, las dos siguen pidiendo volver a entrar.

- **Salir de un grupo** (Ajustes del grupo, la tarjeta de un grupo que te rechazó y «Transferir y salir»): «No pudimos
  completar tu salida del grupo. Vuelve a intentarlo en un momento.», en el mismo tiempo que antes.
- **Aceptar una invitación:** ya no abre la hoja de «Inicia sesión», que con la sesión guardada se cerraba sola y volvía a
  abrirse. La pantalla de unión espera, a los 20 s dice «Está tardando un poco más de lo normal», y la unión se reintenta
  al volver Yala a primer plano.

**Lo que se tocó.** Las decisiones están en el Paso 0 de
`encargos/lanzados/2026-09-17-groups-actions-read-an-offline-token-refresh-as-a-session-expiry.md`, con su revisión
tras la review.

- `GroupsMembershipClient.call`: con el token nulo, `.sessionExpired` solo si el SDK borró la sesión (`canRenewSession`,
  leído DESPUÉS de pedir el token); si la conserva, `.transient(status: -1)` **sin el reintento corto** de `callWithRetry`,
  porque el SDK ya reintenta la renovación dos veces. El testigo es un parámetro del init con default
  `CloudAuthService.shared.canRenewSession`, del mismo singleton que el token, así que las 8 construcciones de producción
  no cambian.
- Docblocks de `GroupsRPCError`, `CloudAuthService.canRenewSession`, `GroupLeaveErrorLogic.Kind`,
  `GroupBackendAcceptErrorLogic.ErrorKind`, `L10n.Groups.Errors.sessionExpired` y `GroupsAccountAssociation.associate`,
  y dos reglas de `.claude/rules/swiftdata-cloudkit.md`: la del token que no llega, que daba este ticket por pendiente, y
  el punto 6 de «Migrar a la nube».

## Qué hace cada consumidor de `GroupsRPCError` con el cambio

Sin red y con el token caducado, antes y ahora. Nadie espera más que antes: el token se pide una vez, como con
`.sessionExpired`.

| Acción | Superficie | Antes | Ahora |
|---|---|---|---|
| Salir de un grupo | Ajustes del grupo, tarjeta del grupo rechazado, «Transferir y salir» (`GroupLeaveErrorLogic`) | «Tu sesión caducó…» | «No pudimos completar tu salida del grupo…». Con la racha de App Attest terminal, lo mismo: `-1` no es el 401 |
| Aceptar una invitación | `GroupBackendInviteEntryHandler.handleJoinError` | `.sessionRequired`: la hoja de inicio de sesión, cuyo cinturón la cerraba y volvía a intentar la unión en bucle (leído, sin ejecutar) | `.transient`: sin hoja; conserva la invitación, re-arma el tap y el reconciler reintenta en el siguiente arranque o `.active` |
| Crear grupo | `GroupFormView` | «…(Error de Yala.GroupsRPCError 2.)» | «…(Error de Yala.GroupsRPCError 1.)». Ticket `groups-create-approve-remove-show-a-raw-rpc-error` |
| Crear enlace de invitación | `GroupMembersView`, `GroupDetailViewModel` | «No se pudo crear el enlace… Revisa tu conexión» | Igual |
| Aprobar / expulsar | `GroupMembersView` | «…GroupsRPCError 2.» | «…GroupsRPCError 1.». Mismo ticket |
| «Salir de todos mis grupos» | `GroupService.isTransientRPC` | Paso diferido | Igual |
| Consentimiento (registrar y leer) | `GroupsConsentRegistrar` | Diferido / sin cambio de caché | Igual |
| Borrar la cuenta | `AccountDeletionService`, paso 1 | `.failed(step: .groups)` | Igual |
| Corregir el nombre al unirse | `correctDisplayNameIfNeeded` | Log | Igual |
| Revocar invitación | `revokeInvite` | Sin llamadores | Sin llamadores |

## Cómo se verificó

- **Unit**, en las dos direcciones: el cliente (`GroupsMembershipClientTests`: sin petición, una sola petición de token,
  sin esperas, el testigo leído tras el token, los one-shots y la racha de App Attest intacta), salir de un grupo de punta
  a punta con su texto y la invitación con lo que se encola en el router (`GroupsActionsOfflineTokenTests`), y el cableado
  de producción (`AttestWiringTests.groupsMembershipConstructions_inheritTheLiveSessionWitness`).
- **Mutantes, los 11 muertos** (3 suites, 43 tests por corrida): siempre `.sessionExpired`; predicado invertido; testigo
  leído antes del token; `status: 401`; default del init `{ false }`; el init que no guarda el testigo; una construcción de
  producción que pasa `hasSession`; el token nulo que suma a la racha de App Attest; el que la borra; el reintento corto de
  vuelta; y siempre `.transient` sin mirar el testigo.
- **Review adversarial** con tres lentes (lógica y contrato, lo que ve la persona, tests). Retiró el reintento corto,
  endureció los tests y abrió tres tickets.
- **Gate:** build x2 sin warnings en lo tocado, unit 7215 tests en 732 suites (0 fallos), XCUITest 19 casos en 5 clases
  de las áreas tocadas con el centinela en 0, `validate-coverage` OK y `docs/TICKETS.md` igual al disco (450).

## Lo que queda, con ticket

- `groups-actions-do-not-retry-a-401-with-a-forced-token-refresh` — con el reloj atrasado, un 401 del gateway con la
  sesión buena sigue diciendo «Tu sesión caducó».
- `groups-join-is-not-retried-when-the-network-returns` — la unión espera al siguiente `.active` aunque «Está tardando…»
  prometa que el grupo aparecerá apenas esté listo.
- `groups-join-reconcile-can-clear-an-invite-while-its-join-is-in-flight` — anterior al cambio.
- `groups-create-approve-remove-show-a-raw-rpc-error` — el error crudo de crear, aprobar y expulsar.
- `groups-join-intent-expires-silently-after-transient-failures` — la invitación que caduca a los 7 días; se le añadió esta
  población.

## Device-QA — NO simulable

Pide una sesión real de Supabase con el token caducado y el teléfono sin red: bajo `-uitest` no hay sesión que caduque, y
el simulador no corta la red por dispositivo. A diferencia del canal personal no hay ventana estrecha: la acción pide el
token antes que App Attest, así que basta con pasar la hora `exp` sin red.

**Montaje.** iPhone con **Yala Dev** (staging), con la build de este PR, y una cuenta que sea **miembro, no creadora**, de
un grupo (A). Otro teléfono con la cuenta creadora de un segundo grupo (B), o cualquier admin de B.

1. En el otro teléfono, con red, crea un enlace de invitación al grupo B y mándalo por Mensajes o WhatsApp al iPhone de
   QA. No lo abras todavía.
2. En el iPhone de QA, con red: Ajustes → «Dónde viven tus datos» → «Modo Nube · Auth». Apunta la hora `exp`.
3. Pon el **modo avión** y deja Yala en segundo plano hasta pasada esa hora. No quites el modo avión en todo el guion hasta
   el paso 6.
4. Abre Yala → Grupos → grupo A → engranaje de arriba a la derecha → «Salir del grupo» → confirma «Salir del grupo».
   - **Esperado:** en un par de segundos, «No pudimos completar tu salida del grupo. Vuelve a intentarlo en un momento.»
     Sigues en el grupo.
   - **Con la build de antes** (control opcional): «Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.»
5. Abre el enlace del paso 1 y sigue la hoja hasta «Unirme al grupo».
   - **Esperado:** **no** aparece la hoja de «Inicia sesión». La hoja de unión espera y a los ~20 s dice «Está tardando un
     poco más de lo normal». Toca «Seguir a la app».
   - **Con la build de antes:** aparece la hoja de «Inicia sesión» y se cierra sola, una o varias veces.
6. Quita el modo avión con Yala abierta. Bloquea y desbloquea el teléfono para que Yala vuelva a primer plano.
   - **Esperado:** sin tocar el enlace otra vez, el grupo B aparece en Grupos, o su aviso de «esperando aprobación» si B
     la pide. Sin volver a primer plano no se reintenta (`groups-join-is-not-retried-when-the-network-returns`).
7. **Control con la sesión borrada de verdad.** Con red, en el dashboard de Supabase de staging: Authentication → Users →
   busca la cuenta por su correo y copia su id. En el SQL editor corre `delete from auth.sessions where user_id = '<id>';`.
   En el iPhone, vuelve a «Modo Nube · Auth» y apunta la `exp` nueva (el token se renovó en el paso 6). Entra en el grupo
   A → engranaje, y deja esa pantalla abierta **con la red puesta** hasta pasada la `exp`: sin sesión, la lista de Grupos
   podría no dejarte volver a entrar al grupo. Toca «Salir del grupo» → confirma.
   - **Esperado:** «Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.» Sigues en el grupo.
