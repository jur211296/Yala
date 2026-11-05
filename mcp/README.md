# mcp/ — conector de Yala para Claude (staging desplegado; producción lista, sin desplegar)

Un servidor MCP remoto de **solo lectura**. Claude lo usa para leer las finanzas de un usuario en la nube de
Yala: cuentas y saldos, categorías, movimientos, resumen de un periodo, presupuestos y pagos recurrentes.
Contexto, decisiones y fases: `docs/exploracion/plugin-claude-mcp.md` (§7 y §8).

- **Worker propio** (`yala-mcp-staging`; en producción `yala-mcp-production`), separado del gateway: no tiene `GROUPS_ENC_KEY`.
- **El servidor OAuth de Claude es este Worker** (`@cloudflare/workers-oauth-provider`), no Supabase. Claude
  recibe un token opaco, atado a `…/mcp`, que no sirve en Supabase. Por qué: el ADR «El conector de Claude emite
  sus propios tokens» (`docs/DECISIONS.md`). Con un token de Supabase en la mano, Claude podía cambiar la cuenta.
- **Supabase queda aguas arriba.** El Worker es un cliente OAuth confidencial de Supabase: el usuario inicia sesión
  allí, y el Worker recibe una sesión con `role = yala_mcp_reader` (hook de Supabase, `qa/cloud/mcp0_0*.sql`),
  que solo tiene SELECT sobre las filas del usuario. La guarda cifrada en KV y nunca la devuelve.
- **Nada del Worker puede escribir la cuenta:** todas sus salidas a Supabase pasan por una lista cerrada
  (`src/egress.ts`).

## Estructura

| Ruta | Qué hace |
|---|---|
| `src/index.ts` | El `OAuthProvider`: metadatos, registro, token, revocación y enrutado. Antes, la configuración y los límites por IP |
| `src/config.ts` | Comprueba la configuración: si está mal (producción contra staging, anon key de otro proyecto, algo PENDIENTE, sin límites), 503 a todo |
| `src/ratelimit.ts` | Límites de peticiones: por IP en las páginas y en registro/token, por usuario en `/mcp` |
| `src/authorize.ts` | El permiso por cliente (`/authorize`), el login (`/oauth/consent`) y la vuelta de Supabase |
| `src/pages.ts` | Las páginas HTML, renderizadas en servidor y sin JavaScript |
| `src/upstream.ts` | El Worker como cliente OAuth de Supabase: canje, refresh, sesión viva, login de staging |
| `src/tokens.ts` | Qué se guarda en cada conexión, cómo se renueva y cuándo caduca |
| `src/mcp.ts` | `/mcp`: comprueba la sesión de Supabase y la retira si ya no existe |
| `src/egress.ts` | La lista cerrada de lo que el Worker puede pedir a Supabase |
| `src/auth.ts` | Verifica los tokens de Supabase (firma, cliente, rol, sesión) |
| `src/server.ts` | Servidor MCP sin estado, errores y auditoría por llamada |
| `src/tools.ts` | Las seis herramientas tal como las ve el SDK de MCP: el núcleo más su esquema de `zod` |
| `src/toolCore.ts` | El núcleo de las seis (qué leen y qué calculan) y el punto de extensión Pro (`plan`). Lo comparte el gateway para Yala IA en la nube: sin dependencias, ver `gateway/src/ai/explore/` |
| `src/logic/` | Cálculos portados de Swift; cada fichero cita la función de origen |
| `plugin/` | Borrador del plugin: `.mcp.json` y tres skills. No publicado |
| `scripts/preflight-production.mjs` | Lo que comprueba `deploy:production` antes de desplegar |
| `scripts/sql-produccion.py` | Genera los SQL del hook para producción (id del cliente y guardas md5) |
| `RUNBOOK-produccion.md` | La salida a producción: pasos, lo que falta crear, coste y marcha atrás |

## Comandos

```bash
npm ci
npm run typecheck
npm test                 # unitarios, sin red (los corre el CI, job `mcp`): el baile OAuth entero con un Supabase falso
npm run deploy:staging   # wrangler deploy --env="" → https://yala-mcp-staging.misty-surf-6866.workers.dev
npm run deploy:production  # SOLO Jürgen, por RUNBOOK-produccion.md: preflight y luego wrangler deploy --env production

# E2E contra staging: el baile OAuth entero, las sondas de escritura en /auth/v1/*, las seis herramientas con A y B,
# refresh y revocación.
set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
npm run test:e2e
```

Cada corrida del e2e registra un cliente en el Worker (caduca a los 90 días sin uso) y revoca al final los permisos
de A y B al cliente del Worker en Supabase.

### Lo que necesita el despliegue (ya hecho en staging)

- **KV** `OAUTH_KV` (`wrangler.toml`): clientes de Claude, grants y tokens (solo por hash) y transacciones de
  consentimiento.
- **Cliente del Worker en Supabase**, confidencial, con una sola vuelta: `<PUBLIC_URL>/oauth/supabase/callback`. Su id
  va en `wrangler.toml` (`SUPABASE_OAUTH_CLIENT_ID`) y en el hook (`mcp0_02`).
- **Su secreto**, que no va en el repo. Se carga desde el fichero, sin pasar por pantalla:

  ```bash
  python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/Secrets/yala-mcp-staging/supabase-oauth-client.json')))['client_secret'],end='')" \
    | npx wrangler secret put SUPABASE_OAUTH_CLIENT_SECRET
  ```

- **En Supabase:** Site URL = el Worker, y `oauth_server_authorization_path = /oauth/consent`. El DCR, apagado.

El antes → después de staging y la marcha atrás: `docs/RUNBOOK-staging-ddl.md`, sección `mcp0_02`.

## Conectar Claude a staging

- **Claude Code:** `claude mcp add --transport http yala-staging https://yala-mcp-staging.misty-surf-6866.workers.dev/mcp`,
  y luego `/mcp` → `yala-staging` → *Authenticate*. Si ya estaba añadido de la fase 0, basta con *Authenticate* otra
  vez: el servidor de autorización cambió.
- **claude.ai o Claude Desktop:** Ajustes → Conectores → *Añadir conector personalizado* → la misma URL.

En los dos casos se abre la pantalla de permiso del Worker (*Continuar*). Luego inicias sesión con **Apple o Google**,
la misma cuenta que usas en la app (login social de Supabase en PKCE; `authorize.ts`, paso 4). En staging hay además,
plegada, «Cuenta de prueba» con email y contraseña para los usuarios de prueba y el e2e; en producción no existe.

## Producción

`[env.production]` está en `wrangler.toml` y **no está desplegado**: lo despliega Jürgen con
`npm run deploy:production`, que se niega mientras quede algo PENDIENTE. Pasos, lo que falta crear (KV, cliente de
Supabase, secreto, hook y configuración de Auth), coste y marcha atrás: `RUNBOOK-produccion.md`.
