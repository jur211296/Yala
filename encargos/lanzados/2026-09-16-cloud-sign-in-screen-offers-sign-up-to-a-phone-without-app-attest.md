# Pantalla de entrar: sin App Attest no ofrecer «Crear mi cuenta»

## Contexto
Ticket: `tickets/backlog/cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest.md`.
Hermano de #180: el chooser ya no ofrece la nube sin Attest, pero WelcomeCloudSignInView tiene dos salidas al alta sin gate — notFound → «Crear mi cuenta» y providerMismatch → «Crear cuenta con…».

## NOCHE / madrugada — decisión recomendada
Opción 1: una sola puerta del alta — las dos salidas obedecen el mismo gate que el chooser (App Attest y kill del alta). Sin AskUserQuestion. Si choca demasiado con device-QA montaje, documenta y aparca.

Hora Lima: si ya es diurno (6:00–21:00), puedes AskUserQuestion a Jürgen para producto/acceso.

## Que se pide
1. Mismo gate del chooser en esas dos salidas.
2. Nota en ticket hermano sobre montaje device-QA (YALA_DEV_SHARED_SECRET) si se cierra la puerta.
3. Tests según repo.
4. Gate, commit, tickets/ + docs/TICKETS.md, PR, merge a 2.1 si OK, /cerrar-total. Bugs → ticket. No Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/cerrar-total sin preguntar. UI tests CI advisory.

## Que NO
marketing/; no reopen #180 salvo patrón.

## Como se sabe que esta bien
Sin Attest: no crear cuenta desde notFound/mismatch. Con Attest: igual. Board + /cerrar-total.

## Avisos Frank
Webhook Mini (URL/key local): (1) decisión/acceso; (2) PR/preview; (3) /cerrar-total + resumen usuario; (4) sin siguiente — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión nocturna, 05:36 Lima, bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

### Lo medido antes de decidir

- **Las salidas al alta de la pantalla de entrar son tres llamadas a `switchToSignUp(with:)`**: el botón de «No encontramos
  una cuenta» (`notFoundContent`) y los dos botones de marca de la salida «crear» del mismatch (`providerMismatchContent`,
  uno por `case`). Ninguna consulta un gate. No hay más en `Yala/`.
- El alta de verdad (`BornCloudSignUpService.signUp`) se construye en dos sitios: esta pantalla y la promoción de
  `FullModeActivationView`, cuya entrada ya pasa por el chooser con la puerta de #180. «Migrar a la nube» va por
  `MigrationWorkExecutor` y tiene ticket propio.
- La puerta del chooser es `WelcomeNewOptionsGate.live`: backend configurado, fuera de uitest (o con
  `-uitest-cloud-chooser`), App Attest (`AppAttestClient.canObtainSessionToken` o el seam), la constante compilada y los dos
  remotos, `cloudModeEnabled` y `cloudOnboardingChoiceEnabled` (el kill del alta).
- **Ningún XCUITest llega a `.notFound` ni a `.providerMismatch`**: las dos fases exigen firmar de verdad con Apple o Google
  y no hay seam de fase. `grep` de sus identificadores en `YalaUITests`: cero.
- **El copy sigue siendo cierto sin los botones.** «Este Apple ID aún no tiene una cuenta Yala en la nube» y «Tu cuenta de
  Yala se creó con %@» no prometen crear nada.
- **Ninguna de las dos pantallas se queda sin salida.** «No encontramos una cuenta» conserva la flecha de atrás
  (`canGoBack` incluye `.notFound`), que vuelve al chooser de nivel 1, y ahí «Es mi primera vez» lleva a la cuenta privada.
  El mismatch conserva «Iniciar sesión con…» y la flecha.
- **El montaje del ticket hermano** (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`) crea hoy su
  cuenta por «Crear mi cuenta». `YALA_DEV_SHARED_SECRET` es un secret de Wrangler del gateway de staging: no está en
  `~/Secrets` (re-medido el 16-sep) y Wrangler no deja leerlo de vuelta. Con él puesto, `canObtainSessionToken` vale `true`;
  el token del bypass solo se guarda en memoria (`AppAttestClient.cached`), así que quitarlo y relanzar devuelve el
  simulador a «sin App Attest».

### Decisiones

**D1 · ¿Qué puerta obedecen las dos salidas?** → La de la card, entera: `WelcomeNewOptionsGate.offersCloudSignUp`, que es
`live.contains(.cloudAccount)`. Con ella entran App Attest y el kill del alta (opción 1), y el resto de términos del chooser.
Por qué: una sola puerta del alta; derivada de `live`, no puede divergir de la card. Alternativa descartada: leer el attest
y `cloudOnboardingChoiceEnabled` en la vista, que es una segunda copia de la puerta (y la opción 2 del ticket).

**D2 · ¿Dónde va la condición?** → En la vista, alrededor de cada salida: `if WelcomeNewOptionsGate.offersCloudSignUp { … }`.
Sin guard dentro de `switchToSignUp`.
Por qué: lo que la persona no puede usar no se pinta. Un guard en la función dejaría un botón muerto el día que pintar y
pulsar divergieran. Alternativas descartadas: el guard además de esconder, que es defensivo; y un tipo de lógica pura con
`ofrece ? método : nil`, cuya tabla probaría un ternario y no el cableado, que es donde está el riesgo.

**D3 · ¿Qué ve quien no tiene App Attest?** → **Corregida tras la review y decidida por Jürgen (06:1x, opción recomendada):**
«No encontramos una cuenta» ofrece un botón principal «Volver» en el sitio de «Crear mi cuenta», con el `welcome.cloud.blockedBack`
que ya existe en los 16 idiomas. El mismatch se queda con una sola salida, «Iniciar sesión con…». Sin copy nuevo.
Por qué: la primera versión dejaba solo la flecha de la esquina, y las dos lentes lo cazaron. El bloque [I] decidió «nunca
un callejón con un solo volver» (`CloudIdentityRoutingLogic.offerSignUpNoAccountFound`), y esta misma vista ya resuelve así
el bloqueo por datos de otra cuenta. Esta D3 decía que las dos pantallas conservaban una salida hacia delante: para «No
encontramos una cuenta» era falso. Alternativas descartadas: solo la flecha, y un texto que explique por qué no se puede
crear, que es copy nuevo en 16 idiomas.

**D4 · ¿Entra algo más?** → No. El intro del alta solo se alcanza por la card o por estas dos salidas, y los reintentos de
`.error` y `.waitingLeader` solo después de haber entrado en el alta. «Crear otra cuenta» ya abre el chooser con la puerta.

**D5 · ¿Cómo se prueba?** → Sin XCUITest nuevo, con tres redes de source-scan y un mutante por red:
(a) el cuerpo entero de `offersCloudSignUp`, buscado sobre el código sin comentarios; (b) toda llamada a `switchToSignUp(`
del fichero cae dentro de un bloque `if WelcomeNewOptionsGate.offersCloudSignUp {`, y son tres, y `entryOverride =
.bornCloud` solo existe dentro de `switchToSignUp`; (c) **el cuerpo entero de las dos pantallas**. La primera (c) solo
medía qué caía dentro y fuera de la puerta, y la review demostró que una condición más alrededor (`#if DEBUG`, un `if`
exterior o interior) le quitaba el botón a un iPhone con App Attest con la suite en verde.
Por qué: en el host de test la capacidad vale `false` y las dos fases son inalcanzables, así que el cableado solo lo ve un
scan; con el marcador exacto y los cuerpos enteros, el scan distingue la condición puesta, quitada, invertida, ampliada o
restringida. El lado `true` ya lo
cubre #180: su XCUITest prueba que `live` ofrece la nube con App Attest. Alternativa descartada: un seam de fase para
XCUITest, superficie de test nueva en una vista de 1.178 líneas para verificar un `if`.

**D6 · ¿Y el montaje del ticket hermano?** → Nota en su ticket, sin reabrirlo: la cuenta se crea con el secreto en `Yala Dev`
por «Es mi primera vez» → «Tu cuenta en la nube», y se quita el secreto y se relanza antes del paso 1. Y se dice dónde NO
está el secreto.
Por qué: es el montaje que el ticket y `gateway-attest.md` ya preveían para cuando esta puerta se cerrara.

**D7 · ¿En qué estado queda el ticket?** → `qa`, con dos pasos de device-QA: sin App Attest (simulador) sale «Volver» y no
«Crear mi cuenta»; con App Attest (iPhone real) sale «Crear mi cuenta», sin pulsarlo. Los dos aceptan el mismatch como
alternativa, porque el faro de iCloud puede llevar ahí (hallazgo de la review).
Por qué: el fallo caro es el contrario —un iPhone con App Attest que pierde la salida— y ningún test ejecutable aquí lo ve.

**D8 · ¿Qué documentación caduca?** → La sección «La puerta del alta» de `gateway-attest.md` (decía que estas salidas no
tienen puerta y proponía crear la cuenta por ahí), los docblocks de `AttestSyncGate.shouldOfferCloudOnly`,
`WelcomeNewOptionsGate` y `ProviderMismatchLogic.Exits`, la cabecera de `WelcomeAccountChoiceLogic` y los docblocks de la
vista que prometen el botón. La review añadió cinco que esta lista no tenía: `CloudIdentityRoutingLogic.offerSignUpNoAccountFound`,
`CloudRemoteFlags.cloudOnboardingChoiceEnabled`, `UITestHooks.fakeAttestSupport`, `CloudWelcomeSignInPhase.providerMismatch` y
`L10n.Welcome.Cloud.blockedBack`, que ahora comparten dos pantallas.
Por qué: un docblock que describe la intención como comportamiento es la siguiente premisa falsa.
