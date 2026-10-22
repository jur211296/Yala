---
id: google-signup-with-reused-credential-leaves-no-sdk-session-to-revoke
status: backlog
priority: low
area: "modo-nube, google, borrado de cuenta"
created: 2026-10-14
updated: 2026-10-14
source: "Frank, implementando vb1f (entrar con Google cuando este iPhone ya tiene cuenta con Apple, opción C), 2026-10-14"
---

# Quien crea su cuenta con la credencial de Google reusada no revoca el permiso de Google al borrarla

## Qué pasa

Desde vb1f, «Registrarse con Google» tras «Esa cuenta usa otro método» (o tras «No encontramos una cuenta») no vuelve a
abrir la hoja de Google: canjea con Supabase la credencial del intento anterior
(`CloudAuthService.signInWithReusedGoogleCredential`). Entre medias, la pantalla suelta la sesión del intento con
`CloudAuthService.signOut()`, que llama a `GIDSignIn.sharedInstance.signOut()` (higiene H6). Así que la cuenta nace con
sesión de Supabase y **sin sesión del SDK de Google**.

Si esa persona borra su cuenta más tarde, `GoogleTokenRevocation` busca el usuario del SDK (`currentUser` o
`restorePreviousSignIn()`), no lo encuentra y hace el skip documentado `no-sdk-session`: el permiso OAuth de Google
queda vivo, con un token inerte. Es el mismo residual que ya existe tras reinstalar la app (D1 del plan de la sesión 1),
ahora con una población más.

**Inferido del código, no medido en device.** No se sabe si `GIDSignIn.signOut()` borra también lo que
`hasPreviousSignIn()` restauraría.

## Por qué no se tocó en vb1f

La revocación de Google es best-effort por diseño (la guideline 5.1.1(v) solo exige formalmente la de Apple) y no
bloquea el borrado. Arreglarlo pide cambiar qué cierra `signOut()` en el SDK, que protege la frontera entre dos personas
en el mismo teléfono: es otra decisión.

## Opciones

1. No llamar a `GIDSignIn.signOut()` en la salida del «otro método» cuando la credencial se recoge para reusarla, y
   cerrarla si al final no se usa. Exige mirar el match doble de `GoogleTokenRevocation` contra ese caso.
2. Aceptarlo como residual y escribirlo junto al de la reinstalación.
