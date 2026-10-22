---
id: cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest
status: done
priority: low
area: "modo-nube, attest, onboarding"
created: 2026-09-16
updated: 2026-09-23
source: "alcance de `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` (2026-09-16): el alta tiene dos puertas fuera del chooser"
qa-status: absorbed
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 absorbed por cloud-sign-in-discovers-account-kind - el boton Crear mi cuenta se ve en su recorrido 2
---

# La pantalla de entrar a la nube ofrece crear una cuenta a un teléfono sin App Attest

## El problema, en lenguaje de usuario

Mi teléfono no tiene App Attest. En «Es mi primera vez» ya no me ofrecen la nube. Pero si toco «Ya tengo una cuenta», entro
con Google y no tengo cuenta, la app me dice «No encontramos una cuenta» y me ofrece «Crear mi cuenta». La creo, apunto mis
gastos y nada llega nunca a mi cuenta.

## Lo medido (leído en el código, sin ejecutar)

- Desde el 2026-09-16 la card «Tu cuenta en la nube» del chooser sale solo si el teléfono puede conseguir token
  (`WelcomeAccountChoiceLogic.visibleNewOptions` → `AttestSyncGate.shouldOfferCloudOnly`, con
  `AppAttestClient.canObtainSessionToken`). Cubre «Es mi primera vez», «Crear otra cuenta» y «Activar Yala completo».
- La pantalla de entrar (`WelcomeCloudSignInView`) tiene **dos salidas más al alta**, y las dos van a
  `switchToSignUp(with:)` sin consultar ningún gate:
  - `.notFound` → «Crear mi cuenta» (`notFoundContent`, `welcome_cloud_not_found_cta`).
  - `.providerMismatch` → «Crear cuenta con…» (`ProviderMismatchLogic.Exits.createWith`).
- Ninguna de las dos mira tampoco el kill del alta (`CloudRemoteFlags.cloudOnboardingChoiceEnabled`), que sí esconde la
  card del chooser. **Eso es anterior** al 2026-09-16.
- Las dos existen por decisión de Jürgen: el paso 6 del rediseño («el veredicto dejó de ser una pared», ADR 2026-09-09 §10)
  y el bloque [I] («No encontramos una cuenta» ofrece crearla a quien no tiene ninguna).
- Sin medir: cuántos teléfonos no tienen App Attest, y si alguien llega a crear una cuenta por aquí.

## Lo que hay que decidir (Jürgen)

1. **Una sola puerta del alta para todas las entradas**: las dos salidas obedecen el mismo gate que el chooser (App Attest
   y el kill del alta). Sin App Attest, «No encontramos una cuenta» se queda sin botón de crear y el mismatch con una sola
   salida, la de entrar con el método del faro.
2. **Solo el attest**: esconder las dos salidas cuando el teléfono no puede conseguir token, sin tocar lo del kill.
3. **Dejarlo**: la población está sin medir y quien cae tiene la salida de
   `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` a las 24 h.

## Un aviso para quien lo implemente

El montaje de device-QA de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` crea hoy su cuenta en el
simulador justo por «Crear mi cuenta». Si se cierra esta puerta, ese montaje necesita `YALA_DEV_SHARED_SECRET` para crear
la cuenta y quitarlo antes del paso 1.

## Decisión (encargo nocturno, 2026-09-16)

**Opción 1: una sola puerta del alta.** Las dos salidas obedecen la misma puerta que la card «Tu cuenta en la nube»: App
Attest y el kill del alta. Las decisiones de detalle, con su porqué, están en el Paso 0 de
`encargos/lanzados/2026-09-16-cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest.md`.

**Y una de Jürgen tras la review (2026-09-16, 06:1x):** sin la puerta, «No encontramos una cuenta» ofrece un botón «Volver»
en el sitio de «Crear mi cuenta», con el texto que ya existe. Descartadas: dejar solo la flecha de la esquina, y un texto
nuevo que explique por qué no se puede crear.

## Hecho el 2026-09-16 — opción 1

**Lo que cambia para la persona.**

- **Sin App Attest, «No encontramos una cuenta» ofrece «Volver» en vez de «Crear mi cuenta».** Lleva a la primera
  pantalla, igual que la flecha de arriba, y el mensaje no cambia: no prometía crear nada. «Volver» y no solo la flecha,
  por decisión de Jürgen: el bloque [I] quitó el callejón con la salida en una esquina.
  - Si este Apple ID recuerda una cuenta (el faro de iCloud), «Es mi primera vez» vuelve a proponer entrar con ella, y
    desde ahí «Crear otra cuenta» lleva a la cuenta en su iCloud privado.
- **Sin App Attest, «Esa cuenta usa otro método» ya no ofrece «Crear cuenta con…».** Queda «Iniciar sesión con…», el
  método con el que se creó su cuenta.
- **Lo mismo con el kill del alta encendido**, que hasta hoy tampoco cerraba estas dos salidas.
- **Con App Attest y el alta abierta no cambia nada**: los dos botones de crear siguen ahí.

**Lo que se tocó.**

- `WelcomeNewOptionsGate.offersCloudSignUp`: la puerta, con nombre. Es `live.contains(.cloudAccount)`, así que no puede
  decir algo distinto de la card.
- `WelcomeCloudSignInView`: los botones de crear van dentro de `if WelcomeNewOptionsGate.offersCloudSignUp`, y «No
  encontramos una cuenta» pinta «Volver» en el `else`, con el `welcome.cloud.blockedBack` que ya existe en los 16 idiomas.
  El identificador del mensaje pasa del contenedor a su bloque, como en el bloqueo por datos de otra cuenta: en el
  contenedor pisaba el de los botones. No hay guard dentro de `switchToSignUp`, a propósito: dejaría un botón muerto el
  día que pintar y pulsar no coincidieran.
- Docblocks que dejaban de ser ciertos: `AttestSyncGate.shouldOfferCloudOnly` («no cubre las dos salidas»),
  `CloudIdentityRoutingLogic.offerSignUpNoAccountFound` («nunca un callejón»), la cabecera de `WelcomeAccountChoiceLogic`,
  `ProviderMismatchLogic.Exits.createWith`, `CloudWelcomeSignInPhase.providerMismatch`,
  `CloudRemoteFlags.cloudOnboardingChoiceEnabled`, `UITestHooks.fakeAttestSupport`, `L10n.Welcome.Cloud.blockedBack` y los
  de la vista que prometían el botón.
- `.claude/rules/gateway-attest.md`, «La puerta del alta»: las salidas pasan por la puerta, qué queda sin ella, y el
  montaje sin App Attest necesita el secreto.
- El montaje de device-QA de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`, reescrito con el
  secreto y en pasos.
- `qa/coverage-index.json`: seis áreas al 16-sep. En `cloud-migration-ui`, el `lastVerified` llevaba pegada una nota de
  cobertura desde `4d0cb2382` y `qa-sync` no podía leer su fecha: la nota pasa a `coverage`.

**Lo que NO cubre.** Entrar con una cuenta que ya existe, que es otra decisión
(`cloud-hydration-spinner-never-gives-up-without-attest`), y «Migrar a la nube» de Ajustes
(`cloud-migration-offers-the-cloud-to-a-phone-without-app-attest`). Cuántos teléfonos caen en la puerta sigue sin medir.

**Cómo se verificó.**

- **Build ×2** (`Yala` y `Yala Dev`, con sus targets de test): verdes y sin un warning en los 11 `.swift` tocados.
- **Unit: la suite entera sobre el árbol final, 7048 casos en 725 suites, 0 fallos** (12 omitidos, los mismos de antes).
  Entera y no por mapeo: los docblocks tocados los leen escáneres de otras suites.
- **XCUITest: 18 casos** en las 5 clases que salen de cruzar lo tocado con el índice (Welcome, Onboarding, activación,
  casos límite y el aviso de empezar de cero), con el centinela del simulador en 0 y sin reinicios. Ninguno llega a estas
  dos pantallas: por eso la red son los scans.
- **Mutantes: 22, todos cazados en su test.** 10 contra la primera versión de los tests y 12 contra la final. Los de la
  final: restringir la puerta con un `if` exterior o interior, un `#if DEBUG` alrededor, la puerta comentada con `/* */`,
  «Iniciar sesión con…» reencaminando al alta, un `else` que da de alta, un comentario que cita el cuerpo bueno sobre uno
  malo, sin «Volver», el id del mensaje otra vez en el contenedor, una cuarta salida sin puerta, la puerta solo con el
  attest y la puerta invertida. El árbol se restauró byte a byte tras cada barrido.
- **Review adversarial de dos lentes** (alcance y producto; tests, documentación y guion) y la regla de attest contra el
  diff. No encontró otra entrada al alta sin la puerta ni un iPhone con App Attest que perdiera el botón. Cazó que los
  scans no veían una puerta RESTRINGIDA —el fallo caro, con la suite en verde—, que «No encontramos una cuenta» volvía a
  ser el callejón que quitó el bloque [I] (de ahí la pregunta a Jürgen y el «Volver»), un guion de device-QA que el faro
  de iCloud podía dar por FAIL, y cuatro docblocks, dos frases de ticket y una del encargo que dejaban de ser ciertos.
  Arreglado todo.
- Índice de QA validado (ratchet OK) y `docs/TICKETS.md` igual al disco: 412 filas y 412 ficheros.
- **Sin device-QA en esta sesión**: el guion está abajo.


## Device-QA — dos pasos

Ningún test llega a estas pantallas: hace falta firmar de verdad con Google. **El faro de iCloud decide cuál de las dos
sale**: si este Apple ID recuerda una cuenta creada con Apple y firmas con Google, en vez de «No encontramos una cuenta»
aparece «Esa cuenta usa otro método». Las dos valen, y cada paso dice qué esperar en cada una.

**Paso A · sin App Attest, en el simulador.**

1. Xcode → scheme **Yala Dev** → Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables. Comprueba
   que **no** hay `YALA_DEV_SHARED_SECRET` (o que está desmarcada).
2. En el simulador iPhone 17 Pro, borra Yala Dev (mantén pulsado el icono → «Eliminar app») y lánzala desde Xcode.
3. «Empezar» → «Ya tengo una cuenta» → «Entrar con Google» → «Iniciar sesión con Google».
4. «Entiendo y quiero activar la nube» y firma con una cuenta de Google **que no tenga cuenta de Yala en staging**.
   - **Esperado**, una de dos:
     - «No encontramos una cuenta» con el botón **«Volver»** y sin «Crear mi cuenta».
     - «Esa cuenta usa otro método» con «Iniciar sesión con…» y **sin** «Crear cuenta con…».
   - **FAIL** si aparece «Crear mi cuenta» o «Crear cuenta con…».
5. Si salió «No encontramos una cuenta», toca «Volver».
   - **Esperado:** «¡Hola! ¿Qué quieres hacer en Yala?».

**Paso B · con App Attest, en un iPhone.** Es el fallo caro: que un iPhone de verdad pierda el botón. Tiene el mismo
montaje que el paso en iPhone de `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`.

1. **Borrar la app se lleva lo que no esté en tu iCloud o en la nube.** Usa un iPhone cuyos datos de Yala no te importe
   perder, o comprueba antes que los tuyos están a salvo.
2. Instala el primer TestFlight que lleve este cambio. Si Yala ya está, bórrala (mantén pulsado el icono → «Eliminar
   app» → «Eliminar app») e instálala otra vez desde TestFlight.
3. Abre Yala con conexión y espera unos 10 segundos en la primera pantalla.
4. «Empezar» → «Ya tengo una cuenta» → «Entrar con Google» → «Iniciar sesión con Google».
5. «Entiendo y quiero activar la nube» y firma con una cuenta de Google **que no tenga cuenta de Yala**.
   - **Esperado**, una de dos:
     - «No encontramos una cuenta» **con** «Crear mi cuenta».
     - «Esa cuenta usa otro método» **con** «Crear cuenta con Google».
   - **No toques ningún botón de crear**: crearía una cuenta de verdad en producción. Sal con la flecha de atrás.
   - **FAIL** si no aparece el botón de crear.

## Relación con otros tickets

- `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` — la puerta del chooser, de donde sale.
- `cloud-migration-offers-the-cloud-to-a-phone-without-app-attest` — la tarjeta de Ajustes, la otra entrada a la nube; desde
  el 2026-09-16 también mira el attest.
- `cloud-hydration-spinner-never-gives-up-without-attest` — lo que ve quien entra con una cuenta que ya existe.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). El botón «Crear mi cuenta» en un iPhone de verdad se ve de paso en el recorrido 2 de `cloud-sign-in-discovers-account-kind`, que sigue en `qa`, y usa la misma comprobación que la bienvenida.
