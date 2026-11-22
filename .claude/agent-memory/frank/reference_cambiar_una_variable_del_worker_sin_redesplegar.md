---
name: cambiar-una-variable-del-worker-sin-redesplegar
description: Subir un porcentaje o un kill-switch del gateway sobre la versión que ya corre, sin wrangler deploy: PATCH de settings con los demás bindings en «inherit» (medido el 22-nov en staging y producción)
metadata:
  type: reference
---

Cuando producción corre código que no está en ningún commit (el 22-nov: `86849564`, parche de una sesión pausada),
`deploy:production` desde una rama le cambia el código. Para mover solo una variable de texto:

- `PATCH /accounts/86c270…/workers/scripts/<worker>/settings`, multipart con una parte `settings` (JSON):
  `{"bindings":[{"type":"plain_text","name":VAR,"text":valor}, {"type":"inherit","name":<cada otro binding>}…],
  "annotations":{"workers/message":"…"}}`. Crea versión y despliegue nuevos con el MISMO script.
- **La respuesta del PATCH trae solo el binding cambiado** («bindings 34 → 1»): no es que haya borrado el resto. Relee
  con `GET …/settings` (salieron los 34, secretos incluidos).
- Comprobar que el código no cambió: `GET …/versions/<id>` → `resources.script.etag` igual en la versión vieja y la nueva.
- Con el token OAuth de wrangler de la Mini ([[secretos-de-staging-en-la-mini]]); los scripts usados están en el
  scratchpad de esa sesión, no en el repo. Cloudflare rechaza el `User-Agent` de Python (error 1010): pon uno propio.
- El fichero `wrangler.toml` se alinea con lo desplegado en el mismo PR, o un `deploy:production` posterior lo deshace.

Relacionado: [[reference-desplegar-el-gateway-desde-la-mini]].
