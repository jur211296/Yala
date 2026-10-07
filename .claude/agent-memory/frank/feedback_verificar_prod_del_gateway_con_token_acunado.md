---
name: verificar-prod-del-gateway-con-token-acunado
description: Para verificar en producción un cambio del proxy de IA del gateway, Jürgen aprobó acuñar un token de sesión de 15 min (dispositivo ficticio) con la clave de firma de prod; en staging prefiere probar él con Yala Dev
metadata:
  type: feedback
---

Un cambio en `/v1/chat/completions` o `/v1/audio/transcriptions` del gateway no se puede comprobar en vivo sin token
de App Attest. Lo que Jürgen eligió el 2026-10-07 (encargo `gpt-4-1-nano-shuts-down-on-october-23`):

- **Staging:** prueba él con **Yala Dev** en su iPhone (una foto + un mensaje en Yala IA) mientras yo leo
  `wrangler tail`. El `DEV_SHARED_SECRET` de staging no está guardado en ningún sitio. Necesita los pasos exactos:
  preguntó «¿qué debo hacer?» y «¿cómo sé si es la última versión?». Para un cambio del gateway la versión de la app
  da igual, y conviene decírselo.
- **Producción:** aprobó acuñar un token de **15 min** para un `sub` ficticio (`frank-verify-AAAA-MM-DD`, tier Pro)
  con `~/Secrets/yala-gateway/prod-jwt-signing-secret` y mandar las peticiones exactas de la app
  (`gateway/bench/lib/appRequests.ts`). Se anota en el PR.

**Why:** producción corre `ENFORCE = "enforce"` y no tiene bypass de dev. Sin tráfico propio, «verificado en prod»
dependería de que un usuario use la IA justo durante el tail.

**How to apply:** pregunta igual la primera vez de cada sesión (es su credencial de producción), proponiendo esta
opción como recomendada. Nunca bajes `ENFORCE` para probar (`.claude/rules/gateway-attest.md`). Relacionado:
[[credencial-pendiente-se-aparca]].
