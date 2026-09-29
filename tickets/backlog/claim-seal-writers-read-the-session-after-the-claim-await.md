---
id: claim-seal-writers-read-the-session-after-the-claim-await
status: backlog
priority: very-low
area: "modo-nube, sesión"
created: 2026-09-29
source: "review adversarial de `a-previous-owners-claim-seal-passes-the-cloud-identity-gate` (lente 2, H4)"
---

# El sello del claim se apunta a la cuenta que hay al volver, no a la que mandó el claim

## El problema

Los escritores del sello (`MigrationWorkExecutor.performClaim`, el adopt, `BornCloudSignUpService`) sellan con
`session.currentUserID` leído DESPUÉS del `await` del claim, y el claim viajó con el JWT de antes. Si la sesión cambiara de
cuenta durante esa espera, el sello quedaría a nombre de una cuenta que no reclamó el corpus.

## Qué medir primero (INFERIDO, sin reproducir)

1. Si alguna puerta puede cambiar la sesión con un claim en vuelo (el runner y el Welcome lo impiden por fase; «Nuevo
   grupo» es la candidata).
2. Si no, descartarlo con esa evidencia.
