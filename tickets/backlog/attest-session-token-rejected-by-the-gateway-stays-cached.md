---
id: attest-session-token-rejected-by-the-gateway-stays-cached
status: backlog
priority: low
area: "attest, gateway, groups"
created: 2026-09-15
updated: 2026-09-15
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
  pull personales lo leen como sesión caducada y cortan el ciclo antes de llegar a Grupos
  (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`).
- Sin medir: cada cuánto rota el secreto (es una operación manual), cuánta gente tiene el reloj atrasado, y qué hace
  el proxy de IA con su propio 401 de un token rechazado.

## Lo que hay que decidir

1. Descartar el token guardado al recibir un 401 de attest, desde un solo punto de decisión (molde
   `AttestKeyRecoveryLogic`) y sin saltarse el single-flight ni la escalera de `AttestRefreshBackoffLogic`.
2. Dejarlo: el daño dura como mucho lo que le queda al token (15 min) y exige un evento raro.

## Relación con otros tickets

- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — de donde sale.
- `.claude/rules/gateway-attest.md` — la caché negativa, la escalera y los dos 401 de la guard.
