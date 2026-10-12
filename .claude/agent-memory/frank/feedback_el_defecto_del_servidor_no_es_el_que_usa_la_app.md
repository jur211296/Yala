---
name: el-defecto-del-servidor-no-es-el-que-usa-la-app
description: Un valor por defecto en una función SQL o del gateway no es el valor efectivo si el cliente pasa el suyo; mide en el llamador antes de citarlo en un texto
metadata:
  type: feedback
---

Un `default` en la firma de una RPC (o en el gateway) no es el valor que vive la gente: el cliente puede pasar el suyo.

**Why:** en la política de 2.1 (2026-10-12) escribí «las invitaciones caducan a los 30 días» porque `create_group_invite(p_ttl_seconds default 2592000)` lo decía. La app pasa siempre `GroupBackendInviteService.defaultTTLSeconds` = 7 días. Lo cazó la lente adversarial; habría salido publicado en seis idiomas.

**How to apply:** antes de citar un plazo, límite o tamaño en copy o en un texto legal, busca quién llama a esa función y con qué argumento. Lo mismo para textos legales en general: se refutan contra el código como un diff, con una lente que intente tumbar cada afirmación (ver [[review-adversarial-caza-lo-mio]]).
