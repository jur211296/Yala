# Conector de Claude — salida a producción

**Estado (22-nov-2026, medido en solo lectura): listo para desplegar en `https://mcp.yala-app.pe`, NO desplegado.**
Lo despliega Dan (autorizado por Jürgen el 22-nov, 08:49 y 08:51 Lima); Jürgen prueba el login con Apple en producción
al conectarse. Este documento tiene solo lo que falta, en orden, y cada paso lleva su comprobación y su marcha atrás.

Contexto: `README.md` (cómo funciona), el ADR «El conector de Claude emite sus propios tokens» (`docs/DECISIONS.md`) y
`webapp/README.md`, «Producción» (lo que Yala web dejó hecho el 16-nov).

## Qué tiene ya producción y qué le falta

Medido el 22-nov con `python3 mcp/scripts/sql-conector-produccion.py estado` (solo lectura, sin secretos):

| Pieza | Hoy en producción | Qué falta para el conector |
|---|---|---|
| Rol `yala_mcp_reader` y sus permisos de lectura | **Ya está** (`mcp0_01`, aplicado con Yala web el 16-nov). Los mismos 14 permisos que staging | Nada |
| Hook de token `yala_mcp_access_token_hook` | Encendido, md5 `7a703d85…`: reconoce a Yala web (`yala_web`) y el id del conector es el **uuid nulo** | Poner el id real del conector (`conector01`) |
| Barrido diario de sesiones del conector | No está. `pg_cron` sí (lo usa el barrido de la web) | `conector02` |
| Servidor OAuth de Supabase | Encendido, registro abierto apagado, ruta `/oauth/consent`. Un solo cliente: «Yala web» | El cliente confidencial del conector (dashboard) |
| Apple y Google | Encendidos, con el cliente **web primero** (`pe.yala.app.web`, «Yala Web (MCP)») | Nada |
| Proveedor de email | **Apagado** | Nada |
| `site_url` | `http://localhost:3000`: no lo usa ningún flujo de hoy | **`https://mcp.yala-app.pe`**: el conector lo necesita (abajo, paso 5) |
| KV `yala-mcp-production-oauth` | Creado (`3683c133…`, en `wrangler.toml`) | Nada |
| Gateway de producción | Corre la versión con «Cuenta sola» + Yala IA ampliada al 100 %. Sin la migración D1 `0004_connector_quota` | La migración y un despliegue desde 2.3 (paso 1) |
| Worker `yala-mcp-production` y `mcp.yala-app.pe` | No existen (el dominio no resuelve) | Desplegar (paso 6) |

**Lo que ya NO se hace**, aunque lo decía la versión anterior de este documento:
- **No se aplican los `mcp0_0*` ni `mcp/scripts/sql-produccion.py`.** Producción ya los tiene; reaplicarlos abortaría por
  su guarda md5 y, si pasaran, el hook perdería `yala_web`: la web dejaría de entrar.
- **No se encienden el hook, el servidor OAuth, Apple ni Google, ni se apaga el email**: ya lo hizo Yala web.
- **No se manda nunca la config de Auth entera** en un `PATCH`: solo la clave que se cambia, o pisaría lo de la web.

## Quién, dónde y con qué

| Qué | Dónde | Con qué |
|---|---|---|
| SQL y config de Auth de Supabase | **La Mini**, en `~/Yala` con 2.3 al día | El token de la Management API, `~/Secrets/yala-supabase-mgmt/pat` |
| Cliente OAuth del conector | Dashboard de Supabase, proyecto `kefvaiymtgytemwbltlz` | La sesión de Jürgen o Dan en supabase.com (no hay API sin la service role key) |
| `wrangler` de producción (gateway y conector) | **La Max** | La cuenta de Cloudflare de Yala (admin@yala-app.pe): `npx wrangler whoami` tiene que mostrar la cuenta `86c270a7776be98639700bd5959b303b` |

## Las dos variantes, y cuál recomiendo

- **A · Completa (recomendada).** Gateway primero (migración `0004` + despliegue desde 2.3), después el conector con su
  herramienta de escritura (`apuntar_movimiento`, deja borradores en la Bandeja). **La condición se cumple:** el PR de
  «Cuenta sola» (#1115) entró en 2.3 el 22-nov (merge `a8f5ae89`), y era lo que impedía desplegar el gateway desde 2.3:
  producción corría ese código sin commit.
- **B · Solo lectura primero.** Si el gateway no puede ir hoy, el conector sale sin el bloque `[[env.production.services]]`
  de `wrangler.toml`: la herramienta de escritura no se ofrece y el conector solo lee. **Coste:** quien conecte su IA
  durante la variante B no gana la herramienta después; tiene que desconectar y volver a conectar (`GrantProps.drafts`).
  Pasos al final, «Variante B».

Recomiendo **A**: la dependencia ya está resuelta y B obliga a reconectar a los primeros usuarios. La decisión de sacar
el conector solo de lectura es de Jürgen; si no dice nada, va A.

## Los pasos (variante A)

### 0 · Comprobar que producción sigue como se midió (Mini, solo lectura)

```bash
cd ~/Yala && git pull --ff-only          # 2.3 con este runbook y su script
python3 mcp/scripts/sql-conector-produccion.py --verificar
python3 mcp/scripts/sql-conector-produccion.py estado produccion | tee ~/Secrets/yala-mcp-production/estado-antes-$(date +%Y%m%d-%H%M).txt
```
**Tiene que decir:** `Hook como el 22-nov (conector nulo): SÍ`, los roles `yala_mcp_reader` y `yala_web`, un solo
cliente («Yala web · confidential»), sin `barrido`, y en Auth `oauth_server_enabled = True` y
`hook_custom_access_token_enabled = True`. **Si algo no cuadra, se para aquí** y se avisa: alguien tocó producción.

Guardar también la foto completa de Auth (es la marcha atrás de `site_url`; tiene secretos, va solo a `~/Secrets`):
```bash
curl -s -H "Authorization: Bearer $(cat ~/Secrets/yala-supabase-mgmt/pat)" \
  https://api.supabase.com/v1/projects/kefvaiymtgytemwbltlz/config/auth > ~/Secrets/yala-mcp-production/auth-config-antes-$(date +%Y%m%d).json
```

### 1 · El gateway: migración `0004` y despliegue desde 2.3 (Max)

```bash
cd ~/Yala && git pull --ff-only && cd gateway && npm ci
npx wrangler whoami                                              # cuenta 86c270a7…
npx wrangler deployments list --env production | tail -5         # APUNTA el id de la versión actual: es la marcha atrás
curl -s https://yala-gateway-production.misty-surf-6866.workers.dev/config > /tmp/gw-config-antes.json
npx wrangler d1 migrations list yala-gateway-production --env production --remote
```
**La lista de migraciones sin aplicar tiene que ser solo `0004_connector_quota.sql`.** Si sale otra, se para: este
runbook no la cubre.
```bash
npm run migrate:production         # crea la tabla connector_quota (techo diario por cuenta). Aditiva
npm run deploy:production          # el predeploy comprueba que el manifest no sea más viejo que el desplegado
```
**Comprobación:**
- `curl -s …/config | diff /tmp/gw-config-antes.json -` → sin diferencias que no se esperen (Yala IA ampliada sigue en 100);
- rutas sin token siguen en 401 (`curl -s -o /dev/null -w "%{http_code}" …/sync/pull` y `…/mail/drafts`);
- la app del iPhone sincroniza y Yala web (`https://app.yala-app.pe`) entra y ve el Panel;
- `npx wrangler tail --env production` un par de minutos, sin `[gw-err]` nuevos.

**Marcha atrás:** `npx wrangler rollback --env production <versión apuntada>`. La tabla `connector_quota` se queda: no
la lee nadie más.

### 2 · El cliente OAuth del conector (dashboard de Supabase)

Proyecto `kefvaiymtgytemwbltlz` → *Authentication → OAuth Server* → *Add client* (el servidor ya está encendido):
- nombre «Yala para Claude», tipo **confidencial** (`client_secret_basic`);
- una sola vuelta, exacta: `https://mcp.yala-app.pe/oauth/supabase/callback`.

Copiar el `client_id` y el secreto **directo** a `~/Secrets/yala-mcp-production/supabase-oauth-client.json` **en la
Max** (`{"client_id": "…", "client_secret": "…"}`, permisos 600). El secreto no pasa por el chat ni por pantalla.

Registrarlo no abre nada: con el hook de hoy, un token de ese cliente recibe **403** (el hook solo conoce a la web). Se
abre en el paso 4.

**Comprobación (Mini):** `python3 mcp/scripts/sql-conector-produccion.py estado produccion` lista dos clientes, el
nuevo con `confidential` y esa vuelta exacta. **Marcha atrás:** borrarlo desde el dashboard (nadie lo usa todavía).

### 3 · El secreto en el Worker (Max)

```bash
cd ~/Yala/mcp && npm ci
python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/Secrets/yala-mcp-production/supabase-oauth-client.json')))['client_secret'],end='')" \
  | npx wrangler secret put SUPABASE_OAUTH_CLIENT_SECRET --env production
npx wrangler secret list --env production       # tiene que salir SUPABASE_OAUTH_CLIENT_SECRET
```
Si el Worker aún no existe, wrangler pregunta si lo crea para guardar el secreto: sí (queda vacío hasta el paso 6).
**Marcha atrás:** `npx wrangler secret delete SUPABASE_OAUTH_CLIENT_SECRET --env production`.

### 4 · El SQL: el hook reconoce al conector, y su barrido (Mini)

```bash
cd ~/Yala
python3 mcp/scripts/sql-conector-produccion.py generar <client_id> ~/Secrets/yala-mcp-production/sql
python3 mcp/scripts/sql-conector-produccion.py ensayo produccion ~/Secrets/yala-mcp-production/sql
```
`generar` escribe cuatro ficheros: `conector01_hook`, `conector02_barrido` y sus `_rollback`. `ensayo` los aplica, los
vuelve atrás y los reaplica **dentro de una transacción que un RAISE final deshace** (lo mismo que se hizo con Yala web
el 16-nov): no confirma nada y prueba las guardas contra la base real. Tiene que decir `ENSAYO OK`.

Qué hace cada uno (y lo que NO toca):
- **`conector01`**: reemplaza el hook por el mismo cuerpo que corre hoy, con el id del conector donde está el uuid nulo
  (md5 `7a703d85…` → el que imprime `generar`). La web sigue saliendo `yala_web`, el login de la app sigue
  `authenticated` sin tocar, y cualquier otro cliente, 403. Aborta si el hook no es el medido, si faltan los roles o el
  cliente web, o si el id no es un cliente confidencial con la vuelta de producción. Comprueba su resultado al final.
- **`conector02`**: el barrido diario (04:17 UTC) que cierra las sesiones de Supabase **del conector** sin uso en 31 días
  o con más de 91 (`qa/cloud/mcp0_04`). No toca sesiones de la app ni de la web. Solo se aplica con el hook de `conector01`.

```bash
python3 mcp/scripts/sql-conector-produccion.py aplicar produccion ~/Secrets/yala-mcp-production/sql/conector01_hook.sql
python3 mcp/scripts/sql-conector-produccion.py aplicar produccion ~/Secrets/yala-mcp-production/sql/conector02_barrido.sql
python3 mcp/scripts/sql-conector-produccion.py estado produccion
```
`aplicar` manda cada fichero como **una transacción**: si una guarda o la comprobación final fallan, no queda nada.
**Comprobación:** el hook con el md5 «después» de `_md5.json` y el id del conector dentro; `barrido` presente; en cron,
`yala-mcp-sweep-connector-sessions` y `yala-web-sweep-sessions`. Y **la web sigue entrando**: abrir
`https://app.yala-app.pe` en una ventana privada, entrar con Google y ver el Panel.

**Marcha atrás**, en este orden: `aplicar … conector02_rollback.sql` y `aplicar … conector01_rollback.sql`. El segundo
devuelve el hook exacto de hoy (md5 `7a703d85…`): el conector vuelve a recibir 403 y la web no cambia.

### 5 · `site_url` = el conector (Mini)

Supabase manda el navegador a `site_url + /oauth/consent` para pedir el permiso **de cualquier cliente OAuth** (medido en
staging el 22-nov con el cliente de la web). Yala web no se entera: lee el `authorization_id` de esa redirección sin
seguirla y no mira el host (`webapp/src/worker/supabase.ts`, `grantReadOnly`). El conector sí la sigue: con
`localhost:3000` la persona acabaría en una página que no existe. `site_url` también hace válida la vuelta del login
social del conector (`https://mcp.yala-app.pe/oauth/consent/social`) sin tocar `uri_allow_list`, igual que en staging.

```bash
curl -s -X PATCH -H "Authorization: Bearer $(cat ~/Secrets/yala-supabase-mgmt/pat)" -H "Content-Type: application/json" \
  -d '{"site_url":"https://mcp.yala-app.pe"}' \
  https://api.supabase.com/v1/projects/kefvaiymtgytemwbltlz/config/auth > /dev/null
python3 mcp/scripts/sql-conector-produccion.py estado produccion | grep site_url
```
**Comprobación:**
- `site_url = https://mcp.yala-app.pe` y `uri_allow_list` sin cambios (`https://app.yala-app.pe/auth/callback`);
- el login social del conector llega a Google con el cliente web:
  `curl -s -o /dev/null -w "%{redirect_url}\n" "https://kefvaiymtgytemwbltlz.supabase.co/auth/v1/authorize?provider=google&redirect_to=https://mcp.yala-app.pe/oauth/consent/social&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=s256"`
  → `accounts.google.com` con `client_id=295312853864-af0pqpn7…`; con `provider=apple`, `appleid.apple.com` con
  `client_id=pe.yala.app.web`;
- Yala web entra otra vez (ventana privada, Google o Apple).

**Marcha atrás:** el mismo `PATCH` con `{"site_url":"http://localhost:3000"}` (el valor de la foto del paso 0).

### 6 · Desplegar el Worker del conector (Max)

En `mcp/wrangler.toml`, sustituir `PENDIENTE-registrar-cliente-oauth-en-supabase-produccion` por el `client_id` (no es
un secreto). Después:
```bash
cd ~/Yala/mcp
npm run deploy:production
```
`deploy:production` corre antes el preflight (`scripts/preflight-production.mjs`): se niega si queda algo PENDIENTE, si
el id no es un uuid, si falta el secreto o un límite, o si fallan el typecheck o los tests. Una vez desplegado, si la
configuración está mal el Worker responde **503 a todo** y lo anota (`evento: config_invalida`).

**Ese cambio de una línea en `wrangler.toml` tiene que volver a 2.3** (un PR corto, o pedírselo a una sesión de Yala):
si no, el siguiente despliegue desde el repo se niega por el PENDIENTE.

**Comprobación:**
- `curl https://mcp.yala-app.pe/` → «Yala MCP: conector de Yala para tu IA…» (sin «(staging)»);
- `curl -s https://mcp.yala-app.pe/.well-known/oauth-authorization-server` → el emisor es `https://mcp.yala-app.pe`;
- `npx wrangler tail --env production --format pretty` mientras se hace el paso 7, sin `config_invalida`.

**Marcha atrás:** `npx wrangler delete --env production` (era el primer despliegue: sin Worker, ninguna IA tiene a quién
pedir nada). Si ya había una versión buena, `npx wrangler rollback --env production`.

### 7 · Conectar Claude a producción (Jürgen)

claude.ai → Ajustes → Conectores → *Añadir conector personalizado* → `https://mcp.yala-app.pe/mcp`, o en Claude Code
`claude mcp add --transport http yala https://mcp.yala-app.pe/mcp`. *Continuar* → **Continuar con Apple** (Jürgen; Google ya
está probado).
**Comprobación:**
- «¿cuánto gasté este mes?» responde con los datos de la app;
- «apunta 1 sol de prueba» deja el borrador en la Bandeja de la app 2.3 (con una app anterior espera en la cola hasta 30
  días y entra al actualizar); se descarta desde la Bandeja;
- en la base, `estado produccion` sigue igual y en `auth.sessions` aparece una sesión del cliente del conector.

El e2e automático (`npm run test:e2e`) entra con email y contraseña, que en producción no existen: en producción se
valida a mano, así.

### 8 · Opcional, fuera del camino crítico: endurecer la cuenta

- **Apagar MFA** (`{"mfa_totp_enroll_enabled": false, "mfa_totp_verify_enabled": false}` con el mismo `PATCH`).
  Recomendado: la app y la web no lo usan y el 22-nov había **0 factores** en producción, así que no afecta a nadie; cierra
  la puerta de que un Worker comprometido le ponga un segundo factor a una cuenta. Marcha atrás: los dos a `true`.
- **Avisos por correo de cambios en la cuenta** (`mailer_notifications_*`, hoy apagados): **pregunta para Jürgen**.
  Encenderlos manda correos a los usuarios (identidad enlazada, email cambiado…).
- `security_update_password_*` no hace falta: con el email apagado nadie entra con contraseña.

## Variante B · solo lectura primero

En vez del paso 1, en el paso 6 se despliega sin la escritura: comentar en `mcp/wrangler.toml` el bloque
`[[env.production.services]]` (las cuatro líneas de `CONNECTOR_DRAFTS`) **solo en la copia local**, desplegar, y
restaurar el fichero (`git checkout mcp/wrangler.toml`, conservando el `client_id`). La herramienta `apuntar_movimiento`
no se ofrece. Cuando el gateway esté (paso 1), se despliega otra vez con el bloque. Quien conectó durante B tiene que
desconectar y volver a conectar para ver la herramienta.

## Lote 5 · `ver_bandeja`, `referencia` y posible duplicado (24-nov)

En staging desde el 24-nov (e2e `test/e2e/bandeja.e2e.test.ts`, 4/4). En producción **no**. Tres pasos, en este orden,
y cada uno con su porqué:

1. **Migración D1 `0007_connector_refs.sql`** en el gateway de producción (`npm run migrate:production` en `gateway/`;
   aditiva, una tabla nueva). Antes que el código: sin ella, una `referencia` hace fallar `apuntar_movimiento`.
2. **Gateway desde 2.3** con este lote. Trae `ConnectorDrafts.pending` y las opciones de `enqueue`; sin opciones se
   comporta como antes, así que el conector de producción de hoy sigue igual.
3. **Conector desde 2.3.** Después del gateway: un conector nuevo contra un gateway viejo ofrecería `ver_bandeja` y su
   lectura de la cola fallaría.

Comprobación: con una cuenta de prueba, `apuntar_movimiento` dos veces con la misma `referencia` → la segunda responde
`ya_apuntado`. Marcha atrás: `wrangler rollback` de los dos Workers; la tabla `connector_refs` se queda (no la lee nadie).

## Marcha atrás completa

Siempre al revés que la subida:
1. **Worker del conector:** `npx wrangler delete --env production` (o `rollback`). Sin él, nadie pide nada.
2. **`site_url`:** `PATCH` a `http://localhost:3000`.
3. **SQL:** `conector02_rollback` y después `conector01_rollback` (paso 4). El hook vuelve al de hoy y la web no cambia.
4. **Cliente OAuth y secreto:** pueden quedarse (sin hook ni Worker no sirven) o borrarse.
5. **Gateway:** solo si dio problemas, `wrangler rollback` a la versión apuntada en el paso 1.

No hay paso que toque lo de Yala web: ni su cliente, ni `yala_web`, ni sus funciones, políticas o su cron.

## Cómo se probó (22-nov, staging)

`python3 mcp/scripts/sql-conector-produccion.py ensayo-staging`, en una transacción que se deshace: staging se lleva a la
forma de producción (marchas atrás generadas), se aplica el SQL generado, se vuelve atrás y se reaplica. Resultado: el
«después» es **byte a byte** el hook que staging corre hoy (md5 `54a4444f…`, con el que su web entra a diario); en la
forma de producción la app sale `authenticated`, la web `yala_web` y el conector 403; con el SQL, el conector
`yala_mcp_reader`; lo de la web (rol, funciones, políticas, cron) idéntico en todos los pasos; reaplicar no cambia nada;
y abortan el SQL de producción sobre otro hook, un id que no es el cliente y el barrido sin el hook.

Además, un ciclo **real** de 30 s en staging: marchas atrás aplicadas → el e2e de Yala web entra (A, B y una cuenta solo
de Grupos) y el conector no → SQL aplicado → la web entra y el e2e del conector pasa (salvo un caso que cuenta seis
herramientas y hoy son siete: ajeno a esto) → staging con la misma huella que al empezar.

## Coste en Cloudflare (estimación)

La cuenta ya está en **Workers Paid** (5 USD/mes, la paga el gateway). El conector **no sube ese tope**: todo lo que
gasta cabe en lo incluido. Precios de la página oficial, leída el 2026-11-04:

| Recurso | Incluido en Paid, al mes | Lo que gasta el conector | Si se pasara |
|---|---|---|---|
| Peticiones | 10 millones | 1 por herramienta, más descubrimiento y refresh. 100 usuarios × 30 llamadas/día ≈ 90 000/mes | 0,30 USD por millón |
| CPU | 30 millones de ms | unos pocos ms por llamada (la espera a Supabase no cuenta) | 0,02 USD por millón de ms |
| KV, lecturas | 10 millones | 1–2 por llamada (validar el token) | 0,50 USD por millón |
| KV, escrituras | 1 millón | registro, autorización y cada refresh (unas pocas por usuario y hora de uso) | 5 USD por millón |
| KV, almacenamiento | 1 GB | kilobytes (clientes y grants) | 0,50 USD por GB-mes |
| Límites de peticiones (`[[ratelimits]]`) | — | 3 cubos | la documentación no les pone precio |

**Tope que se propone:** 0 USD de más al mes en uso normal. Un abuso lo frenan los límites (abajo). Sugerencia: una
alerta de facturación en Cloudflare a partir de 10 USD. Supabase producción ya es Pro y no cambia de plan.

## Otras IA: ChatGPT y Grok

**ChatGPT** ya está en la lista de vueltas OAuth (`authorize.ts`). **Grok** no publica la suya: el primer intento de
conectarlo deja la vuelta rechazada en el log,
```bash
npx wrangler tail --env production --format pretty | grep vuelta_no_permitida
```
y se añade exacta en `[env.production.vars]` como `EXTRA_REDIRECT_URIS = "https://…"` (varias, separadas por comas).
Si el log dice `+query`, la vuelta traía query y la lista compara la URL entera. Una entrada mal escrita no tumba el
Worker: se ignora y se avisa (`vuelta_extra_mal_escrita`). Cómo dar de alta cada IA, para la persona: `CONECTAR-TU-IA.md`.

## Dominio propio

**`mcp.yala-app.pe`** (decisión 64 de la auditoría del 21-nov). El DNS de `yala-app.pe` está en Cloudflare, así que
`routes = [{ pattern = "mcp.yala-app.pe", custom_domain = true }]` crea el registro y el certificado al desplegar. Hasta
el 22-nov era un alias del Worker de staging; ese día se soltó y el de pruebas pasó a `mcp-staging.yala-app.pe`.
Volver a enganchar `mcp.yala-app.pe` a staging rompería este despliegue.

## Límites de peticiones

| Cubo | Clave | Rutas | Límite |
|---|---|---|---|
| `RL_BROWSER` | IP | `/authorize`, `/oauth/consent`, `/oauth/supabase/callback` | 30 por minuto |
| `RL_OAUTH` | IP | `/oauth/register`, `/oauth/token` | 600 por minuto (claude.ai llama desde pocas IPs de Anthropic) |
| `RL_MCP` | usuario | `/mcp` | 120 por minuto |

Se ajustan en `wrangler.toml` sin tocar código. El contador es aproximado y por ubicación de Cloudflare. Un 429 se
anota en el log como `evento: mcp_limite`.
