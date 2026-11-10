---
toca: Yala/App/Logic/CrossAccountEntryGuardLogic.swift, Yala/App/Logic/CloudWelcomeSignInFlow.swift, Yala/App/Logic/CloudIdentityRoutingLogic.swift, Yala/App/Logic/ICloudRestoreInProgressLogic.swift, Yala/App/Views/Onboarding/, Yala/Services/CloudSync/, Yala/Utils/SwiftDataConfiguration.swift, Yala/Resources/, YalaTests/, YalaUITests/
release: no
---
Yala
# Entrar con Google o Apple sin bloquear tu propio iCloud privado (opción B)

card: «Entrar con Google bloqueado por tus propios datos de iCloud privado («datos de otra cuenta»)» (v2.2). Léela entera con `tablero ver`.

## Contexto

El 9-nov Jürgen eligió la opción C (clave t1488u): preguntarle al dueño si pasa sus datos de iCloud a la nube o entra dejándolos aparte. La sesión nocturna midió que no hay forma segura de distinguir datos propios de ajenos en el caso general, que «pasar iCloud a la nube» sería una fusión (ya descartada) y que «dejarlos aparte» pide un flujo nuevo. No se tocó código. El trabajo quedó en el PR #878 (abierto, base 2.2, «No mergear»), rama `encargo/2026-11-09-entrar-con-google-icloud-privado-preguntar`, con el detalle en `docs/sessions/2026-11-09-icloud-privado-entrar-con-cuenta-nube.md`. Checkpoint en la Max: `/Users/max-jur/Claude/flota/checkpoints/01M71NSZ0F5A4K7FSRZDK93ET1`.

Hoy, al entrar con Google o Apple teniendo en el teléfono los datos del iCloud privado, la app sigue mostrando «Este dispositivo tiene datos de otra cuenta» y la única salida es «Empezar de cero», que también borra iCloud.

## Decisión de Jürgen (10-nov 6:45 Lima, clave t1503u-icloud; sustituye a t1488u)

GO para continuar ese checkpoint. Opción B (la que estaba sobre la mesa cuando eligió C): se abre la nube con la cuenta que entra y los datos de iCloud se dejan sin tocar, aparte. No se pregunta ni se mezcla. Un teléfono ajeno sigue protegido.

## Qué se pide

1. Retoma la rama del PR #878 y su checkpoint. Ponte al día sobre `origin/2.2`. No partas de cero ni mergees el checkpoint tal como está (sigue siendo trabajo incompleto).
2. Implementa la opción B: al entrar con Google o Apple, se abre la nube con esa cuenta; los datos de iCloud quedan sin tocar, en su sitio, sin subirse ni mezclarse con la cuenta que entra. No hay pregunta (a)/(b). No se ofrece «pasar iCloud a la nube».
3. Un teléfono prestado o heredado sigue protegido: no se suben ni se mezclan los datos de iCloud con la cuenta que entra, y no se borran de iCloud.
4. El texto ya no llama «de otra cuenta» a los datos propios del iCloud privado. Textos en español neutro latinoamericano, cortos y con el estilo de la app.
5. Tests de lógica de los casos (el dueño entra y iCloud queda aparte; el teléfono ajeno no mezcla ni borra iCloud) y verificación en simulador. El flujo de «dejar iCloud aparte» toca el archivo compartido de store (espejo apagado, relanzar, vaciar el archivo local sin que el borrado viaje a iCloud, y recién entonces adoptar): un error ahí puede borrar el iCloud del dueño, así que cubre ese camino con tests antes de darlo por bueno.
6. QA: hazlo tú mismo en el simulador y, si hace falta, en el iPhone 14 por DeviceMCP (está en Yala Dev con una cuenta iCloud privada). Si corres en la Max, puedes usar un segundo simulador si el primero está ocupado (tope 2).
7. Un solo PR contra 2.2, retomando el #878. Commits y PR sin firma de IA. Si el CI queda verde, el QA está hecho y el trabajo está completo, mergea, mueve la card a done con evidencia y cierra con `/cerrar-total`. No dejes la card en «in qa».

## Qué NO hay que tocar

- TestFlight, marketing/ ni 1.0.
- No debilites la protección del teléfono ajeno.
- No borres ni mezcles datos de iCloud.
- No preguntes al usuario ni ofrezcas la fusión (opción a / opción C).
- Lo menor y reversible lo decides tú y lo anotas en «Decidido sin consultar».

## Cómo se sabe que está bien

- El dueño de un iCloud privado puede entrar con Google o Apple desde el Welcome: se abre su cuenta de la nube y los datos de iCloud quedan sin tocar, aparte.
- Un teléfono ajeno no sube ni mezcla esos datos con la cuenta que entra, y iCloud no se borra.
- La pantalla de bloqueo no llama «de otra cuenta» a los datos propios.
- Tests de lógica (y los de UI que hagan falta) en verde; QA hecho por ti en simulador o iPhone 14; CI verde; PR mergeado a 2.2; card en done.

## Cierre

Modo semiautónomo. Si está completo y mergeado, cierra con `/cerrar-total`. Si aparece algo vital, pregúntalo y espera con la sesión viva.

## Paso 0 — decisiones

> Resueltas por Frank en modo semi (lo menor y reversible se decide sin consultar). Se discuten en el PR.

**D1 · ¿Cómo se deja iCloud aparte?** → Reusando la «vuelta al neutro» de la puerta de Grupos del Welcome (`WelcomeGroupsGateView`, cierre privado de `CloudSessionSignOut`): espera a que lo último llegue a iCloud, borra la copia local por ARCHIVOS antes del mount, deja iCloud intacto y relanza. Un propósito nuevo de esa pantalla, no un flujo nuevo.
Por qué: es el verbo ya medido en device que hace justo eso; la pantalla dice que dos implementaciones del mismo borrado serían dos verdades. Alternativa descartada: espejo apagado + vaciado propio desde la entrada a la nube (un flujo de sincronización nuevo, el riesgo que el encargo nombra).

**D2 · ¿Cuándo se deja aparte y cuándo sigue el bloqueo?** → Solo si la celda de cierre borra por archivos (teléfono en iCloud privado) y hay copia en iCloud (`privateCopyChannel() == .iCloud`). Sin copia, o con el teléfono en la nube, sigue la pantalla de bloqueo.
Por qué: «tus datos siguen en iCloud» tiene que ser verdad; sin copia lo borrado no estaría en ningún sitio y en un teléfono prestado no es de quien entra.

**D3 · ¿Se pregunta?** → No. Se informa en la pantalla de progreso (los datos de iCloud se quedan en iCloud) y se sigue, como la rama «Crear mi primer grupo».
Por qué: lo pide el encargo y la persona acaba de tocar «Entrar con…».

**D4 · Teléfono ajeno: ¿se ofrece «Continuar igualmente» si la espera del export se agota?** → No, ni la salida de perder cambios de grupos. Como en la rama del invitado: solo «Esperar» o «Volver».
Por qué: quien entra puede no ser el dueño; lo que no llegó a iCloud no se pierde por un tercero.

**D5 · ¿Qué pasa tras reabrir?** → Destino pendiente nuevo por proveedor (Google / Apple) que abre la entrada a la cuenta en el consentimiento, igual que «¡Hola de nuevo!». La persona vuelve a tocar su proveedor; la sesión no sobrevive al borrado (lo retira el boot-wipe).
Por qué: el destino `.cloudSignIn` existente está marcado inalcanzable y cae al chooser a propósito; uno nuevo y explícito no cambia ese contrato.

**D6 · Grupos de la era CloudKit en el teléfono** → Se borran con el resto, como en la puerta de Grupos (`neutralReturnFromGroupsGate: true`).
Por qué: `hasLocalDataNow` cuenta `SplitGroup`; si sobrevivieran, la entrada volvería a encontrar datos tras reabrir y el bucle volvería (precedente: decisión A de Jürgen del 29-oct para la puerta).

**D7 · Texto del bloqueo que queda** → Deja de decir «de otra cuenta»: «Este dispositivo ya tiene datos guardados» y un cuerpo que no afirma de quién son.
Por qué: el bloqueo que queda (sin copia en iCloud o datos de la nube) tampoco sabe de quién son.

**D8 · Si el borrado del arranque aborta** → La marca de fallo de la puerta cubre los destinos nuevos: la pantalla dice «no pudimos preparar este dispositivo» en vez de reintentar en bucle.

**D9 · PR** → Se empuja a la rama del PR #878 (se retitula y deja de ser borrador); un solo PR contra 2.2.
