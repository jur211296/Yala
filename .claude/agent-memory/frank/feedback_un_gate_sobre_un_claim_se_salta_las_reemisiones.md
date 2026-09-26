---
name: un-gate-sobre-un-claim-se-salta-las-reemisiones
description: Un gate que decide por un CLAIM del token se salta las reemisiones que no lo traen; y un fallo de verificación TRANSITORIO no debe borrar estado. Dos altas que la review adversarial cazó y yo no.
metadata:
  type: feedback
---

Al diseñar una puerta de autenticación, dos cosas que compruebo ANTES, porque la review adversarial de seguridad
las cazó el 2026-09-26 y yo no las había visto (conector MCP, `mcp/`):

**1. Un gate que decide por un CLAIM del token se salta cada camino que reemite un token SIN ese claim.** El hook de
Supabase daba `role = yala_mcp_reader` solo si el token traía `client_id`. Pero GoTrue reemite un token para la MISMA
sesión al verificar un factor MFA, y esa reemisión **no lleva `client_id`** → salía `authenticated` → escribía toda
la base. Con el Worker comprometido, la cuenta entera. **La regla:** cuando una puerta se apoya en un claim del
token, enumera QUIÉN reemite tokens para esa sesión —algunos dejan caer el claim— y decide por lo DURABLE (la
sesión, `auth.sessions.oauth_client_id`), no por el claim volátil. Es el pariente de
[[un-case-nuevo-hereda-cada-distinto-de]] y [[sellar-en-la-buena-noticia-cobra-la-app-cerrada]], una capa más abajo.

**2. Un fallo de verificación TRANSITORIO clasificado como «inválido» falla DESTRUCTIVO.** Verificaba el JWT de
Supabase contra su JWKS; cualquier excepción de `jwtVerify` la trataba como token inválido, y un token inválido
borraba la conexión. Pero un parpadeo del JWKS (red, timeout, 5xx, rotación de claves) también lanza — y entonces un
corte de Supabase de un minuto revocaba la conexión de TODOS los usuarios activos. **La regla:** en cada frontera de
verificación, distingue «no pude verificar AHORA» (reintenta, conserva el estado, 503) de «verifiqué y está mal»
(revoca). Solo la segunda borra. Es el pariente de [[un-fail-closed-sin-reintento-es-permanente]]: aquí el
fail-closed no solo bloqueaba, borraba.

**Why:** las dos eran de severidad alta y las tres lentes de la review convergieron en la segunda. La review
adversarial sobre lógica de auth **cazó lo mío** otra vez ([[review-adversarial-caza-lo-mio]]): no es teatro, es la
red que ve lo que el autor da por bueno.

**How to apply:** en cualquier gate de token o sesión, antes de darlo por cerrado: (a) grep de todos los sitios que
emiten un token para una sesión ya existente, y comprueba que el gate los cubre a todos; (b) mira el `catch` de la
verificación y pregunta «¿esto puede fallar por un corte, no por un token malo? ¿y si falla, qué borro?».

Relacionado: [[la-premisa-del-encargo-tambien-se-mide]] — mi residual de «qué queda al alcance si comprometen el
Worker» subestimaba el daño hasta que la lente lo midió.
