---
id: backend-account-kind-complete-or-groups-only
status: done
priority: high
area: "gateway, modo-nube, groups"
created: 2026-09-09
source: "ADR 2026-09-09 «Sesiones — dos ejes» §11"
updated: 2026-09-16
qa-status: absorbed
qa-date: 2026-09-16
qa-notes: Servidor verificado contra staging y prod 2026-09-10 (goldens 28-32). Lo visible en la app se verifica en cloud-sign-in-discovers-account-kind - override Jurgen 2026-09-16
---

# El backend tiene que saber decir si una cuenta es «completa» o «solo grupos»

## El problema, en lenguaje de usuario

Entro con mi cuenta de Google en un móvil recién instalado. Yala no puede saber si esa cuenta lleva
mis finanzas personales o solo mis grupos: hoy lo deduce de una preferencia local (`storageMode`) que
en un móvil nuevo no existe. Así que cada puerta se lo inventa a su manera: «Ya tengo cuenta» me
adopta como si fuera completa; «Vengo por un grupo» me trata como solo-grupos aunque tenga años de
datos en la nube.

## Lo medido (2026-09-09, árbol `3a94604e`)

- `GET /account/exists` (`gateway/src/sync/account.ts:255-262`) responde `{ exists: bool }` mirando si
  hay fila en `profiles`. Nada más.
- El cliente deriva «dónde viven mis datos» de `storageMode` local: `YalaAccountLogic.model`
  (`Yala/App/Logic/YalaAccountLogic.swift`, `dataLocation: isCloud ? .cloud : .groupsOnly`) y
  `RestoreRouter.decide` (`RestoreDestination.swift`, por `onboardingMode`).
- El sign-in de grupos (`GroupsSignInView`) no consulta al backend nada sobre la cuenta.

## Lo que se espera

Una cuenta en la nube tiene un **tipo** conocido por el servidor:

| kind | qué significa |
|---|---|
| `complete` | lleva finanzas personales (nació en la nube, o se activó Yala completo en la nube) |
| `groups_only` | solo grupos (nació por «Vengo por un grupo», o es la cuenta asociada de una sesión privada) |

y el cliente lo lee en el bloque [I] para rutear (ticket `cloud-sign-in-discovers-account-kind`).

## Alcance

1. **Esquema:** columna `kind` en `profiles` (Supabase), `text not null default 'groups_only'`, check
   `in ('complete','groups_only')`. Migración de las cuentas existentes: `complete` si tienen corpus
   personal sincronizado (medir en staging qué tabla/contador lo prueba antes de escribir la migración;
   no deducirlo del `storageMode` de nadie). RLS: legible por el dueño; escribible solo por RPC.
2. **Wire:** `GET /account/exists` pasa a devolver `{ exists, kind? }` (campo ausente ⇒ cliente trata
   como `groups_only`, fail-safe hacia la opción menos invasiva). `POST /account/claim` acepta `kind`
   (born-cloud lo manda `complete`; el alta de grupos, `groups_only`). Un endpoint o RPC para
   **promover** `groups_only → complete` (lo usa «Activar Yala completo → nube»). **Una sola degradación**
   `complete → groups_only`, como efecto del **reverse cutover existente** («Volver a iCloud»,
   `POST /account/migration` `reverse_*`): lo personal vuelve a iCloud y la cuenta queda como cuenta de
   grupos **asociada** a esa sesión privada si tiene grupos. Ninguna otra ruta degrada. La
   **promoción** `groups_only → complete` la usan «Activar Yala completo → nube» y «migrar a la nube»
   desde una sesión privada que ya tiene cuenta asociada (misma cuenta, nunca una segunda).
3. **Cliente:** `CloudAccountClient.exists` decodifica `kind`; `CloudWelcomeSignInFlow.route` devuelve
   `.accountFound(kind:)`; `YalaAccountLogic.dataLocation` y `RestoreRouter` dejan de inferir y leen el
   `kind` cacheado de la sesión (persistido en el mismo sitio que el provider de la sesión).
4. **Staging primero** (runbook de DDL en la memoria del agente / `docs/`), golden tests del gateway
   contra staging, y después prod.

## Criterios de aceptación

- [ ] `GET /account/exists` en staging devuelve `kind` para una cuenta nacida en la nube (`complete`) y
      para una de solo-grupos (`groups_only`); para una cuenta inexistente, `exists: false` sin `kind`.
- [ ] El claim born-cloud crea `complete`; el alta de grupos crea `groups_only`.
- [ ] Promover funciona una vez y es idempotente. Degradar solo ocurre dentro del reverse cutover y deja
      `groups_only`; un `complete` con corpus personal vivo nunca se degrada por otra vía.
- [ ] Todas las cuentas de producción tienen `kind` tras la migración, y el conteo por tipo se anota en
      el PR (medido, no estimado).
- [ ] Tests del gateway (`gateway/test/`) para las tres rutas; `CloudAccountClientTests` para el decode
      con y sin `kind`.

## Fuera de alcance

El ruteo del cliente con ese dato (ticket siguiente). La UI.

## Decisiones de Jürgen (2026-09-09, pasada de desbloqueo)

Preguntadas una a una antes de soltar la cola autónoma. **Mandan sobre lo escrito arriba.**

### Lo medido en producción antes de decidir (2026-09-09, MCP Supabase, proyecto `kefvaiymtgytemwbltlz`)

Producción **son dos cuentas y ninguna más, las dos de Jürgen**; cero datos de terceros:

| `profiles.id` | provider | tx | accounts | categories | budgets | grupos | `personal_claimed_at` | tipo |
|---|---|---|---|---|---|---|---|---|
| `1487d06a-1605-4afd-9412-434ac97c9f3e` | — | 0 | 0 | 0 | 0 | 2 | no | `groups_only` |
| `27751374-1225-482c-9e42-fedae5e02f98` | apple | 31 | 11 | 13 | 4 | 2 | **sí** | `complete` |

Totales: `split_groups` 2 · `group_members` 4 (los dos grupos tienen exactamente esas dos cuentas)
· `split_expenses` 9 · `split_shares` 22 · `split_settlements` 4 · `group_invites` 2 · `push_tokens` 3
· `auth.users` 2 (último `last_sign_in_at`: **2026-09-09**, o sea la sesión de device-QA viva).
Ninguna de las dos tiene `migrated_at`: **lo personal nació en la nube y no tiene copia en CloudKit**.

**`personal_claimed_at` clasifica correctamente las dos**, así que el «medir en staging qué tabla/contador
lo prueba» del alcance §1 ya está contestado, y medido contra prod: esa es la señal.

### Las decisiones

- **Se añade columna `kind` explícita** (`text not null default 'groups_only'`, check
  `in ('complete','groups_only')`), aunque `personal_claimed_at` ya dé la misma señal. Queda sabido y
  aceptado el riesgo de dos verdades sobre lo mismo: **quien toque una ruta que cambie el tipo de cuenta
  tiene que mantener las dos coherentes**, y los tests deben cubrir esa coherencia.
- **El campo del wire se llama `kind`** (`GET /account/exists` → `{ exists, kind? }`). Sin cambios en el
  ADR ni en los tickets 3, 8, 9 y 10.
- **`kind` ausente ⇒ `groups_only`, PERO con corrección al refrescar.** El cliente no bloquea el sign-in
  (un gateway caído dejaría a la gente fuera) y no se queda en el modo equivocado: en cuanto una llamada
  posterior devuelva `kind`, la sesión se corrige sola y lo personal aparece. Hay que implementar esa
  corrección, no solo el default.
- **El backfill se escribe igual** (`complete` si `personal_claimed_at is not null`), aunque tras el
  borrado no vaya a tocar ninguna fila en prod: sirve para staging y para cuando haya usuarios reales.

### FRESH START de producción — decisión explícita de Jürgen

**Antes de aplicar el esquema, la sesión que implemente este ticket borra producción entera**, incluidas
las **identidades de `auth.users`**. Es un borrado irreversible aprobado con los conteos de arriba
delante; no vuelvas a preguntar, pero tampoco lo amplíes.

- **Alcance:** todas las tablas de datos + `profiles` + las 2 filas de `auth.users`. Fresh start real: el
  siguiente sign-in con Apple/Google crea una cuenta nueva y ejercita el alta completa.
- **Se pierden a propósito:** 31 transacciones, 11 cuentas, 13 categorías, 4 presupuestos, los 2 grupos
  con sus 9 gastos / 22 shares / 4 liquidaciones, y las 2 invitaciones. **No hay copia en CloudKit.**
- **Orden:** respetar las FKs (hijos antes que padres; `profiles` antes que `auth.users`). Anotar en el PR
  los conteos **antes y después**, medidos, no estimados.
- **Consecuencia para Jürgen, avísasela en el PR:** su iPhone queda con una sesión apuntando a una cuenta
  que ya no existe. Tendrá que cerrar sesión o reinstalar, y **volver a crear los grupos de prueba** antes
  del device-QA de los tickets 5, 8, 9 y 10.
- **Staging NO se toca**: su corpus y sus usuarios de test sostienen los goldens del gateway, que son
  justo lo que valida esta migración.

---

## Paso 0 — el árbol de decisiones, resuelto antes de escribir (2026-09-10)

Todo lo de abajo está **medido en este árbol y contra las dos bases reales**, no inferido. Las
decisiones de Jürgen del 2026-09-09 mandan; lo que sigue resuelve lo que ellas no nombraban.

### D0 · El acceso no es el que dicen los documentos — y no hay bloqueo

`docs/RUNBOOK-staging-ddl.md:36-40` afirma que no hay credencial de DDL de staging y que el MCP
«solo lista producción». **Medido hoy, es al revés en las dos mitades:**

| | Lo escrito (hasta hoy) | Medido 2026-09-10 |
|---|---|---|
| Staging `fostjbbwstyuunmmefuk` | no listado, sin DDL ⇒ «lo hace Jürgen» | **listado**; `execute_sql` entra como **`postgres`** ⇒ DDL y DML completos |
| Prod `kefvaiymtgytemwbltlz` | listado, lectura + DDL | **no listado**; `execute_sql` entra como `supabase_read_only_user` (`transaction_read_only=on`), pero **`apply_migration` escribe** |

El acceso a prod por `apply_migration` se verificó con **control positivo**: crear schema + tabla +
fila, leerlos con `execute_sql`, y borrarlos. ⇒ **este ticket es ejecutable de punta a punta**, y el
runbook queda obsoleto en su premisa central. Rastro de la prueba: quedó **una** fila espuria
(`probe_cleanup_20260910`) en `supabase_migrations.schema_migrations` de prod, porque el applier
inserta la fila **después** de ejecutar el cuerpo; la limpia la migración real de este ticket.

### D1 · `kind` NO es redundante con `personal_claimed_at`, y el backfill de la decisión se queda corto

La sección de decisiones dice que `personal_claimed_at` «clasifica correctamente las dos» cuentas de
prod. **Cierto hoy, falso en general**, y la diferencia importa porque el ticket exige una degradación:

`migration_progress`, rama `reverse_complete` (medida contra staging, cuerpo vivo) hace
`reverse_in_progress=false` + `reverted_at=coalesce(reverted_at, now())` y **no toca
`personal_claimed_at`** — igual que no toca `migrated_at`, y por el mismo motivo declarado (§h.4). ⇒
una cuenta que vuelve a iCloud conserva `personal_claimed_at` no nulo y **debe quedar `groups_only`**.
Ese es exactamente el estado que la señal vieja no sabe expresar, y la razón por la que la columna
explícita que pidió Jürgen es más que una segunda verdad.

⇒ **Backfill:** `complete` si `personal_claimed_at is not null AND reverted_at is null`, si no
`groups_only`. Da el mismo resultado que la fórmula de la decisión en los dos entornos de hoy (cero
filas con `reverted_at`), así que **no cambia ningún resultado medido**; cambia el futuro.

### D2 · «Escribible solo por RPC» hoy no se cumpliría solo con añadir la columna

Los grants de `profiles` son **a nivel TABLA** (`authenticated=arwDxtm/postgres`, ninguna columna con
ACL propia) ⇒ una columna nueva **hereda INSERT/SELECT/UPDATE**, y la policy `profiles_update`
(`auth.uid() = id`) deja al dueño escribirla. Sin nada más, cualquiera se auto-promueve con un
`PATCH /rest/v1/profiles`.

**Se cierra con un trigger `BEFORE UPDATE` + guard de transacción**, no regenerando grants: pasar el
UPDATE de `profiles` a por-columna dejaría toda columna futura sin grant y el síntoma es un push en
noop **silencioso** — el incidente de `created_at` en G2 que `g14_01` documenta.

Verificado en sandbox transaccional contra staging, con las tres pruebas juntas:

| Prueba | Resultado |
|---|---|
| El dueño hace `update profiles set kind='complete'` (control negativo) | **rechazado**, `yala_kind_readonly` |
| La misma escritura dentro de la RPC (control positivo) | pasa |
| `update` de OTRA columna (que no debe romperse) | pasa |

`set_config('yala.kind_write','on', true)` es **local a la transacción** y PostgREST no expone GUCs
arbitrarias al cliente, así que el guard no se puede abrir desde fuera.

### D3 · Coherencia impuesta por el motor, no por disciplina

Jürgen aceptó el riesgo de dos verdades y pidió que quien toque una ruta las mantenga coherentes.
Se impone donde no depende de que nadie se acuerde: `check (kind in ('complete','groups_only'))` y
`check (kind <> 'complete' or personal_claimed_at is not null)` — «completa» exige haber reclamado lo
personal alguna vez. La recíproca **no** se impone: `groups_only` con `personal_claimed_at` no nulo es
justamente la cuenta post-reverse de D1.

### D4 · La promoción no estrena endpoint: es el claim que ya promociona

`g3_02` existe para esto («claim promotes groups lite profile») y su rama TOCTOU-safe ya estampa
`personal_claimed_at` sobre una fila ligera. ⇒ **promover = `POST /account/claim` con `kind:"complete"`**,
idempotente por construcción. Se le añade la rama que g3_02 no cubre: la cuenta **post-reverse**
(`personal_claimed_at` no nulo, `kind='groups_only'`), que hoy caería en `existing_stable` sin promover.
Alcance mínimo: un endpoint nuevo para lo que ya hace uno existente sería una segunda ruta que mantener.

### D5 · Una sola degradación, donde dice la matriz

`kind='groups_only'` se escribe **solo** en `reverse_complete`. La fila E de la matriz
(`docs/sessions/2026-09-09-matriz-escenarios-sesiones.md:67`) lo marcaba como contradicción con el
cuerpo de este ticket: queda resuelta a favor de la matriz.

### D6 · El alta de grupos ya nace bien, gratis

`create_group:29` y `join_group:40` hacen `insert into profiles (id) values (v_uid) on conflict do
nothing` ⇒ la fila ligera **nace con el default `groups_only`** sin tocar esas dos funciones.

### D7 · El campo del wire tiene que ser opcional en el cliente, o rompe todo 200 de hoy

`ExistsResponse.exists` es `Bool` **no opcional** (`CloudAccountClient.swift:167`) y el decode es `try?`
(`:252`). Un `kind` no opcional convertiría **cualquier** respuesta sin ese campo en `.transient` —un
fallo mudo, no visible—. Va como `String?` y se traduce en `:255`.

### D8 · Dónde vive el `kind` cacheado: con el entitlement, no con el provider

El provider se persiste en dos sitios con ciclos de vida distintos (Keychain `cloudauth.provider`, que
muere en `signOut`; iCloud-KV `yala.cloud.accountProvider`, que sobrevive). El `kind` es **un hecho de
la cuenta sellado por `userID`**, y de eso ya hay molde exacto: `AccountEntitlementStore` (UserDefaults
`cloudSync.accountEntitlement`, snapshot con `userID` como sello anti-fuga, `clear()` en
`handleSignOut`). Se copia ese molde. Un `kind` en iCloud-KV viajaría a otro dispositivo del mismo
Apple ID y podría describir **otra** cuenta.

### D9 · «Ausente ⇒ groups_only» con corrección, tal como pidió Jürgen

El default no basta: la decisión exige que la sesión se corrija sola cuando una llamada posterior sí
traiga `kind`. La corrección vive en el mismo servicio que refresca, no en cada pantalla.

## Plan

1. **Migración `g15_01`** (`qa/cloud/g15_01_account_kind.sql`): columna + 2 checks + backfill D1 +
   trigger-guard D2 + `claim_account` con `p_kind` (D4) + `reverse_complete` con la degradación (D5).
   Auto-verificada con guardas de md5 del cuerpo de partida, como `g14_01`.
2. **Staging primero**: aplicar, correr `account.goldens` + `groups.goldens`, y **crear la cuenta
   `groups_only` que hoy no existe** (los 5 perfiles de staging son `complete`: el AC nº1 no es
   satisfacible con el corpus actual).
3. **Gateway**: `exists` amplía `select=` y emite `kind`; `claim` acepta y valida `kind`; tests unit
   offline (hoy no hay ninguno de estas tres rutas) + goldens.
4. **Cliente**: decode opcional, `ExistsRoute.accountFound(kind:)`, store del `kind` cacheado,
   `dataLocation`/`RestoreRouter` leyéndolo, y la corrección al refrescar.
5. **Producción**: conteos → wipe (orden de FKs: las tablas de grupos no cascadean, tres FKs son
   `SET NULL`) → `g15_01` → conteos.

---

## Resultado (2026-09-10)

**Aplicado en staging y en producción, en ese orden.** Paridad byte a byte verificada: los tres md5
—`claim_account`, `migration_progress`, `tg_profiles_kind_guard`— son idénticos en los dos entornos.
Registro completo en `qa/cloud/README.md` § g15_01.

### Criterios de aceptación

- [x] **`GET /account/exists` devuelve `kind`** en los tres casos, verificado contra staging real
      (goldens 28-32): `complete`, `groups_only`, y `exists:false` **sin** `kind`.
- [x] **El claim born-cloud crea `complete`; el alta de grupos crea `groups_only`** — y en ese caso el
      RPC ya no estampa `personal_claimed_at`, que era la incoherencia que el ticket habría fabricado
      el primer día.
- [x] **Promover funciona una vez y es idempotente** (golden 28: `created` la primera, `existing_stable`
      la segunda). **Degradar solo ocurre en `reverse_complete`** — y se vio ocurrir de verdad: el
      usuario B de los goldens de la reversa quedó `groups_only` en staging por esa vía.
- [x] **Todas las cuentas de producción tienen `kind`.** Son cero: el fresh start las borró antes.
      Conteos abajo.
- [x] **Tests del gateway para las tres rutas** (13 unit offline nuevos — antes no había NINGUNO— y 5
      goldens) y **`CloudAccountClientTests` para el decode con y sin `kind`** (5 casos nuevos).

### Fresh start de producción — conteos medidos

| | Antes | Después |
|---|---|---|
| `public.*` (33 tablas) | **1 155 filas** | **0** |
| `auth.users` · `identities` · `sessions` · `refresh_tokens` | 2 · 3 · 1 · 38 | **0 · 0 · 0 · 0** |

Desglose de lo que se borró, tabla a tabla: `exchange_rates` 954 · `cashflow_lines` 85 · `tx_items` 31
· `split_shares` 22 · `categories` 13 · `accounts` 11 · `split_expenses` 9 · `budgets` 4 ·
`split_settlements` 4 · `group_members` 4 · `push_tokens` 3 · `group_invites` 2 · `split_groups` 2 ·
`group_seq_counters` 2 · `groups_consents` 2 · `profiles` 2 · `cashflow_plans` 1 · `sync_seq_counters` 1.

**No se amplió el alcance:** `auth.audit_log_entries` y `auth.flow_state` no entraban en la decisión y
se midieron por si guardaban PII residual — las dos estaban **en cero**, así que no queda nada que
nombrar.

### Lo que se decidió sobre la marcha, y por qué (detalle en «Paso 0»)

1. **El backfill de la decisión se quedaba corto.** `reverse_complete` no toca `personal_claimed_at`, así
   que una cuenta que volvió a iCloud lo conserva. Se le añadió `and reverted_at is null`. Mismo
   resultado en los dos entornos de hoy; distinto en el futuro.
2. **`kind` no es la segunda verdad que Jürgen asumió: hay un estado que la señal vieja no sabe
   expresar.** Se vio en vivo — el usuario B acabó `groups_only` con `personal_claimed_at` puesto.
3. **El backfill corre solo en la aplicación que crea la columna.** Sin ese guard, una re-aplicación
   habría re-promocionado a `complete` a toda cuenta degradada a la que un `reverse_claim` posterior le
   reseteó `reverted_at`, deshaciendo la degradación en silencio.
4. **El cliente NO cambia `dataLocation` ni `RestoreRouter`.** El propio ticket los pedía en el §3 del
   alcance y su «Fuera de alcance» los excluye; el encargo resuelve a favor de lo segundo. Además,
   `RestoreRouter` escribe `OnboardingMode.groupInvite`, que es **never-downgrade cross-device**: un
   fail-safe equivocado ahí sería irreversible. Van al ticket 3, con el aviso escrito.

### Lo que queda para Jürgen

- **Device-QA**: su iPhone tenía sesión con una cuenta que ya no existe. Mientras el JWT siga vivo, las
  llamadas dan **409/502** (no una sesión que falla en silencio): `claim_account` viola
  `profiles_id_fkey`. Hay que **cerrar sesión y volver a entrar**, y **recrear los grupos de prueba**
  antes del device-QA de los pasos 5, 8, 9 y 10.
- **Desplegar el Worker** a staging y a producción para que el `kind` viaje: la base ya está en los dos.
  El orden es innegociable y va en ese sentido — **la base antes que su Worker**; al revés, el Worker
  pide una columna que no existe y devuelve 502 en cada sign-in.

### Ticket que abre

`reverse-cutover-cerrado-para-cuentas-born-cloud` (**high**): la degradación ya funciona, pero la puerta
que lleva a ella está cerrada para toda cuenta nacida en la nube —`reverse_claim` exige `migrated_at`—
y tras el fresh start eso es el 100 % de producción. La fila E de la matriz promete algo que hoy nadie
puede recorrer. Necesita decisión.

---

## Worker desplegado (2026-09-10, con el OK de Jürgen en la sesión del paso 3)

Lo que este ticket dejaba pendiente —«desplegar el Worker a staging y a producción para que el `kind`
viaje»— está hecho, y **en el orden que importa**: la base primero (ya estaba), el Worker después.

| Entorno | Versión desplegada | Antes | Delta de `gateway/` |
|---|---|---|---|
| **producción** `yala-gateway-production` | `034e1074-929c-495b-b91b-579a0b4b0875` | `e5f553f2` (2026-09-10T06:12Z) | **1 commit**: `675aadec`, el del `kind` |
| **staging** `yala-gateway-staging` | `53e181d4-58ec-42b5-8197-a83bab78b15a` | `645b6820` (**2026-08-12**) | **12 commits**, casi un mes sin desplegar |

**La base se verificó en los DOS entornos antes de desplegar, no se heredó de este ticket**: columna
`kind` con `default 'groups_only'::text`, trigger `profiles_kind_guard`, check `profiles_kind_check`, y
`claim_account` con `p_kind` y **una sola sobrecarga** — dos vivas darían `PGRST203` y tumbarían el claim
entero. Producción, además, con 0 perfiles (el fresh start de este ticket).

**El mapa de acceso de hoy** (se mide cada sesión porque cambia): `list_projects` del MCP lista **solo
staging**, pero `execute_sql` contra producción **funciona pasando su `project_id`** aunque no aparezca
listado. Es la mitad inversa de lo que decía el runbook el 2026-09-08.

**Smoke, los dos entornos:** `/healthz` 200 y `/account/exists` sin JWT → 401 `yala_attest_required`
(«Falta el JWT de usuario»), que es lo correcto: esa ruta es `requireUser`. Y el path es `/account/exists`,
sin el prefijo `/v1` que sí llevan otras.

**Y un efecto colateral verificado:** el deploy de producción **no apagó** la elección nube del Welcome —
`CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT` salió a `100` en el volcado del deploy. Es exactamente lo que
protegía el paso 1 (`wrangler-prod-onboarding-choice-percent-drift`), y esta es su primera prueba real.

### Batería del gateway contra staging tras el deploy

`npm test` con las credenciales de staging cargadas (`~/Secrets/yala-supabase-test/test-users.env`, más
`GROUPS_ENC_KEY` y `PUSH_ROLE_JWT` de `~/Secrets/yala-groups-enc/staging*`): **`account.kind.test.ts`
13/13** y `sync.goldens` 13/13 contra red real. El **único** rojo es el golden 20 del freeze, que es
**preexistente y tiene ticket abierto** desde el 2026-09-03
(`account-goldens-freeze-read-test-times-out`, timeout de 5 s, antigüedad desconocida). No lo introdujo
este deploy.

⚠️ **Sin las credenciales en el entorno, tres ficheros de goldens fallan al CARGAR** y eso se lee como
«el código está roto» cuando es «falta un export». Los nombres exactos y de dónde salen, arriba.

## QA · 2026-09-16 — cerrado como absorbido (override de Jürgen)

No queda nada propio que mirar:

- **Servidor:** los cinco criterios están marcados y se verificaron contra staging real con los goldens
  28-32; el Worker está desplegado en staging y en producción (secciones de 2026-09-10 de arriba).
- **App:** lo que un usuario vería —que el sign-in rutee según la cuenta sea nueva, completa o solo
  grupos— se pasó a propósito a `cloud-sign-in-discovers-account-kind`, que sigue en qa con sus recorridos
  de device.
- **La degradación** no se puede recorrer en device porque `reverse_claim` exige `migrated_at`; eso ya
  es `reverse-cutover-cerrado-para-cuentas-born-cloud`, también en qa.
