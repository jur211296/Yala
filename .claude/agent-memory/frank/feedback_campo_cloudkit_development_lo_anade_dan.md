---
name: campo-cloudkit-development-lo-anade-dan
description: Sin token de cktool en la Max ni en la Mini; un campo nuevo de CloudKit en Development se pide al bot Frank para que se lo pase a Dan.
metadata:
  type: feedback
---

Un campo nuevo de CloudKit en el entorno Development (p. ej. `CD_systemRoleRaw` en `CD_Subcategory`, 2026-11-13) no lo
añade la sesión: Jürgen pidió «pídele al bot Frank que le pida al bot Dan que lo añada». Production sigue siendo suyo,
como paso del release.

**Why:** ni la Max ni la Mini tienen management token de `cktool` (medido el 2026-11-13: `cktool get-teams` sin token en
las dos, también por ssh), y Dan tiene acceso a la consola.

**How to apply:** `preguntar-bot` con el contenedor (los dos: `iCloud.com.jurgenschmidt.yala` y `.yala.dev`), el record
type, el nombre y el tipo del campo, y «solo Development». Mientras tanto se sigue con lo demás sin darlo por hecho; el
cierre espera a la confirmación. Ojo: `preguntar-bot --help` no muestra ayuda, ENVÍA «--help» como pregunta.
