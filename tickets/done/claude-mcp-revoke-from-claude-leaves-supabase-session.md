---
id: claude-mcp-revoke-from-claude-leaves-supabase-session
status: done
priority: low
area: cloud
created: 2026-09-26
updated: 2026-11-05
source: encargo 2026-09-26-claude-mcp-oauth-token-can-change-the-account (residual, medido en el diseño)
---

# Desconectar Claude desde Claude deja una sesión huérfana en Supabase

## Qué cambia para el usuario

Hoy nada. En la fase 2, la app enseñará «Claude conectado · Revocar». Si esa pantalla se basa en los permisos de
Supabase, podría decir «conectado» cuando el usuario ya desconectó Claude desde Claude.

## Qué pasa (inferido del código de la librería y de GoTrue; no medido de punta a punta)

Cada conexión de Claude es un grant del Worker, que guarda cifrada una sesión OAuth de Supabase. El Worker borra su
grant en tres casos, y en los tres la sesión de Supabase se queda sin cerrar:

- Claude revoca por RFC 7009 (`/oauth/token` con `token`);
- el usuario vuelve a autorizar el mismo cliente (la librería retira el grant anterior);
- la conexión caduca en el KV.

Esa sesión es **inalcanzable**: su refresh solo existía cifrado en el grant borrado, y canjearlo exige el secreto
del cliente del Worker. Pero sigue viva en `auth.sessions` (en staging no caduca nunca: `sessions_inactivity_timeout
= 0`), y el permiso «Yala para Claude» sigue listado en `GET /auth/v1/user/oauth/grants`.

Revocar desde la cuenta de Supabase sí corta todo al momento: el Worker lo detecta en la llamada siguiente.

## Qué hay que decidir

- **Para la fase 2:** qué lista la app como «Claude conectado». Puede ser el permiso de Supabase, cuyo botón cierra
  todo, o los grants del Worker, que necesitan un endpoint propio.
- **Si se quiere limpiar:** interceptar la revocación de `/oauth/token` antes de la librería para cerrar la sesión de
  Supabase, o un barrido periódico.

## Medido en 2.1 (triage 2026-10-08)

- `mcp/` no tiene commits desde el 2026-09-26 (`67a15b6f2`): la revocación de `/oauth/token` la sigue sirviendo la librería sin cerrar la sesión de Supabase, y no hay barrido.
- La fase 2 («Claude conectado · Revocar» en la app) sigue sin existir: ningún string de la app la menciona.
- Hermano, no duplicado: `claude-mcp-production-auth-hardening` (medium) pide en su punto 6 un `sessions_inactivity_timeout`, que acotaría la vida de la sesión huérfana pero no decide qué lista la app como «Claude conectado».

Triage 2026-10-08: abierto · low → low · sigue igual, pero no cambia nada para el usuario hasta la fase 2; la sesión huérfana es inalcanzable.

## Resuelto (2026-11-04/05, encargo «Login Apple y Google en el conector + lote P7»)

Decidido el 2026-11-05: opción 1A (la lista «Claude conectado» la da el conector, una fila por app de Claude; las
huérfanas, con un barrido diario en la base).

- **Desconectar desde Claude cierra la sesión de Supabase** (`mcp/src/revoke.ts`). Antes de que la librería atienda
  una revocación con refresh, el Worker hace con ese refresh un refresh normal, cierra con el access resultante la
  sesión de Supabase (`/logout?scope=local`) y deja que la librería borre la conexión. Falla abierto: si algo falla,
  la revocación sigue igual. **Medido en staging:** sesiones del Worker en `auth.sessions` 1 → 0.
- **Reconectar y caducar:** el barrido diario `qa/cloud/mcp0_04_sweep_connector_sessions.sql` (pg_cron, 04:17 UTC)
  borra las sesiones del cliente del Worker sin refrescar en 31 días o con más de 91. Aplicado en staging y probado
  con cinco sesiones sintéticas (`docs/RUNBOOK-staging-ddl.md`). Producción: paso 8 de
  `claude-mcp-production-auth-hardening`.
- Tests: `mcp/test/oauth-flow.test.ts` (desconectar con y sin pista, access sin efecto, otro cliente, parámetro
  repetido, Supabase caído).
- **La pantalla de la app** es la fase 2 y queda en `claude-mcp-connected-apps-in-the-app`.
