---
name: la-fase-nueva-hereda-el-arm-de-su-vecina
description: Una fase de fallo nueva copiada de `.failed` heredó su salida sin desarmar, y un bloqueo que dura semanas convirtió la reanudación a ciegas en un borrado diferido
metadata:
  type: feedback
---

Al añadir una fase de fallo copiando la vecina (`.groupsPending` desde `.failed` en el aviso del espejo tardío), copié su «Dejarlo por ahora» = `dismiss()` sin retirar el arm. Las tres lentes de la review lo cazaron a la vez: el arranque reanudaba el borrado a ciegas en cada arranque, y como el motivo nuevo dura semanas (sesión caducada, canal en pausa), el borrado acababa corriendo cuando los cambios subían, llevándose todo lo creado entretanto.

**Why:** la vecina conservaba el arm por una razón que no aplicaba a la nueva: `.failed` puede llegar DESPUÉS de borrar la zona (el arm protege un borrado a medias); la nueva para ANTES de borrar nada. Y la duración del bloqueo cambia qué significa «reanudar en el próximo arranque».

**How to apply:** al copiar una salida de otra fase, pregunta qué estado deja a medias ESA fase y cuánto dura su motivo. Si no deja nada a medias, desarma. Relacionado: [[el-molde-no-traslada-sus-precondiciones]], [[mi-arreglo-abre-un-camino-inalcanzable]].

Y del mismo encargo (2026-09-26): la quiescencia estricta del cierre (`awaitPersonalQuiescenceForGroupsSignOut`) aplicada a un gesto que antes no la tenía bloqueaba con CERO pendientes — lo destapó un mutante que tardó 10 s en vez de 0,3. Un atajo sin espera para el caso vacío va delante de cualquier `await`.
