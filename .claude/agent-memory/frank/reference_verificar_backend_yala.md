---
name: verificar-backend-yala
description: Qué acceso real tengo al backend de Yala (MCP ve SOLO producción, no staging) y cómo verificar una migración SQL contra el motor real sin tocar nada — sandbox transaccional.
metadata:
  type: reference
---

**El acceso no es simétrico, y eso decide qué puedo verificar y qué no.** Medido el 2026-09-04.

| Recurso | ¿Tengo? | Por dónde |
|---|---|---|
| **BD de producción** (`kefvaiymtgytemwbltlz`) | **sí**, lectura y DDL | MCP Supabase |
| **BD de staging** (`fostjbbwstyuunmmefuk`) | **NO** | el conector MCP no la lista |
| Worker staging y producción | **sí**, deploy | `wrangler`, OAuth `admin@yala-app.pe`, `workers:write` |
| Usuarios de test de staging | sí, **sólo JWT de usuario** | `~/Secrets/yala-supabase-test/test-users.env` |
| Llaves de cifrado y push | sí | `~/Secrets/yala-groups-enc/` (`staging.key`, `staging-push-role.jwt`, y sus gemelos `prod`) |

**La consecuencia incómoda: tengo DDL en producción y no en staging** — al revés de lo que pide el
orden habitual. No hay credencial de admin de staging en `~/Secrets/`, ni en el keychain, ni en el
entorno. Si un ticket dice «verificar en staging antes de producción», eso hoy **no se puede cumplir
por esa vía**, y hay que decirlo en vez de inventarlo.

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
