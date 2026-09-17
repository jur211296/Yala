---
id: attest-session-token-rejected-by-the-gateway-stays-cached
status: backlog
priority: low
area: "attest, gateway, groups"
created: 2026-09-15
updated: 2026-09-16
source: "review adversarial de `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` (2026-09-15)"
---

# Un token de App Attest que el gateway ya rechaza sigue guardado en el teléfono

## El problema, en lenguaje de usuario

Tras un cambio en el servidor, o con la hora del teléfono atrasada, los cambios de mis grupos dejan de subir durante
unos minutos aunque la red y la sesión estén bien. Se arregla solo, cuando caduca lo que el teléfono tenía guardado.

## Lo medido (leído en el código, sin ejecutar)

- `AppAttestClient.currentSessionToken()` devuelve el token guardado mientras su caducidad supere el reloj LOCAL más
  `refreshMargin`, 30 s (`Yala/App/Services/AppAttestClient.swift:82`). El token dura 15 min
  (`SESSION_TTL_SECONDS`, `gateway/src/attest/session.ts`).
- El gateway lo verifica con `jwtVerify`, con su propio reloj y con `JWT_SIGNING_SECRET` (`verifySessionToken`). Si
  falla —el secreto rotó, o el reloj del teléfono va más de 30 s por detrás en el último tramo del token—, las rutas
  de Grupos, `/sync/*` y `/prefs/*` responden 401 `yala_attest_required`.
- Nada en el cliente descarta el token guardado al recibir ese 401: cada petición reenvía el mismo hasta que caduca
  según el reloj del teléfono.
- Desde el 2026-09-15 el canal de Grupos lee ese 401 como pasajero y reintenta con backoff
  (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`); antes paraba el loop. En `.cloud`, el push y el
  pull personales también desde el 2026-09-16 (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`),
  **pero sin sumar a la racha**: su puerta ya consiguió el token, así que ese 401 no habla del teléfono. Lo cuenta el
  canario `cloudSyncAttestRequired`. Un push personal que falla así corta el ciclo antes de Grupos hasta que el token
  caduca en el reloj del teléfono.
- Sin medir: cada cuánto rota el secreto (es una operación manual), cuánta gente tiene el reloj atrasado, y qué hace
  el proxy de IA con su propio 401 de un token rechazado.

**Desde el 2026-09-15 este caso puede acabar ofreciendo perder cambios** (review adversarial de
`groups-phone-that-never-attests-is-told-to-retry-forever`). Con el reloj del teléfono 24 h o más por detrás y el proceso
vivo más de un día, el token cacheado da 401 `yala_attest_required` durante más de 24 h aunque cada assertion saldría bien.
Eso cumple el veredicto terminal de Grupos, y el cierre de sesión ofrecería «Cerrar sesión y perderlos» a un teléfono que
sí atesta. El límite de «15 min» de arriba solo vale con el reloj atrasado menos de 15 min.

**Matiz desde el 2026-09-15** (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`), **re-medido el
2026-09-16 y sigue en pie**: `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` probó a quitarlo y su review
lo devolvió. La racha es del teléfono y el motor personal la borra con cualquier token conseguido, también uno cacheado. En `.cloud`, el paso 1 del cierre
borra esa racha falsa antes de que llegue el de grupos, así que el párrafo de arriba solo sigue siendo cierto en los cierres
de `.icloud` y de solo grupos.

## Lo que hay que decidir

1. Descartar el token guardado al recibir un 401 de attest, desde un solo punto de decisión (molde
   `AttestKeyRecoveryLogic`) y sin saltarse el single-flight ni la escalera de `AttestRefreshBackoffLogic`.
2. Dejarlo: el daño dura como mucho lo que le queda al token (15 min) y exige un evento raro.

## Relación con otros tickets

- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — de donde sale.
- `.claude/rules/gateway-attest.md` — la caché negativa, la escalera y los dos 401 de la guard.
