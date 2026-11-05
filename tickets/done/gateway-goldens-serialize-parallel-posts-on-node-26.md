---
id: gateway-goldens-serialize-parallel-posts-on-node-26
status: done
priority: medium
area: gateway, tests
created: 2026-10-12
updated: 2026-11-04
source: card del tablero «Los goldens del gateway hacen en serie las llamadas que el Worker lanza en paralelo: el fetch de Node 26 encola los POST»
---

# Los goldens del gateway hacen en serie las llamadas que el Worker lanza en paralelo

## Qué pasaba

Con Node 26.3.1 (undici 8.5.0 dentro), 20 POST en `Promise.all` a staging tardaban lo mismo que 20 en serie. Un pull de
Grupos son 5 POST por grupo, así que en los goldens cada grupo costaba ~0,9 s: G2·7 tardaba 294 s de sus 360 de timeout
(medido el 2026-10-12). En el Worker real (Cloudflare) no aplica: es el arnés de test en Node.

## Lo medido (2026-11-04, Node 26.3.1)

Sonda de POST `/metrics` a staging (cuerpo inválido → 400, no escribe nada):

| `fetch` | 1 POST | 20 POST en paralelo |
|---|---|---|
| el de Node 26 | ~100 ms | ~2 000 ms |
| el de Node 26 con dispatcher HTTP/1 de undici 7 (`setGlobalDispatcher`) | ~100 ms | ~2 100 ms: lo ignora |
| el de undici 7, `Agent({ allowH2: false })` | ~100 ms (290 el primero, con su conexión) | **~340 ms** |

## Arreglo

`gateway/test/setup.fetch-http1.ts`, `setupFiles` de vitest: el `fetch` global de los tests pasa a ser el de undici 7
(`devDependency` fijada a 7.24.8, la misma que ya traía wrangler) con HTTP/1. Fijar Node 24 se descartó: el CI y las dos
Mac ya están en 26.

| Goldens de Grupos (25 tests, staging) | Antes | Después |
|---|---|---|
| Fichero entero | 370 s | **42 s** |
| G2·7 (timeout 360 s) | 193 s | **10,3 s** (1/35 del timeout) |
| G3·3-ter | 56 s | 3,1 s |
| G7 roundtrip | 38 s | 3,6 s |

Los otros goldens de staging (`account`, `sync`, `push.fanout`: 58 tests) siguen en verde con el arreglo, y la suite
offline entera también.
