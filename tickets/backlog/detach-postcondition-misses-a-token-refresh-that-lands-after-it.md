---
id: detach-postcondition-misses-a-token-refresh-that-lands-after-it
status: backlog
priority: low
area: "modo-nube, groups, sesiones"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `detach-does-not-verify-the-cloud-session-actually-closed` (2026-09-26), lentes de secuencia y del testigo"
---

# Un refresco del token que aterriza después de soltar la cuenta de grupos le devuelve la sesión

## El problema, en lenguaje de usuario

Sueltas la cuenta de grupos en Almacenamiento y la app dice que ya no está asociada. Si justo en ese momento la app estaba
renovando la sesión de esa cuenta y la renovación termina un instante después, la sesión vuelve. En el siguiente arranque los
grupos pueden volver a bajar, sin aviso.

## Lo medido y lo inferido (2026-09-26)

- **Medido en supabase-swift 2.50.0:** `LiveSessionManager.remove()` no cancela `inFlightRefreshTask`, y el refresco guarda la
  sesión al recibir la respuesta sin comprobar nada. `signOut()` no para el auto-refresco (lo dice también
  `CloudAuthKeychainStorage.purgeAll`).
- **Cubierto:** si el refresco aterriza ANTES de que `CloudAuthService.signOut()` relea el llavero, el desasociar se para
  (`.sessionNotClosed`) y el reintento la cierra.
- **No cubierto, inferido:** si aterriza DESPUÉS, el resto del gesto es síncrono (puente, borrado, `finishDetach`) y termina.
  El `/token` se reintenta dos veces con timeout de URLSession, así que con una red mala la ventana puede ser de minutos. El
  `/logout` local revoca el refresh token si llegó al servidor; sin red no llega, y la sesión repuesta es válida del todo.
- **No medido:** si el gateway rechaza un access token de una sesión revocada antes de que caduque (hasta 1 h).

## Qué habría que decidir

Una segunda comprobación que no dependa del instante: por ejemplo, que el registrador del arranque o `startIfEligible`, con
la asociación ya limpia por un desasociar, cierre esa sesión en vez de usarla. O parar el auto-refresco del SDK antes del
cierre (`stopAutoRefresh`) y reanudarlo si el gesto se para. Cualquiera de las dos toca cómo arranca Grupos.
