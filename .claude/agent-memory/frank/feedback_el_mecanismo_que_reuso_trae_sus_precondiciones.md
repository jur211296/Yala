---
name: el-mecanismo-que-reuso-trae-sus-precondiciones
description: Reusar un mecanismo existente hereda su docblock de precondiciones, y si el call-site nuevo no las cumple el daño no está en tu cableado sino en lo que el mecanismo hace de más; medido el 10-sep con el boot-wipe de sign-out
metadata:
  type: feedback
---

**Antes de reusar un mecanismo, lee su docblock de PRECONDICIONES y comprueba una por una si tu
call-site las cumple.** Si no las cumple, no lo adaptes: el problema no es el cableado, es que ese
mecanismo hace cosas que solo tienen sentido cuando esas precondiciones son ciertas.

**Why:** el 2026-09-10, en la mitad 2 de la puerta de Grupos, reusé `armSignOutWipe` +
`performSignOutWipeIfArmed` para «borrar lo local dejando iCloud intacto». En el Paso 0 escribí que
hacía «exactamente lo que este camino necesita y nada que estorbe». Su docblock declaraba tres
precondiciones —«el coordinador de sign-out ya subió TODO el outbox (verificado), cerró la sesión y
armó»— y mi call-site no cumplía **ninguna**. Lo que hacía de más, medido por tres lentes:

- borraba `YalaSyncMeta` **incondicionalmente**, donde viven `GroupSyncOutbox` y `GroupSyncCursor` — o
  sea el canal de Grupos, que mi propio commit prometía no tocar. «El store de Grupos sobrevive» era
  cierto para sus FILAS y falso para su CANAL;
- purgaba las colas pendientes de Apple Pay y Siri, que **nunca pasaron por SwiftData** y por tanto
  nunca estuvieron en iCloud: ninguna subida las podía salvar, y mi copy prometía lo contrario;
- revertía a `.icloud` un device en Modo Nube, borraba el consent de Grupos a quien iba entrando a
  Grupos, y se llevaba la foto de perfil y los tres consents de IA;
- y **mientras el arm está puesto la app queda a medias** (sin drains de foreground, notificaciones
  nuevas descartadas, widget congelado) con un solo desarme posible: el propio borrado al terminar
  bien. Si aborta, no hay salida.

Ninguna de esas cinco cosas era un bug del mecanismo: son correctas **para su call-site original**,
que deja la app en un cover terminal sin salida. El mío tenía un botón «Volver» al lado.

**How to apply:** cuando vayas a llamar a un `arm*`/`perform*`/`wipe*` ajeno, escribe su lista de
precondiciones y márcalas contra tu camino. La pregunta que ahorra la sesión entera es **«¿qué hace
este mecanismo ADEMÁS de lo que yo quiero?»**, y se contesta leyendo su cuerpo, no su nombre. Si la
respuesta incluye superficies que tu promesa al usuario no cubre —colas de otro proceso, un canal
distinto, preferencias, un modo persistido— para y dilo: probablemente lo que hace falta es la pieza
que otro ticket tiene en su alcance, no una adaptación tuya. Hermano del riesgo gemelo:
[[el-mecanismo-existente-se-probo-con-otro-corpus]].

**Cerrado el 2026-09-11, y la salida es la que este párrafo insinuaba:** el camino se reabrió
**consumiendo el COORDINADOR entero** (`CloudSessionSignOut.signOut`) en vez del `arm*` suelto. Las tres
precondiciones del boot-wipe las cumple él por construcción, así que la pregunta «¿qué hace este mecanismo
ADEMÁS de lo que yo quiero?» dejó de tener respuesta mala. ⇒ **cuando un `arm*`/`perform*` ajeno traiga
precondiciones que no cumples, busca quién SÍ las cumple antes de adaptarlo**: casi siempre es el
coordinador que lo llama, y entrar por ahí también te trae sus redes (aquí: el bloqueo si quedan grupos sin
subir, el aviso si la espera se agota y el desarme si el borrado aborta).
