---
name: verificar-backend-yala
description: Qué acceso real tengo al backend de Yala y cómo verificar una migración contra el motor real sin tocar nada. OJO — el mapa de acceso CAMBIÓ el 2026-09-10 y se invirtió: mídelo, no lo heredes.
metadata:
  type: reference
---

## El mapa de acceso CAMBIA. Mídelo al empezar, en dos llamadas.

**El 2026-09-10 estaba invertido respecto a lo que decía esta misma ficha**, escrita el 4-sep y
corregida el 7. Un `list_projects` y un `select current_user` por proyecto cuestan segundos y
zanjan qué se puede hacer en esta sesión:

| | Lo que decía esta ficha (4-sep → 9-sep) | Medido el 2026-09-10 |
|---|---|---|
| **Staging** `fostjbbwstyuunmmefuk` | **no listado, sin DDL** — «lo único que falta es la contraseña que solo tiene Jürgen» | **listado**; `execute_sql` entra como **`postgres`** ⇒ **DDL y DML completos** |
| **Producción** `kefvaiymtgytemwbltlz` | listado, lectura y DDL | **no listado**; `execute_sql` entra como `supabase_read_only_user` (`transaction_read_only=on`) ⇒ **solo lectura** |

**Re-medido el 2026-09-10 (2.ª sesión del día), y hay un matiz nuevo: producción NO está listada pero SÍ
se lee.** `list_projects` devuelve solo staging, y aun así `execute_sql` contra el ref de producción
**funciona** en lectura (entra como `supabase_read_only_user`). ⇒ «no listado» ≠ «inalcanzable»: prueba el
ref igual. Ese día apliqué DDL a los dos entornos con `apply_migration` y verifiqué la paridad de md5
después, en las dos direcciones.

**Y las dos herramientas del MCP no comparten rol.** En producción `execute_sql` es de solo lectura
pero **`apply_migration` escribe** — DDL y DML. Verificado con control positivo: crear schema, tabla
y fila, leerlas con `execute_sql`, y borrarlas. ⇒ **«no tengo acceso» exige probar las DOS**, no una.

**Dos trampas de `apply_migration` medidas ese día:**

- **Un `success: true` no prueba escritura**: un cuerpo que no escribe (`do $$ raise notice $$`)
  pasa igual. Lo que lo prueba es leer después lo que la migración dejó.
- **La fila del historial se inserta DESPUÉS del cuerpo**, así que una migración que borra
  `supabase_migrations.schema_migrations` no se borra a sí misma. Limpiar rastro de pruebas exige
  una migración posterior.

⇒ Si un ticket dice «verificar en staging antes de producción», **hoy sí se puede**. Y el orden
natural vuelve a ser el sano: staging primero.

**CORREGIDO el 2026-09-07: los goldens del gateway contra staging SÍ se pueden correr.** Esta ficha decía
«sólo JWT de usuario» y por eso ni lo intenté durante tres sesiones. `test-users.env` trae las CONTRASEÑAS
(`USER_A_PASS`, `USER_B_PASS`) y la llave de cifrado está en `~/Secrets/yala-groups-enc/staging.key`; con
las dos exportadas, `npx vitest run test/groups.goldens.test.ts` da **25/25 contra staging real** en ~5
min. Sin `GROUPS_ENC_KEY` el fichero entero falla en su `beforeAll` con los 25 casos en `skipped`, que
**parece** «no hay credenciales» y es solo una variable de entorno. Para la suite ENTERA hace falta una
tercera, o `push.fanout.test.ts` sale rojo por entorno y no por código:

    set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
    export GROUPS_ENC_KEY="$(cat ~/Secrets/yala-groups-enc/staging.key)"
    export PUSH_ROLE_JWT="$(cat ~/Secrets/yala-groups-enc/staging-push-role.jwt)"

**Y `npx vitest` NO dispara `pretest`, así que NO sincroniza el manifest** (la copia del gateway está
gitignoreada). Corre `npm run sync:manifest` antes o medirás con el contrato de columnas viejo: eso dejó
dos goldens en rojo un día entero el 2026-09-07. Desde el 8-sep lo canta `test/manifest.sync.test.ts`.

**El número 25/25 es cierto pero FRÁGIL, y conviene saberlo antes de creerte un rojo:** un pull cuesta 5
peticiones por cada grupo del usuario —haya cambios o no— y el corpus de A/B sólo crece (530 y 678 el
8-sep, +20/+15 por corrida). El golden más ajustado consume el **55 %** de su timeout. Un rojo por
TIMEOUT sin línea de aserción probablemente no es código roto: es un test que va justo de tiempo. Ver
`corpus-de-test-de-staging-crece-sin-limite`.

**Lo de arriba describía el mundo del 4 al 9 de septiembre. El 10-sep ya no era verdad** — ver la
cabecera de esta ficha. Se conserva porque la receta de goldens y sus trampas siguen valiendo.

**2026-09-16: staging no contestó por el conector.** `list_projects` lo daba `ACTIVE_HEALTHY`, pero `execute_sql` devolvió «Connection terminated due to connection timeout» tres veces, también con `select 1`. No es falta de permisos: es el conector. Si pasa, anótalo como «no medido» y no lo reintentes en bucle.

**2026-09-24: otra vez, y toda la sesión** (execute_sql ×4 y apply_migration ×1). La REST de staging sí contestaba
(login de A/B/C 200), así que los goldens por el wire sí corren. Producción, en cambio, entró sin problema: lectura
por `execute_sql` y escritura por `apply_migration`, que además sirve de **sandbox** acabando el cuerpo en
`raise exception '<MARCADOR>%', resultados` — el mensaje vuelve en el error y la transacción entera se deshace
(verificado: md5, usuarios sintéticos, tablas e historial sin rastro). Producción tenía **0 cuentas** ese día.

**Un conteo por `execute_sql` en producción NO cuenta filas: RLS se las esconde.** Entra como `supabase_read_only_user`,
que no es dueño de ninguna fila de `profiles`, así que «0» es lo que devuelve con o sin cuentas (lo cantó una lente el
2026-09-24, 4.ª sesión). Se cuenta como `postgres` con `apply_migration` y `raise exception 'MEDIDA %', (select count…)`:
ese día sí dio 0 de verdad. En staging `execute_sql` entra como `postgres` y el conteo vale.

**2026-09-24, 3.ª sesión: staging SÍ contestó** (`execute_sql` como `postgres`, `apply_migration` escribe). El «no contesta»
de la mañana era del conector, no permanente: vuelve a probar antes de heredarlo.

## La vía que sí verifica: sandbox transaccional contra producción

Postgres tiene **DDL transaccional**, así que `create or replace function` dentro de `begin … rollback`
se revierte entero. Eso permite ejercitar una migración **contra el esquema y el motor reales** sin
dejar rastro — más fiel que staging, no menos.

Receta, con lo que costó afinarla:

1. **Comprueba primero que el rollback revierte de verdad** (que el cliente no esté en autocommit por
   statement): `begin; create table _probe(...); rollback;` y luego `to_regclass('_probe') is not null`
   → tiene que dar `false`. Sin este paso no arriesgues un `create or replace` sobre una función viva.
2. Dentro de la transacción: usuario sintético en `auth.users` (`profiles.id` es FK a esa tabla), las
   filas de dominio que haga falta, y `set local request.jwt.claims = '{"sub":"<uuid>"}'` — de ahí lee
   `auth.uid()`, sin necesidad de cambiar de rol.
3. Aplica la función nueva, ejercita los escenarios acumulando en una tabla temporal, haz un `select`
   final y `rollback`.
4. **Confirma que no quedó rastro**: el `md5(prosrc)` de la función vuelve al de antes y las filas
   sintéticas son cero.

**El control negativo es la mitad que da la prueba**, y es gratis: corre los mismos escenarios **sin**
el `create or replace`, o sea contra la función viva. Eso mide el bug en producción en vez de
inferirlo. En `rejoin-tap-renotifies-admins` fue lo que convirtió «el Worker no puede distinguir los
dos casos» en un hecho: el retorno del re-tap era **idéntico byte a byte** al del alta nueva.

## Lo que esto NO alcanza, y no hay que fingir que sí

El push que llega a un teléfono. `.claude/rules/gateway-attest.md` es explícito: un build de Xcode no
puede validar contra producción (el AAGUID de desarrollo da 401 por diseño), así que **quien escribe
el fix no puede ejercitarlo end-to-end**. Eso se documenta como pendiente del owner, no se declara
verificado.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] — su caso 9 es justo el error que esto evita
(«no consta en el repo» leído como «no está hecho»); aquí la regla se aplica en positivo.
