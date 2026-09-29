---
id: born-cloud-sign-up-over-mirror-imported-rows-skips-the-corpus-check
status: backlog
priority: low
area: "modo-nube, onboarding"
created: 2026-09-29
source: "review adversarial de `groups-invite-neutral-gate-has-no-way-out-when-the-exit-cell-cannot-wipe` (2026-09-29), lente de datos cruzados. INFERIDO: medir antes de trabajarlo"
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
