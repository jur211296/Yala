---
id: blocked-sign-in-still-binds-the-subscription-to-that-account
status: backlog
priority: low
area: "modo-nube, suscripción"
created: 2026-09-16
source: "review adversarial de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de identidad, hallazgo 5), 2026-09-16"
---

# Un inicio de sesión que Yala rechaza vincula igual la suscripción del teléfono a esa cuenta

## El problema, en lenguaje de usuario

Tengo Pro en este iPhone. Toco «Activar la nube» y entro por error con la cuenta de Google de otra persona. Yala me
dice «Esa cuenta ya tiene finanzas personales. No cambiamos nada» y cierra la sesión. Pero mi suscripción ha quedado
vinculada a esa cuenta: cuando Pro se resuelva por cuenta, esa persona tendrá Pro en todos sus dispositivos.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- Todo inicio de sesión lanza `AccountEntitlementService.handleSignIn()` (`CloudAuthService`), que con una
  suscripción firmada en el teléfono hace `bindEntitlement` en paralelo a lo que venga después.
- El servidor aplica «última vinculación gana» (`gateway/src/sync/entitlement.ts`); solo rechaza si la compra declaró
  otra cuenta viva con `appAccountToken`.
- `persist` vuelve a mirar el `userID` antes de guardar en local, pero la escritura en el servidor ya salió.
- **Latente hoy**: `CloudSyncFlags.accountEntitlementEnabled` está apagado (`accountEntitlementCompiledDefault = false`),
  así que ningún cliente resuelve Pro por la cuenta. El vínculo sí se escribe.

**No es solo de «Migrar a la nube»**: cualquier inicio de sesión que acabe rechazado después de firmar (Welcome,
Grupos) tiene la misma forma. Ese ticket lo destapó porque su aviso dice «No cambiamos nada».

## Opciones, sin decidir

- Diferir `handleSignIn` hasta que el flujo que firmó acepte la cuenta.
- Aceptarlo y quitar la frase del aviso.

## Criterios de aceptación

- [ ] Antes de encender `accountEntitlementEnabled`, un inicio de sesión rechazado no deja la suscripción vinculada a
      esa cuenta, o el caso se decide y se documenta como aceptado.

## 2026-09-25 · otra entrada: la firma que la puerta de la nube rechaza

Desde `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` la puerta de «Dónde viven tus datos» cierra la
sesión de otra cuenta que entre por ella. Pero `CloudAuthService.signIn(with:)` ya lanzó
`AccountEntitlementService.handleSignIn()` en un `Task`, y `signOut()` suelta la sesión tras dos `await`: en ese hueco el
`Task` puede vincular la suscripción del teléfono a la cuenta rechazada (leído, sin ejecutar; la caché local la protege
`persist`, el servidor no). Es la misma clase que este ticket.
