---
id: claude-mcp-consent-with-apple-and-google
status: qa
priority: low
area: cloud
created: 2026-09-26
updated: 2026-11-05
source: encargo 2026-09-26-plugin-claude-mcp-fase0-spike (residual, fase 1)
---

# Conectar Claude iniciando sesión con Apple o Google

## Qué cambia para el usuario

Al conectar Yala en Claude, la pantalla de permiso le pide iniciar sesión con la misma cuenta que usa en la app:
Apple o Google. Hoy (fase 0, staging) solo acepta email y contraseña, que es lo que tienen las cuentas de prueba.

## Qué hace falta

- **Acceso de Jürgen:** un Services ID de Sign in with Apple con el dominio del conector, y un cliente OAuth web
  de Google en el proyecto `yala-502622`. Los IDs que existen son de iOS (inferido; verificarlo en los dos
  dashboards).
- Activar esos proveedores para web en Supabase Auth, con la URL de vuelta del Worker.
- En `mcp/src/consent.ts`, sustituir el formulario de contraseña por los dos botones. La sesión web sigue
  cerrándose al decidir, como hoy.
- Probarlo con una cuenta real de nube en staging.

## Medido en 2.1 (triage 2026-10-08)

- `mcp/src/consent.ts` no existe: el formulario vive en `mcp/src/pages.ts:77-87` (`loginPage`, comentario «en producción, Apple y Google (fase 1)») y el POST en `authorize.ts:183-192` (`passwordLogin`).
- Sin commits en `mcp/` desde el 2026-09-26. El padre es `claude-plugin-read-only-mcp-connector`, que además lista un bloqueo propio de fase 1 (`claude-mcp-oauth-token-can-change-the-account`).

Triage 2026-10-08: abierto · medium → low · la pantalla de permiso del conector sigue siendo email + contraseña (`mcp/src/pages.ts:77-87`, `authorize.ts:183-192`); es fase 1 de un conector solo en staging y espera accesos de Jürgen.

## Hecho (encargo «Login Apple y Google en el conector + lote P7», 2026-11-04/05)

- La pantalla de permiso pide **Apple o Google** (`mcp/src/pages.ts`, `loginPage`); el email y la contraseña solo
  quedan en staging, plegados como «Cuenta de prueba». Login social de Supabase en PKCE, sin JavaScript
  (`mcp/src/authorize.ts`, paso 4; `mcp/src/upstream.ts`, `pkceLogin`).
- Supabase staging: `external_apple_client_id` con el Services ID web (`pe.yala.app.web`) primero; con el de iOS
  primero, Apple respondía «Invalid client id or web redirect url».
- Una cuenta sin la nube de Yala (sin fila en `profiles`) no se conecta: la página explica cómo activarla y deja
  elegir la otra cuenta (decisión 4B del 2026-11-05).
- **Probado con identidad real (Google, admin@yala-app.pe) en staging el 2026-11-05:** Google → Supabase → Worker →
  «esta cuenta todavía no usa la nube» (y su sesión web cerrada, 0 sesiones); con un perfil de nube temporal, la
  misma identidad llegó hasta la vuelta de Claude con el código y el `state` correctos. Perfil, sesiones y grant de
  la prueba, borrados después. La cuenta vacía de staging que creó Supabase se queda.
- Tests: `mcp/test/social-login.test.ts` (21). e2e contra staging 19/19.

## QA pendiente (Jürgen, staging): el último paso con Apple

No hay sesión de Apple en el Chrome de la Mac. Medido: el botón llega a la página de Apple con el cliente web
correcto. Falta volver de Apple con una cuenta real.

1. En Claude Code: `claude mcp add --transport http yala-staging https://yala-mcp-staging.misty-surf-6866.workers.dev/mcp`
   (si ya está, salta este paso).
2. `/mcp` → `yala-staging` → *Authenticate*. Se abre el navegador.
3. Pulsa **Continuar** y luego **Continuar con Apple**. Entra con tu Apple ID.
4. Si tu cuenta de staging tiene la nube, Claude Code dice que se conectó; si no, la página dice «Esta cuenta todavía
   no usa la nube de Yala». Cualquiera de las dos cierra la prueba de Apple.
