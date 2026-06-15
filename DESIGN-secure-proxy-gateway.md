# Diseño — Gateway seguro para OpenAI + tasas de cambio (Yala 2.0)

**Estado:** BORRADOR PARA APROBACIÓN DEL OWNER · **Fecha:** 2026-06-15 · **Versión: DEFINITIVA (todo en un solo épico, sin deferrals)**
**Responde a:** `AUDIT-security.md` (🔴 crítico — API key en el binario) y la D-C `[2026-06-10]` de `DECISIONS.md`.
**No implementar hasta aprobar.** Este documento es el entregable previo a cualquier código.

---

## 0. Premisas (input del owner)

| Decisión | Elección | Implicación |
|---|---|---|
| **Robustez** | "Solución **robusta y definitiva**, todo de una vez" | Sin fases-como-deferral, sin "v2". Lo que históricamente puse en v2 (verificación de suscripción server-side) **entra**. El forward queda **streaming-ready** de fábrica. |
| **Alcance** | OpenAI + exchange-rate juntos | El cliente queda **sin ningún secreto** en la misma entrega. |
| **Costo** | **Workers Paid $5/mes — ✅ APROBADO** | El owner aprobó el pago mensual. Sin fallback $0. |
| **Dominio** | **`*.workers.dev` — ✅ decidido** | Cero cambios de DNS → no se toca el sitio web ni los universal links de `yala-app.pe`. El usuario nunca ve esta URL (§5). |
| **Política Free/Pro** | **✅ resuelta por revisión de código** | Toda la IA es Pro; cuota de trial para no-Pro (§10). |

> Las 4 decisiones abiertas quedaron cerradas (ver §"Decisiones cerradas" al final). Listo para construir.

---

## 1. El problema en una línea

El cliente iOS llama **directo** a OpenAI y a exchangerate.host con keys inyectadas desde `Secrets.xcconfig` → `Info.plist` → extraíbles en texto plano del IPA (un agente sacó la `sk-proj-…` real del archive de build 18). El "rate-limit" es client-side (`UserDefaults`), trivialmente ignorable con la key robada. **Blast radius: la factura/cuota de OpenAI del owner.**

## 2. Objetivos (los 4 originales + el 5º que completa "definitivo")

1. Keys **server-side** (nunca en el cliente).
2. Validar que el request viene de la app legítima vía **App Attest**.
3. **Rate-limit y cuota server-side** por device.
4. **Rotar keys sin un release** de la app.
5. **(definitivo)** **Verificar la suscripción Pro server-side** (firma de Apple) para que #3 sea confiable y un cliente modificado no consuma la IA cara saltándose el gate Pro.

---

## 3. Hechos verificados en el código (base del diseño)

Auditado en esta sesión (file:line reales).

### 3.1 Ningún servicio usa streaming hoy ✅
Las **8** llamadas LLM son request/response simple (`stream: false`). El proxy no necesita SSE hoy — pero igual lo diseñamos como passthrough genérico (§14), así streaming "just works" el día que se active en el cliente.

### 3.2 SDK uniforme: MacPaw/OpenAI **0.4.7**, con soporte de proxy de fábrica ✅
Los 8 servicios usan `OpenAI(apiToken: apiKey)`. Su `Configuration` ya soporta proxy (doc textual del SDK):
- `token: String?` → **`nil`**: *"works when you have a proxy server that manages authentication."*
- `host`, `basePath`, `scheme`, `port`, `timeoutInterval`, `customHeaders: [String:String]`.

**Consecuencia:** migrar el cliente **no reescribe los servicios** — se cambia el *constructor* del cliente (un factory) + se adjunta el header de sesión. La lógica de chat/transcripción/visión queda intacta.

### 3.3 Inventario de servicios a migrar

| Servicio | Archivo | Endpoint OpenAI | Modelo | Datos que envía |
|---|---|---|---|---|
| ChatAssistantService | `Yala/Services/ChatAssistantService.swift:35` | chat/completions | `gpt4_1_mini` | **Contexto financiero completo (JSON)** |
| InsightsLLMService | `Yala/Services/InsightsLLMService.swift:86` | chat/completions | `gpt4_1_mini` | Agregados financieros |
| VoiceTranscriptionService | `Yala/Services/VoiceTranscriptionService.swift:102` | audio/transcriptions | `whisper_1` | Audio m4a |
| TranscriptionParserService | `Yala/Services/TranscriptionParserService.swift:108` | chat/completions | `gpt4_1_mini` | Texto + subcategorías |
| ChatIntentClassifierService | `Yala/Services/Chat/ChatIntentClassifierService.swift:47` | chat/completions | `gpt4_1_nano` | Solo texto ← **se construye primero** |
| ChatSuggestionsLLMService | `Yala/App/Services/ChatSuggestionsLLMService.swift:32` | chat/completions | `gpt4_1_nano` | Contexto del mes |
| SuggestionsRewriterService | `Yala/App/Services/SuggestionsRewriterService.swift:36` | chat/completions | `gpt4_1_mini` | Whitelist (condicional) |
| ImageVisionService | `Yala/App/Services/ImageVision/ImageVisionService.swift:87` | chat/completions (vision) | `gpt4_1_nano` | Imagen JPEG |
| ExchangeRateAPIService | `Yala/Services/ExchangeRateAPIService.swift:66` | exchangerate.host `/live`, `/timeframe` | — | Solo monedas (no PII) |

Vision = `chat/completions` con `image_url`/base64 → solo hacen falta `/v1/chat/completions` y `/v1/audio/transcriptions`.

### 3.4 Estado actual relevante
- **Rate-limit:** client-side, 75/día en `UserDefaults` (`ChatAssistantService.swift:52-75`), 5s entre requests, timeout 20s. Sin distinción Free/Pro en el servicio.
- **Pro:** `StoreKitManager.isProUser` (StoreKit 2, `:32`) → `FeatureGateService` (`chatAssistant` es Pro-only, gateado solo en UI).
- **Identidad de device:** no hay UUID de instalación persistido. App Attest / DeviceCheck: **inexistentes** hoy.
- **Keys:** `APIKeyService.swift:17-26` (OpenAI), `ExchangeRateAPIService.swift:66-75` (exchange), `Info.plist:20-23`, `Secrets.xcconfig` (raíz, gitignored). `TELEMETRY_DECK_APP_ID` **se queda** en el cliente (no es secreto crítico).

---

## 4. Decisiones de diseño (firmes)

| # | Decisión | Razón |
|---|---|---|
| D1 | **Proxy transparente OpenAI-compatible** | El SDK MacPaw apunta ahí cambiando `host`/`basePath`; cero reescritura de servicios. |
| D2 | **App Attest** (no DeviceCheck) | Prueba "app genuina en device genuino" Y da una llave estable (keyId) para anclar cuota y entitlement. iOS 26+ → universal. |
| D3 | **Challenge → assertion → JWT de sesión corto (≤15 min)** | Compatible con el proxy transparente; el threat (anti-abuso de cuota) no requiere firmar cada body. Amortiza latencia. Token efímero + revocable + rate-limited = blast radius mínimo. |
| D4 | **Verificación de entitlement Pro server-side por firma de Apple** | El cliente envía su **transacción StoreKit 2 firmada (JWS)**; el Worker verifica la cadena contra la **Apple Root CA G3** (offline, sin llamada a Apple) y guarda el entitlement por keyId. Complemento: webhook **App Store Server Notifications V2** para renovación/cancelación/reembolso. Hace #3 **no falsificable**. |
| D5 | **El proxy NO loguea bodies** | Solo metadata (keyId hasheado, endpoint, modelo, status, latencia, tokens). No anonimiza (rompería la IA); su deber es **no persistir**. |
| D6 | **Secretos solo como Worker secrets** | Rotar = `wrangler secret put` → instantáneo, **sin release**. |
| D7 | **Forward genérico streaming-ready** | El Worker reenvía el cuerpo como stream (`ReadableStream`), no buffer. Streaming SSE funciona el día que el cliente ponga `stream:true`, sin tocar el proxy. |
| D8 | **Bypass de dev/test gateado a entorno no-prod** | App Attest no corre en simulador. Builds `DEV_BUILD`/`-uitest` → Worker `staging` con shared-secret. **Prod nunca acepta el bypass.** Mantiene simulador + XCUITests vivos sin debilitar prod. |
| D9 | **No body-binding criptográfico** (exclusión por diseño, no deferral) | Firmar el body exacto exigiría abandonar el SDK (reescribir todo a URLSession) por una ganancia nula para este threat (no defendemos integridad de contenido, sino robo de key). Es la decisión correcta, no un atajo. |

---

## 5. Stack y costo — recomendación final

### Recomendación: **Cloudflare Workers Paid ($5/mes)**

Para "robusto y definitivo", **$5/mes es la decisión correcta** para una app comercial con suscripción. Qué compra exactamente ese $5 (y por qué importa):

| Compra | Por qué importa para "definitivo" |
|---|---|
| **CPU 30s/request** (vs 10ms en free) | La verificación de attestation (CBOR + cadena X.509) y de la firma StoreKit son pesadas. En free tendríamos que rezar para caber en 10ms; en Paid **nunca** es un problema. Robustez real. |
| **Durable Objects** | El primitivo **correcto** para rate-limit por device: objeto single-threaded, fuertemente consistente, sin races. En free no existe → habría que emular con upserts en D1 (tolerable, pero no "definitivo"). |
| **Sin techo de escrituras** | Free limita escrituras (KV 1k/día); Paid lo vuelve un no-problema cuando la base de usuarios crezca. |
| Todo lo demás (req, D1, Cache API, custom domain) | Holgado. |

**Stack definitivo:**
- **Cloudflare Workers Paid** — runtime + secrets.
- **Durable Objects** — contadores de cuota por keyId (consistencia fuerte).
- **D1 (SQLite)** — registro de keys App Attest + cache de entitlement Pro.
- **KV** — nonces de challenge (TTL nativo) + denylist de tokens revocados.
- **Cache API** — caché de tasas de cambio (no son por-usuario → se sirven a todos desde el edge; colapsa N llamadas en pocas).
- **Dominio: `*.workers.dev`** (ej. `yala-proxy.<cuenta>.workers.dev`) — **✅ decisión: cero cambios de DNS**, así no se cae ni el sitio web (Vercel) ni los universal links de invitaciones (`yala-app.pe`). El usuario nunca ve esta URL → un dominio "bonito" no aporta nada. `api.yala-app.pe` queda como mejora cosmética **opcional y aislada** para después (requeriría mover el DNS a Cloudflare; fuera de este épico).

**Total: $5/mes de hosting.** OpenAI sigue siendo passthrough (mismo costo de tokens); exchange-rate **baja** por el cache de edge.

### Costo: ✅ aprobado
El owner aprobó **Workers Paid $5/mes**. No se usa el free tier.

---

## 6. Arquitectura

```
┌─────────────┐  1. register (1×/install): attestation + JWS StoreKit  ┌────────────────────────────┐   key real   ┌────────────┐
│  App iOS    │ ──────────────────────────────────────────────────────▶│  Cloudflare Worker (Paid)   │ ───────────▶ │  OpenAI    │
│ (sin keys)  │  2. refresh (~15 min): assertion → JWT de sesión        │  • verifica App Attest      │ ◀─────────── │            │
│             │  3. requests + Bearer JWT (vía customHeaders del SDK)   │  • verifica entitlement     │   verbatim   └────────────┘
│ MacPaw SDK  │ ◀──────────────────────────────────────────────────────│  • rate-limit (Durable Obj) │ ───────────▶ exchangerate.host
│ host=proxy  │     respuesta OpenAI / tasas (stream passthrough)       │  • NO loguea bodies         │              (Cache API edge)
└─────────────┘                                                         │  Secrets: OPENAI, EXRATE…   │
                                                                        │  D1: keys+entitlement · DO: cuota · KV: nonces │
                                                                        │  Webhook: App Store Notifications V2           │
                                                                        └────────────────────────────┘
```

---

## 7. Flujo de seguridad (detallado)

**Registro (1× por instalación):**
1. `DCAppAttestService.generateKey()` → `keyId` (llave en Secure Enclave, nunca sale).
2. `POST /v1/attest/challenge` → `nonce` (one-time, KV con TTL ~2 min).
3. `attestKey(keyId, SHA256(nonce))` → `attestation` (CBOR). Además, el cliente lee su transacción StoreKit 2 actual → `jwsRepresentation`.
4. `POST /v1/attest/register { keyId, attestation, nonce, storeKitJWS? }`.
5. Worker: decodifica CBOR → valida **cadena X.509 contra App Attest Root CA de Apple** → `rpId == SHA256(teamId.bundleId)` → nonce válido/no usado → guarda `(keyId, publicKey, counter=0)` en D1. Si hay `storeKitJWS`: verifica firma contra **Apple Root CA G3** (offline) → guarda `entitlement_product`, `entitlement_expires_at`, `original_transaction_id`. → emite `{ sessionToken (JWT HMAC, exp ≤15 min, claims: keyId + tier), exp }`.

**Refresh de sesión (cada ≤15 min o ante 401):**
- `challenge` → `generateAssertion(keyId, SHA256(nonce))` → `POST /v1/attest/assert` → Worker verifica firma con la `publicKey` guardada + `counter` **estrictamente creciente** (anti-replay) → re-evalúa entitlement (re-verifica JWS o consulta el cache actualizado por el webhook) → emite nuevo JWT.

**Cada request normal:**
- `Authorization: Bearer <sessionToken>` (vía `customHeaders` del SDK) → Worker verifica JWT (stateless) → chequea entitlement+cuota (política §10, contador en Durable Object) → inyecta key real → forward (stream passthrough) → respuesta verbatim.

**App Store Server Notifications V2 (webhook):** Apple notifica renovación/cancelación/reembolso → el Worker actualiza `entitlement_*` por `original_transaction_id` → el siguiente refresh refleja el cambio (un reembolso revoca el acceso a la IA cara con prontitud).

**Propiedades (honesto):** App Attest + entitlement firmado suben el listón enormemente. **No** vuelve imposible que un device jailbroken reuse un `sessionToken` dentro de su TTL (≤15 min) y su cuota. Pero el blast radius cae de "key global ilimitada para siempre" a "la cuota de **un** device, por ≤15 min, revocable (denylist por keyId), y solo si presentó una suscripción válida firmada por Apple". Es el techo de robustez razonable para este threat.

---

## 8. Esquema de endpoints

| Método | Ruta | Auth | Función |
|---|---|---|---|
| `POST` | `/v1/attest/challenge` | — | Emite nonce one-time. |
| `POST` | `/v1/attest/register` | nonce | Verifica attestation + entitlement, emite JWT. |
| `POST` | `/v1/attest/assert` | nonce + assertion | Refresca JWT (counter + entitlement). |
| `POST` | `/v1/chat/completions` | Bearer JWT | Passthrough OpenAI (chat + vision, stream-ready). |
| `POST` | `/v1/audio/transcriptions` | Bearer JWT | Passthrough Whisper (multipart). |
| `GET` | `/rates/live` · `/rates/timeframe` | Bearer JWT | Tasas (Cache API edge). |
| `POST` | `/webhooks/appstore` | firma Apple | App Store Server Notifications V2. |
| `GET` | `/healthz` | — | Ops. |

Los `/v1/*` devuelven la respuesta de OpenAI **verbatim** → el SDK la parsea igual → errores tipados existentes intactos. Los `/rates/*` conservan la forma JSON de exchangerate.host → `LiveRateResponse`/`TimeframeResponse` decodifican sin cambios.

---

## 9. Modelo de datos

**D1 (relacional):**
```sql
CREATE TABLE attest_keys (
  key_id        TEXT PRIMARY KEY,
  public_key    BLOB NOT NULL,
  counter       INTEGER NOT NULL,
  revoked       INTEGER NOT NULL DEFAULT 0,
  entitlement_product      TEXT,        -- p.ej. 'yala.pro.yearly'
  entitlement_expires_at   INTEGER,     -- epoch; NULL = Free
  original_transaction_id  TEXT,        -- correlación con el webhook
  created_at    INTEGER NOT NULL
);
```
**Durable Object** `RateLimiter` (uno por `key_id`): cuenta requests por ventana (día + ráfaga), consistencia fuerte, sin race. **KV:** `challenge:<nonce>` (TTL nativo), `denylist:<keyId>`. **Cache API:** `rates:<source>:<currencies>` (TTL 6-12h live; histórico cache duro).

---

## 10. Rate-limit, cuota y entitlement (política a confirmar)

**Revisión del código (confirmado en `FeatureGateService.swift:35-40` + entry points):** TODAS las features de IA son **Pro-only** — no hay ninguna IA disponible para Free:

| Servicio(s) | `ProFeature` | Tier |
|---|---|---|
| ChatAssistant + IntentClassifier + ChatSuggestions + SuggestionsRewriter | `chatAssistant` | **Pro** |
| VoiceTranscription + TranscriptionParser | `voiceInput` | **Pro** |
| ImageVision | `imageInput` | **Pro** |
| InsightsLLM | `smartInsightsAI` | **Pro** |
| ExchangeRate | — | Cualquier device atestado |

**Matiz clave (lo que evita romper algo):** hay UN camino sin suscripción — el *setup checklist* desbloquea temporalmente **voz e imagen** para usuarios Free (`PanelView.swift:113,122` → `enableSetupTrial`). El free-trial *de suscripción* (StoreKit, `ProTrialOfferSheet`) sí produce una transacción firmada → el servidor lo ve como Pro válido. Pero el setup-trial **no** tiene transacción → bajo enforcement estricto se rompería.

**Política del Worker (resuelve ambos sin romper nada):**

| Quién | Cuota |
|---|---|
| Atestado + **Pro válido** (incl. free-trial de StoreKit) | Cuota completa por endpoint (ej. chat 75/día + ráfaga N/min). |
| Atestado + **sin Pro** | **Cuota de trial pequeña por device** (cubre el setup-checklist de voz/imagen + un "probar antes de comprar"); agotada → 402/403 upsell. |
| **No atestado** | Bloqueado. |

- El servidor es la **fuente de verdad**; el contador client-side queda solo como UX (feedback instantáneo).
- **429** + header `X-Yala-Limit: daily|burst` → el cliente mapea a `.dailyLimitReached` / `.rateLimited`.
- La cuota de trial **protege la factura** (un cliente modificado sin Pro solo obtiene la cuota pequeña, no acceso ilimitado) **y** mantiene vivo el setup-trial. La tabla es config editable en el Worker **sin release de app**.

---

## 11. Migración del cliente iOS

Cambio central = un factory compartido + el módulo App Attest:

```swift
// ProxyClientFactory.swift  (reemplaza OpenAI(apiToken:) en cada servicio)
enum ProxyClientFactory {
    @MainActor static func makeOpenAI() async throws -> OpenAI {
        let token = try await AppAttestClient.shared.currentSessionToken()  // refresca si expiró
        return OpenAI(configuration: .init(
            token: nil, host: ProxyConfig.host, basePath: "/v1", timeoutInterval: 20,
            customHeaders: ["Authorization": "Bearer \(token)"]))
    }
}
```

Cada servicio cambia **una línea** (`OpenAI(apiToken: key)` → `try await ProxyClientFactory.makeOpenAI()`). Reglas CLAUDE.md: `@MainActor`, `do/catch` con log (nunca `try?` que silencie), sin secretos hardcodeados.

**`AppAttestClient` (nuevo):** generar/persistir keyId (Keychain), `register` (con JWS StoreKit), `assert/refresh`, `currentSessionToken()` (cachea JWT hasta `exp`). En `DEV_BUILD`/`-uitest`: token de dev contra Worker `staging` (D8). **`ExchangeRateAPIService`:** base URL → `/rates/*`, quitar `access_key`, adjuntar Bearer; parsing sin cambios.

---

## 12. Retiro de secretos del cliente

- Borrar `OPENAI_API_KEY` + `EXCHANGE_RATE_API_KEY` de `Secrets.xcconfig` **e** `Info.plist:20-23`.
- `APIKeyService`: eliminar `openAIAPIKey`/`hasOpenAIAPIKey`; **conservar** `telemetryDeckAppID`.
- Gates `hasOpenAIAPIKey` (`ImageSelectionView`/`VoiceRecordingView`) → disponibilidad-del-proxy o degradación graciosa.
- Las keys reales viven **solo** como Worker secrets.

---

## 13. Degradación y mapeo de errores

| Situación | HTTP | Mapeo en cliente |
|---|---|---|
| JWT inválido/expirado | 401 | Re-attest 1×; si persiste → `errorGeneric`. |
| Cuota diaria | 429 `daily` | `.dailyLimitReached` |
| Ráfaga | 429 `burst` | `.rateLimited` (silencioso) |
| Sin entitlement Pro | 403 | `.notProUser` (ya existe) → prompt de upgrade |
| Attestation fallida | 403 | `errorGeneric` / `isAvailable=false` |
| Timeout / upstream caído | 502/504 | `.timeout` / `.networkError` → banner |

La degradación existente (banners, `isAvailable`, fallback regex del classifier, `[]` de suggestions) se conserva. Probablemente **0 keys de l10n nuevas** (reutilizamos las existentes). Si hace falta una nueva → 16 locales.

---

## 14. Streaming

Hoy no se usa (§3.1). El forward del Worker se construye **genérico (passthrough de `ReadableStream`)** → si algún día el cliente envía `stream:true`, el SSE de OpenAI fluye sin tocar el proxy. Es robustez sin scope especulativo.

## 15. Privacidad

- El Worker **no persiste ni loguea** bodies (contexto financiero/audio/imagen). Solo metadata operativa.
- TLS extremo a extremo. El Worker desencripta solo para inyectar la key (misma confianza que hoy — el owner controla app y proxy).
- Cierre del épico: actualizar `PrivacyInfo.xcprivacy` + nutrition labels ASC al flujo real (datos → proxy de Yala → OpenAI). `FinancialInfo` ya añadido el 2026-06-14.

---

## 16. Costos

| Concepto | Costo |
|---|---|
| **Hosting (Workers Paid + DO + D1 + KV + Cache + dominio)** | **$5/mes** (recomendado). Fallback $0 en free (§5). |
| **OpenAI** | Sin cambio (passthrough). Ganancia: el rate-limit + entitlement server-side mata el flood de una key robada. |
| **exchangerate.host** | Igual o **menor** (cache de edge). |
| **Latencia añadida** | 1 hop en edge (~decenas de ms) vs los segundos de la IA → imperceptible. Tasas: cache hit **más rápido** que hoy. |

---

## 17. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Verificación App Attest (X.509) en Workers es la pieza más incierta | Es **lo primero que se construye** del backend (§19). Libs probadas en Workers (`@peculiar/x509` / `nodejs_compat`). CPU 30s del plan Paid elimina el riesgo de tiempo. |
| App Attest no corre en simulador → rompería QA/XCUITests | Bypass de dev gateado a `staging` (D8). Device QA real en físico (flujo del proyecto). |
| Lock-out de usuarios legítimos al cortar el path directo | Flag server `ENFORCE` arranca en "observe" (cuenta pero no bloquea) por una ventana corta tras el deploy del backend, antes de retirar las keys del cliente. Es un interruptor de seguridad del rollout, no un deferral de scope. |
| Verificación de JWS StoreKit / edge cases de sandbox vs prod | Manejar entornos sandbox/prod de App Store; el webhook cubre cambios de estado. |
| Tamaño de body (imagen/audio) | Workers Paid aguanta; validar límites concretos al construir el endpoint de transcripción. |

---

## 18. Exclusiones por diseño (firmes, no deferrals)

- **Body-binding criptográfico por request** — D9: nulo beneficio para este threat, costaría reescribir todo a URLSession.
- **Anonimizar el contexto financiero antes de OpenAI** — rompería la utilidad; el audit lo cerró como no-vuln (cubierto por consent + disclosure).
- **DeviceCheck** — App Attest lo subsume.

---

## 19. Secuencia de construcción (un solo épico, todo incluido, un solo release)

No son fases-que-podrían-no-continuar: es el **orden de trabajo** dentro de la entrega única. Todo se envía junto, con un solo bump de build.

1. **Backend — núcleo de confianza primero:** verificación App Attest (lo más incierto) + verificación JWS StoreKit. Se prueba contra un build real en **device físico**.
2. **Backend — resto:** todos los endpoints (§8), D1/DO/KV/Cache, rate-limit + política de entitlement (§10), no-logging, secrets, webhook App Store, mapeo de errores, dominio.
3. **Cliente — módulo App Attest + factory:** `AppAttestClient` + `ProxyClientFactory`. Migrar `ChatIntentClassifierService` (canario, tiene fallback regex) y verificar el camino completo en device.
4. **Cliente — migrar los 7 servicios OpenAI restantes + `ExchangeRateAPIService`.**
5. **Cliente — retirar secretos** (§12) + verificar toda la degradación (proxy caído, attest fail, 401/403/429).
6. **Rollout:** flag `ENFORCE` observe→enforce; bump de build; ship. `PrivacyInfo.xcprivacy` + nutrition labels.

Cada paso de cliente con su `/verify-ios`; el backend con sus pruebas. Flujo "Complejo" del proyecto (sync/race + dinero) para el cliente.

---

## 20. Manejo de keys y rotación (plan acordado con el owner)

- **Key nueva para 2.0:** el owner genera una **key nueva** de OpenAI para el build 2.0. Esa key va **solo al Worker secret** (`wrangler secret put OPENAI_API_KEY`) — **nunca** al cliente. El build 2.0 sale **sin ninguna key**.
- **Key vieja (1.0):** se mantiene viva mientras existan usuarios en 1.0 (la app 1.0 la usa embebida). El owner la **descarta** cuando 2.0 esté probado y 1.0 sin tráfico relevante → rotación **sin downtime**.
- **Hard spending cap en OpenAI:** se hace **al final** (lo explico paso a paso cuando lleguemos, a pedido del owner). Es la única mitigación no-bypasseable del costo; recomendado activarlo antes de exponer 2.0 a usuarios reales.
- De aquí en adelante, rotar cualquier key = actualizar el Worker secret, **sin release de app** (objetivo #4).
- La `EXCHANGE_RATE_API_KEY` se trata igual: nueva (o la misma) solo en el Worker, fuera del cliente.

---

## ✅ Decisiones cerradas (diseño aprobado)

1. **Costo:** Workers Paid **$5/mes** — ✅ aprobado.
2. **Entitlement (§10):** toda la IA es **Pro**; cuota de trial para no-Pro mantiene vivo el setup-checklist — ✅ resuelto por revisión de código.
3. **Dominio:** **`*.workers.dev`** (cero riesgo de DNS) — ✅ decidido.
4. **Keys (§20):** key nueva → solo Worker; vieja se descarta tras validar 2.0; cap en OpenAI al final — ✅ acordado.

## Para empezar a construir necesito de tu lado

El código se puede escribir, pero **desplegar + verificar** requiere accesos que solo tú tienes:

- **Cuenta de Cloudflare** (con Workers Paid activado) — para `wrangler` deploy, D1, Durable Objects.
- **Key nueva de OpenAI** (la de 2.0) — irá como Worker secret.
- **App Store Connect API key** (para verificar las transacciones StoreKit firmadas y/o el webhook de notificaciones).
- **Device físico** para QA de App Attest (no corre en simulador).
- **Decisión menor:** dónde vive el código del Worker → recomiendo una carpeta `gateway/` en este mismo repo (ya conviven Swift + el `Web/` de Astro), para mantener todo sincronizado.

**Primer paso de construcción:** el núcleo de confianza del backend (verificación App Attest + JWS StoreKit) probado contra un device físico. De ahí, el épico completo de corrido, una sola entrega, un solo bump de build.
