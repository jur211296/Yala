---
updated: 2026-09-08
tags: [runbook, staging, ddl, owner]
---

# Runbook — las tres migraciones de staging

> ## ✅ APLICADAS Y VERIFICADAS EL 2026-09-08
>
> Las tres están dentro. **Este documento queda como registro de cómo se hizo y de qué comprobar si
> hay que repetirlo**, no como trabajo pendiente. Lo que se midió al aplicarlas:
>
> | | Antes | Después |
> |---|---|---|
> | `join_group` — claves `changed` | 0 | 3 `true` + 1 `false` |
> | `join_group` — `yala_group_archived` | 0 | 2 |
> | `join_group` — md5 / chars | `9653d591…` / 4510 | **`4982b50de23df93ed8f9c8bc369e9e17`** / **5365** |
> | `split_groups.budget_limit_amount` | no existía | **`bytea`** |
> | `apply_group_delta` (functiondef) | — | **`61c38595cdd8b7b0ab043437f49a7f2c`** |
> | `groups_pull_rows_split_groups` | — | **`2cac864c6b67ab6da941601e8e53cf2c`** |
>
> Los tres md5 son los que el repo declaraba como esperados ⇒ **staging quedó byte a byte igual que
> producción**. El punto de partida cuadraba con el `c_before` de la guarda de `g14_01`
> (`d2e748320da4f2eca82b19a0048e84ab`), así que ninguna abortó.
>
> **Una desviación del fichero, y por qué:** a `g14_01` se le quitaron su `begin;`/`commit;` propios
> porque el applier (`apply_migration`) ya envuelve en transacción y anidarlos habría cerrado la
> externa antes de tiempo. La atomicidad la puso el applier, igual que en las otras dos, y las
> guardas de md5 fueron dentro intactas.
>
> **Lo que NO se verificó como se esperaba:** los goldens completos dieron 15/25, y **no por las
> migraciones** — son timeouts, y los mismos tests pasan en 1,3 s al correrlos solos. Ver
> `tickets/backlog/goldens-de-staging-solo-pasan-a-trozos.md`.

## Cómo se hizo (registro)

**Para quién:** era para Jürgen. **Ya no.** ⚠️ **La premisa central de este runbook CADUCÓ el
2026-09-10**, y conviene saberlo antes de reusar cualquier frase de aquí:

> Este documento decía «no hay credencial de DDL de staging en el entorno del agente — el conector MCP
> de Supabase solo lista producción (`kefvaiymtgytemwbltlz`), no staging (`fostjbbwstyuunmmefuk`)».
> **Medido el 2026-09-10, era al revés en las dos mitades**: el MCP lista **staging**, y su
> `execute_sql` entra como `postgres` (DDL y DML completos). Producción ya **no** aparece listada y su
> `execute_sql` responde como `supabase_read_only_user`… pero **`apply_migration` sí escribe** allí, DDL
> incluido (verificado con control positivo: crear schema + tabla + fila, leerlos y borrarlos).

⇒ **El mapa de acceso cambia sin avisar: mídelo al empezar la sesión, no lo heredes de un documento.**
Cuestan dos llamadas — `list_projects` y un `select current_user` por proyecto— y esta premisa llevaba
cuatro días propagándose entre tickets como si fuera un hecho. Lo demás de este runbook —orden,
idempotencia, verificación, trampas— sigue medido y vigente.

**Cuánto lleva:** 10-15 minutos las tres, si las pegas seguidas.

**Qué pasa si no se hace:** producción está al día y verificada, así que la app no se rompe. Lo que
se rompe es *staging*: con `g14_01` sin aplicar, fijar un presupuesto de grupo contra staging deja
un **dead-letter permanente**, y un dead-letter **apaga el Merkle de ese grupo**. Hasta que alguien
fije un presupuesto ahí, no pasa nada — la bomba está armada, no detonada.

---

## Antes de empezar

**El orden importa y no es alfabético por casualidad.** `g13_05` es superset de `g13_04` (lleva sus
cuatro claves `changed` dentro), así que aplicarlas al revés deja el estado bueno igualmente — pero
entonces el bloque de verificación de `g13_04` mide un cuerpo que ya no es el suyo y te dará un
falso rojo. Aplícalas en este orden:

1. `qa/cloud/g13_04_join_group_reports_transition.sql`
2. `qa/cloud/g13_05_join_group_rejects_archived.sql`
3. `qa/cloud/g14_01_group_budget_limit.sql`

**Dos vías, elige una:**

- **(A) SQL Editor del dashboard de staging** — proyecto `fostjbbwstyuunmmefuk`. Pega el fichero
  entero. Es la vía canónica del repo y la que envuelve sola en transacción.
- **(B) `psql`** con la URI del pooler:
  ```bash
  psql -1 -f qa/cloud/<fichero>.sql "$SUPABASE_DB_URL"
  ```
  La URI se saca en *Dashboard → Project Settings → Database → Connection string → URI (session
  pooler, puerto 5432)*. La contraseña **no está en el repo ni en `~/Secrets/`**: es tuya.

> **El `-1` de `psql` no es opcional para las dos primeras.** Medido: `g13_04` y `g13_05` **no
> traen `begin;`/`commit;` propios** (0 ocurrencias de cada uno) — dependen de que quien las aplica
> las envuelva. `g14_01` **sí los trae** (`:99` y `:180`), así que ahí el `-1` es redundante pero
> inofensivo.

---

## 1 · `g13_04_join_group_reports_transition.sql`

**Qué arregla, en una frase:** volver a tocar un enlace de invitación al que ya perteneces deja de
avisar a los admins como si acabaras de entrar.

**Cómo:** añade el campo `changed` a las cuatro ramas de retorno de `public.join_group` — `false`
solo en la rama no-op. El gateway ya lo respeta (`gateway/src/groups/rpc.ts:262`:
`if (body.changed === false) return;`), así que **no hace falta desplegar el Worker para esto**.

**Idempotente:** sí. Es un `create or replace` con el cuerpo completo (`:44`); re-ejecutarla
converge al mismo estado. Sin rollback explícito porque no lo necesita.

**Verificar después:** el propio fichero trae el bloque en **`:150-176`** — cuatro comprobaciones
(3 ramas con `changed=true` + 1 con `false`; una aparición de `yala_group_deleted` y una de
`yala_invalid_invite`; grants intactos; y una llamada real contra la BD). Córrelo y mira que las
cuatro pasen.

> El comentario de `:171` remite a «la entrada g13_04 de este README» dentro de
> `qa/cloud/README.md`. **Esa entrada no existe** — medido: el README menciona `g13_04` una sola
> vez y no como sección. Este runbook es lo que había que leer ahí; queda ticket propio
> (`qa-cloud-readme-sin-entradas-g13-04-y-g13-05`).

---

## 2 · `g13_05_join_group_rejects_archived.sql`

**Qué arregla, en una frase:** un grupo archivado deja de aceptar a alguien que entra por un enlace
viejo.

**Cómo:** `join_group` lanza `yala_group_archived` (P0001) cuando el grupo tiene `is_archived=true`,
en dos puntos — la re-entrada desde estado terminal y el alta nueva. El rebind legacy y el re-tap de
un miembro activo siguen pasando, a propósito.

**Idempotente:** sí, mismo motivo (`create or replace` con cuerpo completo, `:65`).

**No hace falta desplegar el Worker:** el gateway propaga cualquier código `/^yala_[a-z_]+$/` como
400 sin allowlist, así que el error nuevo viaja solo.

**Verificar después:** bloque en **`:187`** en adelante — seis comprobaciones. La quinta es la que
vale la pena mirar dos veces: compara el **md5 del cuerpo** (`4982b50de23df93ed8f9c8bc369e9e17`,
5365 caracteres) para que staging quede **byte a byte** igual que producción. Si ese md5 no cuadra,
no sigas a la tercera: quiere decir que staging tenía drift previo.

---

## 3 · `g14_01_group_budget_limit.sql`

**Qué añade, en una frase:** la columna donde vive el tope de gasto de un grupo — la que hoy falta
en staging y arma la bomba del dead-letter.

**Cómo:** añade `split_groups.budget_limit_amount` como columna **cifrada** (`bytea`, patrón G7),
con grant de `update` por columna a `authenticated`; la mete en la lista de columnas cifradas de
`apply_group_delta` y la sirve descifrada en `groups_pull_rows_split_groups`.

**NO es idempotente, y eso es deliberado** (`:80-83`). No pasa nada: trae su propia transacción
(`begin;` en `:99`, `commit;` en `:180`) y **dos guardas de md5 que abortan** (`:110-111`):

- `c_before = d2e748320da4f2eca82b19a0048e84ab` — el cuerpo vivo que espera encontrar. Si no cuadra,
  aborta antes de tocar nada (`:119`).
- `c_after = ae78bce687ab00da0ae463e6525cc09c` — el resultado. Si no cuadra, aborta y revierte
  (`:135`).

⇒ **Es seguro intentarla**: o entra entera o no entra. Y si la ejecutas dos veces, la segunda aborta
diciendo el md5 de llegada — eso significa «ya estaba aplicada», no un error.

### Dos trampas que este fichero se sabe y tú no

- **El orden interno**: la función va **antes** que la columna (`:64-73`). Está así en el fichero;
  no lo reordenes. Al revés, un push de `budget_limit_amount` se guarda **en claro** dentro de una
  columna cifrada y el presupuesto desaparece para todo el grupo. En producción se aplicó al revés y
  salió bien por suerte; el fichero del repo ya está corregido.
- **Nunca re-apliques `qa/cloud/g7_02_encrypt_groups_cutover.sql` después de esta.** Sigue en el
  repo y recrea `apply_group_delta` con `array['name']`, lo que **reabre el agujero** que g14_01
  acaba de cerrar (lo avisa el propio `g14_01:72-73`).

**Verificar después:** las guardas ya lo hacen solas al aplicar. Si quieres el contraste externo:

```sql
select md5(pg_get_functiondef('public.apply_group_delta'::regproc));
-- esperado: 61c38595cdd8b7b0ab043437f49a7f2c
select md5(pg_get_functiondef('public.groups_pull_rows_split_groups'::regproc));
-- esperado: 2cac864c6b67ab6da941601e8e53cf2c
```

> Ojo: ese baremo es sobre `functiondef`, que **no** es el mismo texto que el `prosrc` de las
> guardas internas. Dos md5 distintos del mismo objeto, los dos correctos.

El `.ddl` de referencia del repo (`supabase-groups-staging.ddl`) **ya refleja el estado
post-`g14_01`**, así que no hay que regenerarlo: sirve tal cual como texto esperado.

---

## Verificación end-to-end de las tres (esto es lo que zanja)

Desde `gateway/`, contra staging real:

```bash
set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
export GROUPS_ENC_KEY=$(cat ~/Secrets/yala-groups-enc/staging.key)
npm run sync:manifest                         # ← NO lo hace `npx vitest`: sin esto mides con el manifest viejo
npx vitest run test/groups.goldens.test.ts    # esperado: 25/25, ~5 min
```

**Qué significa hoy y qué significará después.** Hoy pasa 25/25 *porque nadie fija un presupuesto
contra staging*: la suite mide que un manifest con una columna que el server no tiene no rompe nada
mientras nadie la use. Tras aplicar `g14_01`, sigue en 25/25 pero ya sin la bomba debajo.

**Antes de creerte un rojo, mira estas dos cosas** (las dos costaron un día el 2026-09-08):

1. **`npm run sync:manifest`.** La copia `gateway/group_capability_manifest.json` está en
   `.gitignore` y sólo se refresca en `pretest`; `npx vitest` no lo dispara. Con la copia vieja el
   gateway calcula el Merkle con el contrato de columnas anterior. Desde hoy lo canta
   `test/manifest.sync.test.ts`, que es offline y tarda 2 ms — córrelo primero si algo huele raro.
2. **Si el rojo es un TIMEOUT sin aserción, probablemente no está roto: va justo de tiempo.** Un
   pull cuesta 5 peticiones por cada grupo del usuario, y el corpus de `i5-user-a/b` sólo crece
   (530 y 678 grupos el 2026-09-08; +20 y +15 por corrida). Medido ese día: la corrida entera son
   ~32 800 peticiones y 311 s, y el golden más ajustado (`G2 · 2`) consume el **55 %** de su
   timeout — se cae si el tiempo se multiplica por 1,8, sea por latencia o por corpus. Detalle y
   decisión pendiente en `corpus-de-test-de-staging-crece-sin-limite`.

---

## Lo que NO es parte de esto: el Worker

**Estado, medido hoy:** `group_capability_manifest.json:3` ya dice `"canon_version": "c2"` en el
repo, pero el Worker no se ha desplegado. Mientras tanto los clientes caen en el guard de canon y
**saltan la verificación Merkle de Grupos** — a propósito y sin daño. Vuelve encendido cuando
despliegues y el parque converja.

**El bloqueo NO es de credencial, y hasta hoy la documentación decía lo contrario.**
`gateway/README.md` afirmaba «`wrangler deploy` no está autenticado en este entorno». Medido con
`wrangler whoami`: **sí lo está** — OAuth de `admin@yala-app.pe`, con `workers (write)` y
`workers_scripts (write)`. Corregido en ese README en este mismo cambio.

**Entonces por qué no lo despliego yo:** porque el último deploy de staging es del **2026-08-12** y
arrastra commits ajenos (`eb6593ce`, `6bf0f588`). Desplegar hoy subiría trabajo de otros que nadie
ha revisado. Eso es decisión tuya, no falta de acceso.

```bash
cd gateway && npm run deploy:staging      # el predeploy copia los manifests
cd gateway && npm run deploy:production
```

**Orden recomendado: SQL primero, Worker después** (lo dice `g13_04:29-31`). Ningún orden pierde un
aviso legítimo; solo ese hace que el arreglo entre en vigor de una vez.

---

## `mcp0_01_readonly_role.sql` — conector de Claude, fase 0 (solo staging, 2026-09-26)

**Aplicada en staging** con `apply_migration` el 2026-09-26. **Producción: no**, hasta la fase 1.

Crea el rol `yala_mcp_reader` (miembro de `authenticator`, SELECT sobre 9 tablas y nada más), una política SELECT
para ese rol en cada tabla y la función `yala_mcp_access_token_hook`. Es **aditiva**: no toca ninguna política,
función ni GRANT existente, así que no choca con las migraciones de la cola A. Marcha atrás:
`qa/cloud/mcp0_01_rollback.sql`, **después** de apagar el hook (si no, falla todo login).

Verificado en SQL como `yala_mcp_reader` con el `sub` de A: lee sus 69 filas de `accounts` y 1291 de `tx_items` (lápidas incluidas), y 0 de B;
`UPDATE`, `INSERT`, `delete_personal_account` y `apply_delta` dan `42501`; `claim_account` y
`migration_progress` (las dos que PUBLIC puede ejecutar) también. El hook cambia el rol solo si hay `client_id`.

**Y la configuración de Auth, que no es DDL**, también se aplicó el mismo día por la Management API, en este
orden: hook, Site URL y servidor OAuth con DCR. El antes y el después, y cómo se revierte, están en
`tickets/done/claude-mcp-activate-oauth-in-staging.md`. **El orden importa:** con OAuth encendido y el hook
apagado, Supabase emite a los clientes OAuth tokens que escriben. Para revertir, primero OAuth y luego el hook.

---

## Referencias

- Detalle por migración y su historia: `qa/cloud/README.md` (la entrada de `g14_01` está en
  `:1558-1594`; las de `g13_04` y `g13_05` **no existen** — ver el ticket citado arriba).
- Tabla de accesos por entorno: `.claude/agent-memory/frank/reference_verificar_backend_yala.md`.
- Los tickets que dejaron esto pendiente: `tickets/qa/rejoin-tap-renotifies-admins.md` (g13_04),
  `tickets/qa/groups-archived-group-rejects-join.md` (g13_05), `tickets/qa/groups-budget.md`
  (g14_01).
