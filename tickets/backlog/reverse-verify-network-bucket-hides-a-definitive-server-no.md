---
id: reverse-verify-network-bucket-hides-a-definitive-server-no
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` (2026-09-21), lente de la máquina — confirmado midiendo la cadena entera"
---

# Un «no» definitivo del servidor que llega por el Merkle se lee como falta de cobertura, y ahora espera 72 horas

## El problema, en lenguaje de usuario

Estoy volviendo a iCloud y mi cuenta en la nube deja de estar disponible justo en el paso de comprobación. La app no me
dice nada: la barra se queda parada en «Comprobando que todo llegó…» y ahí sigue **tres días**, como si fuera mi
conexión. No es mi conexión, y esperar no lo arregla.

Lo mismo si lo que falla es la base de datos local del teléfono al leer la cola de subida: la app lo lee como «no hay
red» y espera igual.

## Por qué pasa (medido el 2026-09-21)

La cadena, leída entera:

1. `SyncMerkleClient.fetchMerkle` sí distingue: `401 → .sessionExpired`, `403 → .accountUnavailable`, resto `.transient`.
2. **`SyncMerkle` lo aplana**: `guard case .snapshot(let remote) = outcome else { return .skipped(reason: "fetch-failed") }`.
   Los tres desenlaces mueren ahí y salen con la misma palabra.
3. `VerifyProbeMapping.map` manda `"fetch-failed"` —y también `"outbox-fetch-failed"`, `"quarantine-fetch-failed"` y el
   `default` de cualquier `reason` que este build no conozca— a **`.networkTimeout`**.
4. Desde el 2026-09-21 `driveReverseVerify` manda `.networkTimeout` al techo de la etapa con `blocker: nil`, o sea al
   presupuesto **LARGO: 259 200 s (72 h)**.

Así que `.networkTimeout` no es «no hay red»: es un cajón que incluye un `403` definitivo, un `401`, dos `fetch` de
SwiftData que lanzaron y cualquier motivo futuro. Para la mitad que **no es red**, el techo largo es generoso: no se va
a resolver sola.

**El alcance está acotado, y conviene decirlo.** En `verify()` el push y el pull corren ANTES del Merkle y los dos
tipan su 401 y su 403 (`.sessionExpired` / `.blocked(.accountUnavailable)`). La ventana es la del `403` (o `401`) que
empieza **entre el pull y el Merkle**, más los fallos locales de SwiftData, más un `reason` futuro. Con el outbox vacío
—el caso normal de la vuelta, que no sube— el push se salta entero, así que el único filtro previo es el pull.

**Qué se perdió y qué se ganó.** Antes de ese ticket esta mitad gastaba los 8 reintentos de red y degradaba a
`reverseFailedRollback` en minutos: un terminal feo, pero **visible**, con su tarjeta y su «Reintentar». Ahora espera
en silencio. El canario `cloudReversePreMountWaiting` se emite en cada observación, así que a nivel de flota sigue
siendo visible; a nivel de dispositivo, no.

No se arregló en el ticket que lo destapó porque el arreglo está **aguas arriba**, en `SyncMerkle`, que comparten la
ida y el motor de sincronización: es alcance propio con su propia QA.

## Qué habría que decidir antes de hacerlo

1. **Dónde se tipa.** Lo natural es que `SyncMerkle` deje de aplanar y propague `.sessionExpired` /
   `.accountUnavailable` como hacen el push y el pull. Eso toca a los tres consumidores, no solo a la vuelta.
2. **Qué hace la IDA con lo tipado.** Hoy la ida agrupa red, sesión y `blocked` en su rama de red a propósito
   (`forward-verify-reads-an-expired-session-as-network`). Si el Merkle empieza a tipar, la ida hereda la pregunta.
3. **Los fallos LOCALES** (`outbox-fetch-failed`, `quarantine-fetch-failed`) no son del servidor ni de la red: ¿techo
   corto, terminal propio, o se quedan donde están?
4. **El `default` de un `reason` futuro.** Hoy cae en «conservador». Con el techo largo detrás, «conservador» significa
   72 h; puede que ya no sea la lectura conservadora.

## Criterios de aceptación

- [ ] Decidido 1-4 antes de tocar código.
- [ ] Un `403` que solo ve el Merkle elige el techo CORTO en la vuelta, o el terminal que se decida.
- [ ] Un `401` que solo ve el Merkle enciende el aviso de «vuelve a entrar» de la vuelta (hoy no: `lastReverseSessionExpiry`
      solo lo escribe la rama `.sessionExpired` de `driveReverseVerify`, a la que ese 401 no llega).
- [ ] La IDA no cambia sin que se decida (test que lo fije, como los que ya hay).

## Relacionado

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el que metió la red en el techo y destapó esto.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el techo de la etapa.
- `forward-verify-reads-an-expired-session-as-network` — la misma pregunta por el lado de la ida.
