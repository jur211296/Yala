---
name: retirar-al-llegar-no-al-pedir
description: «Sin borrar» retiraba el borrado al ARRANCAR la migración y media docena de salidas volvían a iCloud con él perdido; lo que solo es verdad al llegar se retira al llegar
metadata:
  type: feedback
---

**Una renuncia que solo es verdad cuando el estado cambia de verdad se apunta al pedirla y se CUMPLE al llegar.**

**Why:** el 2026-10-04 (`late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`) puse «Activar la nube
sin borrar» y retiré el borrado pendiente justo antes de `startMigration`. Mi propio docblock decía «echarse atrás en la
elección de cuenta no le cuesta el borrado» — y la hoja de Apple/Google se abre DENTRO de `startMigration`. Las tres
lentes de la review lo cazaron por separado: hoja cancelada, puerta de identidad, claim rechazado, «Cancelar», techo,
todas volvían a iCloud con el borrado perdido en silencio, que era el bug del ticket.

**How to apply:** antes de elegir el punto de commit de una decisión del usuario, enumera las salidas del flujo entre
ese punto y el estado final (`grep` de `return`/`signInFailed`/`failedRollback`). Si alguna vuelve atrás, la decisión
va como marca durable que lee quien CONFIRMA el estado final (aquí, el arranque en `.cloud`) y caduca si el intento
termina en el origen. Y el estado intermedio necesita su propia regla (aquí, congelar el borrado con la migración en
vuelo). Hermana de [[el-techo-arranca-cuando-se-concede]] y [[mi-docblock-tambien-es-una-premisa]].
