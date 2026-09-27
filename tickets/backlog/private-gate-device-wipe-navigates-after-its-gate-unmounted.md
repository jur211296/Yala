---
id: private-gate-device-wipe-navigates-after-its-gate-unmounted
status: backlog
priority: low
area: "onboarding, grupos"
created: 2026-09-27
source: "review adversarial de `private-gate-remote-wipe-can-strand-its-arm` (lente de montajes), 2026-09-27"
---

# El borrado del teléfono de la puerta privada sale del Welcome aunque la puerta ya no esté en pantalla

## El síntoma (inferido, sin reproducir)

Elijo «Es mi primera vez → privado» sobre un teléfono con datos, confirmo el borrado, y mientras borra abro una
invitación de grupo. La invitación sustituye la pantalla, pero en cuanto termina el borrado la app sale del Welcome por
el camino privado: relanza, o baja el cover encima de la invitación.

## Lo medido (2026-09-27)

`WelcomePrivateICloudGateView.wipeDevice` no mira la cancelación después de `await deviceCorpus.wipe()`, a propósito:
un borrado consumado tiene que aplicar sus consecuencias. Pero junto a las consecuencias durables (preferencias
residuales, testigo del espejo tardío) también navega: `onProceed()` o `continueWithoutValidating()`.

La `.task(id: phase)` de la puerta solo se cancela si la puerta se desmonta: durante `.wipingDevice` no hay «volver»
y solo esta función cambia la fase. Una invitación de grupo que reemplaza la cadena del Welcome
(`RouterIntent.presentGroupsInviteNeutralGate`) cambia el step y la desmonta (`WelcomeFlowContainer`,
`onChange(of: initialStep)`). Con el mount neutro, `onProceed` → `leaveWelcome(.privateOnboarding)` persiste el
destino del relanzamiento (con su `exit(0)` al pasar a segundo plano) y va a `.mirrorRelaunch`.

**Inferido:** que la invitación llegue justo en esa ventana. El borrado del teléfono es local y corto.

## Por dónde va

El molde que cerró `private-gate-remote-wipe-can-strand-its-arm` en `wipe()`: la cancelación se lee una vez; lo
durable se aplica siempre y la navegación solo con la puerta montada. Aquí lo durable incluye
`markPrivateChoseWithoutICloud()`, que hoy va dentro de `continueWithoutValidating()` junto a `onProceed()`: hay que
separarlos sin duplicar el único escritor del testigo (lo fija `lateWitness_writtenOnContinueOnly`).
