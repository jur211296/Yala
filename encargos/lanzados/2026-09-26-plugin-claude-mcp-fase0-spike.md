# Fase 0 del plugin de Yala para Claude: spike de un MCP remoto de solo lectura contra staging

## Contexto
La exploración está en `docs/exploracion/plugin-claude-mcp.md` (PR #258, mergeado a 2.1). Léela entera primero: define las herramientas, el encaje con la API y la auth del modo nube, el aislamiento recomendado y las fases. Jürgen decidió las cuatro preguntas del §6:
1. Gratis por defecto. Deja un punto de extensión para marcar algunas herramientas como Pro más adelante (no implementar el cobro).
2. Sí vale que solo sirva a usuarios en modo nube.
3. El lanzamiento a producción espera a que la nube esté estable (tras 2.1). Esta fase 0 va ya, solo en staging.
4. «Suscripciones sin usar» pasa a llamarse «recurrentes a revisar».
En paralelo corre una sesión de la cola A que compila la app y toca el sync de grupos.

## Qué se pide
El spike de la fase 0 según el doc: un servidor MCP remoto de solo lectura, aislado de la app (en la carpeta, paquete o repo que recomienda el doc), autenticado por usuario contra la nube de staging (OAuth o el camino que marque el doc) y con RLS respetada. Incluye las herramientas de lectura que el doc prioriza para la fase 0 y un borrador de las skills de análisis, con el nombre «recurrentes a revisar». Actualiza el doc con lo aprendido: qué funcionó, qué falta para la fase 1 y los requisitos del portal que sigan abiertos. Opción robusta y de buena práctica, no la mínima.

## Qué NO hay que tocar
Nada en Supabase prod: ni migraciones ni despliegues. En staging, solo lo imprescindible para el spike, y documentado. Ningún código de la app iOS ni del sync del modo nube. No compilar la app ni correr su suite de tests. No enviar nada al portal de Anthropic ni publicar el plugin. Nada de marketing/. Ningún secreto en el repo: si hace falta una credencial, pídesela a Jürgen con AskUserQuestion (de día) o aparca.

## Cómo se sabe que está bien
Con un usuario de prueba de staging, Claude (Claude Code o Desktop) conecta con el MCP, se autentica y lee datos reales de staging con al menos las herramientas de fase 0. Otro usuario no ve esos datos. Hay tests del servidor. El doc queda actualizado. PR mergeado a 2.1, ticket al día en tickets/ y docs/TICKETS.md, cierre con /cerrar-total. Los residuales van como tickets propios.

MODO AUTÓNOMO: no preguntes «¿Sigo?» ni esperes aprobación por tocar más de 3 ficheros; implementa hasta PR, merge y /cerrar-total. De día (06:00–21:00 Lima) puedes preguntar a Jürgen con AskUserQuestion solo lo de producto o acceso; de noche, elige lo recomendado o aparca.

## Paso 0 — decisiones

> Autónomo en horario de día. La de acceso (D2) se le preguntó a Jürgen: eligió «token de gestión». El resto
> son técnicas y las contesté yo con lo medido; se discuten en el PR.

**Hechos medidos antes de decidir (2026-09-26, 08:00 Lima).**
- Staging `fostjbbwstyuunmmefuk`: `execute_sql` entra como `postgres`. El servidor OAuth está **apagado**
  (`/.well-known/oauth-authorization-server/auth/v1` → 404 `feature_disabled`). No hay ningún hook de Auth.
- `authenticated` tiene INSERT/UPDATE en 20 tablas y EXECUTE en 31 funciones de `public`: 16 son `SECURITY DEFINER`, y 11 de ellas
  escriben (`delete_personal_account`, `create_group`, `join_group`…). PUBLIC ejecuta
  tres, las tres `SECURITY INVOKER`.
- Ya existe un rol propio colgado de `authenticator`: `yala_push` (G8-3). El molde de «rol a medida» está probado aquí.
- Datos: A tiene 39 cuentas y 1035 movimientos; B, 193 movimientos y ninguna cuenta. `local_day` falta en 1142 de
  4465 movimientos; no hay zona horaria del usuario en `user_preferences`.
- `wrangler` autenticado como `admin@yala-app.pe`.

**D1 · Dónde vive** → `mcp/` en este repo, con su propio Worker (`yala-mcp-staging`).
Por qué: es lo que recomienda §3 del doc; el contrato del esquema está al lado. Descartado: ruta del gateway (le
daría acceso a `GROUPS_ENC_KEY` y un deploy del MCP alcanzaría al sync).

**D2 · Servidor OAuth** → el de Supabase Auth en staging, con registro dinámico (DCR). Lo activo por la
Management API con un token que Jürgen guarda en `~/Secrets/yala-supabase-mgmt/`. Site URL de staging → el Worker.
Por qué: es el camino del doc y deja el `sub` de Supabase como identidad sin tocar nada. Descartado: OAuth propio
en el Worker (guardaría refresh tokens de Supabase con poder de escritura).

**D3 · Pantalla de consentimiento** → la sirve el propio Worker en `/oauth/consent`, renderizada en servidor.
Login con email y contraseña, que es lo que tienen los usuarios de prueba. El token de la sesión viaja en una
cookie `HttpOnly; Secure; SameSite=Strict` de 5 min, atada al `authorization_id`. Sign in with Apple y Google en
web quedan para la fase 1.
Por qué: sin JS de terceros ni CDN, y la contraseña no se guarda. Descartado: supabase-js en el navegador (más
superficie para un spike).

**D4 · Solo lectura de verdad** → hook de *custom access token* que, si el token trae `client_id` (o sea, lo pidió
un cliente OAuth), cambia `role` a `yala_mcp_reader`. Ese rol solo tiene SELECT sobre las 9 tablas que lee el MCP,
con políticas SELECT propias `auth.uid() = user_id`. No tiene ninguna escritura ni EXECUTE sobre las funciones
`SECURITY DEFINER`. Todo es **aditivo**: no modifica ninguna política ni función existente, y tiene script de
marcha atrás.
Por qué: cierra también las 11 RPC de escritura, que una política restrictiva por tabla no alcanza. Y no toca los
objetos que mueve la cola A. Descartado: políticas RESTRICTIVE por `client_id` (dejan `delete_personal_account`
abierta a un token de Claude).

**D5 · El MCP solo acepta tokens de solo lectura** → rechaza con 401 cualquier token sin `client_id` o con
`role ≠ yala_mcp_reader`, aunque la firma sea buena.
Por qué: falla cerrado. Si el hook se cae, el MCP deja de servir en vez de servir con un token que escribe.

**D6 · Herramientas** → las 6 de §1. Las tres directas (`listar_cuentas`, `listar_categorias`,
`buscar_movimientos`) y las tres calculadas (`resumen_periodo`, `estado_presupuestos`, `listar_recurrentes`),
portadas de Swift con tests. Lo que la v0 no porta sale en un campo `avisos` de la propia respuesta: el ajuste de
gastos de grupo (`GroupBridgeStatsAdjustment`) y la conversión con tasas del día.
Por qué: las skills se apoyan en las tres calculadas y el encargo pide la opción robusta. Descartado: solo
`listar_cuentas` (el mínimo del doc). Golden vectors generados desde Swift: fase 1, porque aquí no se compila la app.

**D7 · Zona horaria** → parámetro `zona_horaria` (IANA), por defecto `America/Lima`. El día de un movimiento es
`local_day` si existe, y si no, `date` en esa zona. La respuesta dice qué zona usó.
Por qué: el servidor no conoce la zona del teléfono. Guardarla en `user_preferences` es fase 1 y toca la app.

**D8 · Punto de extensión Pro** → cada herramienta declara `plan: "gratis" | "pro"`, y una sola función decide
si se puede usar. Hoy todas son gratis y la función no consulta nada. Sin cobro.

**D9 · Despliegue** → `wrangler deploy` del Worker nuevo a `workers.dev`, solo staging. Así Claude Desktop y
claude.ai pueden conectarse, además de Claude Code.
Por qué: un Worker aparte no arrastra commits ajenos, que era la razón para no desplegar el gateway.

**D10 · CI** → `mcp/*` entra en la lista de rutas de `qa.yml` que no disparan la suite de iOS, y el MCP tiene su
propio job: typecheck y tests unitarios, sin red.

**D11 · Plugin** → borrador en `mcp/plugin/`, con `plugin.json`, `.mcp.json` a la URL de staging y tres skills:
`gasto-del-mes`, `presupuesto` y `recurrentes-a-revisar`. No se publica ni se envía.

**D12 · Auditoría** → una línea de log estructurado por llamada (herramienta, `client_id`, hash del `sub`,
latencia), sin datos financieros. La auditoría visible para el usuario es fase 2.

**D13 · DDL de staging** → en `qa/cloud/mcp0_01_readonly_role.sql`, con su `mcp0_01_rollback.sql`, y anotado en
`docs/RUNBOOK-staging-ddl.md`. Producción no se toca.

**D2 · revisada a las 10:00 (Jürgen, «hazlo sin token»)** → la activación de OAuth en staging se aparca. El PR
lleva todo lo demás, y la activación queda como `tickets/blocked/claude-mcp-activate-oauth-in-staging.md`, con los
pasos del dashboard y el e2e de OAuth listo para correr. Lo que se pudo medir sin OAuth se midió con la sesión
normal de A y B (`mcp/test/e2e/tools.e2e.test.ts`).

**D2 · revisada otra vez a las 10:10 (Jürgen guardó el token de gestión)** → se usa SOLO sobre staging: el token
nuevo solo ve ese proyecto. Orden aplicado: hook, Site URL, servidor OAuth con DCR. Antes y después en
`tickets/done/claude-mcp-activate-oauth-in-staging.md`. El e2e de OAuth pasó 10/10 y Claude Code se conectó de
verdad. El primer token que dejó era de otra cuenta (solo veía la organización «Tests»); se detectó por el 403 y
Jürgen lo cambió.

**D14 · (review adversarial) presupuestos: ¿cuadrar con el chat o con la pantalla?** → con la pantalla de
Presupuestos, que es con la que el usuario va a comparar. No quita movimientos futuros ni de cuentas excluidas o
archivadas; el chat sí. El resumen de periodo sigue a Estadísticas y al chat.
