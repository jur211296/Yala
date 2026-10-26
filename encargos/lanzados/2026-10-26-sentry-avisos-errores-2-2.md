# Sentry: avisos de errores y caídas (card tablero-sentry-avisos-de-errores-y-caidas-en-la-6bee)

Cierre: **cierra-sola** → al terminar, `/cerrar-total`. Versión 2.2. PR chica contra la rama 2.2.

## Contexto Sentry (ya creado por Jürgen)
- Org: `yala-is` · Team: `yala` · Region: https://us.sentry.io
- Proyecto `yala-ios` (platform apple-ios)
  - DSN: <DSN: fuera del repo — Secrets.xcconfig / wrangler secret>
- Proyecto `yala-gateway` (platform javascript; Worker Cloudflare — Sentry no aceptó javascript-cloudflare)
  - DSN: <DSN: fuera del repo — Secrets.xcconfig / wrangler secret>

**Los DSN son secretos: NUNCA en git, PR, commits, logs públicos, Slack ni el tablero.**

## Tareas
1. **iOS**: integrar sentry-cocoa siguiendo docs apple-ios (SPM preferido; CocoaPods solo si el proyecto ya usa Pods).
   - DSN vía `Secrets.xcconfig` (gitignored; verificar `.gitignore`) → Info.plist `SENTRY_DSN = $(SENTRY_DSN)` → leer en runtime. Si DSN vacío, no iniciar SDK.
   - Agregar `Secrets.example.xcconfig` con placeholder.
2. **Gateway (Cloudflare Worker)**: `@sentry/cloudflare` (withSentry) con `dsn: env.SENTRY_DSN`.
   - `wrangler secret put SENTRY_DSN` (para dev: `.dev.vars` gitignored). Nada en wrangler.toml.
3. **Scrubbing (obligatorio)**: `sendDefaultPii: false`; `beforeSend` / `beforeBreadcrumb` que eliminen montos, nombres, correos y cualquier dato financiero (bodies de request, query strings, headers auth/cookies, user email/name/ip, breadcrumbs de HTTP con payload). Sin session replay / attachments de pantalla.
4. **Error de prueba**: disparar uno en la app (botón/flag debug) y uno en el gateway (ruta debug protegida o script) y confirmar que aparecen en Sentry `yala-ios` y `yala-gateway` sin PII.
5. PR chica a 2.2 con resumen (sin DSN). Luego `/cerrar-total`.

## Hecha cuando
Un error de prueba de la app y uno del backend aparecen en Sentry, sin datos personales ni financieros del usuario (montos, nombres, correos) en los eventos.

## Build iOS en la Mini (norma de flota)
Pipeline serial: limpiar → build con `xcodebuild -jobs 2` sin simulador encendido → encender 1 simulador → tests → apagarlo y borrar su data. Nunca solapar build y simulador. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, mira si el PR #636 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.2` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

/cerrar-total

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Plantilla de secretos.** El repo ya tiene `Secrets.xcconfig.template` (versionada) con el mismo propósito que el `Secrets.example.xcconfig` del encargo. Se añade `SENTRY_DSN` a esa plantilla en vez de crear una segunda: dos plantillas divergen. *Asumido.*
2. **DSN en xcconfig.** En un `.xcconfig` `//` abre comentario, así que el DSN se escribe `https:/$()/…`. La plantilla lo explica.
3. **Dónde vive el DSN de iOS.** En `Secrets.xcconfig` del árbol principal (los worktrees lo enlazan). Ya está en `baseConfigurationReference` de las configuraciones de proyecto; `Info.plist` gana `SENTRY_DSN = $(SENTRY_DSN)`. DSN vacío → el SDK no arranca.
4. **SDK iOS por SPM**, `sentry-cocoa` versión exacta, producto `Sentry`, solo en el target de la app (no widgets ni share extension: alcance mínimo).
5. **Scrubbing iOS por lista blanca:** `sendDefaultPii = false`, sin session replay, sin screenshots ni view hierarchy, sin trazas de rendimiento; `beforeSend` quita usuario, request, extra y tapa importes/correos/tokens en mensajes; `beforeBreadcrumb` descarta breadcrumbs HTTP con payload y de consola, y deja la URL sin query.
6. **Gateway:** `withSentry` sobre la app Hono (patrón de la doc). Hono atrapa los errores en `onError`, así que ahí se llama a `captureException`. Mismo scrubbing por lista blanca: del request, método y ruta.
7. **Errores de prueba.** iOS: fila en Ajustes › desarrollador (solo `DEV_BUILD`). Gateway: `POST /v1/debug/sentry` con el gate de `/v1/debug/push` (no-prod + `DEV_SHARED_SECRET`); en producción, 404. Los dos mensajes llevan datos falsos (correo e importe) para comprobar en Sentry que salen tapados.
8. **Verificación del gateway sin desplegar:** `wrangler dev` local con `.dev.vars` (gitignored). El secret se sube a staging y producción con `wrangler secret put`; el deploy del código queda para el flujo normal tras el merge.
9. **Ajustes al medir (2026-10-26).** El SDK de Cloudflare 11 ya no tiene `sendDefaultPii`: su equivalente es `dataCollection` con todo apagado. El primer evento de cada lado destapó dos fugas que la limpieza no cubría: el `userInfo` del NSError (contexto «user info» y `mechanism.data`) y la IP de envío; las dos se cierran en `beforeSend` (`infer_ip: "never"`). Se añadió `-sentry-test-error` (DEV_BUILD) junto al botón, para probar sin navegar.
