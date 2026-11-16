---
name: yala-web-espera-decisiones
description: Yala web: en PRODUCCIÓN (app.yala-app.pe) desde el 16-nov, entera y con Grupos; sin enlace público; la app publicada aún no recoge lo apuntado en la web (2.3 del iPhone).
metadata:
  type: project
---

Plan y decisiones en el artifact https://claude.ai/artifact/JN7jw8J1UXBQGNNpLNErAe y en `docs/web-app/index.html`. La
colección `decisiones` de su db seguía VACÍA el 14-nov (medido con `ArtifactData list`): vale la recomendada en las 13.
El 14-nov Jürgen cambió D10: los lotes 2 y 3 se hacen ya en 2.3 (`docs/DECISIONS.md`, lote del 14-nov).

Estado al 14-nov: lote 0 (entrar y sesión) y lote 1 (Panel, Registros, Bandeja, Apuntar, sesiones y «Navegadores
conectados» en el iPhone) desplegados en staging; producción, nada. El device-QA de la beta en el iPhone 14 espera la
mano de Jürgen: entrar con Apple en Yala Dev y en la web (Face ID). Guion en `tickets/done/yala-web-lote-1-beta.md`.

Lote 2 (14-nov): Estadísticas, Pagos planificados y entrar con el iPhone por QR, en staging. Del lote 2 del plan
quedaron fuera, por no pedirlos el encargo, Presupuestos, Grupos en lectura, ⌘K, CSV y los 16 idiomas: van en el
siguiente encargo. Device-QA del QR (cámara y Face ID reales) en `tickets/done/yala-web-lote-2.md`.

Lote 3 (14-nov): Grupos en lectura y, tras la respuesta de Jürgen (14-nov 13:52: **opción A**), también escritura desde
la web: nuevo gasto con reparto igual, saldar e invitar, con el rol propio `yala_web` (web3_02) y la entrada interna
`WebGroupsWriter` del gateway. Todo solo en staging: **producción de la escritura la quiere tras una revisión**, no la
subas sin que la pida. Datos de prueba en staging: «Viaje a Cusco» (A, B y C) y «Depa Miraflores» (A y B; la e2e de
escritura escribe ahí y lo borra al acabar con el token de la app de A).

Lo que se intentó y no funcionó (14-nov): dar al rol `yala_web` INSERT + RLS y EXECUTE de `apply_group_delta`. Sin USAGE
en el esquema `auth` (que `postgres` no puede conceder) la función INVOKER falla; se cambió a funciones DEFINER
por operación (`web_add_group_expense`/`_settlement`). Detalle en `docs/aprendizajes-tecnicos.md`.

**16-nov: en producción**, probada de punta a punta con test@yala-app.pe (Google y Apple, Face ID de Jürgen). Jürgen
la prueba con su cuenta personal; no se enlaza desde la web pública hasta que él lo diga. Lo que falta es de la 2.3 del
iPhone (`ConnectedBrowsersConfig.baseURL` fuera de DEV_BUILD). El 15-nov el informe daba por hecho que bastaba
`wrangler.toml` para encender Grupos en el gateway: el código lo apagaba en producción. Mide el código, no el plan.

**Why:** la web reusa el núcleo de `shared-core` y la cola de borradores del gateway; cada lote lo aprueba él.

**How to apply:** al abrir el lote 2, lee la db del artifact por si contestó algo y parte del README de `webapp/`. Lo
que el lote 1 dejó fuera (origen «Yala web» propio en la Bandeja, cerrar sesión en el iPhone no cierra la web, la
política de privacidad) está en el README. Relacionado: [[secretos-de-staging-en-la-mini]],
[[propuestas-como-artifact-visual]].
