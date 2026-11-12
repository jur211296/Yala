---
name: reference-forzar-una-preferencia-en-un-lanzamiento
description: Para ver en el simulador algo que -uitest da por visto (tarjeta de avisos de Grupos, etc.), pasar -<clave> NO como argumento de lanzamiento
metadata:
  type: reference
---

Bajo `-uitest`, `UITestEphemeralDefaults` pone varias marcas de «visto» en el dominio de REGISTRO (p. ej.
`hasSeenGroupsNotificationPrompt`), y por eso la tarjeta «Avisos del grupo» no sale nunca en el simulador. El dominio de
ARGUMENTOS manda sobre ese: lanzar con `-hasSeenGroupsNotificationPrompt NO` (en `simctl launch` o en
`launchForUITest(extraArguments:)`) la hace salir sin tocar plist ni cfprefsd. Medido el 2026-10-28 (card rj3b).

Más barato que [[reference-forzar-preferencias-en-el-simulador]] cuando la marca vive en el dominio de registro.
