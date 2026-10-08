---
description: El proxy de IA del gateway y su contrato con la app — tareas, tabla de modelos, cupo de prueba, tamaño de la foto y banco. Se carga al tocar el enrutado de IA, la cuota, el banco o los clientes de IA de la app.
paths:
  - "gateway/src/ai/**"
  - "gateway/src/policy.ts"
  - "gateway/src/rate_limiter.ts"
  - "gateway/src/ratelimit.ts"
  - "gateway/bench/**"
  - "Yala/App/Services/ProxyClientFactory.swift"
  - "Yala/App/Services/ProxyErrorMapper.swift"
  - "Yala/App/Services/ImageVision/**"
  - "Yala/Services/VoiceTranscriptionService.swift"
---

# Proxy de IA: el gateway decide, la app dice qué pide (2026-10-07)

Decisión de Jürgen del 2026-10-07: el gateway elige proveedor, modelo y parámetros de cada llamada de IA, **primero por
calidad medida y después por precio**. La app ya no decide nada: dice qué tarea pide.

## El contrato de la tarea

- **`ProxyTask.rawValue` (app) = clave de `TASKS` (`gateway/src/ai/tasks.ts`).** Cambiar un nombre en un lado rompe el
  enrutado del otro. Lo fijan `ProxyTaskHeaderTests.taskNamesMatchTheGateway` (lee el TS) y `everyCallSiteNamesItsTask`.
- **Con `X-Yala-Task`, el cubo de cuota sale de la tarea**, no de `X-Yala-Category`. La app sigue mandando la categoría
  (derivada de la tarea) para los gateways de antes; si no casa, el gateway da 400. Sin cabecera (versiones instaladas),
  la tarea se deduce y el cubo es el declarado, como siempre.
- **`insights.hero` y `legacy.passthrough` son `deducedOnly`**: solo existen para versiones viejas y no se aceptan por
  cabecera. Una tarea nueva de la app entra en `TASKS`, en `ProxyTask` y en su fila de `ROUTES` el mismo día.

## La tabla (`gateway/src/ai/routes.ts`)

- **Cambiar el modelo de una tarea = editar su fila + `npm test` + desplegar el Worker.** Ninguna release. La fila sale
  del banco y su comentario dice con qué números.
- **Sin cabecera solo sirve OpenAI**: las versiones instaladas dicen en sus permisos que el contenido «se envía a
  OpenAI». Una fila de otro proveedor necesita su `LEGACY_OVERRIDES` de OpenAI, o `routeFor` lanza (test en
  `ai.routing.test.ts`). Encender otro proveedor exige además los textos de permisos y consentimiento en los 16 idiomas,
  la política de privacidad web publicada (producción de la web sigue a la rama 1.0), DPA y clave como secret.
- **Las filas `managed` ignoran los parámetros del cuerpo** (modelo, temperatura, formato): manda la fila. Un
  `maxOutputTokens` demasiado bajo trunca el JSON y la app lo rechaza: se fija con el p99 del banco ×2.

## El cupo de prueba del plan free

- **5 notas de voz y 5 fotos EN TOTAL por instalación** (keyId de App Attest; reinstalar da otro cupo, aceptado por
  Jürgen). `policy.ts` lo declara con `trial`, el Durable Object lo cuenta sin ventana (`rate_limiter.ts`).
- **Una nota = un uso**: transcribir abre la nota (`notePairing: "grant"`) y leerla en los 10 minutos siguientes no gasta
  ni ocupa hueco de ráfaga (`"consume"`). Funciona igual para las versiones instaladas, que no mandan ninguna marca.
- **Un fallo del proveedor (5xx, 429, 408, red) devuelve el uso** (`refundQuota`). Un 4xx del proveedor sí gasta.
- **Agotado: 403 `yala_trial_exhausted`**, que la app enseña como «Ya usaste tus notas/fotos de prueba» con «Ver Yala Pro»
  (`ProxyErrorMapper.isTrialExhausted`). El copy no lleva la cifra a propósito: si el cupo cambia, no caduca.
- **Staging corre `observe` y no bloquea**: el 403 solo se ve en producción. Se verifica con un token de 15 min para un
  dispositivo ficticio y `gateway/scripts/verify-ai.ts --trial`, a ritmo de persona (la ráfaga free es 5/min).

## La foto

- **La app reduce la foto al `maxEdge` de la fila `photo.read`**, que el gateway publica en `/config` (`ai.photoMaxEdge`).
  Sin él, 1536 (`PhotoUploadSizing`). Nunca se amplía. Cambiar el modelo de la foto puede cambiar ese número sin release.
- **El «$» a secas lo decide la divisa principal del usuario** (`VisionCurrencyContext.dollarAlone`): si no se escribe con
  «$», es `null` y se elige en la revisión. El prompt enseña ¥ (JPY o CNY según el texto), R$, zł y CHF.

## El banco (`gateway/bench/`)

- **La clave de OpenAI del banco cobra del mismo saldo prepago que producción** (organización de Yala, proyecto
  AI-bench). Un banco sin tope puede dejar a producción sin crédito: pon tope de gasto por corrida.
- **Los prompts se leen del Swift**: si cambias la firma de la función que los contiene (p. ej.
  `systemPrompt(currency:)`), cambia el marcador en `bench/lib/appRequests.ts`.
- **La latencia se mide en serie y sola** (candado `bench/.latency-lock`); en paralelo sale inflada.
