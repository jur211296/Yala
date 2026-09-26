---
id: claude-mcp-oauth-token-can-change-the-account
status: backlog
priority: high
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-plugin-claude-mcp-fase0-spike (medido en el e2e de OAuth contra staging)
---

# El permiso que el usuario da a Claude para LEER también le deja cambiar la cuenta

## Qué cambia para el usuario

Hoy, en staging, cuando alguien conecta Yala a Claude y pulsa «Permitir», Claude recibe una llave que no puede
tocar sus finanzas —la base lo impide—, pero sí puede cambiar datos de la **cuenta** de inicio de sesión: los
metadatos, y por lo que expone esa API también el email y la contraseña. La pantalla le promete que Claude «no
podrá crear, cambiar ni borrar nada». Esto bloquea la fase 1: no se lanza a producción así.

## Qué se midió (2026-09-26, `mcp/test/e2e/oauth.e2e.test.ts`)

- El token que Supabase emite a Claude sale con `role = yala_mcp_reader` y `client_id`. PostgREST le deniega
  todas las escrituras (403) y las RPC de escritura.
- Con ese mismo token, `PUT /auth/v1/user` de GoTrue responde **200** y aplica el cambio. Lo que se probó fue una
  clave de metadatos, que después se borró por SQL. GoTrue no mira el rol de Postgres ni el `scope` del token
  (`openid email`).
- En staging, `security_update_password_require_reauthentication` está en `false`. Así que, inferido, no medido,
  cambiar la contraseña tampoco pediría nada más.

El e2e lo deja como `it.fails`: el día que se cierre, ese test se pone rojo y avisa de que hay que retirarlo.

## Qué hay que hacer

Hay que decidir el camino, y medirlo con el mismo e2e:

1. Averiguar si Supabase ofrece restringir los endpoints de `/auth/v1/user*` para tokens OAuth, por `scope` o
   por cliente. Es lo limpio. Si no existe, abrir un issue en `supabase/auth`.
2. Mientras tanto, activar `security_update_password_require_reauthentication` y la confirmación de cambio de
   email. Eso cubre la contraseña y el email, pero no los metadatos.
3. Si no hay forma en Supabase, emitir a Claude un token que NO sea de Supabase: un OAuth propio en el Worker
   (por ejemplo, la librería `workers-oauth-provider` de Cloudflare) que guarde la sesión de Supabase cifrada.
   Es lo que el Paso 0 descartó por guardar refresh tokens, y hay que volver a pesarlo con este dato.

## Contexto

El hueco lo anticipó la lente de seguridad de la review adversarial del 2026-09-26, y el e2e lo confirmó.
