Yala
# Yala web, cimientos: worker yala-web en staging, entrar con Apple y Google, sesión segura y núcleo compartido
---
card: tablero-yala-web-definir-y-maquetar-la-app-web-c-ljz7
toca: webapp/, shared-core/, mcp/src/, mcp/test/, mcp/package.json, mcp/package-lock.json, docs/web-app/, tickets/backlog/yala-web-lote-0-cimientos.md, tickets/done/yala-web-lote-0-cimientos.md
esfuerzo: high
cierre: cierra-sola
---

Primer lote de construcción de Yala web (la web como un dispositivo más en modo nube). Jürgen aprobó la maqueta y las 13 decisiones con las opciones recomendadas (13-nov, 10:00). El plan completo está en `docs/web-app/index.html` (PR 941) y las respuestas de las decisiones en la colección `decisiones` del artifact https://claude.ai/artifact/JN7jw8J1UXBQGNNpLNErAe. Léelos antes de empezar y sigue el Lote 0 tal como está ahí.

Alcance del Lote 0 (cimientos, versión 2.3):
1. Worker de Cloudflare «yala-web» en una carpeta nueva `webapp/`, desplegado solo en staging con su dominio de staging.
2. Entrar con Apple y con Google desde el navegador, con sesión de servidor cifrada (cookie segura, sin tokens en el navegador) y protección anti-bots.
3. Núcleo compartido: lo que el conector (`mcp/`) ya hace para leer y escribir datos de la nube se mueve a `shared-core/` y lo usan los dos, con pruebas de paridad que demuestren que el conector sigue igual.
4. Una página mínima que, ya con sesión, muestre el nombre de la cuenta y salga bien. Nada de Panel todavía: eso es el Lote 1.

Dependencia externa (card `tablero-services-id-de-apple-y-cliente-web-de-go-zioy`): el Services ID de Apple y el cliente web de Google los crea Dan en las consolas. Escribe en esa card, al inicio, el dominio de staging y las URL de retorno exactas que necesitas, para que Dan pueda crearlos. Mientras no existan, deja el código listo y probado con dobles, y el inicio real queda pendiente en la card. No inventes credenciales.

Riesgo conocido: Supabase tiene una sola Site URL. No cambies la configuración de autenticación de producción. Cualquier cambio en el servidor de producción o en la autenticación de Supabase es vital y se pregunta según el modo. En staging puedes hacerlo y lo anotas.

**Pruebas:** tests unitarios y de paridad del conector (vitest), y una prueba de punta a punta en staging hasta donde lo permitan las credenciales. Al final corre la suite completa de `mcp/` una vez.

**Archivos:** puede correr en paralelo con sesiones de Yala de la app iOS, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR. No toques `Web/` (es el sitio de marketing y sale con la rama 1.0).

**Entrega:** un PR contra 2.3, mergeado si CI pasa, el ticket en done y la card en QA. Commits y PR sin firma de IA. El resumen va como artifact visual de Claude. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Lo vital (acceso, credenciales, datos del servidor, seguridad) se pregunta según el modo de la sesión. Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones (resueltas por Frank en modo semi, 13-nov)

Medido: las credenciales web de Apple (`pe.yala.app.web`) y Google («Yala Web (MCP)») ya están en Supabase staging y
la vuelta que ven es la de Supabase; `GET /auth/v1/oauth/authorize` da el `authorization_id` sin navegador; el gateway
importa `mcp/src/{toolCore,data,supabaseEnv,logic/dates}` por ruta relativa; wrangler no puede crear widgets de Turnstile.

1. Acceso de solo lectura: segundo cliente OAuth confidencial de Supabase («Yala web (staging)»), con el hook dándole `yala_mcp_reader` (D8).
2. El permiso lo pide y aprueba el servidor de la web con la sesión normal del login social, que cierra en la misma petición: la Site URL del conector no se toca.
3. Sesión en KV: clave = SHA-256 de la cookie; tokens cifrados AES-GCM con clave derivada de la cookie.
4. Duración (D4): 30 días deslizantes, tope 90; equipo compartido = cookie de sesión del navegador + 30 min sin uso.
5. Anti-bots: Turnstile verificado en el servidor antes del login social + límites por IP (`/auth/*`) y por sesión (`/api/*`).
6. Turnstile en staging con las claves de prueba publicadas por Cloudflare; el widget real queda para Jürgen.
7. Sin nube (`profiles` ausente o `kind = groups_only`): no entra, se explica cómo activarla (D3).
8. Nombre de la cuenta: `GET /auth/v1/user` (metadatos `full_name`/`name`, si no el correo); sirve también de chequeo de sesión viva.
9. Núcleo a `shared-core/src/`; en `mcp/src/` un reexport por ruta movida, para que el gateway (fuera de `toca:`) no cambie.
10. Paridad: foto de la salida de las seis herramientas sacada ANTES de mover; `shared-core` debe dar lo mismo byte a byte, y la suite de `mcp/` entera verde.
11. CI: las pruebas del núcleo viven en `mcp/test/` (job `mcp`); la web añade su job en `.github/workflows/qa.yml` (fuera de `toca:`, cambio mínimo).
12. E2E: ruta de contraseña solo en staging (como el conector), con usuarios A y B: entrar, nombre, sonda de escritura que falla, salir.
13. Dominio: `yala-web-staging.misty-surf-6866.workers.dev`; `app.yala-app.pe` exige mover el DNS (RCP) y queda para producción.

Detalle y porqués: `tickets/backlog/yala-web-lote-0-cimientos.md`.
