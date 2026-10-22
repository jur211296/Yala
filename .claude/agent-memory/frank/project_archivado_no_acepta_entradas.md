---
name: archivado-no-acepta-entradas
description: El grupo archivado ya rechaza miembros nuevos (g13_05, prod). Qué queda abierto — device-QA, el drift de staging que ya son DOS migraciones, y una decisión de producto sobre qué significa «archivado».
metadata:
  type: project
---

**Cerrado en código el 2026-09-06 y aplicado en producción.** Un grupo archivado ya no acepta
miembros nuevos, y quien tapea ese enlace ve por fin el copy `groups.reconnect.archived.*` — que
llevaba meses traducido a 16 idiomas **sin un solo consumidor**.

## Lo que queda abierto, y de quién es

1. **Device-QA de dos teléfonos.** Ticket en `qa/`, y ya con su fila en el Grupo A de
   `qa/guion-tanda.md` (A archiva → B tapea y ve el aviso; A desarchiva → B entra). No es mío: pide
   TestFlight y App Attest en `enforce`.
2. **Staging arrastra ya DOS migraciones** — g13_04 (del 4-sep) y g13_05. Mismo bloqueo las dos: **no
   hay credencial de DDL de staging**, re-medido el 6-sep (el conector MCP solo lista producción,
   `~/Secrets/yala-supabase-test/` solo tiene JWTs de usuario). Se cierran aplicando los dos `.sql` en
   orden. Es acceso de Jürgen; no es una tarea pendiente que se pueda destrabar sola.
3. **Una decisión de producto**: `groups-archived-still-accepts-changes` — ver
   [[decisiones-que-esperan-a-jurgen]].

## Lo que conviene recordar del cómo, porque se repite

- **La premisa del encargo era CIERTA, por primera vez en tres sesiones** — y aun así se midió antes
  de creérsela, ejecutando el RPC contra la función viva de producción en sandbox transaccional. El
  control negativo dio el bug con nombre y apellidos (miembro dentro + uso del invite consumido), no
  una lectura del `prosrc`. Medir cuando la premisa acaba siendo verdad **no es tiempo perdido**: es
  lo que convirtió «el ticket dice que pasa» en «pasa, y así exactamente».
- **El gate no iba donde parecía.** Por `join_group` pasan cuatro caminos y solo dos son entrada
  nueva; ponerlo arriba habría roto el AC de «los de dentro no se ven afectados» en dos sitios (el
  rebind legacy y el no-op del re-tap). Ante un RPC con varias ramas de retorno, **enumera las ramas
  antes de elegir la línea**.
- **Comprueba el md5 del `prosrc` contra el fichero del repo después de aplicar.** La primera versión
  de mi `.sql` difería de lo aplicado en UN comentario — 18 caracteres— y así es exactamente como
  nació el drift que esta misma migración venía a cerrar. Ahora coinciden byte a byte.

Relacionado: [[el-orden-del-enum-se-ve-fuera]] · [[verificar-backend-yala]] ·
[[la-premisa-del-encargo-tambien-se-mide]]
