---
name: dos-getters-que-parecen-sinonimos
description: Elegí el getter compuesto de un flag y era fail-closed sin snapshot; el docblock del propio flag ya separaba qué clase de call-site lee cuál, y mi consumidor era de la otra clase. El aviso no salía a quien más lo necesitaba.
metadata:
  type: feedback
---

**Cuando dos getters del mismo flag parecen sinónimos, mira cómo lo leen los consumidores que YA existen
antes de elegir — y pregunta de qué CLASE es el tuyo.**

**Why:** el 2026-09-15, en `groups-tab-does-not-say-this-phone-cannot-sync-groups`, escribí el aviso fijo
de la pestaña Grupos con `CloudSyncFlags.groupsBackendEnabled`, que es `compilado && remoto`. Parecía lo
correcto: «¿está el canal encendido?». El docblock de ese mismo flag ya tenía escrito, desde el 2026-07-30,
que hay **dos clases de call-site**: las ENTRADAS leen el compuesto —es lo que el kill-switch existe para
cortar— y los TEARDOWNS leen `groupsBackendCompiledCapability`, porque **el término remoto es fail-closed
ante un snapshot ausente o corrupto y no es testigo del corpus de ese teléfono**. Los cuatro call-sites de
`CloudSignOutFlowLogic.path` ya usaban el segundo, y yo afirmé en mi docblock que usaba «el mismo par que
ellos» sin comprobarlo.

Daño medido: un teléfono **restaurado desde una copia de iCloud** hereda la racha de attest y no la key, y
en su primer arranque no tiene snapshot de remote-config ⇒ el aviso **no salía**, mientras el cierre de
sesión sí se lo enseñaba. Era el bug del ticket, vivo, en la población más probable. Lo cazó una lente
adversarial; mis tres redes de test estaban verdes, porque bajo `-uitest` los dos getters valen lo mismo.

**How to apply:**

- **La pregunta no es «¿qué significa este getter?» sino «¿de qué clase es mi consumidor?».** Un aviso
  sobre datos que YA existen es de la clase de los teardowns, no de las entradas: si el flag se apaga por
  una razón ajena al teléfono, lo que hay sigue estando ahí.
- **`grep` de los call-sites reales antes de escribir el docblock.** Yo escribí «el mismo par que
  `CloudSignOutFlowLogic.path`» y los cuatro pasaban el OTRO. Es la familia de
  [[mi-docblock-tambien-es-una-premisa]]: una afirmación sobre lo que hacen otros se verifica con un grep,
  y si la propago a una rule, el error viaja.
- **Fail-closed en un AVISO es fail-abierto para el usuario.** Un gate que se apaga solo deja de avisar, y
  eso no se parece a un fallo: se parece a que no hay problema. Cuando el consumidor es un aviso, pregunta
  qué pasa si su entrada llega vacía por error — es [[un-gate-falla-abierto-por-su-entrada]] por el otro
  lado.
- **Y bajo test los dos getters pueden valer lo mismo**, así que ningún XCUITest distingue. Lo que sí
  distingue es un source-scan que PROHÍBA explícitamente el getter equivocado, con el porqué en el mensaje.

Relacionado: [[mi-docblock-tambien-es-una-premisa]] · [[la-premisa-del-encargo-tambien-se-mide]] ·
[[el-default-seguro-no-es-el-mismo-para-todos]].
