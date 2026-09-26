---
id: private-signout-groups-session-expiry-does-not-say-where-to-sign-in
status: backlog
priority: low
area: "groups, sesión, settings"
created: 2026-09-25
source: "residual de `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` (2026-09-25)"
---

# Sin cuenta en la nube, «vuelve a iniciar sesión» tampoco dice dónde

## El problema, en lenguaje de usuario

Uso Yala con mi iCloud y tengo una cuenta para los grupos. Mi sesión de grupos caducó con un gasto de grupo sin subir.
Toco «Cerrar sesión» y Yala me dice «Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.» No dice dónde.

## Lo medido (leído, sin ejecutar, 2026-09-25)

- Desde `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` el cierre **en la nube** enseña su propio
  motivo (`.cloudSessionExpired`) con la puerta nombrada. Las celdas **privadas** (C, D) y la **solo-grupos** (F) siguen con
  `.sessionExpired` y `groups.errors.sessionExpired` (`SignOutBlockedCopy.message`).
- Sesión privada con la sesión de grupos **borrada por el SDK**: la puerta existe —«Dónde viven tus datos» › Grupos en
  `.associatedNeedsSignIn` (`GroupsAssociationLogic.sectionState`)—, pero el aviso no la nombra.
- Sesión privada con la sesión **guardada y rechazada** por el servidor (401 `yala_attest_invalid`): `hasSession` es `true`,
  la sección sale `.associated` y no ofrece entrar. No hay puerta.
- Solo-grupos (F): la sección es `.notApplicable`. La única puerta es «Nuevo grupo» o el estado vacío de Grupos, igual que
  describía el ticket de la nube antes de su arreglo.

## Lo que hay que decidir

¿Un texto por celda que nombre su puerta, y una puerta para la sesión guardada que el servidor rechaza? El molde está en la
nube: la puerta prueba con un ciclo antes de firmar y ata la firma a la cuenta.
