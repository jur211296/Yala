---
id: sign-out-exits-do-not-verify-the-cloud-session-closed
status: backlog
priority: medium
area: "modo-nube, sesiones"
created: 2026-09-26
updated: 2026-09-26
source: "Paso 0 de `detach-does-not-verify-the-cloud-session-actually-closed` (2026-09-26): la premisa del ticket, medida"
---

# Si la sesión en la nube sobrevive a «Cerrar sesión», el teléfono queda como recién instalado con esa sesión dentro

## El problema, en lenguaje de usuario

Cierras sesión, la app se reinicia y enseña la bienvenida como si el teléfono fuera nuevo. Si en ese cierre la sesión de tu
cuenta en la nube no se borró del teléfono, sigue ahí: la siguiente persona que use el teléfono, o tú al volver a entrar con
otra cuenta, arranca con la sesión anterior viva, y Grupos puede bajar los grupos de quien cerró.

## Lo medido (2026-09-26)

- El ticket `detach-does-not-verify-the-cloud-session-actually-closed` decía que los cierres de sesión «se pueden permitir» no
  comprobar el `signOut()` porque terminan en `armSignOutWipe` y relanzan. **No es así:** el boot-wipe
  (`SwiftDataConfiguration.performSignOutWipeIfArmed`) borra ficheros de stores y preferencias, pero no toca el llavero de
  la sesión (`CloudAuthKeychainStorage`, service `com.yala.cloudauth`). Solo lo purga `CloudSessionRetirement`, que arma
  «Empezar desde cero» y el primer arranque tras instalar.
- Medido en supabase-swift 2.50.0 (`SupabaseSignOutContractTests`): la sesión sobrevive a `signOut(scope: .local)` sin que
  lance si el llavero no la deja borrar; y un refresco del token en vuelo la repone.
- Desde el 2026-09-26 `CloudAuthService.signOut()` devuelve si la sesión se fue (`sessionIsGone`, fallo cerrado), y los cuatro
  cierres de `CloudSessionSignOut` (`:862`, `:1098`, `:1288`, `:1330`, medido en la rama del arreglo) lo descartan. Y con la sesión
  superviviente ya no borra el perfil capturado ni el proveedor: quedan con la sesión que describen.

## Qué habría que decidir

O los cierres comprueban el `signOut()` antes de armar el borrado —y entonces hay que elegir qué enseñan y si reintentan,
porque algunos ya soltaron cosas que no vuelven—, o el boot-wipe purga también la sesión del llavero, como ya hace el retiro
de «Empezar desde cero». La segunda es más barata, pero `purgeAll()` se lleva además los pares de SIWA y de Google, que
`signOut()` conserva a propósito: eso es una decisión.
