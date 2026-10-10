---
id: born-cloud-sign-up-over-mirror-imported-rows-skips-the-corpus-check
status: backlog
priority: low
area: "modo-nube, onboarding"
created: 2026-09-29
source: "review adversarial de `groups-invite-neutral-gate-has-no-way-out-when-the-exit-cell-cannot-wipe` (2026-09-29), lente de datos cruzados. INFERIDO: medir antes de trabajarlo"
updated: 2026-10-08
---

# El alta nacida en la nube no mira si el espejo ya bajó filas del Apple ID

## Lo que dijo la lente (inferido, confianza baja)

`WelcomeCloudSignInView.runBornCloudFlow` escribe el par `.cloud` (`BornCloudSignUpService.activateBornCloudStorage`)
sin consultar `hasLocalDataNow`. Si el mount de ese proceso ya llevaba el espejo, sale por el terminal `.relaunch`; al
reabrir, el store monta `.cloudMirrorOff`, con el onboarding sin terminar y **con las filas que el espejo importó del
Apple ID del teléfono**. El motor las subiría a la cuenta nueva: el corpus de quien es dueño del Apple ID, en la cuenta
de la nube de otra persona.

No lo causa el arreglo del invitado; ese solo deja que una invitación siga encima, y el grupo va a la cuenta de la
sesión activa, no a un iCloud.

## Medir primero

1. ¿Puede llegar el alta nacida en la nube con filas importadas? (Las puertas del Welcome —`WelcomePrivateICloudGate`,
   el guard cross-cuenta— pueden cortarlo antes.)
2. Si llega, ¿qué sube el motor en el primer arranque `.cloud`?

## Cómo se sabe que está bien

Un alta nacida en la nube nunca sube filas que no escribió esa persona.

## Medido en 2.1 (triage 2026-10-08)

- `WelcomeCloudSignInView.runBornCloudFlow` sigue llamando a `service.activateBornCloudStorage(mountedDecision:context:)` en `.activateStorageAndRelaunch` sin mirar antes si el store tiene filas importadas; ningún commit desde el 2026-09-29 añade esa comprobación.
- Sigue sin medir si se llega ahí con el espejo ya montado y filas importadas. Si la medida lo confirma, sube a `very-high`: es el corpus de otra persona en una cuenta ajena.

Triage 2026-10-08: abierto · low → low · el chequeo de corpus sigue sin existir, pero el camino es inferido con confianza baja y las puertas del Welcome pueden cortarlo; medir antes.
