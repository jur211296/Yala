---
id: welcome-cloud-back-leaves-chooser-marked-seen
status: backlog
priority: medium
area: "onboarding, modo-nube"
created: 2026-09-10
updated: 2026-10-08
source: "review adversarial (lente de flujo) de `beacon-routes-only-never-blocks`, 2026-09-10"
---

# Volver atrás desde el sign-in de nube deja el Welcome «ya elegido», y un cierre ahí se salta la comprobación de iCloud

## El síntoma, en lenguaje de usuario

Toco «Ya tengo una cuenta → Apple» (o «Es mi primera vez» con el faro puesto), me arrepiento y vuelvo
atrás al primer nivel del Welcome. Si en ese momento la app se cierra —la mato, o iOS la desaloja mientras
miro otra cosa—, al reabrirla no veo el Welcome: entro directo al onboarding de la cuenta privada, sin
haber elegido nada y sin la comprobación de iCloud del paso 4. Si mi iCloud tiene datos, el espejo los
baja por debajo del onboarding.

## Lo medido (2026-09-10, árbol del PR de `beacon-routes-only-never-blocks`)

- Las entradas al cover de nube marcan `hasShownWelcomeChooser = true` al ENCAMINAR, antes de que la
  persona haya firmado nada: `ContentView.swift`, `onSelectExistingOption` y `onBeaconRoutesToCloudSignIn`.
- El `onBack` de ese cover reabre el Welcome en `.chooser` **sin** devolver el flag a `false`.
- Con el flag en `true`, `presentNextOnboardingScreen` abre `OnboardingView` directamente, y
  `isFreshInstallForNeutralMount` (`SwiftDataConfiguration.swift`) deja de montar neutro: el arranque
  siguiente adjunta el espejo de iCloud.
- Hay dos precedentes de que el flag vuelve a `false` cuando la persona está otra vez eligiendo:
  `onCancelFromStep1` lo resetea, y la rama organizador (G3) no lo marca «para que un abandono a mitad
  pueda volver al Welcome».

## Por qué no se arregló en `beacon-routes-only-never-blocks`

Ese ticket arregló SU camino: «Crear otra cuenta» devuelve el flag a `false` al abrir el chooser, que es
el estado de quien llega ahí por el recorrido normal. El `onBack` es anterior, lo usan todas las entradas
del cover, y cambiarlo es otro objeto.

## Qué hay que decidir antes de tocarlo

- ¿Basta con que `onBack` devuelva el flag a `false`? Comprobar antes que ningún relanzamiento R2 dependa
  de que siga en `true` tras un «volver»: el alta born-cloud lo necesita en `true` DESPUÉS de elegir la
  card, no antes.
- La alternativa de fondo: marcarlo al COMPROMETERSE (firmar, o aceptar el consentimiento) y no al
  encaminar, como ya hace G3.

## Medido en 2.1 (triage 2026-10-08)

- El `onBack` del cover de nube (`ContentView.swift:3046-3050`) sigue sin `hasShownWelcomeChooser = false`.
- Tres entradas marcan el flag al encaminar, antes de firmar nada: `onSelectExistingOption` (`:2717`), `onBeaconRoutesToCloudSignIn` (`:2775`) y también la card de alta en la nube, `onSelectCloudAccount` (`:2750`), que el ticket no nombraba.
- Solo `onCreateAnotherAccount` (`:3041`) lo devuelve a `false`.
- `isFreshInstallForNeutralMount` (`Utils/SwiftDataConfiguration.swift:260-269`) sigue exigiendo `!hasShownWelcomeChooser`.

Triage 2026-10-08: abierto · medium → medium · El onBack del cover de nube sigue sin devolver hasShownWelcomeChooser a false, y las tres entradas lo marcan al encaminar; solo onCreateAnotherAccount lo resetea
