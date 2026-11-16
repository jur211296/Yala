# Panel de Yala (`panel/`)

Worker de Cloudflare **aparte del gateway** con el panel propio de telemetría: siete secciones (Uso, Registro, Grupos,
Nube, Pro, IA, Salud), cada número con una frase de plantilla. Lo decidió Jürgen el 2026-11-06 (las 8 «A» de
`docs/telemetria/propuesta-2026-11.md`; la decisión 1 acabó en **C**: funciones, oferta de Pro, límite del plan gratis y
pasos del alta).

```
App ──POST /metrics──▶ gateway ──▶ Analytics Engine (90 días)
                       gateway (avisos de Apple, cupo de IA) ──▶ Analytics Engine
                                                     │
                       cron 06:00 UTC ◀── API SQL ───┘        Supabase ── yala_stats_counts() (solo números)
                            │                                     │
                            └──▶ D1 `yala-panel` (agregados por día, para siempre) ◀┘
                                         │
                            GET / ◀──────┘  detrás de Cloudflare Access (admin@yala-app.pe)
```

## Qué hace cada pieza

| Fichero | Qué |
|---|---|
| `src/cron.ts` | El cron diario: resume hasta AYER (UTC), recalcula 3 días (avisos que llegan tarde) y, con la D1 vacía, rellena 85 |
| `src/ae.ts` | Lee Analytics Engine por la API SQL. Pide filas finas y cuenta en memoria |
| `src/summarize.ts` | Del dato fino al resumen diario. Función pura. **Ningún `install` sale de aquí** |
| `src/supabase.ts` | Los conteos de la base (grupos, invitaciones, cuentas en la nube) |
| `src/view.ts` | Del resumen a las secciones y frases (plantillas fijas, sin IA) |
| `src/render.ts` | La página: estilo de la maqueta aprobada, claro y oscuro, sin JavaScript |
| `src/access.ts` | Verifica el JWT de Cloudflare Access. Sin configurar, 503 |
| `src/health.ts` | Umbrales de Salud (ámbar desde 1 aparato, rojo desde 5; ajustables) |
| `src/prices.ts` | Precio por modelo de IA. Un modelo nuevo del gateway sin precio pone rojo `test/prices.test.ts` |

## Privacidad

- D1 solo guarda agregados por día. Los `install` (hash anónimo) se usan en memoria durante el cron para contar
  distintos y la retención, y no se escriben.
- Un corte con 1 o 2 aparatos se pinta «menos de 3».
- De Supabase salen 11 números por día; el rol `yala_stats` no puede leer ninguna tabla.

## Ver el panel sin desplegar

```bash
npm ci
npm run preview -- /tmp/panel.html          # datos reales de Analytics Engine (token de solo lectura en ~/Secrets)
npm run preview -- /tmp/panel.html --vacio  # la página sin ningún día resumido
```

## Desplegar (Dan o Jürgen — la sesión no despliega)

**Orden obligatorio, por este motivo:** un evento que el gateway no conoce tumba el LOTE ENTERO que manda la app (400)
y la app lo descarta, con los canarios que viajaran en él. El gateway con `use` va **antes** que cualquier build que lo
mande.

1. **Gateway** (acepta `use`, apunta los avisos de Apple y la última pregunta del cupo):
   `cd gateway && npm test && npm run deploy:staging` → comprobar → `npm run deploy:production`.
2. **Supabase**: aplicar `qa/cloud/tel01_stats_counts.sql` en staging y en producción (banco local:
   `bash qa/cloud/tel01-local-test.sh`). Comprobar como dueño `select public.yala_stats_counts();`.
3. **D1 del panel**: `cd panel && npx wrangler d1 create yala-panel`, pegar el `database_id` en `wrangler.toml` y
   `npm run migrate`.
4. **Secrets del panel**:
   - `CF_ANALYTICS_TOKEN`: token de la API de Cloudflare con un solo permiso, *Account Analytics Read*. Vale el de
     `~/Secrets/yala-cloudflare/analytics-read.token` (caduca 2027-08-05):
     `npx wrangler secret put CF_ANALYTICS_TOKEN < ~/Secrets/yala-cloudflare/analytics-read.token`.
   - `STATS_ROLE_JWT`: `node scripts/mint-stats-role-jwt.mjs <legacy-secret-de-prod> | npx wrangler secret put STATS_ROLE_JWT`.
5. **Cloudflare Access**: Zero Trust → Access → Applications → *Self-hosted*, dominio `panel.yala-app.pe`, política
   «Allow» solo para `admin@yala-app.pe`. Copiar el dominio del equipo (`<equipo>.cloudflareaccess.com`) y el
   *Application Audience (AUD) Tag* a `ACCESS_TEAM_DOMAIN` y `ACCESS_AUD` de `wrangler.toml`.
6. `npm run deploy`. La primera corrida del cron (06:00 UTC, la 01:00 en Lima) rellena 85 días. Para no esperar a la
   madrugada: `npx wrangler dev --remote --test-scheduled` y abrir
   `http://localhost:8787/__scheduled?cron=0+6+*+*+*` (corre el mismo cron contra la D1 remota).
7. **App**: el build siguiente de 2.3 trae los eventos de uso. Antes de subirlo, comprobar que el gateway de
   producción ya acepta `use`:
   `curl -s -X POST https://yala-gateway-production.misty-surf-6866.workers.dev/metrics -H 'content-type: application/json' -d '{"v":1,"install":"0000000000000000","events":[{"e":"use","n":"panel"}]}'`
   → `{"ok":true,"accepted":1}` (un 400 = el gateway aún no lo tiene: no subir el build).

## Cerrar la app en TelemetryDeck (decisión 6 — Jürgen o Dan)

El código ya no la usa desde el 2026-07-17; solo le pueden llegar aparatos con 2.0.0–2.0.2.

1. Entrar en <https://dashboard.telemetrydeck.com> con la cuenta de Yala.
2. Exportar lo que se quiera conservar (opcional).
3. App «Yala» → ajustes de la app → borrar la app (o cancelar el plan si la cuenta no tiene más apps).
