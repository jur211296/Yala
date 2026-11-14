# Yala web (`webapp/`)

La app de Yala en el navegador, como un aparato más de la cuenta en la nube. Plan, maqueta y las 13 decisiones
aprobadas: `docs/web-app/index.html`. Tickets: `tickets/*/yala-web-lote-0-cimientos.md` y `tickets/*/yala-web-lote-1-beta.md`.

**Lote 0 (2.3, solo staging):** entrar con Apple o Google, sesión segura en el servidor y defensa anti-bots.

**Lote 1 (2.3, la beta, solo staging):** Panel, Registros y Bandeja en lectura; «Apuntar», que deja el gasto en la
Bandeja del iPhone; Configurar (cuenta, sesiones web, ocultar montos, idioma, salir); español e inglés; y, en el iPhone
(Yala Dev), Ajustes › Tu cuenta de Yala › «Navegadores conectados» para ver y cerrar las sesiones web.

**Lote 2 (2.3, solo staging):** Estadísticas (Resumen, Distribución y Tendencias) y Pagos planificados (próximos cobros
y suscripciones), en lectura y con las cifras del iPhone; y entrar con el iPhone por código QR, con «Vincular un
navegador» en «Navegadores conectados» (Yala Dev).

**Lote 2b (2.3, solo staging):** lo que faltaba del lote 2 del plan: Presupuestos en lectura, buscar en todo (⌘K),
exportar Registros a CSV, la marca «Pagado» en los próximos cobros y los 16 idiomas de la app.

Staging: <https://yala-web-staging.misty-surf-6866.workers.dev>

**Lote 3 (2.3, solo staging):** Grupos en lectura (lo que te deben y lo que debes, quién le debe a quién, saldos por
persona, gastos y pagos) con las cifras del iPhone; las cuentas «solo Grupos» entran y ven Grupos y Configurar; y los
borradores de la web que el iPhone aún no recogió se editan o se descartan desde la Bandeja. Y, con la opción A que eligió
Jürgen el 14-nov, la web **escribe** en Grupos: nuevo gasto con reparto igual, saldar e invitar por enlace (solo staging
hasta una revisión).

## Cómo funciona

```
Navegador ──cookie HttpOnly──▶ Worker «yala-web-staging» ──▶ Supabase Auth (login social, permiso OAuth)
   (solo pinta)                 · sesión cifrada en KV         ──▶ PostgREST, rol yala_mcp_reader (solo lectura)
                                · lista de sesiones (DO)       ──▶ Turnstile (anti-bots)
iPhone ──Bearer (su sesión)──▶  · shared-core (núcleo)         ──▶ D1 del gateway: cola de borradores (mail_drafts)
                                · lista cerrada de salidas
```

1. **Entrar.** La página pide Turnstile y manda un formulario a `/auth/start`. El Worker verifica el desafío y lleva al
   login de Apple o Google **a través de Supabase** (PKCE). Apple y Google solo ven la vuelta de Supabase, y las
   credenciales web que usan ya existían: el Services ID `pe.yala.app.web` y el cliente web «Yala Web (MCP)».
2. **Vuelta** (`/auth/callback`). Con el código, el Worker abre una sesión NORMAL de Supabase y con ella:
   - comprueba que la cuenta usa la nube (`profiles.kind`; «solo Grupos» no entra hasta el lote 3);
   - pide y aprueba **él solo** el permiso de su cliente OAuth (`GET /oauth/authorize` da el `authorization_id` sin
     navegador), así que no pasa por la Site URL de Supabase, que en staging es la del conector de Claude;
   - canjea el código con su secreto y recibe una sesión que el hook marca `role = yala_mcp_reader`;
   - cierra la sesión normal.
3. **Sesión.** Cookie `__Host-yala-web` (`HttpOnly`, `Secure`, `SameSite=Lax`). En el KV, la clave es el SHA-256 de la
   cookie y los tokens van cifrados con AES-GCM con una clave derivada de la propia cookie: leer el KV no revela nada.
   Dura 30 días sin uso (tope 90). Con «equipo compartido», hasta cerrar el navegador o 30 minutos sin uso.
4. **Salir** (`/auth/logout`). Cierra la sesión de Supabase que llevaba dentro, borra la del KV y la cookie.

Defensas: Turnstile al entrar; límites por IP (`/auth/*`) y por sesión (`/api/*`); `Origin` obligatorio en los POST; CSP
cerrada, `no-store` y `Referrer-Policy: same-origin` en todo (la página incluida: `run_worker_first`); y una lista cerrada de lo que el
Worker puede pedir fuera (`src/worker/egress.ts`). Si la configuración está mal, 503 a todo (`src/worker/config.ts`).

## Lote 1: mirar, apuntar y sesiones

- **Mirar.** `/api/panel`, `/api/registros` y `/api/categorias` llaman a los cálculos del núcleo compartido tal cual
  (`listar_cuentas`, `resumen_periodo`, `buscar_movimientos`, `listar_categorias`): mismas cifras que el conector y que
  la app. `/api/bandeja` lee `inbox_drafts` pendientes (SELECT dado por `supabase/web1_01`). Cada petición comprueba antes
  que la sesión de Supabase sigue viva (`GET /user`): así una sesión cerrada desde el iPhone deja de leer al momento.
- **Apuntar.** `POST /api/borradores` deja la fila en la cola COMÚN de borradores (decisión D9): `mail_drafts` del D1 del
  gateway de staging, con la forma del correo del banco más `source: "web"`, `account_ref` y `subcategory_ref`. El iPhone
  la recoge por `GET /mail/drafts` (también cuando hay sesiones web, no solo con el correo preparado) y la pasa a su
  Bandeja con origen «Automatización» y evidencia «Yala web». Tope: 30 al día por cuenta. El gateway no cambió.
- **Sesiones.** Un Durable Object por cuenta (`SessionIndex`) guarda la lista: navegador, sistema, ciudad aproximada,
  fechas y equipo compartido. No va en el KV porque su `list` es eventual (una sesión recién abierta tardaba hasta un
  minuto en verse). «Cerrar» borra la sesión del KV, su entrada y su sesión de Supabase (`yala_web_close_session`). La
  página pregunta `/api/me` cada 30 s y al volver a la pestaña: una sesión cerrada vuelve a la pantalla de entrar.
- **El iPhone** entra por `/api/dispositivo/*` con el token de su sesión de la nube (`role = authenticated`, sin
  `client_id`). Sin App Attest: solo ve y cierra las sesiones web propias (decisión P9 del ticket).

## Lote 2: estadísticas, pagos y entrar con el iPhone

- **Estadísticas** (`/api/estadisticas?periodo=mes_actual|mes_pasado|anio_actual`): una lectura de movimientos y las
  tres pestañas calculadas por `shared-core/src/logic/stats.ts` con las reglas de las pantallas del iPhone
  (`InsightsCalculator`, `TopSpendingCategoriesCalculator`, `CashFlowCalculator`). Como el iPhone, deja fuera los
  movimientos sin cuenta (el chat y el conector sí los cuentan). Paridad: `mcp/test/golden.test.ts`, con los valores que
  escribe la app (`YalaTests/MCP/MCPAppParityGoldenTests.swift`).
- **Pagos planificados** (`/api/pagos`): los cobros de los próximos 30 días con el calendario del iPhone
  (`ScheduledPaymentDateCalculator`, port en `shared-core/src/logic/schedule.ts`), sin las fechas saltadas, y las
  suscripciones con su equivalente mensual. Lo «ya pagado» del mes no se descuenta todavía.
- **Entrar con el iPhone (QR)**: ver la cabecera de `src/worker/pairing.ts`. La web pide un código con Turnstile y queda
  ligada a él por una cookie propia; el iPhone lo lee, enseña el navegador y la ciudad, pide Face ID y lo aprueba con su
  sesión; el Worker pide el permiso de solo lectura de siempre y guarda solo el código de autorización, que sin la cookie
  de ese navegador (PKCE) no sirve. Un Durable Object por código (`QrPairing`), que una alarma vacía al caducar. Límite
  propio para las preguntas del navegador (`RL_QR`).

## Lote 2b: Presupuestos, ⌘K, CSV, «Pagado» y 16 idiomas

- **Presupuestos** (`/api/presupuestos`): `estado_presupuestos` del núcleo tal cual, activos e inactivos (paridad con la
  pantalla del iPhone en `mcp/test/golden.test.ts`). La página los pinta en los tres bloques del iPhone: Excedidos,
  Activos e Inactivos.
- **«Pagado» en los próximos cobros** (`/api/pagos`, `src/worker/paid.ts`): la regla de la lista de Pagos del iPhone
  (`ScheduledPaymentsViewModel.calculatePaymentData` + `ScheduledPaymentPaidStatusHelper`): N movimientos enlazados al
  pago en un mes pagan las N primeras fechas no saltadas de ese mes. Cada cobro trae `pagado`, «Por pagar»
  (`total_gastos`) deja fuera lo pagado y `pagados` los cuenta. Diferencia aceptada: un borrador aprobado cuyo
  movimiento se borró sigue contando en el iPhone y en la web no (el rol de la web no lee
  `inbox_drafts.source_scheduled_payment_ref`).
- **Buscar en todo** (`src/client/app/Busqueda.tsx`): ⌘K / Ctrl+K o la lupa de la barra. Secciones, cuentas, categorías
  y presupuestos se filtran en la página; las notas de los registros, con `/api/registros?texto=`. Sin ruta nueva.
- **Exportar a CSV** (`src/client/app/csv.ts`): «Exportar CSV» en Registros baja lo que se ve, de 200 en 200
  (`/api/registros?limite=200`; cualquier otro `limite` se queda en 50), con tope de 5.000. El archivo es el del iPhone
  (`TransactionsExportService.makeCSVData`): cabeceras fijas en inglés, coma, BOM, fechas `AAAA-MM-DD`, punto decimal,
  etiquetas con «;». Se arma en el navegador.
- **Idiomas** (`src/client/i18n.ts` + `src/client/i18n/<código>.ts`): los 16 de la app. El español es el contrato
  (`Texts`); es-AR, es-ES y en-GB son parches sobre su base; es-419 = es y pt = pt-BR, como en la app. `main.tsx` carga
  el idioma antes de importar la página, así que el navegador solo baja el suyo. `test/idiomas.test.ts` repasa los 16:
  todas las claves, nada sin traducir y ninguno de los nombres de sitio que retiró la decisión 51 de 2.3 (las listas de
  `YalaTests/DosNombresDeSitioTests.swift`).

## Lote 3: Grupos

- **De dónde salen las filas.** Ocho columnas de Grupos están cifradas y la llave (`GROUPS_ENC_KEY`) solo vive en el
  gateway. La web la pide por un *service binding* (`GATEWAY_GROUPS` → entrada `WebGroupsReader` del gateway de
  staging, `gateway/src/web/groupsReader.ts`): no sale a internet ni tiene ruta pública, y la llave no viaja. La entrada
  solo acepta tokens de la web (`yala_web`, o `yala_mcp_reader` de antes de web3_02; el del iPhone por ahí se saltaría
  App Attest), lee con los cinco RPC lectores `groups_pull_rows_*` y solo está encendida con `WEB_GROUPS_READER = "on"`
  (staging).
- **Quién puede leer qué** lo decide la RLS de `supabase/web3_01_grupos_lectura.sql`: SELECT de las cinco tablas de
  Grupos para `yala_mcp_reader` solo si el token es del cliente de la web (`yala_is_web_reader()`) y la persona es
  miembro. El conector de Claude, que comparte el rol, no gana nada. Ninguna escritura.
- **Saldos:** `shared-core/src/logic/groupBalances.ts`, port de `GroupBalanceService` con paridad contra la app
  (`mcp/test/groups-parity.test.ts` ← `YalaTests/MCP/WebGroupsParityGoldenTests.swift`). Con «una sola moneda», la tasa
  de hoy de las filas de la persona (o la tabla estática si no tiene): la app usa la última de su almacén, así que una
  tasa de otro día puede dar otro céntimo.
- **Como la lista del iPhone:** los grupos archivados salen al final con su marca y no suman al resumen ni a los pagos
  por confirmar; con «una sola moneda», los saldos por persona también se consolidan (`shownBalances`); y el nombre de
  quien borró su cuenta (`__deleted_user__`) lo traduce la página («Usuario eliminado»).
- **Lo que no cabe se dice:** más de 50 grupos, o un grupo con más de 5.000 filas en alguna tabla, marcan `incompleto` y
  la página lo avisa en vez de enseñar saldos cortados en silencio. Un gateway que no lee es un 503 que se devuelve (no
  se lanza), para que la sesión renovada se guarde igual.
- **Rutas:** `/api/grupos` (resumen y tarjetas, como mucho 50 grupos, los más recientes primero) y
  `/api/grupos/detalle?id=` (solo ese grupo). Con los 50 grupos de prueba de A, la lista tarda unos 6 s: cada grupo son
  cinco lecturas y un Worker abre seis conexiones a la vez. El detalle, ~1 s.
- **«Solo Grupos»:** la sesión lo apunta al entrar (`soloGrupos`, `session.ts`), `/api/me` lo dice y lo de la nube
  completa responde 409 `solo_grupos`. Entrar con el iPhone por QR sigue siendo solo para la nube completa.
- **Borradores:** `POST /api/borradores/editar` y `/descartar`, solo los de la propia cuenta con `source = web` dentro
  de la caducidad de la cola. Se edita en sitio (mismo `id`: el iPhone deduplica por él). Si ya no está, 409
  `recogido`. Ventana aceptada: si el iPhone ya lo bajó y aún no lo confirmó, le llega la versión que bajó.

## Lote 3: escribir en Grupos (opción A, 14-nov)

La pregunta era cómo pasa la web la puerta de App Attest de Grupos, que un navegador no puede dar. Jürgen eligió la A:
un permiso propio de la web, por el gateway, solo en staging hasta una revisión. Lo que sustituye a App Attest:

- **Rol propio, `yala_web`** (`supabase/web3_02_grupos_escritura.sql`). El hook de token se lo da a los tokens de la
  web; hereda todo lo que lee `yala_mcp_reader` y solo añade EXECUTE de tres funciones: `web_add_group_expense`,
  `web_add_group_settlement` y `create_group_invite`. Ningún permiso de tabla. El conector de Claude sigue en `yala_mcp_reader`, sin escribir.
- **Lista cerrada en la base:** una función SECURITY DEFINER por operación, y cada llamada es una transacción (todo o
  nada). `web_add_group_expense` solo deja crear un gasto NUEVO con todas sus cuotas: cuotas de ese gasto, de miembros
  activos, que suman su importe, sin saldo inicial. `web_add_group_settlement`, un pago NUEVO entre dos miembros activos.
  Las dos exigen miembro activo de un grupo vivo y no archivado, y un id **nuevo en todos los grupos**: el iPhone busca
  gastos y pagos solo por id, así que un id repetido en otro grupo movería esa fila de grupo en los teléfonos (lo cazó
  la revisión adversarial). Ya existente en este grupo = reenvío (`exists`, no toca nada). Por dentro, `apply_group_delta`,
  la misma función que el iPhone. Van como funciones del dueño porque `auth` es de `supabase_admin` y no deja dar USAGE
  a un rol nuevo (medido: «permission denied for schema auth»).
- **Lista cerrada en el gateway:** la entrada interna `WebGroupsWriter` (`gateway/src/web/groupsWriter.ts`, binding
  `GATEWAY_GROUPS_WRITER`, `WEB_GROUPS_WRITER = "on"` solo en staging) tiene tres operaciones y arma ella los deltas:
  nuevo gasto con reparto igual (`shared-core/src/logic/groupSplit.ts`, paridad con `GroupSplitCalculator`), apuntar un
  pago (confirmado si lo apunta quien paga o quien recibe; si no, pendiente, como `SettlementSaldar23Logic`) y crear un
  enlace con el formato de la app (7 días, 20 usos). Valida miembros activos, divisas que el grupo ya usa, céntimos y
  fechas. Los demás miembros reciben el aviso push de siempre.
- **Límite por cuenta:** cubo `webw:<sub>` (300 al día, 20 por minuto), que se aplica también en `observe`.
- **Reintentos:** el id lo pone el formulario al abrirse. Un fallo no deja nada escrito (transacción); un reenvío de lo
  que ya entró devuelve `ya_estaba` sin tocar nada.
- **Tokens de antes de web3_02** llevan `yala_mcp_reader`: leen igual, y al escribir el gateway responde `role`, la ruta
  renueva el token una vez (el hook ya da `yala_web`), repite y guarda la renovación.
- **Rutas:** `POST /api/grupos/gasto`, `/api/grupos/pago` y `/api/grupos/invitar` (mismo origen). El detalle trae
  `puedeEscribir`, `puedeInvitar` (admin, o «miembros pueden invitar») y `divisas`.
- **Queda en el iPhone:** editar o borrar gastos, repartos que no sean iguales, confirmar o rechazar pagos, estrenar una
  divisa en el grupo y todo lo de membresía (aprobar, quitar, salir).

## Núcleo compartido

Los cálculos y el lector de PostgREST viven en `shared-core/` (los usan el conector, el gateway y la web). La web lo
importa por ruta relativa. Ver `shared-core/README.md`.

## Comandos

```bash
npm ci
npm run typecheck
npm test                     # unitarias, sin red
npm run deploy:staging       # build de la página + wrangler deploy
set -a; source ~/Secrets/yala-supabase-test/test-users.env; set +a; npm run test:e2e   # contra staging
```

El e2e del lote 1 apunta borradores de verdad en la cola de staging, con la descripción `e2e-lote1-<marca>`. Después,
se retiran para que no le lleguen al iPhone del usuario de prueba A:

```bash
npx wrangler d1 execute yala-gateway-staging --remote \
  --command "DELETE FROM mail_drafts WHERE json_extract(payload, '$.merchant') LIKE 'e2e-lote1-%'"
```

La ruta `/auth/password` (contraseña) existe **solo en staging**, para el e2e: la niegan la configuración y la lista
cerrada en cualquier otro entorno.

## Supabase staging (escritura del lote 3, 2026-11-14)

`supabase/web3_02_grupos_escritura.sql`, aplicado el 14-nov (marcha atrás: `supabase/web3_02_rollback.sql`). Hook de token:
md5 `120f45468bc1db690a4c5655e7a7d48c` (el de web0_01) → `54a4444f713eea227049396021d27ebd`.

| Qué | Antes | Después |
|---|---|---|
| rol `yala_web` | — | sin login, miembro de `yala_mcp_reader` (hereda), `authenticator` puede entrar con él |
| `yala_mcp_access_token_hook` | web y conector → `yala_mcp_reader` | web → `yala_web`; conector → `yala_mcp_reader` |
| `web_add_group_expense(...)`, `web_add_group_settlement(...)` | — | `security definer`, EXECUTE solo `yala_web` (ver «Lote 3: escribir en Grupos») |
| `web_group_write_guard`, `web_group_active_member` | — | `security definer`, sin EXECUTE para nadie: las usan las dos de arriba |
| `create_group_invite` | EXECUTE `authenticated` | también `yala_web` |

Sonda tras aplicar: `yala_web` sin INSERT, UPDATE ni DELETE en ninguna tabla, sin EXECUTE en `apply_group_delta` ni en
las demás RPC de Grupos; `yala_mcp_reader` igual que antes. Con un token real de la web, PostgREST da 42501 a insertar,
cambiar y borrar en tablas y a `apply_group_delta` (`test/e2e/web.e2e.test.ts`).

**Producción: nada.**

## Supabase staging (cambios del lote 3, 2026-11-14)

`supabase/web3_01_grupos_lectura.sql`, aplicado el 14-nov (marcha atrás: `supabase/web3_01_rollback.sql`):

| Qué | Antes | Después |
|---|---|---|
| `yala_is_web_reader()` | — | `security definer`, sin parámetros: ¿el token es del cliente OAuth de la web? (claim o sesión) |
| `split_groups`, `group_members`, `split_expenses`, `split_shares`, `split_settlements` | sin acceso para `yala_mcp_reader` | SELECT + política `web_reader_select` (cliente de la web y miembro o escritor del grupo) |
| `groups_pull_rows_*` (5), `is_group_member`, `is_group_writer`, `yala_try_decrypt` | EXECUTE solo `authenticated` | también `yala_mcp_reader` |

Sonda tras aplicar: `yala_mcp_reader` sigue sin EXECUTE en `apply_group_delta`, `create_group`, `join_group`,
`groups_forget_user` ni `record_groups_consent`, y sin INSERT ni UPDATE en ninguna tabla de Grupos.

**Producción: nada.**

## Supabase staging (cambios del lote 1, 2026-11-14)

`supabase/web1_01_bandeja_y_sesiones.sql`, aplicado el 14-nov (marcha atrás: `supabase/web1_01_rollback.sql`):

| Qué | Antes | Después |
|---|---|---|
| `inbox_drafts` para `yala_mcp_reader` | sin acceso | SELECT con política de filas propias (como sus otras 9 tablas) |
| `yala_web_close_session(uuid)` | — | `security definer`; solo sesiones del cliente web y de `auth.uid()`; EXECUTE para `authenticated` y `yala_mcp_reader` |
| Barrido diario | — | `yala_web_sweep_sessions()` + cron `yala-web-sweep-sessions` (04:27 UTC): sesiones web sin uso en 31 días o con más de 91 |

**Producción: nada.**

## Supabase staging (cambios del lote 0, 2026-11-13)

| Qué | Antes | Después | Marcha atrás |
|---|---|---|---|
| Cliente OAuth «Yala web (staging)» | — | `03e0f13b-818f-4a93-8e69-701ea6343fda`, confidencial, vuelta `…/auth/supabase/callback`. Secreto en `~/Secrets/yala-web-staging/supabase-oauth-client.json` | borrarlo en *Authentication → OAuth Server* |
| Hook `yala_mcp_access_token_hook` | md5 `0a03fb943169e9fcee294fca49710398` (mcp0_03) | md5 `120f45468bc1db690a4c5655e7a7d48c` (`supabase/web0_01_hook_web_client.sql`) | `supabase/web0_01_rollback.sql` |
| `uri_allow_list` | `yaladev://auth-callback` | + `https://yala-web-staging.misty-surf-6866.workers.dev/auth/callback` | quitar la segunda entrada |
| Site URL | la del conector | **sin cambios** | — |

Comprobado después de aplicar: el login normal de la app sigue saliendo `authenticated` y sin `client_id`.

**Producción: nada.** Ni Worker, ni cliente OAuth, ni hook, ni `uri_allow_list`.

## Pendiente

- **Turnstile real.** Staging usa las claves de prueba de Cloudflare (siempre pasan). Hace falta crear el widget
  (dashboard de Cloudflare → Turnstile, dominio `yala-web-staging.misty-surf-6866.workers.dev`) y cambiar
  `TURNSTILE_SITE_KEY` y el secreto. `config.ts` rechaza las de prueba en producción.
- **Origen «Yala web» en la Bandeja del iPhone.** Hoy entra como «Automatización» con la evidencia «Yala web»: un origen
  propio pide un caso nuevo en `DraftSourceType`.
- **Cerrar sesión en el iPhone** no cierra las sesiones web (borrar la cuenta sí).
- **La política de privacidad** tiene que nombrar lo que guarda la web: la sesión, el navegador y la ciudad aproximada.
- **Producción y `app.yala-app.pe`**: el dominio pide mover el DNS de `yala-app.pe` a Cloudflare (hoy en RCP).
