---
id: cloud-migration-offers-the-cloud-to-a-phone-without-app-attest
status: done
priority: low
area: "modo-nube, attest, migración"
created: 2026-09-16
updated: 2026-09-23
source: "alcance de `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` (2026-09-16): la puerta del attest solo gatea el alta"
qa-status: absorbed
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 absorbed por cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest - misma comprobacion con test de paridad
---

# «Migrar a la nube» se ofrece a un teléfono que no puede conseguir App Attest

## El problema, en lenguaje de usuario

Tengo mis datos en mi iCloud privado y mi teléfono no tiene App Attest. En Ajustes → «¿Dónde viven tus datos?» me ofrecen
«Migrar a la nube». Acepto el consentimiento, confirmo dos veces y la migración no termina nunca, y no sé por qué.

## Lo medido (leído en el código, sin ejecutar)

- Desde el 2026-09-16, «Es mi primera vez» no ofrece la nube a un teléfono sin App Attest
  (`WelcomeAccountChoiceLogic.visibleNewOptions`, con `AppAttestClient.canObtainSessionToken`). Esa puerta solo gatea el
  ALTA, por decisión del encargo.
- La card de la migración no mira el attest: `StorageRowGateLogic.offersCloudMigrationEntry` es
  `remoteEnabled || isEngaged`, y `StorageSettingsView.abortIfCloudEntryClosed` re-mide solo ese término.
- La migración sube con `SyncPushClient` y un `attestProvider` que devuelve `nil` sin token
  (`CloudMigrationController.makeExecutor`, `{ try? await session.attestToken() }`). `/sync/push` exige attest en producción
  (`requireUserAndAttest`, `.claude/rules/gateway-attest.md`).
- `MigrationSnapshotUploader` trata un push que no da 2xx como `.transient`, y el runner reintenta después: el rechazo del
  attest no tiene una clasificación propia.

## Lo inferido, sin ejecutar

- **No deja a nadie atrapado**: según `MigrationStateMachine`, el servidor confirma antes de que se persista el modo, así que
  una subida rechazada no debería cambiar a `.cloud`.
- **Qué ve la persona, no se sabe**: por el `.transient` de arriba lo probable es un reintento sin fin, pero no está medido
  si la pantalla enseña un progreso parado, el error genérico u otra cosa.

## Lo que hay que decidir (Jürgen)

1. Extender la puerta del alta a la card de migración: sin App Attest no se ofrece «Migrar a la nube».
2. Ofrecerla igual y decir por qué falla, con un error propio del attest.
3. Dejarlo: la población está sin medir y la migración no pierde datos.

## Decisión (encargo del 2026-09-16, sesión diurna)

**Opción 1:** sin App Attest, Ajustes no ofrece la nube. **Y la tarjeta entera**: también «Activar la nube en este
dispositivo», la cara que sale en un segundo dispositivo cuando la cuenta ya se migró desde otro (Jürgen, 07:1x, la
recomendada). Las decisiones de detalle, con su porqué, están en el Paso 0 de
`encargos/lanzados/2026-09-16-cloud-migration-offers-the-cloud-to-a-phone-without-app-attest.md`.

## Hecho el 2026-09-16 — opción 1, la tarjeta entera

**Lo que cambia para la persona.** Un teléfono que no puede conseguir App Attest abre Perfil → «Dónde viven tus datos» y
ya no ve la tarjeta de la nube: ni «Migrar a la nube» ni «Activar la nube en este dispositivo». Ve la tarjeta «iCloud
privado» y, si aplica, la sección de Grupos. No hay texto nuevo.

- **Con App Attest no cambia nada**: la tarjeta sigue ahí.
- **Quien ya está en modo nube, o con una migración a la vista (barra, «Reintentar», espera a otro dispositivo),
  conserva su pantalla**: la puerta cierra la entrada, no el panel, igual que el kill de la nube.

**Lo medido al hacerlo (leído en el código, sin ejecutar), y cambia una frase de arriba.** El claim va por `requireUser`,
sin attest, así que pasa: «Migrar a la nube» deja la cuenta **creada** en el servidor antes de intentar subir nada. Lo que
va después —subir el snapshot, o bajar el corpus al adoptar— va por `/sync/push|pull`: sin token el gateway responde 401,
el cliente lo lee como sesión caducada y la migración lo trata como transitorio. La conclusión de «Lo inferido» se
sostiene: el modo no se persiste y nadie cambia a `.cloud`.

**Lo que NO cubre, y dónde queda:**

- **Quien ya tocó la tarjeta sin App Attest antes de este cambio**, y depende de la cara (leído, sin ejecutar). Sin medir
  cuántos son, y sin ticket: la población de teléfonos sin App Attest tampoco está medida.
  - «Migrar a la nube»: conserva su barra de progreso, que no termina. En el servidor queda su cuenta creada y vacía, y
    el claim escribió además el faro en el iCloud del Apple ID (`.writeBeacon`), así que el Welcome de sus otros
    dispositivos los encamina a esa cuenta.
  - «Activar la nube en este dispositivo»: tras el claim la fase vuelve a `notStarted` con el adopt pendiente, y la
    pantalla lo pinta `.idle`. **Pierde la tarjeta y no ve progreso**, mientras el adopt se reintenta en cada arranque,
    en cada vuelta a la app y cada 30 s con la pantalla abierta. Antes tenía un botón que relanzaba el mismo bucle.
  - Con la migración en «No pudimos…», «Reintentar» devuelve la pantalla a `.idle`, ya sin tarjeta.
- Un segundo dispositivo sin App Attest de alguien que ya migró se queda sin ninguna puerta y sin aviso. Es el coste
  aceptado de D1: hoy tiene un botón que no termina.
- **Un colateral, anotado donde toca** (decisión de Jürgen, 2026-09-16): la pantalla de Grupos «Esa cuenta ya tiene Yala
  completo» dice «Se decide en Ajustes, en «Dónde viven tus datos»», y sin App Attest allí ya no hay tarjeta. Queda en
  `groups-block-has-no-route-to-storage-settings`, que va a cambiar esa frase por un botón.
- En una sesión solo-grupos la pantalla dice «iCloud privado» a quien no tiene datos personales, y sin App Attest ya es
  lo único que enseña. Es anterior a este cambio: `groups-only-session-storage-screen-says-data-lives-in-icloud`.
- Entrar con una cuenta que ya existe desde el Welcome: `cloud-hydration-spinner-never-gives-up-without-attest`.

**Lo que se tocó.**

- `StorageRowGateLogic.offersCloudMigrationEntry` gana `isAttestSupported`, sin default:
  `isEngaged || (remoteEnabled && AttestSyncGate.shouldOfferCloudOnly(isAttestSupported:))`. La decisión es la misma
  función que usa el Welcome.
- `StorageSettingsView` le pasa la misma entrada que `WelcomeNewOptionsGate.live`: el seam de XCUITest o
  `AppAttestClient.canObtainSessionToken`. La leen el render de la tarjeta y los dos arranques del flujo.
- Docblocks que dejaban de ser ciertos: `AttestSyncGate`, `AppAttestClient.canObtainSessionToken` y
  `UITestHooks.fakeAttestSupport`. Y «La puerta del alta» de `.claude/rules/gateway-attest.md`.
- Tests: la tabla 2³ y el caso del ticket; scans del término, del `case .idle` y del guard de aborto enteros; paridad de la
  entrada con el Welcome; una sola lectura de la capacidad y una sola declaración; y
  `StorageMigrationAttestUITests`, con el predicado real del simulador y su gemelo con el seam.

**Cómo se verificó.**

- Build ×2 (`Yala` y `Yala Dev`, con sus targets de test), sin warnings en los 7 `.swift` tocados.
- **Unit: la suite entera, 7052 casos en 725 suites, 0 fallos** (7048 de antes y los 4 nuevos).
- **XCUITest: 15 casos** en las 6 clases del cruce con el índice, con el centinela del simulador en 0 y sin reinicios. 14
  en verde. `EdgeCasesUITests.test_extremeMinimumAmountSaves` cayó en el lote (34 s esperando la pantalla de éxito) y pasó
  aislado 2 de 2 (30 s): nunca abre Perfil, así que no puede ejecutar nada de este cambio. Es el flaky de
  `edgecases-extreme-minimum-flaky-under-load`, anotado allí.
- **Mutantes: 13, cada uno en rojo en su test.** En la pantalla: `true` en la capacidad, un término pegado detrás, un
  `#if DEBUG` alrededor de la tarjeta, una segunda lectura en el botón, el guard de aborto invertido, la declaración
  duplicada bajo `#if DEBUG … #else` y el seam solo. En la lógica: quitar el término, invertirlo, aplicárselo al engaged y
  saltarse la decisión compartida. En XCUITest: la puerta viendo siempre App Attest pone rojo el negativo, y quitar el
  seam de Ajustes pone rojo el positivo.
- **Review adversarial de tres lentes** (producto y poblaciones, tests y mutantes, reglas y docblocks). Cazó tres cierres
  de más sin red, que ahora la tienen; «conserva su panel» falso para la cara de adoptar; el colateral de Grupos; un
  docblock de `classify` que afirmaba de más; y que el arreglo de la cabecera «percent 0» era medio ticket ajeno, así que
  se devolvió.
- **Sin device-QA en esta sesión**: el paso en iPhone real está abajo.

## Device-QA — un solo paso, en iPhone real

Sin App Attest lo prueba el XCUITest en el simulador, que es un teléfono sin App Attest. Lo que ningún simulador prueba
es el fallo caro: que un iPhone de verdad pierda la tarjeta. Si pasara, «Migrar a la nube» desaparecería para todo el que
tiene sus datos en iCloud.

**Montaje.** Tu iPhone con el primer TestFlight que lleve este cambio, y Yala con los datos en tu iCloud privado (no en la
nube). No hace falta borrar nada. Si tu iPhone ya está en la nube, este paso no aplica tal cual: úsalo después del paso en
iPhone de `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` eligiendo «Tu cuenta en tu iCloud privado».

1. Abre Yala con conexión y toca tu foto de perfil, arriba en el Panel.
2. Baja hasta «Dónde viven tus datos» y tócala.
   - Si la tarjeta de arriba dice «Tu cuenta en la nube», tu iPhone ya está en la nube: para aquí, el paso no aplica.
   - Si en vez de tarjetas ves una barra de progreso, «Reintentar» o una espera a otro dispositivo, hay una migración a
     medias: tampoco aplica.
3. **Esperado:** arriba, la tarjeta «iCloud privado»; más abajo, «Migrar a la nube» con el botón «Activar la nube».
   - Si otro dispositivo tuyo ya migró, en su lugar sale «Activar la nube en este dispositivo» con «Activar en este
     dispositivo». También vale.
   - **No toques el botón**: crearía tu cuenta de verdad en producción y empezaría a mover tus datos.
   - **FAIL** si no aparece ninguna de las dos tarjetas.

## Relación con otros tickets

- `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` — la puerta del alta, de donde sale.
- `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest` — las dos salidas al alta de la pantalla de entrar.
  Desde el 2026-09-16 pasan por la puerta, y desde este ticket también la tarjeta de Ajustes. El claim de
  `MigrationWorkExecutor` se sigue alcanzando sin ella desde el Welcome (`startAdoptWithExistingSession`), al entrar con
  una cuenta que ya existe: eso queda fuera a propósito.
- `cloud-hydration-spinner-never-gives-up-without-attest` — lo que ve quien entra con una cuenta que ya existe, que la
  puerta tampoco cubre.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Ajustes usa la misma comprobación de App Attest que la bienvenida, con un test de paridad (`StorageMigrationAttestUITests`). Si la bienvenida ofrece la nube en el iPhone, esta también: lo comprueba `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`, que sigue en `qa`.
