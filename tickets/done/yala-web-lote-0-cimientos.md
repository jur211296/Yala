---
id: yala-web-lote-0-cimientos
status: done
priority: high
area: web
created: 2026-11-13
updated: 2026-11-13
source: encargo 2026-11-13-yala-web-cimientos (card tablero-yala-web-definir-y-maquetar-la-app-web-c-ljz7)
---
# Yala web, lote 0: cimientos

Primer lote de construcción de Yala web (plan en `docs/web-app/index.html`). Jürgen aprobó las 13 decisiones con la
opción recomendada el 13-nov: V1 (Worker en Cloudflare), S1 (React + TypeScript servidos por el Worker), R1 (núcleo
TypeScript compartido con pruebas de paridad), D4 (30 días sin uso; equipo compartido hasta cerrar o 30 min), D8 (el
servidor de la web lee con el rol de solo lectura del conector).

## Alcance

1. Worker «yala-web» en `webapp/`, solo en staging.
2. Entrar con Apple y con Google, sesión de servidor cifrada (cookie que la página no lee) y defensa anti-bots.
3. Núcleo compartido: lo que el conector lee y calcula pasa a `shared-core/` y lo usan los dos, con paridad.
4. Página mínima: con sesión, el nombre de la cuenta y «Salir». Sin Panel (lote 1).

## Paso 0 — decisiones

Medido antes de decidir (13-nov, rama 2.3 y Supabase staging):

- Las credenciales web de Apple (Services ID `pe.yala.app.web`) y de Google (cliente web «Yala Web (MCP)») ya existen
  y ya están en Supabase staging. Apple y Google solo ven la vuelta de Supabase (`…supabase.co/auth/v1/callback`).
  La web no necesita altas nuevas en las consolas para staging. Escrito en la card de Dan.
- `GET /auth/v1/oauth/authorize` del servidor OAuth de Supabase responde 302 con un `authorization_id` sin pedir
  navegador ni sesión. El servidor de la web puede pedir y aprobar el permiso él solo, así que **la Site URL de
  staging (la del conector) no se toca**.
- `yala_mcp_reader` no puede leer `profiles`; el conector la consulta con la sesión normal del login social. La web
  hace lo mismo. `profiles.kind` vale `complete` o `groups_only`.
- El gateway importa `mcp/src/toolCore.ts`, `data.ts`, `supabaseEnv.ts` y `logic/dates.ts` por ruta relativa, y su
  test exige que `mcp/src/logic/` exista y no importe paquetes.
- Wrangler tiene sesión, pero sin el permiso `challenge-widgets.write`: no puede crear el widget de Turnstile.

| # | Pregunta | Decisión | Por qué |
|---|---|---|---|
| P1 | ¿Cómo consigue la web un acceso de solo lectura? | Segundo cliente OAuth confidencial de Supabase, «Yala web (staging)». El hook le da `role = yala_mcp_reader`, igual que al conector. | D8. Sin el rol, la «sonda que intenta escribir» no tendría nada que demostrar. |
| P2 | ¿Quién aprueba ese permiso? | El servidor de la web, con la sesión normal del login social, que cierra en la misma petición. | Así no pasa por la Site URL ni por la pantalla de permiso del conector. |
| P3 | ¿Dónde vive la sesión? | KV `WEB_KV`. La clave es el SHA-256 del valor de la cookie y los tokens van cifrados con AES-GCM, con una clave derivada de esa misma cookie. | Leer el KV no revela ningún token, como en el conector. No hace falta un secreto de servidor que rotar. |
| P4 | ¿Cuánto dura? | D4: 30 días deslizantes y 90 como tope. En equipo compartido, la cookie es de sesión del navegador y caduca a los 30 min sin uso. | Decisión aprobada. El tope de 90 días es el mismo del conector. |
| P5 | ¿Defensa anti-bots? | Turnstile antes de mandar al login social, verificado en el servidor, más un límite por IP en `/auth/*` y otro por sesión en `/api/*`. | El plan pide Turnstile y límites porque la web no tiene App Attest. |
| P6 | ¿Claves de Turnstile en staging? | Las de prueba que publica Cloudflare (siempre pasan). El widget real queda para Jürgen. | No se inventan credenciales y wrangler no puede crear el widget. El código ya verifica de verdad. |
| P7 | ¿Quién no usa la nube (D3)? | Sin `profiles` o con `kind = groups_only`: no entra. Se cierra la sesión normal y la página explica cómo activar la nube. | D3: «solo Grupos» entra en el lote 3. |
| P8 | ¿«Nombre de la cuenta»? | `GET /auth/v1/user` con el acceso de solo lectura: `full_name` o `name` de los metadatos, y si no hay, el correo. | `profiles` no guarda nombre. Esa llamada sirve además para comprobar que la sesión sigue viva. |
| P9 | ¿Cómo se mueve el núcleo sin romper el gateway? | El código va a `shared-core/src/`. En `mcp/src/` queda un reexport de una línea en cada ruta movida. | El gateway sigue igual, sin tocarlo, porque está fuera de este encargo. |
| P10 | ¿Qué prueba la paridad? | Una foto de la salida de las seis herramientas sobre los datos de prueba, sacada **antes** de mover. Después del movimiento, `shared-core` tiene que dar lo mismo byte a byte, y la suite entera de `mcp/` tiene que seguir verde. | Demuestra que el conector sigue igual. |
| P11 | ¿Dónde corren esas pruebas en el CI? | Dentro de `mcp/test/`, que ya corre en el job `mcp`. La web tiene su propio job (cambio mínimo en `.github/`, anotado). | «Las del núcleo, en el CI». |
| P12 | ¿Pruebas de punta a punta sin Apple ni Google? | Una ruta de login con contraseña **solo en staging**, como la del conector. Se prueba con los usuarios A y B: entrar, ver el nombre, la sonda de escritura (debe fallar) y salir. | Apple y Google no se automatizan. Fuera de staging, la ruta se niega en la configuración y en la lista cerrada de salidas. |
| P13 | ¿Dominio? | `yala-web-staging.misty-surf-6866.workers.dev`. | `app.yala-app.pe` exige mover el DNS a Cloudflare (hoy está en RCP). Queda para producción. |

Cambios en Supabase **staging** (permitidos por el encargo, anotados): registrar el cliente OAuth de la web, añadir
su id al hook (`webapp/supabase/web0_01_hook_web_client.sql`, con guarda md5 y marcha atrás) y añadir
`https://yala-web-staging.misty-surf-6866.workers.dev/auth/callback` a `uri_allow_list`. Producción no se toca.

## Fuera de este lote

- Barrido de sesiones huérfanas del cliente web en Supabase (el análogo de `mcp0_04`): lote 1, con la lista de sesiones.
- El widget real de Turnstile y `app.yala-app.pe`.
- Producción: ni Worker, ni cliente OAuth, ni hook.

## Resultado (13-nov)

- `shared-core/`: el núcleo de lectura del conector, movido tal cual. La foto de paridad (sacada antes de mover) sale
  igual byte a byte; suite de `mcp/` y del gateway en verde sin tocar el gateway.
- `webapp/`: Worker `yala-web-staging` desplegado en <https://yala-web-staging.misty-surf-6866.workers.dev>, con la
  página (React + Vite), login con Apple y Google vía Supabase, sesión cifrada, Turnstile y límites.
- Supabase staging: cliente OAuth de la web, hook `web0_01` y la vuelta en `uri_allow_list` (detalle y marcha atrás en
  `webapp/README.md`). Producción sin tocar.
- Revisión de seguridad independiente: cazó dos fallos que habrían impedido entrar y salir desde un navegador real
  (la cookie del login con prefijo `__Host-` y `Path=/auth`, que el navegador descarta; y `no-referrer`, que hace que
  los formularios lleguen con `Origin: null`) y seis menores. Arreglados, con pruebas que los cazan; comprobado en
  Chrome que «Continuar con Apple» llega a la pantalla de Apple.
- Pruebas: 46 unitarias de la web; e2e contra staging 9/9 (página, puerta de Apple y de Google, A y B entran y salen,
  contraseña mala, «solo Grupos» no entra, y la sonda: con el rol de la web PostgREST rechaza insertar, cambiar y
  borrar).

## Guion de prueba para Jürgen (Apple y Google de verdad)

Lo único que no se automatiza es pasar por la pantalla de Apple o de Google. En un ordenador o en el iPhone:

1. Abre <https://yala-web-staging.misty-surf-6866.workers.dev>.
2. Toca «Continuar con Apple» y entra con la cuenta con la que usas **Yala Dev** con la nube activada.
3. Tiene que salir «Hola, <tu nombre>» y tu correo. Si sale «Tu Yala vive en iCloud», esa cuenta no tiene la nube en
   staging: es correcto, pero prueba con la de Yala Dev.
4. Toca «Salir». Tiene que volver a la pantalla de entrar con «Saliste de Yala web».
5. Repite con «Continuar con Google».
6. Marca «Es un equipo compartido», entra, cierra el navegador entero y vuelve a abrir la dirección: tiene que pedirte
   entrar otra vez.
