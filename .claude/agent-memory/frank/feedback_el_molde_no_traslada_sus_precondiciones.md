---
name: el-molde-no-traslada-sus-precondiciones
description: Copiar un método «con el molde de X» hereda su forma, no las condiciones que lo hacían correcto en X — el belt copiado hacía que el botón no firmara justo en el caso principal del ticket
metadata:
  type: feedback
---

Cuando escribo «molde de `X`» en un docblock, he copiado la FORMA. Las precondiciones que hacían
correcta a `X` **no viajan**, y hay que comprobarlas una por una en el destino.

**Why:** el 2026-09-17, en `reverse-before-mount-stays-stuck-with-an-expired-session`, escribí
`signInToResumeReverse` «con el molde de `signInToResumeSync`» y cité ese molde **tres veces** en el
Paso 0. Las tres veces heredé algo que allí era cierto y aquí no:

1. **Su belt de «sesión viva» comprueba `hasSession && accessToken() != nil`.** En su sitio vale. En
   el mío, la observación que enciende la pantalla la produce sobre todo **un 401 del gateway con la
   sesión intacta**: ahí los dos términos son ciertos y `accessToken()` devuelve *el mismo JWT que el
   servidor acaba de rechazar* (solo auto-refresca con menos de 30 s de margen). El belt saltaba la
   firma, retomaba con el token rechazado y recibía el mismo 401 ⇒ **el botón que ofrece entrar no
   entraba, en el caso PRINCIPAL del ticket**. Lo correcto era `forceRefreshAccessToken()`, que rota.
2. **Su seguridad de identidad no está en el método: está aguas abajo.** `signInToResumeSync` termina
   en `handleBecameActive()`, cuyo gate deja el motor `.idle` si la cuenta no es la del device. El
   mío conduce el runner directo —la fase de la vuelta no es estable, así que ese gate no corre— y el
   paso que sube lee un outbox sin dueño. Con el chooser de Google, elegir la cuenta de al lado
   escribía el corpus de una persona bajo el `sub` de otra.
3. **Su `isWorking` va antes del primer `await`**; el mío iba después, y el re-kick de 30 s se colaba.

Los tres los cazó la review adversarial, ninguno la suite.

**How to apply:** antes de escribir «molde de X», responde tres preguntas sobre X y sobre el destino:

- **¿Qué ENTRADA recibe cada uno?** El mismo `guard` sobre entradas distintas decide distinto. Aquí,
  «no hay token» y «el token no vale» son estados diferentes y el belt solo distinguía el primero.
- **¿Qué corre DESPUÉS?** Si la seguridad de X vive en lo que X llama al final, copiarlo sin ese
  final deja el guard fuera. Recorre el camino completo de los dos, no el cuerpo del método.
- **¿Qué lo mira desde fuera?** `isWorking`, un flag de la matriz de readiness, un re-kick: si otro
  mecanismo lee ese estado, el ORDEN de las líneas es parte del contrato, no estilo.

Y el corolario de red: cuando el destino es un singleton con `init` privado —un controller que vive
sobre el `mainContext`— **ninguno de estos tres defectos lo puede ver un test de comportamiento**. La
red es un source-scan del cuerpo (`ReverseUploadControllerWiringTests`), y ahí el orden se fija
comparando posiciones (`range(of:).lowerBound`), no con un `contains`.

Ver también [[review_adversarial_caza_lo_mio]] y [[feedback_dos_getters_que_parecen_sinonimos]].

**Segunda vez, 2026-09-26** (`late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed`): la fase nueva
«El borrado quedó a medias» copió la jerarquía de `.failed` —reintentar arriba, sin «¿seguro?»— porque las dos vienen de
un borrado fallido. Pero `.failed` se ve SEGUNDOS después de confirmar dos veces; la nueva la presenta el arranque, quizá
días después y con datos nuevos en el teléfono. Lo cazó la review: la salida que no borra va arriba y terminar pide
confirmación. ⇒ **antes de copiar los botones de una fase, pregunta CUÁNDO la ve la persona**, no solo de qué viene.
