---
id: sign-out-blocked-by-a-surviving-session-already-dropped-the-account-caches
status: backlog
priority: low
area: "modo-nube, sesiones"
created: 2026-09-26
updated: 2026-10-08
source: "review adversarial de `sign-out-exits-do-not-verify-the-cloud-session-closed` (2026-09-26)"
---

# Si el cierre se para porque la sesión sigue, la app ya soltó el Pro de la cuenta y otras cachés

## El problema, en lenguaje de usuario

Tocas «Cerrar sesión», la app te dice que tu sesión sigue abierta y que no se borró nada. Pero hasta que reintentes o reabras
la app, puede que el Pro de tu cuenta aparezca apagado y que Grupos no reciba avisos: el cierre ya había soltado esas cosas
antes de descubrir que la sesión no se fue.

## Lo medido (2026-09-26)

- `CloudAuthService.signOut()` borra, ANTES de tocar la sesión, la caché del tipo de cuenta, la marca del adopt, la caché del
  entitlement (re-deriva `isProUser`) y la sesión de Google. Los cierres (`finalizeSessionExit`, `performCloudSecureSignOut`)
  cortan además el motor, el canal de Grupos y desregistran el push token antes de llamarlo.
- Desde `sign-out-exits-do-not-verify-the-cloud-session-closed` esos cierres se PARAN si la sesión sobrevive
  (`.signOutSessionSurvived`), y la persona sigue en la app con ese estado a medias. Es el mismo estado que ya deja el bloqueo
  S2 (lo encolado tras el teardown) y el desasociar parado. El consent de Grupos sí se movió detrás de la comprobación.
- Reintentar o relanzar lo repone todo. Cazado por la review adversarial de ese ticket.

## Qué habría que decidir

Si merece la pena que `signOut()` separe «soltar la sesión» de «soltar lo que cuelga de ella» y los cierres solo hagan lo
segundo con la sesión ida. Toca el orden de un camino que también usan el desasociar y el relevo.

## Medido en 2.1 (triage 2026-10-08)

- `CloudAuthService.signOut(returningToPreviousAccount:)` sigue llamando a `AccountKindService.handleSignOut`, `AdoptSessionOwnership.record(nil)`, `GIDSignIn.signOut()` y `AccountEntitlementService.handleSignOut()` ANTES de leer `storedSessionIsGone`. Solo el perfil capturado y el proveedor se movieron detrás de la comprobación.

Triage 2026-10-08: abierto · low → low · sigue pasando (las cachés se sueltan antes de saber si la sesión se fue), pero solo cuando la sesión sobrevive al cierre, y reintentar o reabrir la app lo repone.
