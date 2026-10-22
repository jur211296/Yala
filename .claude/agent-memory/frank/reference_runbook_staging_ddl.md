---
name: runbook-staging-ddl
description: Dónde vive el runbook de DDL de staging; su premisa «falta la credencial» CADUCÓ el 2026-09-10; y el dato que dos documentos negaban — wrangler SÍ está autenticado aquí
metadata:
  type: reference
---

**El procedimiento para aplicar DDL a staging está en `docs/RUNBOOK-staging-ddl.md`** (escrito el
2026-09-08). No lo reconstruyas ni lo dupliques: si algo cambia, se edita ahí.

**Why:** lo mismo estaba disperso en cinco sitios con conteos que ya no cuadraban entre sí — el
README de `qa/cloud`, `docs/ESTADO.md`, el ticket de `groups-budget` y dos tickets de `qa/` que
seguían diciendo «dos migraciones» cuando eran tres. Un conteo repetido en cinco documentos diverge;
uno solo, no.

**How to apply:**

- **⚠️ CADUCADO el 2026-09-10: ya NO falta la credencial de DDL de staging.** Esta ficha y el
  runbook decían que el MCP lista producción y no staging. Ese día era **al revés**: el MCP lista
  staging y `execute_sql` entra ahí como `postgres` (DDL completo), mientras producción solo se
  escribe por `apply_migration`. El mapa de acceso cambia sin avisar ⇒ **mídelo cada sesión**;
  está en [[verificar-backend-yala]]. Lo demás del runbook —orden, idempotencia, verificación,
  trampas— sigue medido y vigente.
- **`psql -1` no es opcional en `g13_04` y `g13_05`**: medido, no traen `begin;`/`commit;` propios
  (0 ocurrencias). `g14_01` sí los trae y además guardas de md5 que abortan la transacción entera,
  así que **intentarla es seguro**: o entra completa o no entra.
- Verificación end-to-end de las tres: `groups.goldens.test.ts` contra staging, 25/25 (~5 min).
  **Antes, `npm run sync:manifest`** — `npx vitest` no lo dispara y medirías con el manifest viejo.

## El dato que dos documentos negaban: `wrangler` SÍ está autenticado

`gateway/README.md` afirmaba «`wrangler deploy` no está autenticado en este entorno». **Medido el
2026-09-08 con `wrangler whoami`: es falso** — OAuth de `admin@yala-app.pe`, con `workers (write)` y
`workers_scripts (write)`. Mi ficha [[verificar-backend-yala]] tenía razón desde el 4-sep y el README
llevaba desde entonces diciendo lo contrario. Corregido en ese README.

**El deploy del Worker sigue siendo decisión de Jürgen, pero por otro motivo** — y la distinción
importa, porque «no tengo acceso» y «no me toca decidirlo» se arreglan distinto: el último deploy de
staging es del **2026-08-12** y arrastra commits ajenos (`eb6593ce`, `6bf0f588`), así que desplegar
hoy subiría trabajo de otros sin revisar.

⇒ **Cuando un documento diga que no tienes un acceso, compruébalo antes de heredarlo.** Un «no
puedo» heredado se convierte en trabajo que nadie hace: aquí llevaba cuatro días propagándose entre
tickets. Es la familia de [[la-premisa-del-encargo-tambien-se-mide]].

Relacionado: [[verificar-backend-yala]] · [[presupuesto-de-grupo]]
