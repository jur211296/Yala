---
fecha: 2026-09-26
estado: fase 0 hecha en staging (§7); el bloqueo para la fase 1, cerrado (§8) — código en mcp/
ticket: tickets/backlog/claude-plugin-read-only-mcp-connector.md
---

# Plugin de Yala para Claude: conector MCP de solo lectura + skills

**Qué es:** un conector MCP remoto sobre la nube de Yala. Cada usuario lo autoriza con OAuth y Claude
puede leer sus saldos, movimientos, categorías, presupuestos y pagos recurrentes. Encima van tres skills
de análisis.

**No es una idea nueva.** El diseño del modo nube lo dejó previsto como diferido #22, con estado
FUTURO-v2 (`docs/modo-nube/MODO-NUBE-DIFERIDOS.md:281-290`). Ese diferido pone tres condiciones: lectura
con el JWT del usuario y RLS, **nunca `service_role`**; un consentimiento propio; y auditoría de accesos.
También se decidió no cifrar de extremo a extremo, entre otras cosas para que este conector sea posible
(`MODO-NUBE-DIFERIDOS.md:285`).

**En corto:**

- Es viable, y Supabase ya trae casi todo el servidor OAuth que Claude exige.
- La fase 1 **no toca ningún fichero** de los que está tocando la cola A.
- Sí comparte dos contratos que no son ficheros: los permisos (RLS/grants) de las 16 tablas y la
  configuración de Auth del proyecto de producción.
- El trabajo gordo no es el MCP. Es **portar a TypeScript los cálculos** que hoy solo existen en Swift:
  saldos, gasto de un presupuesto, conversión de divisas e intervalos de fecha.

Convención del documento: **medido** = lo leí en el fichero o en la página citada. **Inferido** = lo
deduzco yo. **NO VERIFICADO** = no lo encontré en ninguna fuente.

---

## 1. Herramientas del MCP

**Criterio de diseño:** herramientas que devuelven **resultados ya calculados**, no filas crudas. Hay
dos motivos:

- La revisión de Anthropic rechaza «a full database dump when a summary was requested» ([criterios de
  revisión][rc]).
- Si Claude suma las filas por su cuenta, sus cifras no cuadran con las de la app. Pasa con las
  divisas, el signo de los reembolsos y el ajuste de los gastos compartidos (`GroupBridgeStatsAdjustment`).

Todas las herramientas llevan `title` y `readOnlyHint: true`, que es obligatorio ([rc]), y ninguna pasa
de 64 caracteres de nombre.

| Herramienta | Entrada | Salida | Origen (medido) | Lógica que hay que portar desde Swift |
|---|---|---|---|---|
| `listar_cuentas` | `incluir_archivadas?` | nombre, tipo, divisa, saldo actual; total en divisa preferida | `accounts` (`supabase-staging.ddl:15-38`) + `tx_items` | **No hay columna de saldo.** El saldo inicial es un movimiento `balance_adjustment_type` (`Yala/Models/TransactionItem.swift:64-65`). Portar `InitialBalanceService.currentBalance` (`Yala/Services/InitialBalanceService.swift:46`) y `LiveBalanceCalculator.liveBalance` (`Yala/App/Logic/Calculators/LiveBalanceCalculator.swift:67`) |
| `buscar_movimientos` | `desde`, `hasta`, `cuenta?`, `categoria?`, `texto?`, `limite ≤ 200`, `cursor?` | lista paginada: fecha, importe, divisa, importe en divisa preferida, nota, categoría, cuenta | `tx_items` (`:388-424`) + `categories`, `subcategories`, `accounts`, `tags` | Excluir `deleted = true`. El «comercio» sale de `note` (`FullFinancialContextBuilder.canonicalMerchant`, `Yala/Services/Chat/FullFinancialContextBuilder.swift:990`) |
| `listar_categorias` | — | categorías y subcategorías, `is_income`, visibles | `categories` (`:134-153`), `subcategories` (`:348`) | ninguna |
| `resumen_periodo` | `periodo` (`mes_actual`, `mes_pasado`, `rango`) | ingresos, gastos y neto; top de categorías y comercios | `tx_items.amount_in_preferred_currency` + `user_preferences` (`:427`) | Clasificar ingreso o gasto por categoría, con acumulación con signo. Intervalos con el `-1 s` del `CLAUDE.md` («Cálculos con fechas»). Modelo: `buildPeriods` y `buildCategories` (`FullFinancialContextBuilder.swift:374, 451`) |
| `estado_presupuestos` | `solo_activos?` | por presupuesto: límite, gastado, %, días restantes, estado | `budgets` (`:40-69`) + `tx_items` | `BudgetsViewModel.calculateSpending` (`Yala/App/ViewModels/BudgetsViewModel.swift:615`) y `InsightsCalculator.currentBudgetInterval` (`Yala/App/Logic/Calculators/InsightsCalculator.swift:565`) |
| `listar_recurrentes` | `solo_activos?` | nombre, importe, frecuencia, próximo cobro, último pago, equivalente mensual y anual | `scheduled_payments` (`:304-346`) + `tx_items.scheduled_payment_ref` | `buildRecurring` y `monthlyMultiplier` (`FullFinancialContextBuilder.swift:659, 770`) |

**Quedan fuera de la fase 1:**

- **Grupos.** Nueve columnas de grupos van cifradas en servidor con pgcrypto
  (`supabase-groups-staging.ddl:11, 28-33`). La clave `GROUPS_ENC_KEY` vive solo en el gateway
  (`gateway/README.md`, sección de secrets). Leerlas obligaría a meter esa clave en el conector.
- **Escritura.** Va en la fase 3.

**Skills del plugin**, construidas sobre esas herramientas:

- *gasto-del-mes*: usa `resumen_periodo` + `buscar_movimientos`.
- *presupuesto*: usa `estado_presupuestos`.
- *recurrentes-a-revisar*: usa `listar_recurrentes`.

**«Suscripciones sin usar» no se puede prometer.** Yala no sabe si usas un servicio, solo que lo
pagas. Por eso la skill se llama *recurrentes-a-revisar* (decidido el 2026-09-26, §6): enseña lo que
pagas cada mes y al año, y lo que lleva tiempo sin cobro asociado.

**Ninguna skill da asesoría de inversión ni juzga la solvencia.** La Usage Policy trata las «financial
decisions, including investment advice… creditworthiness» como caso de alto riesgo. Para esos casos
exige que un profesional revise el resultado y que se avise al usuario de que interviene IA ([aup]).

## 2. Encaje con la API y la autenticación actuales

**Lo que ya existe (medido):**

- **Datos en claro para el servidor.** Las tablas personales son `TEXT` y `NUMERIC` normales, sin
  payload opaco. Cifrar por columna se descartó a propósito (`MODO-NUBE-DIFERIDOS.md:118-123`).
- **RLS por usuario.** Las 16 tablas llevan 4 políticas por comando con
  `(select auth.uid()) = user_id`, y `authenticated` tiene `GRANT SELECT,INSERT,UPDATE`
  (`supabase-staging.ddl:4-6`).
- **Login.** Sign in with Apple y Google, nativos en iOS, entran en Supabase Auth con
  `signInWithIdToken` (`Yala/Services/CloudSync/CloudAuthService.swift:5, 296, 344`).
- **El gateway ya lee en nombre del usuario** sin claves de servicio. Verifica el JWT ES256 contra el
  JWKS (`gateway/src/sync/userauth.ts:4-15`) y reenvía ese mismo JWT a PostgREST
  (`userauth.ts:56`: «NUNCA service_role»).
- **Proyecto de producción** `kefvaiymtgytemwbltlz`, con plan Pro (`qa/cloud/README.md`). El modo nube
  está al 100 % de rollout (`gateway/wrangler.toml`, `[env.production.vars]`).

**Supabase Auth ya puede hacer de servidor OAuth para un MCP (medido en su documentación).** Ofrece
OAuth 2.1 con PKCE, discovery, registro dinámico de clientes (DCR) y rotación de refresh tokens
([supabase-mcp], [supabase-oauth]). **Está en beta**, gratis mientras dure la beta ([supabase-start]).
Encaja con lo que exige Claude ([auth]):

- DCR o CIMD.
- PKCE S256, anunciado en los metadatos.
- Callback `https://claude.ai/api/mcp/auth_callback`, y loopback con cualquier puerto para Claude Code.
- Un `401` con `WWW-Authenticate: Bearer resource_metadata=…`. Eso lo sirve el MCP, no Supabase.
- Hasta 10 s para discovery y token, y `invalid_grant` cuando caduca el refresh.

**Lo que falta:**

1. **Solo lectura de verdad.** Es la trampa principal.
   - Los scopes de Supabase (`openid`, `email`, `profile`, `phone`) **no controlan el acceso a la base
     de datos**. Supabase lo dice literalmente ([supabase-token]).
   - El token que recibe Claude es un JWT `authenticated` con un claim `client_id`, y pasa por las RLS
     actuales. Esas RLS **permiten INSERT y UPDATE**. Quien tenga el token podría escribir por PostgREST
     sin pasar por el MCP.
   - Hace falta DDL que discrimine por `client_id`: que las políticas de escritura exijan
     `client_id IS NULL`, o un rol solo-SELECT asignado con un *custom access token hook*.
   - **NO VERIFICADO** que ese hook pueda cambiar el `role` de un token OAuth. Es lo primero que hay
     que probar en el spike.
2. **Pantalla de consentimiento web.** Supabase exige construir la UI de autorización en una ruta
   propia ([supabase-start]). El usuario inicia sesión **en la web**.
   - Hoy el login es nativo de iOS. Para la web hacen falta un Services ID de Sign in with Apple y un
     cliente OAuth web de Google.
   - Inferido: no existen, porque los client IDs que conozco son de iOS. Hay que verificarlo en el
     dashboard. Es acceso de Jürgen: Apple Developer y Google Cloud.
3. **Revocación.**
   - Supabase deja a tu cargo «allow users to revoke access later» ([supabase-mcp]).
   - **NO VERIFICADO:** que haya una API de Supabase para listar y revocar las autorizaciones de un
     usuario.
   - Hereda además el hueco del diferido #23: revocar Sign in with Apple no mata la sesión de Supabase.
     Lo acota el timeout de inactividad de 30 días (`MODO-NUBE-DIFERIDOS.md`, #23).
   - **NO VERIFICADO:** que `POST /account/delete` borre también las autorizaciones OAuth. Las filas sí
     caen por `ON DELETE CASCADE` sobre `auth.users` (`supabase-staging.ddl:15-16`).
4. **Un camino de lectura propio.** El MCP no puede reutilizar `GET /sync/pull`
   (`gateway/src/index.ts:73`): en producción exige App Attest (`gateway/wrangler.toml:88`,
   `ENFORCE = "enforce"`), y el servidor de Anthropic no tiene attestation.
5. **Auditoría de accesos**, que la pide el diferido #22. El gateway no escribe telemetría
   (`tickets/backlog/gateway-has-no-telemetry.md`).

**Lo que depende de trabajo sin terminar:**

- **Modo nube estable en producción.** Es el gatillo del diferido #22. El sign-in real contra
  producción sigue marcado SIN VERIFICAR (`docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md:172`).
- **Solo los usuarios en modo nube tienen datos en Supabase.** Para quien está en privado (iCloud) el
  conector no ve nada. Inferido, porque la sesión privada no sube a la nube.
- **La política de privacidad** todavía dice que Yala no tiene servidores propios
  (`Web/src/i18n/translations.ts:160, 202`). Corregirla ya bloquea la publicación del rediseño
  (`tickets/backlog/session-redesign-web-and-store-copy.md:38`). El conector añade un destinatario
  nuevo: Anthropic.
- **El esquema se sigue moviendo.** Hubo cuatro fixes de la nube el 24-sep que tocaron
  `gateway/src/sync/account.ts`.

## 3. Paralelismo con la cola A

Medido con `git log --since=2026-09-01` sobre `origin/2.1` y con los PR #255-#257 del 26-sep.

| Superficie compartida | Ruta | ¿La toca la cola A? | ¿La toca el plugin? |
|---|---|---|---|
| Sync, sign-out y wipe en la app | `Yala/Services/CloudSync/**`, `Yala/App/Logic/CloudSignOutFlowLogic.swift`, `Yala/Utils/DataWipeService.swift` | **Sí**: #255, #256 y #257 son de hoy | **No** en fases 1-2 |
| Perfil y Ajustes | `Yala/App/Views/Profile/ProfileView.swift`, `…/Settings/GroupsAssociationSection.swift` | Sí (#255) | Solo en la fase 2, con «Claude conectado · Revocar» |
| Gateway | `gateway/src/sync/account.ts` (5 commits este mes), `gateway/src/groups/*` | Sí | **No**, si el MCP es un Worker aparte |
| Contrato del esquema | `supabase-staging.ddl`, `supabase-groups-staging.ddl`, `capability_manifest.json` | Sí, lo cambia | Solo lo **lee**. Si cambia una columna, las lecturas del MCP se rompen |
| RLS y grants de las 16 tablas | en la base; se aplican por `docs/RUNBOOK-staging-ddl.md` | Potencialmente | **Sí**: el DDL de solo lectura (§2.1). **Este es el choque real** |
| Configuración de Auth en producción | dashboard de Supabase: OAuth server, redirects | La usa el login de la app | **Sí**: activar el servidor OAuth. No es un fichero, pero es el mismo Auth que usa el login |
| Web | `Web/` | No; lo lleva el ticket de copy legal | Sí: consentimiento y política |
| CI | `.github/workflows/qa.yml:146-153` | — | Una carpeta nueva **dispara la suite de iOS** hasta que se añada a esa lista, como se hizo con `gateway/*` |

**Veredicto:** en código, Jürgen tiene razón. La fase 1 no comparte ningún fichero con la cola A. El
roce está en dos contratos:

- **El DDL de permisos.** Tiene que ir en una migración propia, aplicada por el runbook en una ventana
  en la que la cola A no esté migrando.
- **La configuración de Auth de producción.** Se activa primero en staging, y en producción solo con
  el sign-in real ya verificado.

**Recomendación: una carpeta `mcp/` dentro de este repo, con su propio Worker.** No va como ruta del
gateway ni en un repo aparte. Las razones:

1. **El contrato vive aquí.** El esquema y el manifiesto están en la raíz, y el gateway ya fija la
   paridad con tests (`gateway/test/manifest.sync.test.ts`). Con `mcp/` al lado, un cambio de esquema
   rompe el test del MCP **en el mismo PR** que lo provoca. En un repo aparte ese desvío pasaría en
   silencio.
2. **Worker propio, no una ruta del gateway.** El gateway es la línea de vida de la app: attest, sync
   y grupos. Además guarda `GROUPS_ENC_KEY`, que el MCP no debe tener. Con Worker propio, un fallo o un
   deploy del MCP no alcanza al sync, y los secretos y los despliegues quedan separados.
3. **Portar la lógica es el riesgo.** La mitigación es generar golden vectors desde los tests de Swift.
   El repo ya usa ese patrón con `golden_vectors.json` y `hlc_conformance_vectors.json`, y un repo
   aparte lo complicaría.

Las dos cosas que esto obliga a hacer: añadir `mcp/*` a la lista de `qa.yml`, y darle al MCP una suite
propia en CI. Hoy el gateway no la tiene (`tickets/backlog/ci-no-corre-la-suite-del-gateway.md`).

## 4. Qué exige Anthropic para aprobarlo

Fuentes consultadas el 2026-09-26.

- **El anuncio.** El tuit de @ClaudeDevs no carga en x.com (HTTP 402). Se leyó por el endpoint de
  embebidos de X. Remite al [blog] del 25-sep, que cuenta tres cosas: hay un portal para enviar,
  seguir la revisión y ver el uso; los plugins empaquetan MCP y skills; y pueden enviar los planes de
  pago.
- **La Software Directory Policy** ([policy]) se leyó con una herramienta que resume. Las citas son
  literales, pero los números de sección no se han contrastado.

| Requisito | Qué dice | Fuente | Estado de Yala |
|---|---|---|---|
| Quién envía | Planes Pro, Max, Team o Enterprise | [publish] | — |
| Forma | Conector MCP remoto y un plugin (`.claude-plugin/plugin.json` + skills + `.mcp.json`) que apunte a la misma URL. README de 40 palabras o más, licencia, sin secretos en `.mcp.json` | [publish], [build] | por hacer |
| Política de privacidad | Enlace claro a qué datos se recogen, cómo se usan y cuánto se retienen. El portal la pide en el paso *Listing* | [policy], [submission] | **falla**: la actual no menciona la nube ni Anthropic |
| OAuth | Lo de §2: DCR o CIMD, S256, callbacks, `401` + `resource_metadata`, tiempos máximos | [auth] | Supabase lo cubre; **NO VERIFICADO** si soporta CIMD |
| Diseño de herramientas | `title` + `readOnlyHint`/`destructiveHint`, lectura y escritura en herramientas separadas, descripciones sin instrucciones a Claude | [rc] | cubierto por §1 |
| Tamaño de respuesta | «Frugal» con los tokens; sin volcados. Claude Code avisa a partir de 10 000 tokens y corta en 25 000 | [policy], [rc], [cc-mcp] | paginar `buscar_movimientos` |
| Cuenta de prueba | Obligatoria y «fully populated» | [rc] | falta una cuenta de nube en producción con datos demo y login de Google para los revisores |
| Documentación | Pública para la fecha de publicación; vale un post. Al menos 3 prompts de ejemplo | [rc], [policy] | por hacer |
| Propiedad | API propia y dominio que coincida con el servicio | [rc] | usar `yala-app.pe` |
| Casos prohibidos | «Transfer money, cryptocurrency, or other financial assets» | [rc] | la lectura no choca. **NO VERIFICADO** si apuntar un gasto cuenta como transacción |
| Compliance | El portal pide siete reconocimientos; uno es sobre «financial transactions» | [submission] | **NO VERIFICADO** el texto exacto |
| Datos financieros | **NO VERIFICADO**: no encontré una regla específica ni un consentimiento o retención propios del sector. El formulario del conector pregunta por datos de salud, no financieros | [submission] | — |
| Entrenamiento | Anthropic no entrena con el contenido crudo de los conectores, salvo lo que se copia al chat | [privacy] | citable en nuestra política |
| Términos | Directory Terms (16-mar-2026): licencia sobre marca y descripciones, retirada sin causa, indemnización | [terms] | **revisión legal de Jürgen** |
| Revisión | Conector: escaneo automático, sale como «Community» y puede escalar a «Verified». Plugin: revisión humana antes de publicar. «Review time isn't fixed». Máximo 10 envíos en 24 h | [submission], [verification], [status] | sin plazo publicado |

## 5. Esfuerzo y fases

Las estimaciones son **inferidas**: el repo no tiene nada comparable medido. Se cuentan en días de
sesión.

- **Fase 0 · Spike en staging, 1-2 días.**
  - Qué se hace: activar el servidor OAuth en el proyecto de staging, una página de consentimiento
    mínima y una sola herramienta (`listar_cuentas`), conectada como *custom connector* en claude.ai.
  - Qué cierra: los NO VERIFICADO de §2 y §4 (CIMD, el hook de rol, la API de revocación, la
    latencia del token).
  - Termina en un sí o un no.
- **Fase 1 · Solo lectura, unas 3 semanas.**
  - El Worker `mcp/` con las 6 herramientas.
  - **El port de la lógica con golden vectors**, que se lleva cerca de la mitad del tiempo.
  - La migración de permisos por el runbook.
  - La web de consentimiento y de revocación, con Sign in with Apple y Google web.
  - La política de privacidad, la documentación y los 3 prompts.
  - La cuenta demo y las 3 skills, y el envío.
  - Depende de dos cosas: el modo nube estable en producción y el ticket de copy legal cerrado.
- **Fase 2 · En la app, alrededor de 1 semana.**
  - «Claude conectado» en Perfil, con Revocar.
  - El aviso de consentimiento propio que pide el diferido #22.
  - La auditoría de accesos.
  - Toca `ProfileView.swift`, así que se coordina con la cola A.
- **Fase 3 · Escritura acotada, sin estimar.**
  - Lo más seguro sería un «apunta este gasto» que cae en el **Inbox** como borrador (`inbox_drafts`,
    `supabase-staging.ddl:212`) y que el usuario aprueba en la app.
  - Aun así, escribir obliga a estampar HLC y `field_hlcs` como el protocolo de sync. Eso es el
    corazón de la cola A, y **no se empieza hasta que esté asentada**.
  - Grupos, en lectura, va detrás, porque necesita `GROUPS_ENC_KEY`.

## 6. Decisiones que son de Jürgen

**Contestadas el 2026-09-26:** (1) gratis por defecto, con un punto de extensión para marcar alguna
herramienta como Pro más adelante; (2) sí vale que solo sirva a quien está en modo nube; (3) producción
espera a que la nube esté estable, tras 2.1, y la fase 0 va ya en staging; (4) «recurrentes a revisar».
Las preguntas, tal como se plantearon:

1. **¿Gratis o Pro?** Las funciones de IA de la app verifican el entitlement Pro (`gateway/README.md:3`),
   y la nube es «siempre gratis» (`MODO-NUBE-DIFERIDOS.md:202-205`). Un conector gratis le da a Claude
   lo que la app cobra.
2. **¿Vale un conector que solo sirve a quien está en modo nube?**
3. **¿Cuándo?** El gatillo del diferido #22 es el modo nube estable en producción. La fase 0 se puede
   hacer antes, porque solo toca staging.
4. **Reformular «suscripciones sin usar»** como «recurrentes a revisar» (§1).

## 7. Fase 0: lo que se hizo, lo aprendido y lo que falta (2026-09-26)

**En corto: sí, con un bloqueo para la fase 1.** Claude Code se conectó al conector de staging, hizo el baile
OAuth con Supabase, pasó por la pantalla de consentimiento y respondió con los datos reales del usuario de prueba.
La base impide que ese token escriba en las finanzas, y otro usuario no ve nada. Pero **GoTrue sí deja al token
cambiar la cuenta de inicio de sesión** (`PUT /auth/v1/user` → 200), y eso hay que cerrarlo antes de producción
(`claude-mcp-oauth-token-can-change-the-account`). **Cerrado el mismo día: §8.**

### Qué se construyó

- **`mcp/`**, un Worker propio (`yala-mcp-staging`, desplegado en `workers.dev`). Tiene las seis herramientas de
  §1, los metadatos del recurso protegido (RFC 9728), el `401` con `resource_metadata` y la pantalla de
  consentimiento. Guía: `mcp/README.md`.
- **El rol `yala_mcp_reader`** y su hook, en staging (`qa/cloud/mcp0_01_readonly_role.sql`, con marcha atrás y
  entrada en `docs/RUNBOOK-staging-ddl.md`).
- **La configuración de Auth de staging:** hook, Site URL y servidor OAuth con DCR. El antes y el después están en
  `tickets/done/claude-mcp-activate-oauth-in-staging.md`.
- **Tests:** 49 unitarios sin red (job `mcp` del CI) y 17 e2e contra staging (`tools` 7 y `oauth` 10), todos en
  verde.
- **`mcp/plugin/`**, el borrador del plugin: `plugin.json`, `.mcp.json` y tres skills (`gasto-del-mes`,
  `presupuesto`, `recurrentes-a-revisar`). No se ha publicado ni enviado.
- **Punto de extensión Pro:** cada herramienta declara `plan` y `planAllows` decide. Hoy las seis son gratis.
- **Auditoría:** una línea de log por llamada, con herramienta, cliente, hash del usuario, latencia y resultado.
  Sin datos.

### Qué funcionó (medido)

- **Claude Code, de verdad.** `claude mcp add --transport http …` → «Needs authentication» → `/mcp` →
  *Authenticate*. Claude Code:
  - hizo DCR por su cuenta;
  - mandó PKCE S256 y el parámetro `resource`, sin `scope`;
  - volvió a su loopback con el código.

  Respondió «39 cuentas, −189 PEN» para A, la misma cifra que el e2e.
- **El hook se invoca para los tokens OAuth y al refrescarlos.** El token sale con `role = yala_mcp_reader` y
  `client_id`. El login normal sigue saliendo `authenticated` y sin `client_id`.
- **Solo lectura en la base.** Con el token de Claude, PostgREST responde 403 a `PATCH`, `INSERT` y a las RPC de
  escritura. En SQL, como `yala_mcp_reader`, también dan `42501` `delete_personal_account`, `apply_delta`,
  `claim_account` y `migration_progress`.
- **Aislamiento.** B no ve ninguna cuenta ni movimiento de A, ni por el MCP ni pidiendo a PostgREST las filas de A
  con su propio token.
- **Tiempos.** Discovery en 312-524 ms y token en ~225 ms, lejos de los 10 s de Claude. Cada herramienta tarda
  entre 430 y 870 ms.
- **Revocación.** `GET` y `DELETE /auth/v1/user/oauth/grants` funcionan. Tras revocar, el refresh da
  `refresh_token_not_found`, pero **el access token vivo sigue sirviendo hasta que caduca** (1 h). Es un JWT y el
  MCP no consulta el estado de la sesión.
- **La pantalla de consentimiento cierra su sesión web.** Tras decidir, ese token da 403 en `/auth/v1/user`.

### Lo que la verificación destapó y cambió el código

- **En Workers, `fetch` guardado como método falla** («Illegal invocation»). En Node funciona, así que los tests
  unitarios no lo veían. Lo cazó el e2e contra el Worker desplegado.
- **La review adversarial** (tres lentes: seguridad, paridad de cálculos, protocolo) encontró, y se arregló:
  - **Seguridad y protocolo:**
    - `GET /mcp` devolvía un stream vacío que hacía reconectar al SDK cada segundo; ahora da 405.
    - Lista cerrada de dominios de vuelta en la pantalla de consentimiento (`claude.ai`, `claude.com` y el
      loopback): con DCR, cualquiera registra un cliente llamado «Claude».
    - El cursor se valida como ISO estricto.
  - **Consultas y fechas:**
    - El filtro de fechas de `buscar_movimientos` usa el mismo día que enseña (`local_day`).
    - Corregido el inicio del día en zonas que adelantan la hora a medianoche.
    - La paginación solo para cuando llega una página vacía.
  - **Paridad con la app:**
    - Naturalezas estrictas (lo que la app no reconoce deja el presupuesto en 0, como en la app).
    - Los null valen el default del modelo.
    - El gasto medio diario no cuenta el día en curso.
    - Las tasas se completan con filas anteriores.
    - El top se ordena por magnitud y se agrupa por categoría, no por nombre.
    - Los presupuestos cuadran con la pantalla de Presupuestos, no con el chat.
- **El orden importa:** el hook va antes que el servidor OAuth. Al revés, hay una ventana en la que Supabase emite
  tokens que escriben.

### Qué sigue NO VERIFICADO

- **CIMD.** Supabase no lo anuncia en sus metadatos. Claude Code usó DCR sin problema.
- **Claude Desktop y claude.ai.** Solo se probó Claude Code. Los dos usan el callback
  `https://claude.ai/api/mcp/auth_callback`, que está en la lista de dominios permitidos.
- **RFC 8707.** Claude Code manda `resource`, pero el token sale con `aud = "authenticated"`. Supabase no lo
  aplica, y el MCP no puede exigir una audiencia propia.

### Lo aprendido que cambia el diseño

1. **Un rol a medida, no políticas por `client_id`.** Las 11 RPC `SECURITY DEFINER` que escriben corren como su
   dueño, y una política RESTRICTIVE no las alcanza. Con el rol no llegan a ejecutarse. Además todo es aditivo:
   no toca nada que mueva la cola A.
2. **Solo lectura en Postgres no es solo lectura en Auth.** GoTrue no mira el rol ni el `scope`. Es el bloqueo de
   la fase 1.
3. **El MCP falla cerrado.** Exige `client_id` y `role = yala_mcp_reader`.
4. **Días, no instantes.** El MCP cuenta por días inclusivos en la zona del usuario. Portar los presupuestos
   destapó un bug de la app: cuentan la medianoche del día 1 siguiente (`budget-interval-counts-next-period-midnight`).
5. **Las filas llegan a medias** (el sync es por campo): la lógica usa el default del modelo o salta la fila, y lo
   cuenta en `avisos`.
6. **Faltan datos del teléfono en la nube.** `local_day` falta en 1142 de 4465 movimientos de staging, y la zona
   horaria no viaja. (`firstWeekday` sí: es una preferencia sincronizada que solo sube cuando el usuario la cambia;
   corregido en §9.)
7. **Las cuentas de prueba casi no tienen movimientos con categoría.** Los cálculos se validaron con datos a
   mano; la paridad con cifras reales la darán los golden vectors.
8. **Staging tiene presupuestos con `natures` en inglés** (fixtures `i12-*`). La app los ignora, y el MCP también.
9. **DCR deja un cliente registrado por cada conexión**, y borrarlos exige `service_role`.

### Qué falta para la fase 1

- ~~**Bloqueante:** que el token de Claude no pueda cambiar la cuenta.~~ Cerrado en §8: Claude recibe un token del
  Worker, que no sirve en Supabase.
- ~~**Paridad de cifras:** golden vectors desde Swift, gastos de grupo, tasa del día y zona horaria
  (`claude-mcp-numbers-match-the-app`).~~ Cerrado en §9, salvo la zona horaria
  (`app-uploads-its-timezone-to-the-cloud`).
- **Login con Apple y Google** en la pantalla de consentimiento (`claude-mcp-consent-with-apple-and-google`).
- **Producción:**
  - Aplicar `mcp0_01` y `mcp0_02` (con el id del cliente del Worker en producción) por el runbook, en una ventana sin
    migraciones de la cola A.
  - Encender el hook y, DESPUÉS, OAuth, solo con el sign-in real ya verificado. DCR de Supabase apagado desde el
    principio. El resto, en `claude-mcp-production-auth-hardening` (§8).
- **Límites de peticiones** en `/mcp` y en la pantalla de consentimiento.
- ~~**Una sesión web abandonada** en la pantalla de consentimiento vive hasta 1 h.~~ Ya no: la sesión web vive lo que
  dura una petición (§8).
- **Un dominio propio** (por ejemplo `mcp.yala-app.pe`).
- **Retirar el login con contraseña**, que hoy solo existe con `ENVIRONMENT = staging`.

### Requisitos del portal que siguen abiertos

- **Política de privacidad:** sigue fallando (`session-redesign-web-and-store-copy`). Además tiene que nombrar a
  Anthropic como destinatario.
- **Cuenta de prueba** en producción, con datos y un login que puedan usar los revisores.
- **Documentación pública** con 3 prompts de ejemplo. El borrador de `mcp/plugin/README.md` los trae.
- **Licencia del plugin:** el borrador dice «Propietaria». Lo decide Jürgen.
- **CIMD, el texto de los siete reconocimientos y los Directory Terms:** como en §4.
- **Lo que ya cumple el borrador:**
  - la forma del plugin, un README de más de 40 palabras y ningún secreto en `.mcp.json`;
  - `title` y `readOnlyHint` en todas las herramientas, y nombres de menos de 64 caracteres;
  - respuestas paginadas y ninguna herramienta de escritura.

## 8. El token de Claude ya no es de Supabase (2026-09-26, tarde)

**En corto: el bloqueo de §7 está cerrado.** Claude recibe un token del propio Worker, y ese token no sirve en
Supabase. Se midió contra staging con los usuarios A y B:

- las 17 escrituras de `/auth/v1/*` que se probaron con ese token dan **403 `bad_jwt`**, y la cuenta de A queda
  idéntica;
- las seis herramientas leen como antes;
- B no ve nada de A;
- revocar corta al momento, desde Claude y desde la cuenta.

La decisión y su porqué están en el ADR «El conector de Claude emite sus propios tokens» (`docs/DECISIONS.md`).

### Por qué no bastaba con Supabase (medido en el código de GoTrue v2.197.0)

- **No hay forma de limitar lo que puede hacer un token OAuth.** El middleware `requireAuthentication`
  (`internal/api/auth.go`) acepta cualquier JWT válido del usuario y no mira `client_id` ni `scope`. Protege `/user`,
  `/factors`, `/logout`, `/reauthenticate`, `/user/identities`, `/user/oauth/grants` y `/oauth/authorizations`.
  Tampoco hay issue ni PR abierto en `supabase/auth`. El texto del issue va redactado en el PR, sin publicar.
- **La «vía 2» cubre menos de lo que decía el ticket** (`internal/api/user.go`):
  - la reautenticación para cambiar la contraseña solo se pide si la sesión tiene **más de 24 h**;
  - «contraseña actual» solo se pide si el usuario **ya tiene** una. A un usuario de Apple o Google el token le puede
    poner una contraseña, y con ella se entra;
  - el cambio de email ya pedía doble confirmación en staging;
  - los metadatos, el alta de un TOTP y el `logout` global no los cubre ninguna opción.

### Cómo funciona ahora

El Worker es el servidor OAuth de Claude (`@cloudflare/workers-oauth-provider` 1.1.0), y Supabase queda aguas
arriba. El código está en `mcp/src/authorize.ts`; la guía, en `mcp/README.md`.

1. Claude se registra en el Worker (DCR). Solo se aceptan vueltas a `claude.ai`, `claude.com` o loopback.
2. **Permiso por cliente en el Worker**, ANTES de salir hacia Supabase: quién pide, a dónde vuelve y qué no podrá
   hacer. Así lo pide la guía de seguridad de MCP para servidores que autentican a través de otro.
3. El Worker manda a Supabase como **su propio cliente confidencial**, con PKCE. Supabase vuelve a la pantalla de
   login del Worker (`/oauth/consent`). El login, la aprobación y el cierre de la sesión web ocurren **en una sola
   petición**: esa sesión ya no vive en una cookie.
4. En el callback, el Worker canjea el código, verifica que el token es de solo lectura y de su cliente, y lo guarda
   cifrado. A Claude le devuelve un código propio, y luego tokens propios.
5. **En cada llamada a `/mcp`** comprueba la sesión de Supabase con `GET /auth/v1/user`. Si ya no existe, retira la
   conexión y responde 401.
6. **En cada refresh de Claude** rota también el refresh de Supabase. La conexión dura 30 días sin uso, y 90 como
   máximo desde que se autorizó.
7. **Nada del Worker puede escribir la cuenta**: todas sus salidas a Supabase pasan por una lista cerrada
   (`mcp/src/egress.ts`), y `PUT /auth/v1/user` no está en ella.

### Qué cambió en staging (antes → después)

| Qué | Antes | Después |
|---|---|---|
| Worker `yala-mcp-staging` | versión `ecd32b4f` (fase 0) | versión `c597b9cc` (OAuth propio) |
| KV del Worker | — | `yala-mcp-staging-oauth` (`9705886913ee4d1fb7217ef6e3ecdef7`) |
| Secreto del Worker | — | `SUPABASE_OAUTH_CLIENT_SECRET` (copia en `~/Secrets/yala-mcp-staging/`) |
| Cliente OAuth del Worker en Supabase | — | `65fb5767-59a5-4f50-b77c-7970e67589c5`, confidencial |
| Hook `yala_mcp_access_token_hook` | cualquier `client_id` → lector (md5 `5a048417…`) | solo el cliente del Worker, y por el cliente de la SESIÓN, no por el claim; el resto, 403 (md5 `0a03fb94…`, `mcp0_02`+`mcp0_03`) |
| `oauth_server_allow_dynamic_registration` | `true` | `false` |
| `security_update_password_require_reauthentication` | `false` | `true` |
| `security_update_password_require_current_password` | `false` | `true` |
| `mfa_totp_enroll_enabled` / `mfa_totp_verify_enabled` | `true` | `false` |

La marcha atrás, paso a paso, está en `docs/RUNBOOK-staging-ddl.md`, secciones `mcp0_02` y `mcp0_03`. Producción no se tocó.

**`mcp0_03` lo trajo la review** (2026-09-26): con `mcp0_02` el hook decidía por el claim `client_id`, y GoTrue reemite un
token para la misma sesión al verificar un factor MFA SIN ese claim — salía con `role = authenticated` y escribía la base.
Con un Worker comprometido eso era la cuenta entera. `mcp0_03` decide por `auth.sessions.oauth_client_id`, así que todo
token de la sesión del Worker es de solo lectura. Verificado en SQL con una sesión sintética (rama por sesión → lector) y
con el login normal (intacto). MFA, además, apagado.

### Medido (e2e contra staging, 18/18)

- **Descubrimiento:** 98-104 ms. **Token:** unos 950 ms. **Cada herramienta:** 445-800 ms, con la comprobación de
  sesión incluida.
- **Con el token que recibe Claude:**
  - las 17 sondas de escritura dan 403 `bad_jwt`: `PUT /user` con cuerpo vacío, metadatos, email, contraseña y
    teléfono; alta, reto y baja de factores; códigos de recuperación; `logout` global; `reauthenticate`; identidades;
    permisos; passkeys; y aprobar autorizaciones;
  - su refresh no vale en `/auth/v1/token` ni en `/auth/v1/oauth/token` (400), y PostgREST no lo acepta (401).
- **Revocar desde la cuenta** (`DELETE /auth/v1/user/oauth/grants`): la llamada siguiente a `/mcp` ya da 401.
  **Revocar desde Claude** (RFC 7009): lo mismo.
- **Un cliente de la fase 0**, aprobado por el propio usuario por la API: 403 del hook, «Este cliente no puede
  conectarse a Yala.», y ningún token.
- El login normal sigue saliendo `authenticated` y sin `client_id`. El DCR de Supabase responde 403.
- Tras el e2e no queda viva ninguna sesión creada en la corrida, ni web ni OAuth (medido en `auth.sessions`).

### Lo que queda

- **Producción** (`claude-mcp-production-auth-hardening`): registrar allí el cliente del Worker; `mcp0_02` con ese
  id; DCR apagado; la capa de contraseñas; y **apagar el proveedor de email**, que la app no usa y que cierra la vía
  de la primera contraseña si alguien comprometiera el Worker.
- **Revocar desde Claude deja una sesión huérfana en Supabase:** inalcanzable, pero listada
  (`claude-mcp-revoke-from-claude-leaves-supabase-session`). Importa para el «Claude conectado · Revocar» de la
  fase 2.
- **Login con Apple y Google** (`claude-mcp-consent-with-apple-and-google`): ahora va en `/oauth/consent` de
  `mcp/src/authorize.ts`, no en `consent.ts`. Necesitará `grant_type=id_token` en la lista de `egress.ts`.
- **CIMD:** la librería lo soporta, pero queda apagado porque aquí no se puede probar sin publicar un documento de
  metadatos.
- **Límites de peticiones** (§7): ahora incluyen también `/oauth/register` del Worker, que escribe en KV.
- **En staging siguen registrados cinco clientes que ya no reciben tokens:** los cuatro públicos de la fase 0 y uno
  que registró el primer e2e antes de apagar el DCR. Borrarlos exige `service_role`.
- **El token de Claude lleva en claro el id de usuario de Supabase**, porque es el formato de la librería
  (`usuario:grant:secreto`). No es una credencial.

## 9. Las cifras del conector cuadran con la app, y lo dice la app (2026-09-26, noche)

**Qué cambia para quien use Claude:** un gasto de grupo que pagaste tú cuenta por tu parte, no por el total; un
movimiento en otra divisa se convierte con la cotización de su día, como en Estadísticas; y el campo `avisos` ya no
habla de grupos ni de tasas. Solo queda un aviso de diferencia: la zona horaria, cuando Claude no la pasa.

### Cómo se sabe

`mcp/test/golden/app-parity.json` son escenarios escritos como filas de PostgREST. El test de Swift
`YalaTests/MCP/MCPAppParityGoldenTests.swift` los mete en SwiftData por el camino real del pull (`EntityApplyMap`) y
calcula con el código de producción —`InitialBalanceService`, `FullFinancialContextBuilder.buildFromArrays`,
`BudgetsViewModel.calculateSpending`, `GroupBridgeStatsAdjustment`, `CurrencyConverter.convertChecked`—, y escribe
los `expected` (con `TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1`) o los verifica (sin ella). `npm test` en `mcp/` pasa las
mismas filas por el TypeScript y exige la misma cifra, al medio céntimo. Si la app cambia una regla, el test de
Swift se pone rojo; si el conector se separa, `npm test`.

Lo que el conector copia tal cual de la app —la tabla estática de tasas y los nombres de «Préstamo a grupos» en todos
los idiomas— también viaja en el golden y se compara.

### Las reglas portadas

- **Tasa del día** (`mcp/src/logic/fx.ts`): port de `CurrencyConverter.resolveRates`. La clave es el día **UTC** del
  instante; la fila de ese día; lo que falte, de las 30 filas anteriores; y lo que siga faltando, de la tabla
  estática. «La tasa de hoy» (saldos, presupuestos, recurrentes) es la misma función con el día UTC de ahora. `≈` si
  algo no salió de la fila del día, con el umbral del 5 % de `ApproximateMarkThreshold` en los resúmenes.
- **Gastos de grupo** (`mcp/src/logic/groups.ts`): port literal de `GroupBridgeStatsAdjustment`. Se construye con las
  dos patas presentes: las herramientas leen las hermanas por `split_expense_id` aunque caigan fuera del rango.
- **Primer día de la semana:** el que pase Claude (`primer_dia_semana`), si no la preferencia sincronizada, y si no,
  lunes — que es también el default de la app.

### Diferencias que quedan, y por qué

- **Zona horaria**, cuando Claude no la pasa: el único aviso que queda en `avisos`
  (`app-uploads-its-timezone-to-the-cloud`).
- **Filas de tasas duplicadas.** En staging, 367 días tienen dos o tres filas (una por dispositivo), con valores que
  difieren hasta un 12,6 %. La app convierte con la primera que le devuelve SwiftData, sin orden; el conector las
  funde con una regla determinista (y respeta la ventana de 30 FILAS de la app, no 30 días). No hay cifra de la app
  que copiar hasta que ella también lo sea (`duplicate-exchange-rate-rows-pick-an-arbitrary-rate`).
- **Una divisa que no es de las 54, o un alias** («S/.», «US$»). La app normaliza el alias y colapsa lo desconocido
  a USD (`fx-unknown-currency-code-collapses-to-usd`); el conector no lo suma y lo dice. El wire trae códigos ya
  normalizados.
- **Días, no instantes.** Un movimiento de hoy posterior a la hora actual cuenta en el conector y no en el chat de la
  app; y el periodo de un presupuesto termina el último día, no en la medianoche del siguiente
  (`budget-interval-counts-next-period-midnight`). El golden no mide el periodo de los presupuestos: es una entrada.
- **La «tasa de hoy» depende de que alguien la haya descargado.** Si el usuario no ha abierto la app hoy, no hay
  fila de hoy y el conector arrastra la de ayer, con «≈»; la app, al abrirse, descarga la de hoy.

Hallazgo de la review que va a la app: las claves de día de las tasas siguen el calendario del teléfono
(`exchange-rate-date-keys-follow-the-phone-calendar`, inferido).

[rc]: https://claude.com/docs/connectors/building/review-criteria
[auth]: https://claude.com/docs/connectors/building/authentication
[submission]: https://claude.com/docs/connectors/building/submission
[verification]: https://claude.com/docs/connectors/verification
[publish]: https://claude.com/docs/directory/publish
[status]: https://claude.com/docs/directory/submission-status
[build]: https://claude.com/docs/plugins/build
[blog]: https://claude.com/blog/build-plugins-for-claude
[policy]: https://support.claude.com/en/articles/13145358-anthropic-software-directory-policy
[terms]: https://support.claude.com/en/articles/13145338-anthropic-software-directory-terms
[aup]: https://www.anthropic.com/legal/aup
[privacy]: https://privacy.claude.com/en/articles/10023580-is-my-data-used-for-model-training
[cc-mcp]: https://code.claude.com/docs/en/mcp
[supabase-mcp]: https://supabase.com/docs/guides/auth/oauth-server/mcp-authentication
[supabase-oauth]: https://supabase.com/docs/guides/auth/oauth-server
[supabase-start]: https://supabase.com/docs/guides/auth/oauth-server/getting-started
[supabase-token]: https://supabase.com/docs/guides/auth/oauth-server/token-security
