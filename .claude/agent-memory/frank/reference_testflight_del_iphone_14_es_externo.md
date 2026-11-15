---
name: testflight-del-iphone-14-es-externo
description: La cuenta de TestFlight del iPhone 14 es la de test; desde el 15-nov está en el grupo interno y ve cada build sin revisión de Apple
metadata:
  type: reference
---

Medido el 2026-11-15 con la 2.3 (1). La app TestFlight del iPhone 14 usa la cuenta **test** del dominio. El «Correo electrónico admin@…» que sale en la ficha de la app dentro de TestFlight es el **correo de contacto de la app, no la cuenta del tester**. Me confundió una vez y me llevó a buscar en el grupo equivocado.

- Hasta el 15-nov esa cuenta estaba solo en el grupo **externo** «Testers Yala», que necesita la revisión beta de Apple para cada build: el teléfono no veía la 2.3 recién procesada.
- El 15-nov Dan la sumó al grupo **interno** «Test interno», que tiene acceso a todos los builds. Desde entonces un build procesado aparece en el iPhone 14 en el acto.
- No se puede sumar por la API una cuenta que no sea usuario del equipo de App Store Connect: devuelve «Tester(s) cannot be assigned (not in group …)». Jürgen pidió no invitar usuarios por API: eso lo hace Dan.
- `asc builds add-groups` contra el grupo interno da 422 («Cannot add internal group to a build»): ya lo recibe solo. `asc builds groups list` lo confirma.

**How to apply:** si un build nuevo no aparece en TestFlight del iPhone 14, mira primero si la cuenta test sigue en «Test interno» (`asc testflight groups testers list`, sin imprimir correos). Para la prueba de humo, usa la cuenta Google test, no la personal de Jürgen: el build de TestFlight escribe en producción. Relacionado: [[feedback_upload_ok_no_es_build_aceptado]].
