---
id: claude-mcp-revoke-from-claude-leaves-supabase-session
status: backlog
priority: low
area: cloud
created: 2026-09-26
updated: 2026-09-26
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
