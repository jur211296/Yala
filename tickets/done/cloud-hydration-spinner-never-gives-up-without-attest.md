---
id: cloud-hydration-spinner-never-gives-up-without-attest
status: done
priority: medium
area: "modo-nube, attest, copy"
created: 2026-09-15
updated: 2026-09-17
source: "review adversarial de `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` (2026-09-15)"
---

# «Descargando tus datos…» gira para siempre en un teléfono que no consigue App Attest

## El problema, en lenguaje de usuario

Estreno teléfono, entro en mi cuenta de la nube y la app me dice «Descargando tus datos…» con una ruedecita. No
baja nada nunca, y la ruedecita no para. Desde ayer, además, encima sale un aviso que dice que este teléfono no
puede sincronizar — o sea, la app me está diciendo las dos cosas a la vez.

## Lo medido (leído en el código, sin ejecutar)

`CloudHydrationLogic.showBanner` tiene tres términos y **ninguno mira el attest**
(`Yala/App/Views/Shared/CloudHydrationBanner.swift:36-44`):

```swift
guard !firstPullCompleted else { return false }
return cloudEngineActive && storeLooksEmpty
```

Con el veredicto de attest terminal, los tres se quedan fijos:

- `CloudSyncRuntime.performCycle` devuelve `.accountUnavailable` y el loop pone `state = .stoppedUntilRelaunch`
  (`CloudSyncRuntime.swift:477`; `:488` en `3eed0fb50`), que está **pegado a propósito** (sin loop) hasta relanzar.
  **Corregido el 2026-09-17:** esa parada no la produce el veredicto, sino el presupuesto de la puerta
  (`AttestSyncGate.classify`: un `.unavailable` tras tres fallos seguidos en el mismo proceso). Con los otros fallos
  que cuentan en la racha (`DCError`, `yala_attest_invalid`, `unknownKey`) el motor reintenta para siempre. El spinner
  gira igual en los dos casos, así que la conclusión del ticket se mantiene.
- Así que el primer pull no completa nunca ⇒ `firstPullCompleted` sigue `false`. Y es de sesión de proceso: renace
  `false` en cada arranque, así que relanzar tampoco lo cura mientras el attest siga roto.
- El store sigue vacío ⇒ `storeLooksEmpty` sigue `true`.

El banner es un `.overlay(alignment: .top)` sobre el `TabView` (`ContentView.swift:2968-2970`), así que sale en
**todas** las pestañas, Panel incluido.

**La co-aparición con el aviso de attest está inferida de las cuatro condiciones, no ejecutada.** Las dos se cumplen
a la vez en la misma población: teléfono nuevo o recién adoptado, en `.cloud`, con sesión y sin conseguir attest. A
las 24 h el Panel enseña «Descargando tus datos…» girando y, debajo, «Este teléfono no puede sincronizar tus datos».

**El spinner eterno es PREEXISTENTE** —vive desde que existe el banner de hidratación— y no lo introdujo el aviso;
lo que el aviso hace es volverlo contradictorio a la vista. Antes la persona solo veía la ruedecita y no sabía por
qué; ahora ve la ruedecita y, al lado, la explicación de que no va a pasar nada.

## Lo que hay que decidir (Jürgen)

1. **El spinner se rinde**: `CloudHydrationLogic` gana un cuarto término (el veredicto terminal) y el banner
   desaparece, dejando solo el aviso de attest, que ya explica el estado. Es la opción más simple y la que deja una
   sola voz.
2. **El spinner cambia de cara**: en vez de desaparecer, dice que la descarga está parada y por qué. Cuesta copy
   nuevo en 16 idiomas y solapa con el aviso de attest, que ya lo dice.
3. **Dejarlo**: la población es estrecha (teléfono nuevo + attest roto más de un día). Pero es justo la persona a la
   que el aviso le dice «usa otro teléfono» — acaba de estrenar uno.

**Decidido (2026-09-17, encargo de noche): opción 1.** Las decisiones de diseño, con su porqué, están en el Paso 0 de
`encargos/lanzados/2026-09-17-cloud-hydration-spinner-never-gives-up-without-attest.md`.

## Relación con otros tickets

- `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` — de donde sale, y el otro lado de la contradicción.
- `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest` — desde el 2026-09-16 «Es mi primera vez» no ofrece la
  nube sin App Attest. No cambia la población de este ticket, que entra con una cuenta que ya existe: esa entrada no
  pasa por la puerta.
- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale el veredicto terminal.
- `cloud-hydration-spinner-keeps-spinning-with-the-engine-stopped` (nuevo, low) — el spinner sigue girando cuando el
  motor se para por algo que no es el veredicto.
- `cloud-hydration-banner-does-not-see-data-that-arrives-after-mount` (nuevo, low) — el banner no se entera de los
  datos que llegan después de montar.
- `reentry-counts-as-fresh-install` (en `qa`) — su guion reinstala Yala, y reinstalar borra la racha: este cambio no
  le afecta.

## Lo hecho (2026-09-17)

**Con el veredicto de App Attest terminal, «Descargando tus datos…» ya no gira: queda solo el aviso «Este teléfono no
puede sincronizar tus datos».** Si el attest vuelve y el motor empieza a bajar, la ruedecita reaparece en un segundo.
Sin copy nuevo.

- **El término es el veredicto a secas** (`GroupsAttestStreakStore.isTerminal()`), no la decisión entera del aviso. La
  descarga que el banner explica es el pull del motor, y ése exige token: `performCycle` pasa por su puerta antes de
  subir y de bajar, y un token conseguido borra la racha. Las otras condiciones del aviso dicen a quién le es cierta su
  frase, no si el motor baja algo.
- **Lo lee vivo en su tick de 1 s**, el mismo que ya tenía por `hasCompletedFirstPull`. Con el `@State` y el cableado
  del aviso (`.cloudAttestVerdictWatcher`), el del Panel y el del overlay se refrescarían en momentos distintos, y el
  aviso podía salir con el spinner girando.
- **El veredicto no termina el sondeo** (`CloudHydrationLogic.keepsWatching`, función pura nueva). Una racha heredada
  lo esconde al arrancar, el primer ciclo la borra al conseguir token y la descarga empieza justo después: si el sondeo
  acabara ahí, esa descarga iría sin banner. Antes el bucle salía con el primer `false`.

### Ficheros

- `Yala/App/Views/Shared/CloudHydrationBanner.swift` — cuarto término, `keepsWatching` y el sondeo.
- `YalaTests/CrossAccountEntryGuardLogicTests.swift` — la tabla y dos source-scans (suites `CloudHydrationLogicTests` y
  `CloudHydrationBannerWiringTests`).
- `.claude/rules/gateway-attest.md` — la viñeta: de qué se fía, las tres decisiones y el residual del reloj.
- `qa/coverage-index.json` — el banner entra en `cloud-sync-runtime`, junto al aviso.

### La review adversarial (dos lentes) no tumbó el diseño y corrigió lo mío

1. **Afirmaciones demasiado anchas.** Escribí «una descarga exige token» y «en una reversa tampoco baja nada». Los pulls
   de la migración (`MigrationWorkExecutor.verify` y el drenaje de la vuelta a iCloud) bajan sin la puerta del motor,
   con el attest en `try?`, y no tocan la racha. Ahora todo habla del pull del MOTOR, y el caso raro está escrito.
2. **Un residual sin escribir: el cruce de las 24 h por reloj.** Mi Paso 0 decía que el spinner y el aviso «coinciden
   como mucho un segundo». Con una escritura de la racha es cierto; si las 24 h se cumplen con la app delante nadie
   escribe, el spinner se va y el aviso espera a su siguiente refresco. Ver «Residuales aceptados».
3. **El source-scan no fijaba dónde cuelga el sondeo.** Fijaba el cuerpo del primer `.task`, así que moverlo dentro de
   `if visible {` —donde no arranca nunca— o añadir otro escritor de `visible` dejaba la suite en verde. Hay un segundo
   caso que lo fija.
4. **Un docblock de test prometía de más** («deja de compilar») y el caso «nunca a la vez que el aviso» decía ver algo
   que vive en el cableado. Corregidos.

## Cómo se verificó

- **Build ×2** (`Yala`, `Yala Dev`): verdes, sin warnings en lo tocado.
- **Unit, la suite entera:** 7194 tests en 731 suites, 0 fallos (12 omitidos). Son 6 tests y 1 suite más que en #188,
  justo los nuevos.
- **XCUITest de las áreas tocadas:** 5 casos en 3 clases (`CloudAttestPanelBannerUITests`, `EdgeCasesUITests`,
  `WelcomeFreshStartAlertUITests`), 0 fallos, centinela en 0. Ninguno ve el banner: sin seam de `.cloud`, confirman
  que el overlay no rompe nada.
- **8 mutantes, los 8 en rojo**, cada uno por el test previsto:

  | Mutante | Lo caza |
  |---|---|
  | quitar el término del veredicto en `showBanner` | la tabla, el caso del ticket y el invariante contra el aviso |
  | la vista pasa `attestVerdictIsTerminal: false` | los dos source-scans (la tabla sigue verde) |
  | volver a terminar el sondeo con `guard visible` | los dos source-scans |
  | leer el veredicto una vez, antes del bucle | los dos source-scans |
  | mover el `.task` dentro de `if visible {` | **solo** el scan de dónde cuelga: el del cuerpo sigue verde |
  | un `.onAppear` que escribe `visible` | el scan de dónde cuelga |
  | meter el veredicto en `keepsWatching` con valor por defecto | los dos source-scans (la tabla sigue verde) |
  | `&&` por `\|\|` en `keepsWatching` | la tabla y el caso de falsos positivos |

  Un mutante salió primero sin veredicto: el simulador no lanzó la app («Busy… failed preflight checks») y no corrió
  ningún test. Repetido aislado, rojo.
- **Review adversarial en una pasada, dos lentes** (carreras y ciclo de vida; rule y criterios contra el diff), con cada
  hallazgo comprobado en el código antes de aceptarlo. Una lente midió con dos sondas de SwiftUI el `.task` dentro de
  un `overlay` y la captura de `storeLooksEmpty`.
- `validate-coverage` OK y `docs/TICKETS.md` igual al disco (444).

## Residuales aceptados

- **El cruce de las 24 h con la app delante deja un rato sin ninguna voz.** El spinner lee el veredicto cada segundo y
  el aviso en tres momentos (montar, escritura de la racha, volver a primer plano). Si las 24 h se cumplen por reloj,
  nadie escribe: el spinner se va y el aviso no sale hasta su siguiente refresco. Con el motor reintentando dura como
  mucho un backoff (300 s), porque el rechazo que marca `terminalReported` notifica. Con el motor parado por
  `.unavailable`, hasta el siguiente gesto. Con el reloj hacia atrás justo después del cruce salen los dos hasta ese
  gesto. Cerrarlo pide que el aviso también sondee, y eso es reabrir el #177. Se prefiere el silencio breve a la
  co-aparición.
- **Fuera del Panel y de «Dónde viven tus datos» no queda ninguna voz.** El spinner salía en todas las pestañas y el
  aviso vive en esas dos. Es la opción 1 tal cual: el ticket ya lo sabía al elegirla.
- **En una vuelta a iCloud retomada tras relanzar, el banner puede esconderse mientras el drenaje baja datos**, si el
  veredicto era terminal y el attest vuelve justo entonces. Antes giraba hasta relanzar, también después de bajarlos.
- **Sin XCUITest positivo.** Verlo exige `storageMode == .cloud`, y no hay seam de uitest que lo ponga (precedente del
  #177). Un negativo en `.icloud` no puede fallar: ahí el sondeo sale antes de leer el veredicto.
- **Sin device-QA.** Un iPhone real atesta, y el simulador no crea cuentas en la nube sin el secreto de staging. La
  población de verdad —teléfono en la nube, sin App Attest un día entero— no se monta en ningún dispositivo.
