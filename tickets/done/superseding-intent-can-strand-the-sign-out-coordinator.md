---
id: superseding-intent-can-strand-the-sign-out-coordinator
status: done
priority: medium
area: "modo-nube, groups"
created: 2026-09-11
source: "review adversarial de la mitad 2 del paso 5 (`groups-entry-on-a-mirrored-store-still-blocks-the-owner`), lente de flujo de UI"
updated: 2026-10-04
qa-status: not-replicable
qa-date: 2026-10-04
qa-notes: barrido 2026-10-04 sin device-QA - carrera con modo avion y una invitacion abierta desde otro telefono sobre la espera agotada; cubierto por sus unit tests
---

# Un intent que supera la cadena del Welcome puede dejar el coordinador del cierre cerrado con llave

## Lo medido (2026-09-11)

Mientras la vuelta al neutro de la puerta de Grupos espera al export, `CloudSessionSignOut.phase` es
`.working`, y **`.working` no es blocker de nada**: la matriz de readiness solo sube el blocker con
`.awaitingRelaunch`. El único blocker vivo entonces es `welcomeFlow`, que está en la lista de los
derribables: `dismissWelcomeChainForSupersedingIntent` lo baja ante `presentGroupsConsent`,
`presentGroupsSignIn` o `presentGroupBackendInviteOnboarding` — o sea, ante un enlace de invitación o una
notificación de grupo que llegue en ese momento.

Al desmontarse el step, su `.task(id:)` se cancela, el `sleep` de la espera devuelve `false` y el
coordinador queda en `phase = .blocked(0, .exportUnconfirmed)` con `blockedExit` puesto **y sin nadie que
lo mire**. A partir de ahí, `guard phase == .idle` cierra en silencio todo cierre de sesión del resto del
proceso, el de Ajustes incluido.

La variante cara: si la cancelación cae después de soltar credenciales (`armAfterCredentials`), ya han
corrido el teardown de la sesión de grupos, el desregistro del push token y `CloudAuthService.signOut()`, y
el arm **no** llega a escribirse: dispositivo a medio cerrar y sin borrado armado.

## Lo que ya está mitigado, y lo que no

**Mitigado para la puerta**: al volver a entrar, `neutralReturnEntryPhase` comprueba
`CloudSessionSignOut.shared.phase == .idle` y, si no lo está, enseña una pantalla con salida en vez de
colgarse en un progreso. La persona no queda atrapada.

**No mitigado**: el cierre de sesión de Ajustes de ese mismo proceso, que vuelve mudo. Y la sesión ya
soltada en la variante cara.

**Y desde el 2026-09-15 la variante cara deja también cambios de GRUPOS en el teléfono** (review adversarial de
`groups-phone-that-never-attests-is-told-to-retry-forever`). Con la pérdida aceptada de un teléfono sin App Attest, el
residual de grupos ya no tiene que ser cero para soltar credenciales: esas filas mueren con el borrado del arranque. Si el
arm no llega a escribirse —esta cancelación, un kill entre `CloudAuthService.signOut()` y el arm, o salir de la puerta del
Welcome sobre un `.exportUnconfirmed` con credenciales ya sueltas—, las filas se quedan en `GroupSyncOutbox`, que no
guarda dueño. Inferido, sin medir: si luego entra otra cuenta sin «Empiezo de cero», suben con su JWT. Purgarlas en sesión
se descartó: es un `save()` sobre el contexto compartido, lo que `PrivateSignOutWiringTests.groupsMarkerRule_andNoSwap`
prohíbe en ese tramo.

## Por dónde va

- Que `.working` suba también un blocker de la matriz mientras haya un cierre en vuelo — es un cierre de
  sesión, no una pantalla que se pueda tapar.
- O que el desmontaje del step reconozca el bloqueo, con cuidado: `acknowledgeBlocked` borra `blockedExit`,
  y con credenciales ya soltadas eso pierde el punto de retorno.

## Criterios de aceptación

- [x] Un intent superseding durante la espera no deja el coordinador en un `.blocked` sin dueño.
- [x] Tras ese caso, «Cerrar sesión» en Ajustes sigue funcionando — porque el caso ya no ocurre: el Welcome no se
  derriba, y la persona sale del bloqueo por sus botones, que lo reconocen.

## Paso 0 (2026-10-01, MODO AUTÓNOMO)

- **La premisa se midió antes de tocar nada.** Desde el 2026-09-14 (`b49cb5c8b`) la matriz tiene `signOutWorking`, que va
  por delante de la cadena del Welcome en `blocker()`. O sea que la mitad `.working` de la ventana —la del ticket, con
  la variante cara de `armAfterCredentials`— ya no se derriba. Pero **por accidente**: ningún test lo fijaba.
- **La mitad que seguía abierta es `.blocked`.** Con el «espera agotada» de la puerta en pantalla, `.blocked` no es
  blocker (a propósito: puede quedarse puesto, y retener el router con él lo mataría), el único blocker es
  `welcomeFlow`, y `isBlockedSolelyByWelcomeChain` dejaba derribarlo. Desmontar el step dejaba el `.blocked` y su
  `blockedExit` sin dueño: el strand del ticket, con el `signOut` de Ajustes mudo el resto del proceso.
- **Decidido:** un término nuevo `isSignOutBlocked` en `ShellReadinessState` que **no** es blocker y solo impide el
  derribo. Descartada la otra vía del ticket («que el desmontaje reconozca el bloqueo»): `acknowledgeBlocked` borra
  `blockedExit`, y con credenciales soltadas eso pierde el punto de retorno.
- **Asumido:** si el `.blocked` es de otro dueño (no del Welcome), la invitación espera igual a que el Welcome se
  cierre. Es más seguro que derribarlo y la persona no queda atrapada: el Welcome tiene sus salidas. Lo mismo con
  un `.blocked` ya huérfano por otra vía (review adversarial): las invitaciones esperan tras el Welcome hasta que la
  persona salga por otro camino, o hasta reabrir la app, que devuelve la fase a `.idle`. El daño del huérfano —Ajustes
  mudo— ya existía; lo nuevo es solo esa espera.
- **Y el re-peek al cambiar de fase.** Retener el intent abría un hueco: al reconocer el bloqueo la fase vuelve a
  `.idle` sin bumpear la revisión, y la invitación esperaba un bump que no llega (B4-04). `ContentView` re-mira la cola
  en cada cambio de fase con el shell tapado, igual que `dismissSplash` y el asentamiento del arranque.

## Resuelto (2026-10-01)

- `ContentViewReadinessLogic`: `isSignOutBlocked` y el guard al frente de `isBlockedSolelyByWelcomeChain`.
- `ContentView`: el snapshot lee `.blocked` del coordinador (`signOutIsBlocked`) y el `onChange` de la fase pasa por
  `signOutPhaseChanged()`, que recomputa y re-mira la cola.
- Tests: `ContentViewReadinessLogicTests` (4 nuevos, incluido el que fija la mitad `.working`) y
  `SignOutBlockedOwnershipWiringTests` (3, cableado por source-scan con el cuerpo entero).

## Guion de QA (device, iPhone con iCloud)

Montaje: un iPhone con Yala instalada y datos personales en iCloud, en el Welcome (reinstalar, o cerrar la sesión
privada), y un enlace de invitación a un grupo a mano (en Notas o Mensajes, abierto desde otro teléfono).

1. En el Welcome, toca «Crear mi primer grupo». La puerta empieza a devolver el teléfono al neutro.
2. Pon el modo avión para que la subida a iCloud no termine, y espera al aviso «espera agotada» con sus botones.
3. Con ese aviso en pantalla, quita el modo avión y abre el enlace de invitación.
   **Esperado:** el aviso sigue ahí. La invitación NO tapa el Welcome.
4. Toca la flecha de volver de arriba a la izquierda (en esta rama el aviso no trae botón «Volver»; la flecha es su
   salida). **Esperado:** vuelves a los dos caminos y, enseguida, se presenta la invitación.
5. Cierra la invitación, ve a Ajustes → «Cerrar sesión». **Esperado:** responde (no se queda mudo).

## Barrido de `qa` · 2026-10-04 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido antes del QA del lunes (encargo `2026-10-04-barrido-qa-antes-del-qa-del-lunes`), con el criterio de #224 y #291. Es una carrera: abrir una invitación justo encima del aviso de espera agotada, con modo avión y otro teléfono para mandar el enlace. No se provoca de forma fiable a mano. Lo fijan los unit tests del arreglo (commit `03742d873`).
