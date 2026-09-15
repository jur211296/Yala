---
name: hoja-apple-id-cierre-bloqueado
description: El cierre por cambio de Apple ID es una hoja con fases que enseña el bloqueo y deja libre al coordinador; el ticket no nombraba una segunda puerta (getter compuesto) y la review cazó un progreso eterno MÍO. Queda device-QA y una decisión de copy.
metadata:
  type: project
---

**(2026-09-15) Si el cierre por cambio de Apple ID se bloquea, ahora se ve y se sale.** El `.alert` de #159 es
una hoja con fases: pregunta, progreso, el motivo con el copy de Ajustes, «Reintentar» y «Ahora no». «Ahora
no» reconoce el bloqueo de su cierre, y el teléfono ya no se queda sin poder cerrar sesión.

**Why:** era `high` porque, además del silencio, la fase pegada en `.blocked` cerraba `signOut`, el
desasociar y la puerta del invitado el resto del lanzamiento.

**How to apply:**

- **Lo que queda abierto:** el device-QA va en el recorrido 5 de `device-qa-apple-id-change-closes-private-session`
  (no es simulable, y no se abrió ticket de QA aparte). La decisión de copy de
  `apple-id-close-notice-does-not-say-what-else-the-close-does` (medium) trae recomendación: una frase solo
  cuando el cierre se lleva grupos del teléfono.
- **El ticket tenía una puerta menos de las que había.** Además del bloqueo, el tap resolvía la celda con el
  getter COMPUESTO de Grupos y el coordinador con el COMPILADO: con kill remoto o sin snapshot, el botón no
  hacía nada. Si otro aviso resuelve una celda para `signOut`, compara su getter con el del coordinador.
- **Las hojas de las pestañas no entran en la matriz del shell** (Ajustes abierto sobre el Panel): es lo que
  hacía alcanzable el progreso eterno. Va anotado en `orphan-alerts-behind-fullscreen-covers`; no se tocó
  porque cambia todos los intents del shell.
- **Un rojo del lote que no se reprodujo:** `RemoteWipeNoticeRoutingUITests.test_notice_keepWaiting…` cayó
  una vez con el paywall sin presentar; aislado dio 3/3 en el árbol base y 3/3 en el mío. Si vuelve a caer,
  la hipótesis es la carrera «drenar mientras el alert se desmonta», que no es de este cambio.
- **Los mutantes de XCUITest cazaron dos afirmaciones falsas del PROPIO test**, que ninguna lente vio: el
  manejador de interrupciones de XCTest reconocía el bloqueo por el test, y otra hoja no discrimina la
  retención de la matriz. Las dos trampas están en `.claude/rules/testing.md`; la lección de método es la de
  [[el-oraculo-del-mutante-es-el-efecto-que-produce]].
- Ver [[la-fase-ajena-tiene-otros-escritores]] y [[apple-id-cierra-la-sesion-privada]].
