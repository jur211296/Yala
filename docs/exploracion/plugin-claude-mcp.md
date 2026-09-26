---
fecha: 2026-09-26
estado: exploración — no hay código ni nada desplegado
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

⚠️ **«Suscripciones sin usar» no se puede prometer.** Yala no sabe si usas un servicio, solo que lo
pagas. Lo honesto es enseñar «lo que pagas cada mes y al año, y lo que lleva tiempo sin cobro
asociado». Es una decisión de producto (ver §6).

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

1. **¿Gratis o Pro?** Las funciones de IA de la app verifican el entitlement Pro (`gateway/README.md:3`),
   y la nube es «siempre gratis» (`MODO-NUBE-DIFERIDOS.md:202-205`). Un conector gratis le da a Claude
   lo que la app cobra.
2. **¿Vale un conector que solo sirve a quien está en modo nube?**
3. **¿Cuándo?** El gatillo del diferido #22 es el modo nube estable en producción. La fase 0 se puede
   hacer antes, porque solo toca staging.
4. **Reformular «suscripciones sin usar»** como «recurrentes a revisar» (§1).

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
