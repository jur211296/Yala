---
id: fresh-start-has-no-way-out-when-group-writes-can-never-upload
status: qa
priority: medium
area: "groups, modo-nube"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26)"
---

# «Empezar de cero» no tiene salida cuando los cambios de grupos no pueden subir nunca

## El síntoma

Recibo un iPhone que era de otra persona, o mi sesión de grupos caducó. Quedan gastos de grupo sin subir. Toco
«Empezar de cero» y la app me dice que faltan cambios de grupos por subir. Vuelvo a intentarlo días después y me
dice lo mismo. No puedo empezar de cero, y el texto me pide «vuelve a iniciar sesión» en una cuenta que no es mía.

## Lo medido (2026-09-26, review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently`)

Desde ese ticket, «Empezar de cero» sube el outbox de grupos antes de borrar y, si no sube, no borra. Con
`.sessionExpired` (la sesión la borró el SDK), `.permanent` o `.channelPaused` sostenido, la subida no drena nunca.
El gesto no ofrece «perderlos», por la decisión de Jürgen del 2026-09-15 para el desasociar, y el cierre de sesión
solo la ofrece con `.attestUnavailable`. Queda una salida real: desinstalar Yala, que borra el store y el outbox de
todas formas.

Lo cazaron dos lentes por separado. Antes de ese ticket el gesto era justo la salida: borraba el outbox sin avisar.

## La decisión que falta (de Jürgen)

1. Ofrecer «Empezar de cero y perderlos», con la cifra y una segunda confirmación, solo con los motivos que esperar
   no arregla: `.sessionExpired`, `.permanent` y `.attestUnavailable`. Es el molde del cierre de sesión con el attest.
2. Dejarlo como está: la salida es reinstalar.

En el alert del shell, la opción 1 pide un segundo alert con sus labels literales y su entrada en la matriz de
readiness (`.claude/rules/swiftui-ds.md`).

## Decidido (Jürgen, 2026-09-26)

La opción 1, con guardas: ofrecer «perderlos» solo con los motivos que esperar no arregla.

## Arreglado (2026-09-26)

**Si los cambios de grupos no pueden subir nunca, «Empezar de cero» ya no deja atrapado a nadie.** Con la sesión que los
apuntó borrada, la cuenta no disponible o el teléfono más de un día sin App Attest, el aviso «Faltan cambios de tus grupos
por subir» dice por qué no van a subir, cuántos se perderían, y ofrece «Empezar de cero y perderlos». Un segundo paso
(«¿Perder estos cambios?») pide confirmarlo; solo «Perderlos y empezar de cero» borra. Con el canal en pausa, sin red o con
cualquier cosa que un rato arregla, el aviso sigue igual que antes y sin esa salida.

- **Qué motivos la ofrecen**: `CloudSignOutFlowLogic.freshStartOffersGroupsLossExit`, `switch` exhaustivo.
- **El motivo se mide en el gesto**: la confirmación no borra a partir del aviso; vuelve a subir. Si drena, no se pierde
  nada. Si vuelve a bloquear con uno de los tres motivos y lo que queda está entre lo enseñado, borra perdiéndolo. Si no,
  vuelve el aviso con la cifra nueva.
- **Por fila, no por cifra** (`FreshStartGroupsLoss`): filas vivas del outbox y entradas del espejo del App Group, que el
  borrado purga entero. La cifra del aviso cuenta las dos. El cinturón del escritor deja pasar eso y nada más
  (`requireNoUnsentGroupWrites(accepting:)`).
- **Lo aceptado vale para un intento**: lo consume la subida siguiente, sea cual sea su desenlace.
- **Segunda confirmación como fase, no como alert**: la puerta privada del Welcome y el aviso del espejo tardío ganan dos
  fases. Encadenar dos `.alert` del mismo anchor es el brick de `.claude/rules/swiftui-ds.md`; sin presentación nueva no
  hay entrada nueva en la matriz de readiness.
- **El alert «Borrar todo y continuar» ya no se niega en el sitio con cambios pendientes**: no puede subirlos, así que
  nunca sabía el motivo y siempre decía «inténtalo en un rato» (la trampa del iPhone heredado). Ahora reabre el Welcome en
  la puerta privada, directa en su borrado del teléfono (`WelcomeFlowStep.freshStartDeviceWipe`), que sube, enseña el
  motivo y ofrece la salida. Sin pendientes borra en el mismo tap, como siempre.
- **Copy**: con la sesión caducada ya no pide «vuelve a iniciar sesión» (la cuenta puede no ser tuya). 8 textos nuevos en
  16 idiomas. Canario `freshStartDiscardedGroupWrites`.

**Lo que cazó la review adversarial (tres lentes) y se arregló en la rama:**
- Con `.sessionExpired` o `.permanent`, un gasto que un drain a medias dejó en el History no salía en la cifra y se perdía.
  Ahora, antes de ofrecer la salida, se vuelve a capturar; si la captura no termina, el bloqueo sale sin «perderlos».
- Lo aceptado sobrevivía a un borrado que se paraba antes de subir (la espera del import) y lo gastaba otro gesto. Ahora el
  borrado lo toma en su primer paso (`takeFreshStartAcceptedLoss`).
- La X del aviso del espejo tardío, desde «faltan cambios», retiraba el testigo; ahora hace lo mismo que «Dejarlo por ahora».
- La entrada `.wipeDevice` borra al montarse: exige un permiso de un uso que da el tap del alert del shell.
- Un test de cableado existente (`ForceFetchCancellationWiringTests`) contaba la forma vieja de la re-espera.

**Verificado**: ver el PR. Tests en `YalaTests/CloudSync/FreshStartGroupsLossExitTests.swift` (lógica, servicio y
cinturón con filas de verdad, cableado de las pantallas).

**Sin tocar, asumido**: un kill a mitad de un borrado con pérdida aceptada deja el arm; la reanudación del arranque no
lleva aceptación, se para en la subida y se desarma, como siempre. La aceptación vive en memoria.

## Device-QA (pendiente, no bloquea)

Hace falta la build **Yala Dev** (apunta a staging) en tu iPhone o en el simulador, y una cuenta de prueba con un grupo.

**A. Sin red, la salida NO aparece**
1. Con la cuenta de grupos iniciada y un grupo, activa el **modo avión**.
2. Apunta un gasto en ese grupo.
3. Perfil → Ajustes → «Vaciar datos» → «Vaciar definitivamente». La app vuelve a la bienvenida.
4. «Es mi primera vez en Yala» → «Tu cuenta en tu iCloud privado». Si sale «Empezar desde cero», toca «Borrar todo y continuar».
5. **Esperado**: la pantalla de la puerta sube y enseña «Faltan cambios de tus grupos por subir» con «Volver a intentarlo» y
   «Dejarlo por ahora». **No** aparece «Empezar de cero y perderlos». Toca «Dejarlo por ahora»: vuelves atrás y el gasto
   sigue en el grupo.

**B. Con la sesión borrada, la salida aparece y pide confirmar**
1. Repite A.1–A.3 (gasto sin subir, en la bienvenida).
2. En el panel de Supabase de **staging** → SQL Editor, borra las sesiones de tu usuario de prueba (su id está en
   Authentication → Users): `delete from auth.sessions where user_id = '<id>';`. Así el SDK no puede renovar y borra la
   sesión del teléfono, que es el caso del iPhone heredado.
3. Quita el modo avión y espera unos segundos.
4. Repite A.4.
5. **Esperado**: «Faltan cambios de tus grupos por subir», con «(1)» y un texto que dice que solo pueden subir con la cuenta
   que los apuntó. Botones «Dejarlo por ahora» y «Empezar de cero y perderlos». No dice «vuelve a iniciar sesión».
6. Toca «Empezar de cero y perderlos» → sale «¿Perder estos cambios?» con la cifra. Toca **«Mejor no»**: vuelves al aviso
   anterior y no se borró nada.
7. Otra vez «Empezar de cero y perderlos» → **«Perderlos y empezar de cero»**. **Esperado**: sigue al onboarding; el gasto
   no llega nunca al grupo (compruébalo desde otra cuenta miembro).

**C. Aviso del espejo tardío** (solo si tienes a mano el escenario del aviso «Tus datos de iCloud llegaron después»): con
lo de B.1–B.3 montado, «Borrar» → «Borrar todo» en ese aviso tiene que enseñar la misma oferta y el mismo «¿seguro?».
