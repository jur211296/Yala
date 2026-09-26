# mcp/ — conector de Yala para Claude (fase 0, staging)

Un servidor MCP remoto de **solo lectura**. Claude lo usa para leer las finanzas de un usuario en la nube de
Yala: cuentas y saldos, categorías, movimientos, resumen de un periodo, presupuestos y pagos recurrentes.
Contexto, decisiones y fases: `docs/exploracion/plugin-claude-mcp.md`.

- **Worker propio** (`yala-mcp-staging`), separado del gateway: no tiene `GROUPS_ENC_KEY` ni ningún secreto.
- **El servidor de autorización es Supabase Auth** (OAuth 2.1 + DCR + PKCE). Este Worker solo valida el token
  y sirve la pantalla de consentimiento.
- **Solo lectura en la base, no solo en el código.** El token que recibe Claude sale con
  `role = yala_mcp_reader` (hook de Supabase, `qa/cloud/mcp0_01_readonly_role.sql`), que solo tiene SELECT sobre
  sus propias filas. El MCP rechaza cualquier token sin ese rol (falla cerrado).

## Estructura

| Ruta | Qué hace |
|---|---|
| `src/index.ts` | Enrutado: metadatos del recurso protegido, consentimiento y `/mcp` |
| `src/auth.ts` | Valida el JWT (JWKS de Supabase) y exige `client_id` + `role = yala_mcp_reader` |
| `src/consent.ts` | Pantalla de consentimiento, renderizada en servidor |
| `src/server.ts` | Servidor MCP sin estado, errores y auditoría por llamada |
| `src/tools.ts` | Las seis herramientas y el punto de extensión Pro (`plan`) |
| `src/logic/` | Cálculos portados de Swift; cada fichero cita la función de origen |
| `plugin/` | Borrador del plugin: `.mcp.json` y tres skills. No publicado |

## Comandos

```bash
npm ci
npm run typecheck
npm test                 # unitarios, sin red (los corre el CI, job `mcp`)
npm run deploy:staging   # wrangler deploy → https://yala-mcp-staging.misty-surf-6866.workers.dev

# E2E contra staging: el baile OAuth entero y las seis herramientas con A y B.
set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
npm run test:e2e
```

Cada corrida del e2e registra un cliente OAuth nuevo en staging por DCR y revoca sus permisos al final. Los
clientes no se pueden borrar sin `service_role`, que este repo no usa.

## Conectar Claude a staging

- **Claude Code:** `claude mcp add --transport http yala-staging https://yala-mcp-staging.misty-surf-6866.workers.dev/mcp`,
  y luego `/mcp` → `yala-staging` → *Authenticate*.
- **claude.ai o Claude Desktop:** Ajustes → Conectores → *Añadir conector personalizado* → la misma URL.

En los dos casos se abre la pantalla de consentimiento: entras con un usuario de prueba de staging (email y
contraseña) y pulsas *Permitir*.

## Antes de producción

No hay entorno de producción en `wrangler.toml` a propósito. Lo que falta está en §7 del documento de
exploración.
