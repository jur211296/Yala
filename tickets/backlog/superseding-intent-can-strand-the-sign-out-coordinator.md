---
id: superseding-intent-can-strand-the-sign-out-coordinator
status: backlog
priority: medium
area: "modo-nube, groups"
created: 2026-09-11
source: "review adversarial de la mitad 2 del paso 5 (`groups-entry-on-a-mirrored-store-still-blocks-the-owner`), lente de flujo de UI"
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

- [ ] Un intent superseding durante la espera no deja el coordinador en un `.blocked` sin dueño.
- [ ] Tras ese caso, «Cerrar sesión» en Ajustes sigue funcionando.
