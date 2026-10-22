# Cerrar el hueco: el token OAuth de solo lectura que Yala da a Claude puede cambiar la cuenta vía Supabase Auth

## Contexto
Fase 0 del conector MCP de Yala para Claude mergeada hoy (PR #261, base 2.1). Claude se conecta por OAuth a
Supabase staging y recibe un token con `role = yala_mcp_reader`: PostgREST le deniega escrituras (403), pero
con ese mismo token `PUT /auth/v1/user` de GoTrue responde 200 y aplica cambios (metadatos medido; email y
contraseña inferidos, `security_update_password_require_reauthentication` = false en staging). La pantalla de
consentimiento promete que Claude «no podrá crear, cambiar ni borrar nada». Esto bloquea la fase 1.
Ticket: `tickets/backlog/claude-mcp-oauth-token-can-change-the-account.md` (léelo entero: ahí están las tres
vías). Contexto técnico: `docs/exploracion/plugin-claude-mcp.md` §7, `mcp/`, `mcp/test/e2e/oauth.e2e.test.ts`
(el hueco está como `it.fails`), `docs/RUNBOOK-staging-ddl.md`, y el Paso 0 en
`encargos/lanzados/2026-09-26-plugin-claude-mcp-fase0-spike.md`.

## Que se pide
- Cerrar el hueco de verdad: con el token que recibe Claude no debe poder cambiarse NADA de la cuenta
  (metadatos, email, contraseña, identidades, MFA, ni cualquier otro endpoint de escritura de `/auth/v1/*`).
  La promesa de la pantalla tiene que cumplirse entera.
- Decisión ya tomada (norma de Jürgen: siempre la opción robusta, no la mínima): la vía 2 del ticket (reauth de
  contraseña + confirmación de email) NO basta sola porque deja los metadatos. Primero comprueba si Supabase
  permite restringir `/auth/v1/user*` para tokens OAuth por scope o cliente; si existe y cubre todo, úsala. Si no
  existe o deja algo, implementa la vía 3: OAuth propio en el Worker (p. ej. `workers-oauth-provider` de
  Cloudflare) que emite a Claude un token que no es de Supabase y guarda la sesión de Supabase cifrada, con
  revocación, rotación y expiración bien resueltas. Vuelve a pesar lo que el Paso 0 descartó con este dato y deja
  la decisión escrita (ADR si lo pide el repo). La vía 2 se aplica además como defensa en profundidad.
- Si la vía limpia no existe en Supabase, deja redactado el texto del issue para `supabase/auth` en el PR (no lo
  publiques).
- El e2e `oauth.e2e` pasa a verde en el caso del hueco (quita el `it.fails` y convierte en test positivo que
  prueba que TODAS las escrituras de la cuenta fallan), y siguen verdes unitarios, `tools.e2e` y el login normal
  de la app (`authenticated`, sin `client_id`).
- Actualiza `docs/exploracion/plugin-claude-mcp.md` y el runbook con lo que cambie en staging (tabla antes/después
  como en #261, con marcha atrás).

## Que NO hay que tocar
- Producción de Supabase: nada. Solo el proyecto staging `fostjbbwstyuunmmefuk` (`yala-modo-nube-staging`).
  Token de gestión en `~/Secrets/yala-supabase-mgmt/pat` (Llavero: `yala-supabase-mgmt-pat`); solo ve staging.
  No lo imprimas ni lo copies a ficheros del repo.
- Código Swift de la app y el target iOS: no. En paralelo corre otra sesión de Yala sobre sync (Cola A) en su
  worktree; tú te quedas en `mcp/`, docs, qa/cloud y tickets. Si al integrar chocan `tickets/` o
  `docs/TICKETS.md`, rebasa sobre origin/2.1 y recuenta.
- No publiques el plugin ni despliegues nada fuera de `workers.dev` de staging.
- Los otros tickets de MCP (`claude-mcp-numbers-match-the-app`, `claude-mcp-consent-with-apple-and-google`) y el
  bug `budget-interval-counts-next-period-midnight`: no.

## Como se sabe que esta bien
- Medido contra staging real con los usuarios de prueba A y B: todas las escrituras de `/auth/v1/*` con el token
  de Claude fallan; lectura de finanzas por las seis herramientas sigue funcionando; B no ve a A; revocar corta.
- Review adversarial de seguridad sobre el diff antes del merge, con hallazgos arreglados.
- PR a 2.1 mergeado, ticket movido y `docs/TICKETS.md` al día, `/cerrar-total`.

## MODO AUTÓNOMO
Queda suspendida para este encargo la regla del repo de esperar aprobación si hay más de 3 ficheros y el
«¿Sigo?» tras el plan: implementa de punta a punta (gate, PR, merge, `/cerrar-total`) sin pedir permiso para
seguir. Es horario diurno (Lima): puedes preguntar a Jürgen con AskUserQuestion solo lo que sea de producto o
acceso de verdad (p. ej. si necesitas algo de su cuenta). Las decisiones técnicas las tomas tú eligiendo la
opción robusta. Si aparecen bugs o decisiones nuevas, ticket propio antes de cerrar.

## Paso 0 — decisiones

> Resueltas en autónomo (encargo lanzado, horario diurno): ninguna es de producto ni de acceso, así que las
> contesté yo con lo medido. Se discuten en el PR.

**Hechos medidos antes de decidir (2026-09-26, 11:00 Lima).**
- Staging corre **GoTrue v2.197.0** (`/auth/v1/health`), que es la última versión publicada de `supabase/auth`.
  En su código, `requireAuthentication` (`internal/api/auth.go`) acepta cualquier JWT válido del usuario y **no
  mira `client_id` ni `scope`**. Con él se protegen `/user` (GET, PUT), `/user/identities/*`, `/user/oauth/grants`,
  `/factors/*`, `/passkeys/*`, `/logout`, `/reauthenticate` y `/oauth/authorizations/*`. Tampoco hay issue ni PR
  abierto que lo cambie (búsqueda en `supabase/auth`, 26-sep). La doc de Supabase solo dice que los scopes no
  controlan el acceso a la base.
- **La vía 2 cubre menos de lo que suponía el ticket.** Medido en `internal/api/user.go`:
  - `security_update_password_require_reauthentication` solo pide el código si la sesión tiene **más de 24 h**. Una
    sesión OAuth recién emitida cambia la contraseña sin él.
  - `security_update_password_require_current_password` solo se aplica si el usuario **ya tiene** contraseña. Un
    usuario de Apple o Google no la tiene, así que el token puede **ponerle una** y entrar con email y contraseña:
    una sesión `authenticated` completa. En producción, todos los usuarios son de Apple o Google.
  - El cambio de email ya pide confirmar las dos direcciones en staging (`mailer_secure_email_change_enabled = true`,
    `mailer_autoconfirm = false`). Los metadatos, el alta de un factor TOTP (`mfa_totp_enroll_enabled = true`) y el
    `logout` global no los cubre ninguna opción.
- Staging tiene 4 clientes OAuth, los 4 públicos por DCR y de la fase 0. No les queda ningún consentimiento vivo, ni
  autorizaciones ni sesiones OAuth. `sessions_inactivity_timeout = 0` y `sessions_timebox = 0`.
- El token de gestión solo ve `fostjbbwstyuunmmefuk`. Es staging.
- `@cloudflare/workers-oauth-provider` 1.1.0 trae lo que hace falta:
  - guarda tokens y códigos solo por hash, y los `props` cifrados con una clave envuelta por el propio token;
  - rota los refresh tokens, revoca por RFC 7009, hace DCR y ata la audiencia al recurso (RFC 8707);
  - sus helpers de consentimiento y de proveedor aguas arriba atan el `state` al navegador con una cookie
    `__Host-`.

  Importa `cloudflare:workers`, así que no carga en Node sin un alias.

**D1 · ¿Existe en Supabase una forma limpia de restringir `/auth/v1/*` a tokens OAuth?** → No. Se hace la vía 3 y
se redacta el issue para `supabase/auth` en el PR, sin publicarlo.
Por qué: medido arriba, en el código de la versión que corre staging. Alternativa descartada: reescribir `sub` en el
hook para que GoTrue rechace el token. Depende de un detalle de implementación, rompe `auth.uid()` en PostgREST y
deja sin comprobación de sesión viva.

**D2 · Arquitectura** → el Worker pasa a ser el **servidor OAuth de Claude**, con `workers-oauth-provider`
(`OAuthProvider`: servidor de autorización y recurso en el mismo Worker). Claude recibe un token **opaco** del
Worker, atado a la audiencia `…/mcp`. La sesión de Supabase la consigue el Worker como **cliente OAuth propio** del
servidor OAuth de Supabase, que queda aguas arriba. Esa sesión se guarda cifrada en los `props` y **nunca sale del
Worker**.
Por qué: el token que tiene Claude no es un JWT de Supabase, así que GoTrue, PostgREST y el gateway lo rechazan por
construcción. Además cumple la regla de MCP de no reenviar el token del cliente («token passthrough»). Alternativa
descartada, y que el Paso 0 de la fase 0 también descartó por otro motivo: una sesión normal (`authenticated`)
guardada en el Worker, porque escribe todo. La que se guarda ahora es de solo lectura en la base.

**D3 · Cliente del Worker en Supabase** → uno solo, **confidencial** (`client_secret_basic`) y con PKCE S256. Su
única vuelta es `…/oauth/supabase/callback`. Se registra por DCR antes de apagarlo, así que no hace falta
`service_role`. El secreto va a `~/Secrets/yala-mcp-staging/` y a `wrangler secret`, en el mismo gesto y sin
imprimirlo.
Por qué: un código de Supabase robado no se canjea sin el secreto del Worker. Alternativa descartada: cliente
público, con el que ese código basta con el `code_verifier` del atacante.

**D4 · En Supabase, solo el Worker recibe tokens OAuth** → el hook pasa a una lista cerrada (`mcp0_02`): el cliente
del Worker sale con `yala_mcp_reader` y **cualquier otro `client_id` se deniega** (error del hook, 403). Además se
apaga el DCR de Supabase (`oauth_server_allow_dynamic_registration = false`); Claude se registra en el Worker.
Por qué: aunque alguien reencienda el DCR o reuse un cliente de la fase 0, Supabase no emite tokens fuera del Worker.
Los 4 clientes viejos se quedan registrados, porque borrarlos exige `service_role`, pero ya no reciben tokens.

**D5 · Orden de la experiencia** → primero el **consentimiento por cliente**, en el Worker: quién pide, a qué dominio
vuelve, aviso si es `localhost`, qué podrá leer y lo que no podrá hacer. Después, Supabase y el **login** en
`/oauth/consent`. Tras el login, el Worker aprueba la autorización de SU cliente, cierra la sesión web **en la misma
petición** y vuelve por el callback. El callback solo se acepta con la cookie ligada al navegador (`finishUpstream`).
Por qué: la guía de seguridad de MCP pide el consentimiento antes de salir hacia el tercero (el problema del
«confused deputy»). Y la sesión web ya no vive 5 min en una cookie: vive lo que dura una petición. Alternativa
descartada: login primero, que obligaría a guardar la sesión web entre pantallas.

**D6 · Cómo se registra Claude en el Worker** → DCR en `/oauth/register`, con un `clientRegistrationCallback` que
rechaza cualquier `redirect_uri` fuera de la lista: `claude.ai`, `claude.com` y loopback. La lista se vuelve a
comprobar en `/authorize`. CIMD queda apagado.
Por qué: Claude Code usa DCR (medido en la fase 0). CIMD no se puede probar aquí sin publicar un documento de
metadatos; queda como opción para la fase 1.

**D7 · Revocación** → corta **al momento** por los tres lados:
- desde Claude, con RFC 7009 en el Worker (lo hace la librería);
- desde Supabase, por el futuro botón de la app o `DELETE /user/oauth/grants`: en cada llamada el Worker comprueba
  que la sesión de Supabase sigue viva (`GET /auth/v1/user`), y si no, revoca su grant y responde 401;
- si la cuenta se borra o se bloquea, lo mismo.

Por qué: en la fase 0 el token vivo seguía sirviendo hasta 1 h tras revocar. El coste es una llamada más a GoTrue
por petición (~150 ms). Residual: cuando se revoca desde Claude, la sesión de Supabase queda huérfana. Es
inalcanzable, porque su refresh solo existía cifrado en el grant borrado y canjearlo exige el secreto del Worker.
Pero sigue apareciendo en `/user/oauth/grants`. Se documenta.

**D8 · Rotación** → dos rotaciones:
- la del Worker la hace la librería: token nuevo, y el anterior vale hasta el primer uso del nuevo;
- la de Supabase va en el `tokenExchangeCallback` y se guarda en la **misma escritura** del grant.

Si Supabase detecta reúso o responde `invalid_grant`, se lanza `invalid_grant`, la librería revoca el grant y Claude
vuelve a autorizar: falla cerrado. Si Supabase está caído, `temporarily_unavailable`, y el grant se conserva.

**D9 · Caducidad** →
- el access token del Worker dura lo que le quede al de Supabase, menos 60 s;
- el grant dura 30 días deslizantes (`refreshTokenIdleTTL`);
- a los **90 días** de autorizar hay que volver a conectar, aunque se use.

Por qué: la reconexión periódica es la práctica de las apps que leen datos bancarios. Además acota una sesión que
en staging nunca caduca sola. Es un valor por defecto técnico y se puede ajustar.

**D10 · Dónde viven los tokens de Supabase** →
- el refresh, solo en los `props` del grant;
- el access, solo en los `props` del access token del Worker.

Nunca van en respuestas, logs, `metadata` ni URLs. El `userId` del grant es el `sub` de Supabase. El `metadata`
(visible en KV) no lleva datos personales.

**D11 · Defensa en profundidad si alguien compromete el Worker** →
- el rol `yala_mcp_reader`;
- el hook con lista cerrada;
- una **lista cerrada de salidas** del Worker hacia Supabase, por método y ruta: ningún camino del código puede
  hacer `PUT /auth/v1/user`;
- el token de Supabase se verifica en cada uso (firma, `role`, `client_id`, `sub`);
- la vía 2 activada en staging (`require_reauthentication` + `require_current_password`).

Residual escrito: con el Worker comprometido siguen al alcance los metadatos, el TOTP y la primera contraseña. Para
producción se deja una recomendación en la fase 1: apagar el proveedor de email, que la app no usa, y así se cierra
la vía de la primera contraseña. Va en un ticket propio.

**D12 · Tests** → dos capas:
- **Unitarios en Node:** la librería con un alias de `cloudflare:workers` a un stub, KV en memoria y Supabase falso.
  Cubren el baile entero y cada rama de fallo.
- **E2E contra staging:**
  - el baile real y las seis herramientas;
  - B no ve a A;
  - **todas** las escrituras de `/auth/v1/*` con el token de Claude fallan;
  - la respuesta de token no lleva nada de Supabase;
  - el refresh rota;
  - revocar corta, por los dos lados;
  - el login normal sigue `authenticated` y sin `client_id`.

Descartado: `vitest-pool-workers`, que pide vitest 4 y otro wrangler.

**D13 · Decisión escrita** → entrada en `docs/DECISIONS.md`, en el formato del repo: «El conector de Claude emite
sus propios tokens». La exploración §7 y el runbook se actualizan con el antes → después de staging y su marcha
atrás.
Por qué: quien no lo sepa podría volver a entregar a Claude un token de Supabase, y rehacerlo cuesta.

**D14 · Orden de los cambios en staging** →
1. registrar el cliente del Worker (con el DCR aún encendido);
2. KV y desplegar el Worker, que funciona con el hook actual;
3. `mcp0_02`, el hook con lista cerrada;
4. apagar el DCR de Supabase;
5. vía 2;
6. e2e completo.

Por qué: ningún paso abre nada que antes estuviera cerrado. Entre el 3 y el 6 el conector de staging solo funciona
por el Worker nuevo, y Jürgen tiene que reautenticar su Claude Code.
