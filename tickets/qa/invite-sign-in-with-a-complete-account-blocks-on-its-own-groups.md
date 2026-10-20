---
id: invite-sign-in-with-a-complete-account-blocks-on-its-own-groups
status: qa
priority: medium
area: "groups, modo-nube, onboarding"
created: 2026-10-19
updated: 2026-10-19
source: "tablero-unirse-por-enlace-en-una-instalacion-nue-t2q8 (QA guiado 2026-10-19)"
---

# Unirse por enlace con una cuenta completa bloquea por «datos de otra cuenta» que son sus propios grupos

## En lenguaje de usuario

En una instalación nueva abro un enlace de invitación, toco «Unirme al grupo» y entro con mi cuenta de la nube (completa). Me dice «Este dispositivo tiene datos de otra cuenta». Por «Ya tengo una cuenta» entro sin problema.

## Lo medido (2026-10-19)

- Con una cuenta completa, la hoja de Grupos firma con destino `.adoptAsCompleteAndOpenGroups` y **arranca el canal de Grupos en el callback de éxito** (`GroupsBackendInviteModifier`). El canal baja los grupos de esa cuenta.
- Después la persona sigue por el alta de la nube del Welcome (`adoptCompleteAccountFromGroups`), cuyo guard cross-cuenta (`CrossAccountEntryGuardLogic`, `hasLocalDataNow` = `checkHasExistingData`) **cuenta `SplitGroup`**: ve los grupos recién bajados y bloquea.
- «Ya tengo una cuenta» no arranca ningún canal antes de su guard: por eso entraba.

## Lo que cambia

Con destino `.adoptAsCompleteAndOpenGroups` (y el bloqueado) la hoja no arranca el canal (`GroupsSignInChannelStartLogic.startsChannelAtSignIn`). Lo arranca quien termina el alta: el arranque, el primer plano o el motor de la nube. Con los demás destinos, como siempre.

## Tests

`InviteFreshInstallEntryTests`: la tabla con controles, y las dos puertas (Welcome y enlace) dejando entrar en la celda del QA, con el control de datos ajenos de verdad bloqueando. Scan del cableado en `InviteFreshInstallEntryWiringTests`.

## Lo que NO cierra

El arranque en frío y la vuelta a primer plano también arrancan el canal: si caen entre la firma y el guard, el bloqueo vuelve. `complete-account-invite-adopt-can-pull-groups-before-the-guard`.

## Device-QA (Jürgen, iPad, TestFlight 19)

1. Borra Yala, reinstala sin abrir, abre el enlace de «QA unión».
2. «Unirme al grupo» › Google `jur211296@gmail.com` (cuenta completa).
3. Esperado: no sale «Este dispositivo tiene datos de otra cuenta»; entra en su cuenta y el grupo aparece.
