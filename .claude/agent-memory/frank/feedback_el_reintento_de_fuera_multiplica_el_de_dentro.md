---
name: el-reintento-de-fuera-multiplica-el-de-dentro
description: Metí el token que no llega en el reintento corto del cliente sin mirar que el SDK ya reintenta la renovación dos veces — el coste que escribí en el Paso 0 era falso por 3x, y el reintento además tapaba el mutante del orden del testigo
metadata:
  type: feedback
---

**Antes de meter una operación en un reintento, cuenta los reintentos que ya hace la capa de dentro, y escribe el coste
multiplicado.** Y un test de orden sobre algo que se reintenta tiene que contar intentos: el segundo intento puede
«arreglar» el orden roto.

**Why:** el 2026-09-17 (`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`) dejé que el token nulo con la
sesión guardada entrara en el reintento corto de `GroupsMembershipClient.callWithRetry` («la red puede volver entre
intentos») y escribí en el Paso 0 «~4 s más, lo mismo que con el token vigente». Dos lentes de la review, por separado,
leyeron que supabase-swift ya reintenta la renovación dos veces (`RetryRequestInterceptor`, con POST añadido): eran ~7 s sin
red en vez de ~1, y hasta ~9 min en vez de ~3 con una red que cuelga. La tercera lente cazó que ese mismo reintento dejaba
vivo el mutante «testigo leído antes del token»: el primer intento salía pasajero, el segundo leía el testigo ya en `false`
y el test acababa en el `.sessionExpired` esperado. Lo limpio fue quitar el reintento, no justificarlo.

**How to apply:**

- Al envolver con reintento algo que habla con un SDK o un servicio, abre su capa HTTP (interceptores, `retryLimit`,
  timeouts por defecto) antes de escribir el tiempo. «El mismo que con X» es una afirmación medible.
- Si la operación de dentro ya reintenta, el de fuera casi nunca añade opciones: sin red, esperar no sube nada (misma
  lección que `signout-pending-copy-says-wait-seconds-when-offline`).
- En un test de orden o de «se lee después», afirma también cuántas veces se pidió la cosa y cuántas esperas hubo.

Relacionado: [[antes-de-poner-techo-mide-que-la-espera-existe]] · [[review-adversarial-caza-lo-mio]] ·
[[la-asercion-que-no-puede-fallar]].
