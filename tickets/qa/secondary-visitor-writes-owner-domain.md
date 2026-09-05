---
id: secondary-visitor-writes-owner-domain
status: qa
created: 2026-08-12
updated: 2026-09-05
source: YalaWiki/Bugs/secundaria-la-visita-escribe-en-el-dominio-del-dueno.md
---


# De visita en el móvil de otra persona: seis vías escriben en el dominio del DUEÑO

## El síntoma, en lenguaje de usuario

Presto mi móvil a alguien para que entre a Yala con su cuenta (sesión de invitada). Al terminar, **mi
Yala no vuelve a estar como estaba**: mi nombre y mi divisa pueden haber desaparecido, mi barra de
pestañas quedó como la dejó ella, mi permiso de Grupos se borró y vuelvo a ver la pantalla del consent.
En el peor caso, **mis grupos desaparecieron del móvil**.

Y si ella tocó «Es mi primera vez → privacidad total» desde el Welcome, **nada la detuvo**.

## Dónde muerde hoy

| Entorno | Estado |
|---|---|
| Producción | **DARK** — `SECONDARY_SESSION_ROLLOUT_PERCENT = "0"`, el recorrido entero es inalcanzable |
| Staging / `Yala Dev` | **100 %** — alcanzable end-to-end |

⇒ no es una urgencia de hotfix, **es un bloqueante del encendido**. El día que el percent suba, sube con
esto dentro.

## Lo medido

### 1 · Dos señalizadores escriben DIRECTO al iCloud del dueño, sin un solo guard

**Re-verificado a mano** (`Yala/App/Services/PreferenceSyncService.swift`):

```
481  func signalWipeInitiated() {
483      iKV.set(timestamp, forKey: WipeKey.remoteWipe)
495  func signalOnboardingCompleted() {
497      iKV.set(timestamp, forKey: WipeKey.remoteOnboarding)
```

Ninguno de los dos consulta el modo ni `SecondarySessionStore.isActive()`. El `iKV` es el
`NSUbiquitousKeyValueStore` **del Apple ID del dispositivo**, que es el del dueño — la invitada no cambia
la cuenta de iCloud del móvil. Están **fuera del switch** que sí gobierna el resto del servicio.

### 2 · La rama «privacidad total» del Welcome no tiene ninguna puerta

La rama del organizador («Vengo por un grupo → Crear mi primer grupo») se bloquea con tres términos en
orden (`GroupsOrganizerGateLogic.swift:78`: canal → **visita** → datos ajenos). La rama «Soy nuevo →
privacidad total» **no pasa por nada equivalente**:

- `WelcomeFlowContainer.swift:287-300` va directo al portal `leaveWelcome`, que solo comprueba el mirror.
- El portal solo interpone relanzamiento si el mount fue `.neutralNoMirror`; en secundaria es
  `.secondaryCloudSession` ⇒ **pasa de largo** (`WelcomeMirrorRelaunchLogic.swift:94-99`).
- El alert de borrado se decide con `checkHasExistingData` (`ContentView.swift:1086`), que mide el
  **store montado** — en secundaria, el de la invitada, vacío ⇒ **ni siquiera salta**.
- Aguas abajo, `OnboardingView.completeOnboarding` (`:1779-1794`) escribe cinco preferencias más
  `hasCompletedOnboarding` en el dominio del dueño, y `OnboardingResetHelper` (`:34-46`) le borra
  `userName` y `defaultCurrencyCode` y escribe `""` en los dos del iKV.

**El chooser de 3 ramas SÍ es alcanzable con sesión secundaria viva**, y hay dos productores medidos:
«Vaciar mis datos» (sin guard, retira `hasCompletedOnboarding`/`hasShownWelcomeChooser` del
`UserDefaults.standard` compartido) y el propio choke-point de la rama organizador, que remonta el cover
**en** la puerta — desde ahí dos «Volver» llegan al chooser (`ContentView.swift:981-988`).

### 3 · El alta born-cloud le escribe el FARO al dueño

**Re-verificado a mano** (`Yala/Services/CloudSync/BornCloudSignUpService.swift`):

```
249  if claimState == .created {
250      beacon.writeCloudAccountLinked(
251          provider: sessionProvider, accountSub: userID, now: now())
```

Sin término de sesión secundaria. El hermano de esta escritura **sí lleva el cinturón**:
`MigrationWorkExecutor.swift:455-465` suprime el faro en secundaria y declara el caso «inalcanzable por
diseño». Aquí es alcanzable: «Soy nuevo → cuenta en la nube» desde el chooser. El faro vive en el iCloud
KV del dueño ⇒ **sus otros dispositivos quedarían encaminados a la cuenta de la invitada**.

### 4 · Con el canal de Grupos APAGADO, la invitada monta el store de grupos del DUEÑO

**Re-verificado a mano** (`Yala/Utils/SwiftDataConfiguration.swift`):

```
458  static func decide(flagOn: Bool, secondaryActive: Bool) -> GroupsStoreDecision {
459      (flagOn && secondaryActive) ? .secondary : .primary
```

Con el canal apagado monta el **primario**. Y `checkHasExistingData` cuenta `SplitGroup` sobre el
contexto montado ⇒ el alert de borrado del Welcome salta **con los grupos del dueño**, y confirmarlo
llama a `wipeLocalGroupsDomain`, que borra todas las filas `Split*` del store montado y sella el dominio
Grupos en las preferencias del dueño (`DataWipeService.swift:283-287`).

> La nota del panel `degradado-ajustesdueno` del Atlas («con el canal apagado se filtra») describe el
> **tab**, no el **store**. Es una descripción incompleta del mismo hecho.

### 5 · La curación de entrada es one-shot y el vaciado en sesión la desarma

`performSecondaryEntryTasksIfNeeded` (`SwiftDataConfiguration.swift:875-891`) repone
`hasCompletedOnboarding`/`hasShownWelcomeChooser`, y su propio docblock nombra el daño: «sin el healing,
el boot mostraría el Welcome sobre el store secundario vacío y un re-sign-in caería en el adopt CLÁSICO,
que escribe el PAR global `.cloud`+`mirrorOffArmed` del dueño».

Pero está gateada por el marker `entryPurgeDone`, **excluido del barrido de prefs**
(`DataWipeService.swift:469-470`, el dominio `cloudSync.*` no se toca) ⇒ tras un vaciado en sesión los
flags caen y **nadie los repone**, ni en ese arranque ni en los siguientes.

### 6 · La purga de frontera borra el permiso de Grupos del DUEÑO

`SecondarySessionBoundaryPurge.swift:46-49` llama a `GroupsConsentState.clear()` en **ambas** fronteras,
sin distinguir de quién es el registro ⇒ el dueño vuelve a ver la pantalla del permiso.

### 7 · Y el test que debía cubrir todo esto mira el inventario equivocado

`YalaTests/CloudSync/SecondaryOwnerDomainGuardsTests.swift:214-247` busca los escritores de **una** key
(`set(string: OnboardingMode` / `setSynced(OnboardingMode`), encuentra dos y comprueba que los dos llevan
guard. `OnboardingView.completeOnboarding` **no escribe el modo** — escribe otras cinco preferencias por
el mismo servicio — así que queda fuera del conteo y su ausencia de guard no rompe nada.

Es literalmente la regla que ese mismo fichero escribió («el inventario que el escáner mira tiene que ser
el inventario que la función escribe»), fallando una capa más arriba. Misma familia que el conteo por
cliente de `AttestWiringTests`.

## Efectos colaterales medidos (mismo recorrido, misma causa)

- **El onboarding privado en secundaria promete categorías y no crea ninguna**: `completeOnboarding`
  llama a `seedCategoriesIfNeeded`, y el seed retorna en su primera línea si hay sesión secundaria
  (`CategorySeed.swift:375-378`, cinturón M1). Pregunta, responde que sí, deja el store vacío.
- **Hay DOS entradas al onboarding privado y solo una lleva el alert de borrado**: el «Empezar desde
  cero» de la pantalla de restauración (`ContentView.swift:668-676`) llama a la misma limpieza y abre el
  onboarding **sin consultar `hasExistingData` y sin alert**.
- **La barra de pestañas que edite la visita se escribe durable en el dominio del dueño**
  (`TabBarConfigView.swift:265` → `AppPreferences.swift:1182-1188`).
- **`FullModeActivationView`**: sus escrituras de `usageFocus` y de la config del tab bar no llevan guard
  y el borrado de salida no las repone. *(No medido: si la vista es alcanzable en secundaria.)*

## Lo NO medido (no escribir como hecho)

- Si el vaciado en sesión de la invitada empuja tombstones a **su** cuenta nube (y le borra los datos en
  sus propios dispositivos). La hoja de alcance lo promete; el drain de este camino no se midió.
- Si borrar las filas `Split*` del store del dueño (canal apagado) se queda en local o llega a algún
  canal. El store es `cloudKitDatabase: .none` y el transporte CloudKit de Grupos ya no existe, pero la
  interacción con el outbox/drain en esa configuración no se midió.
- Qué escribe exactamente el adopt clásico disparado desde una sesión secundaria (par, faro, journal).
- Si `PreferenceSyncService` sigue observando el iKV del dueño en `.localOnly` — una señal de wipe remoto
  de otro dispositivo del dueño podría vaciar la sesión de la invitada y reabrirle el Welcome por un
  tercer camino.
- Si en un iPhone compartido la invitada puede completar «Entrar con Apple» con identidad distinta a la
  del Apple ID del dispositivo (SIWA usa la cuenta del OS). Google sí sería plausible.

## La decisión pendiente (no es un fix mecánico)

El patrón «un guard más por cada escritor» ya falló una vez aquí: son **seis vías y contando**, y la
séptima entrará sin que nadie la vea. Hay dos formas de atacarlo y son distintas en coste y en garantía:

1. **Guard por escritor** — barato, incremental, y el mismo modelo que ya se le escapó a
   `completeOnboarding`. Exige rehacer el source-scan para que cuente **el inventario que la función
   escribe**, no una key.
2. **Frontera en el servicio** — que `PreferenceSyncService` (y el iKV) **no puedan** escribir en
   secundaria salvo por una puerta explícita. Convierte el problema de «acordarse en N sitios» en «un
   sitio que decide». Es lo que la regla de `gateway-attest.md` llama la guard del handler.

Mi lectura: **(2) para el iKV y el dominio de prefs, (1) solo donde (2) no llegue**, porque el inventario
va a seguir creciendo. Pero es decisión de owner.

## Criterio de hecho

- Un test que enumere **todas** las escrituras a `UserDefaults.standard` y al iKV alcanzables con
  `SecondarySessionStore.isActive() == true`, y exija guard o excepción declarada con su porqué. Con
  **conteo esperado** (el molde de `AttestWiringTests`), o el escáner volverá a mirar el inventario
  equivocado sin que nadie se entere.
- **Mutación obligatoria**: quitar un guard tiene que dar exit 65. Si solo cae al añadir uno nuevo, el
  test comprueba la forma y no el fondo.
- La rama «privacidad total» del Welcome, bloqueada o encauzada, con copy propio (no el prestado del
  guard de sign-in — ver [[welcome-copy-acusa-al-dueno-de-traer-datos-ajenos]]).
- E2E en staging (donde el percent está al 100): entrar de visita, tocar las seis vías, cerrar sesión y
  comprobar que el dueño recupera nombre, divisa, tab bar, consent y grupos.

## Relacionados

- [[welcome-empiezo-de-cero-borra-antes-de-preguntar-y-falla-mudo]] — el mismo alert, otro humano
- [[secundaria-salida-de-la-invitada-bloqueo-permanente-y-outbox-de-grupos]] — la salida de este recorrido
- [[prefs-cinco-keys-synced-suben-y-no-vuelven]] — el mismo canal de prefs, otro defecto

## Implementación · parte 1 de N (2026-08-12, `25a36be2`)

Decisión del owner: **frontera en el servicio**, opción (2) del §«decisión pendiente».

### Lo que se cerró

`Yala/Services/CloudSync/OwnerKeyValueStore.swift` (nuevo) es la **única puerta de escritura al
`NSUbiquitousKeyValueStore`**. `NSUbiquitousKeyValueStore.default` ya no se nombra en ningún otro
fichero del árbol salvo tres LECTORES declarados con su porqué (`ContentView`,
`PanelPreferencesMigration`, `AppPreferences`). Cubre las **vías 1 y 3** del ticket.

La vía 3 (el faro de `BornCloudSignUpService`) quedó cerrada **sin tocar su llamador**, porque el
default del init de `CloudBeacon` es la puerta. Eso es exactamente lo que un guard por escritor no
daba, y es el argumento a favor de la opción (2) hecho evidencia.

### Y la tesis del ticket se queda CORTA: eran OCHO vías, no seis

Al inventariar todos los escritores del iKV aparecieron dos que no estaban en ningún sitio:

| Vía nueva | Coordenada | Daño |
|---|---|---|
| **7ª · el idioma** | `L10n.swift:59-65` (`LanguageManager.overrideLanguage`) + el remap de alias en `:150` | El idioma que elige la invitada viaja al Apple ID del dueño y le cambia la app en TODOS sus dispositivos |
| **8ª · el interruptor maestro de avisos** | `ScheduledPaymentNotificationService:445` | Espeja en el iKV del dueño un one-shot (`masterToggleFlipKey`). Quemado con la decisión de otra persona, **no vuelve**: su propio docblock dice que el espejo existe para que una reinstalación no re-flipee un OFF deliberado |

⇒ «la séptima entrará sin que nadie la vea» era optimista: ya habían entrado dos.

### El escáner se pagó el primer día

`OwnerKeyValueWiringTests` cazó un fallo que yo mismo acababa de introducir: pasar la puerta como
`object:` de `NotificationCenter.addObserver` registra un observer **que no dispara nunca** (ese
parámetro filtra por identidad del EMISOR), así que las preferencias llegadas de otro dispositivo
habrían dejado de aplicarse en silencio. La puerta expone `notificationSource` para eso.

### Verificación

7 tests nuevos (tabla · comportamiento con store espía que cuenta ESCRITURAS · source-scan con conteo
por escritor, molde `AttestWiringTests`). **Mutación a exit 65 verificada**: quitar el `guard` de un
setter del wrapper deja `secondarySessionWritesNothing` en rojo. Gate: build ×2, 53 unit en 8 suites,
2 XCUITest, índice OK.

---

## Vía 6 · REFUTADA en su causa (medido el 2026-08-12)

El ticket dice: «`SecondarySessionBoundaryPurge:46-49` llama a `GroupsConsentState.clear()` en ambas
fronteras ⇒ el dueño vuelve a ver la pantalla del permiso». **La coordenada es exacta y la conclusión
es falsa para el caso dominante**, por C1:

1. El consent vive en `groups_consents` (Supabase), **append-only por el GRANT** (sin `update` ni
   `delete`), y la copia local es un snapshot **sellado con el `userID` dentro**.
2. `AppBootstrapper:531` llama `GroupsConsentRegistrar.handleSignIn()` **en cada arranque, sin gate**,
   y ese método hace `refreshFromServer()` → RPC `groups_consent_state` → `applyServerState` re-sella
   el snapshot local. ⇒ **el dueño con sesión Yala viva no vuelve a ver la pantalla**: el coste real es
   un round-trip de red, no una regresión de UX.

**Lo que SÍ queda vivo, que es un caso distinto y más estrecho del que el ticket describe:** el
consent **LEGACY** (aceptado antes de C1) se guarda sin sello (`userID == nil`) y
`GroupsConsentDecisionLogic:60` lo da por bueno **para cualquiera** — el `if let sealed` no entra
cuando el sello es nil, y su docblock (`:37`) lo dice a propósito. Por tanto:

- en la frontera de **ENTRADA** el `clear()` es **necesario**: sin él la invitada hereda el consent no
  sellado del dueño;
- y es **destructivo** para un dueño que aceptó antes de C1 y **no tiene sesión Yala**, porque sin
  `sub` no hay nada con lo que re-sellar y `refreshFromServer` es no-op ⇒ ese sí vuelve a ver la
  pantalla, y no lo repara nada.

**Propuesta (no implementada, decisión de owner)**: en la frontera de entrada, **custodiar** las dos
keys legacy en un slot que `GroupsConsentDecisionLogic` no lea (p. ej. `groups.consent.legacy.custody`)
en vez de borrarlas, y reponerlas en la frontera de salida. Cierra las dos mitades sin tocar el sello.
No lo he hecho porque toca una frontera de consentimiento —territorio RGPD— y el daño actual es «ver
una pantalla de permiso otra vez», no pérdida de datos.

---

## Lo que sigue ABIERTO de este ticket (medido, no tocado)

| Vía | Estado | Por qué no se cerró esta noche |
|---|---|---|
| **2 · la rama «privacidad total» sin puerta** | ABIERTA | Es un cambio de PRODUCTO, no un guard: hay que decidir si se bloquea (con copy propio, molde de `welcome.groups.secondary*`) o se encauza. El ticket ya lo pide con copy propio; falta la decisión de qué se le ofrece a la invitada |
| **4 · el store de Grupos con el canal apagado** | ABIERTA | `SwiftDataConfiguration.decide(flagOn:secondaryActive:)` monta el PRIMARIO cuando el canal está off. Cambiarlo no es un guard: hay que decidir qué monta una sesión secundaria sin canal de Grupos —¿un store secundario vacío, o ninguno?— y esa elección cambia lo que ve la invitada en el tab |
| **5 · la curación one-shot que el vaciado desarma** | ABIERTA | `entryPurgeDone` queda fuera del barrido (`cloudSync.*` no se toca). El fix es pequeño pero cambia el contrato de idempotencia de `performSecondaryEntryTasksIfNeeded`, y quería medir antes si re-armarlo puede correr dos veces en el mismo arranque |
| **7 · el test que mira el inventario equivocado** | ABIERTA para `UserDefaults`, **cerrada para el iKV** | `OwnerKeyValueWiringTests` es el inventario correcto del iCloud KV. El de `UserDefaults.standard` sigue sin existir, y es la otra mitad (abajo) |

## La otra mitad de la frontera, que sigue abierta y hay que decidir

La puerta cubre el **iCloud KV**. El otro medio por el que la sesión secundaria toca el dominio del
dueño es el **`UserDefaults.standard`**: `PreferenceSyncService` escribe su espejo local **SIEMPRE**,
también en `.localOnly` (`local.set` corre antes del `switch behavior`), y `local` está **hardcodeado a
`.standard`** — lo dice la propia regla de C1 en `swiftdata-cloudkit.md`: «no existe ningún dominio de
`UserDefaults` por sesión […] la caché de una visita cae SIEMPRE en el dominio del dueño».

Ahí es donde vive lo que el ticket cuenta en su §2 (`completeOnboarding` escribiendo cinco preferencias
más `hasCompletedOnboarding`) y en sus efectos colaterales (la barra de pestañas, `usageFocus`).

**La pregunta que necesito que respondas**: ¿se ataca con un **dominio de preferencias por sesión**
(`UserDefaults(suiteName:)` sellado con el `sub` de la invitada, que es el fix de raíz y hace
imposibles todas las vías de golpe) o con **guards por escritor** sobre el inventario correcto?

Lo que he medido para que la decisión sea informada:

- el dominio por sesión es el fix de raíz, pero `UserDefaults.standard` se lee **directamente** en
  cientos de sitios (`@AppStorage`, `AppPreferences`, seams de tests), así que cambiar `local` no basta:
  habría que decidir qué pasa con cada lector, y un lector que se quede en `.standard` leería las prefs
  del dueño mientras el escritor escribe en el dominio de la invitada — que es **peor** que hoy, porque
  hoy al menos son coherentes entre sí;
- los guards por escritor son el modelo que ya se le escapó a `completeOnboarding` **y** a las dos vías
  que descubrí esta noche;
- una tercera vía que no está en el ticket: dejar `local` en `.standard` pero **restaurar** en la
  frontera de salida un snapshot de las keys del dueño tomado en la de entrada. No hace imposible el
  daño, pero lo hace **reversible**, que es lo que hoy no es.

No la he tomado yo porque las tres tienen coste y alcance muy distintos, y la primera es un proyecto,
no un fix de una noche.


---

# Decisiones del owner (2026-08-13)

## La otra mitad de la frontera → opción (a), en su propio item

**`UserDefaults` con dominio POR SESIÓN**, el fix de raíz. Descartadas las otras dos: el guard por
escritor es el modelo que ya se escapó tres veces (a `completeOnboarding`, al idioma y al interruptor
de avisos), y el snapshot-y-restaura deshace el daño en vez de impedirlo.

No cabe en una sesión de arreglo de bugs ⇒ **[[prefs-dominio-por-sesion-secundaria]]** (Backlog), con
el alcance escrito. Lo que hay que entender antes de abrirlo: **el riesgo no está en el escritor, está
en los lectores** — un lector que se quede en `.standard` mientras el escritor va al cajón de la
invitada produce una app incoherente durante toda la visita, que es peor que el estado actual.

## La vía 4 es PEOR de lo que este ticket decía (re-medido el 2026-08-13)

El ticket la cuenta como «la invitada monta el store de grupos del DUEÑO». Medido, la cadena completa
es más grave, y conviene tenerla escrita porque la pregunta que la destapó fue «¿por qué hablamos de
un store de grupos si Grupos vive en el backend al 100 %?».

**Porque «backend al 100 %» dice dónde vive la VERDAD, no dónde vive la COPIA.** `YalaGroups` es un
store SwiftData local con `cloudKitDatabase: .none` —nunca fue CloudKit, no murió con el transporte—
que el pull materializa y que la app lee para pintar: no hay lecturas en vivo contra Supabase. Es un
archivo real en el disco de cada teléfono.

La cadena, con sus tres eslabones:

1. `GroupsStoreDecision.decide(flagOn:secondaryActive:)` monta el **primario** cuando el canal está
   apagado (`(flagOn && secondaryActive) ? .secondary : .primary`).
2. La invitada **no llega a ver** esos grupos —el tab está cerrado en secundaria con el canal
   apagado— pero `checkHasExistingData` **los cuenta**, así que el alert de borrado del Welcome le
   salta con los grupos del dueño dentro.
3. Si lo confirma, `wipeLocalGroupsDomain` borra las cinco tablas `Split*` **y conserva el cursor a
   propósito** (`groupCursorsJSON` es la barrera anti-fuga del bug `31dded30`).

⇒ **con el cursor en su marca alta el servidor no reenvía nada**: el dueño se queda sin sus grupos en
ese teléfono aunque estén intactos en Supabase, y **no se auto-repara**. No es una filtración
cosmética: es pérdida local permanente de la copia.

**Y «canal apagado» con el rollout al 100 % es alcanzable**, medido: `groupsBackendEnabled` es
`compilado && CloudRemoteFlags.groupsBackendEnabled`, y `absentDefault` es **`false` en producción**
(`CloudRemoteConfig.swift:120`) ⇒ basta un arranque anterior al primer fetch de remote-config (que se
refresca como mucho cada 6 h) o un kill switch — que es justo la respuesta operativa a un incidente.

**Extraída a ticket propio**: [[secundaria-canal-apagado-la-visita-borra-los-grupos-del-dueno]], con
la cadena entera, el fix en cuatro piezas y —lo que la hace inusual en esta familia— una receta para
REPRODUCIRLA en simulador. Va después de [[prefs-dominio-por-sesion-secundaria]], porque comparte los
dos ficheros principales.

**Consecuencia para el orden de ataque**: la vía 4 sube de prioridad. Es la única de las que quedan
que destruye algo que no vuelve solo, y su arreglo probablemente no sea «montar el secundario» sino
**que el detector del Welcome no cuente —ni el wipe borre— un store que no es de esta sesión**.

migrated from YalaWiki Bugs/secundaria-la-visita-escribe-en-el-dominio-del-dueno.md @ 1934e8ad

---

## 2026-09-03 (noche) · el encauzamiento YA EXISTE, y lo que queda es otra cosa

**Decisión del owner (2026-09-02): «encauzar», no bloquear** — que la visita pueda usar Grupos con su
propio dominio aislado. Al ir a construirlo, medido contra `ae4d394f`: **ese dominio aislado ya está
construido, cableado y verde.** La decisión sigue siendo la correcta; lo que cambia es que casi todo
su coste ya está pagado.

### Lo que ya existe (verificado en el árbol, no leído del ticket)

`Yala/Services/CloudSync/SessionDefaults.swift` crea un cajón de `UserDefaults` por sesión
(`yala.session.<sub>`, `:95-99`), lo resuelve **en cada acceso** (`:116`, deliberadamente no cacheado),
lo siembra al entrar y lo destruye al salir. Y sus tres consumidores grandes ya lo usan:

| Consumidor | Coordenada | Verificado |
|---|---|---|
| Todos los `@AppStorage` del árbol | `Yala/App/YalaApp.swift:116` — `.defaultAppStorage(SessionDefaults.current)` | ✅ |
| `AppPreferences` (sus 76 properties) | `Yala/App/AppBootstrapper.swift:40` | ✅ |
| `PreferenceSyncService` | `Yala/App/Services/PreferenceSyncService.swift:87` (**computed**, no `let`) | ✅ |

Su ticket, `prefs-domain-per-secondary-session`, está en `tickets/qa/` porque sus cuatro fases están
hechas: lo que le falta es el E2E en device del owner, no código.

⇒ **De las ocho vías del inventario, la mayoría ya no escriben en el dominio de la dueña.** Este
ticket describe un mundo anterior a ese trabajo y hay que leerlo con esa corrección delante.

### Lo que SIGUE vivo, y es un defecto NUEVO que este ticket no describía

**Un par escritor/lector partido en `hasCompletedOnboarding`:**

| Rol | Coordenada | Dominio al que va |
|---|---|---|
| Escritor | `Yala/App/Views/Onboarding/OnboardingView.swift:1823` | **de la DUEÑA** (`UserDefaults.standard`) |
| Lector | `Yala/App/ContentView.swift:16` (`@AppStorage`) | **de la VISITA** (el cajón, vía `:116` de `YalaApp`) |
| Lector | `Yala/App/AppBootstrapper.swift:994` · `:2436` · `:2451` | **de la DUEÑA** |

La key está declarada como de DISPOSITIVO (`SessionPreferenceKeys.swift:195-199`), así que el escritor
casa con su clasificación; el problema es que **hay lectores en los dos dominios a la vez**. En sesión
secundaria: la visita termina el onboarding, su flag sigue en `false` y el Welcome puede reabrirse;
y la dueña recibe una escritura cruzada.

Es exactamente el modo de fallo que la cabecera de `SessionDefaults` (`:20-24`) declara **peor que el
bug original**, aquí invertido. Y **ningún escáner lo ve**: `hasCompletedOnboarding` no está en la
lista `watched` de `YalaTests/CloudSync/SessionPreferenceKeysTests.swift`.

### Por qué no se arregla en esta sesión

**No es «alinear una línea»: es decidir en qué dominio vive la key, con un escritor y cuatro lectores
repartidos entre los dos.** Mover sólo uno empeora la incoherencia, y la elección cambia el arranque
de la app —qué ve la dueña y qué ve la visita al abrir—. Eso es del owner, y de madrugada no se
decide. Las dos salidas, para que la decisión no haya que reconstruirla:

1. **El escritor baja al cajón** (`SessionDefaults.current` en `:1823`) y los tres lectores de
   `AppBootstrapper` también. Coherente con que cada sesión tenga su onboarding.
2. **El lector de `ContentView:16` sube a `.standard`** (dejando de ser `@AppStorage` implícito).
   Coherente con «es una key de dispositivo, no de persona».

Sea cual sea, **la key entra en el `watched` del escáner en el mismo commit**: es la lección de la
vía 7 aplicada a sí misma.

### Lo demás que queda, ya sin sorpresas

- La rama «privacidad total» sigue **sin puerta** (`WelcomeFlowContainer.swift:289-293`), mientras la
  rama organizador sí la tiene. Con el dominio por sesión ya montado, la pregunta de producto es más
  estrecha de lo que era: no «cómo aislarla» sino «qué se le enseña».
- La segunda entrada al onboarding privado sigue **sin alert** (`ContentView.swift:678-686`).
- Vía 6 (consent legacy) **no la cerró** el dominio por sesión: `GroupsConsentState.defaults` es
  `.standard` a pelo (`GroupsConsentState.swift:72`). Va aparte, con su propia decisión.

---

## DECISIONES DEL OWNER · 2026-09-03 — las dos que quedaban

### 1 · `hasCompletedOnboarding` vive en el cajón de cada sesión (opción 1)

**Aprobada la opción 1**: el escritor de `OnboardingView.swift:1823` baja a `SessionDefaults.current`
y los tres lectores de `AppBootstrapper` bajan con él. Coherente con que cada persona tenga su propio
onboarding: la visita hace el suyo sin marcar el de la dueña, y al revés.

**La condición que el propio ticket puso a las dos salidas sigue en pie y no es opcional**: la key
entra en el `watched` del escáner **en el mismo commit**. Un escritor movido sin su lector —o sin la
red que avisa -de que se han vuelto a separar— es exactamente el estado del que se sale.

Descartada la opción 2 (subir el lector de `ContentView:16` a `.standard`). Era defendible —«es una
key del dispositivo, no de la persona»— pero deja a la visita heredando el onboarding de la dueña.

### 2 · Consent legacy: custodiar y reponer

**Aprobada la propuesta del ticket** (la de la vía 6, hoy sin implementar): en la frontera de entrada
las dos keys legacy se **custodian** en un slot que `GroupsConsentDecisionLogic` no lee, y se
**reponen** en la frontera de salida. No se borran.

**Por qué no borrarlas, que era la alternativa simple**: la dueña volvería a ver una pantalla de
permiso que ya aceptó, y como responsables del tratamiento perderíamos la prueba de ese
consentimiento. El repo ya tiene precedente en esa dirección — el registro de consentimiento es
append-only por diseño (C1, 2026-08-11).

**Los dos riesgos que el ticket NO traía y que la implementación tiene que resolver**, medidos el
2026-09-03 y repetidos aquí porque son la parte difícil:

1. `GroupsConsentState` escribe en `.standard` **a pelo** — el dominio por sesión no lo cubrió, así
   que custodiar «lo que resuelva la puerta» no basta.
2. La reposición cae en la ventana donde un borrado mal dirigido **arrasaría el `UserDefaults` entero
   de la dueña**. La destrucción del cajón va con el `sub` por parámetro explícito y ANTES de
   `SecondarySessionStore.clear`, como ya documenta la regla de `swiftdata-cloudkit.md`.

### Qué queda de este ticket

Con esto **no quedan decisiones pendientes aquí**: lo que sigue abierto es código. La rama «privacidad
total» del Welcome (`WelcomeFlowContainer.swift:289-293`) es diseño de producto y sigue sin decidirse,
pero no bloquea a las dos de arriba.

---

# IMPLEMENTADO · 2026-09-05 — las dos decisiones del 3-sep, en código

Las dos decisiones que este ticket dejó tomadas y sin escribir están hechas y verdes. Lo que queda
del ticket es **device-QA**, no código: por eso pasa a `qa/`.

Commits: `258a90c3` (la key al cajón) · `833b9f40` (custodia del consent).

## Decisión 1 · `hasCompletedOnboarding` vive en el cajón de cada sesión

**Y el inventario del ticket se quedaba corto otra vez.** Decía «un escritor y cuatro lectores»;
medidos contra el árbol eran **tres escritores y siete lectores** en `.standard`, repartidos por
seis ficheros:

| Rol | Coordenada | Qué pregunta o afirma | Dónde acabó |
|---|---|---|---|
| Escritor | `OnboardingView.swift` · `completeOnboarding` | «esta persona terminó su onboarding» | **cajón** |
| Escritor | `ContentView.swift` · `completeOnboardingAsRestoreSkip` | lo mismo, por el camino de restauración | **cajón** |
| Escritor | `ContentView.swift` · `onSecondaryEntryFlagsMarked` | la ventana de ENTRADA | **se queda en `.standard`** |
| Lector ×3 | `AppBootstrapper` · `checkForICloudMismatch` · `seedDefaultNotifications` · `checkForPendingSharedImage` | alert de restart · seed de avisos · imagen compartida | **cajón** |
| Lector | `ContentView.swift` · el gate del organizador | «¿ya vio un educativo de Grupos?» | **cajón** |
| Lector | `GroupsContainerView.swift` | el gemelo del anterior | **cajón** |
| Lector | `RouterEntryGate.swift` · `readinessProvider` | readiness del router | **cajón** |
| Lector | `GroupBackendInviteEntryHandler.swift` | routing del invitado fresco | **cajón** |

**Y las coordenadas de esta tabla se escribieron por NOMBRE de función a propósito.** La primera
versión citaba `AppBootstrapper.swift:1050 / :2446 / :2461` — que eran las líneas del árbol de ANTES
del commit; los comentarios que el propio commit añade las desplazaron a `:1053 / :2484 / :2502`
antes de que el ticket llegara a leerse. Es exactamente el defecto que el `CLAUDE.md` de este repo
persigue («tres coordenadas de un informe apuntaban a líneas anteriores al propio commit que las
medía»), cometido en el ticket que lo cita. Los nombres de función no se desplazan.

Los cuatro lectores que el ticket no nombraba **no eran opcionales**: la propia regla que este
ticket puso («escritor y lectores viajan en el mismo commit») los obliga, y dos de ellos —el gate
del organizador y su gemelo del tab— tienen escrito en el código que si discrepan «el tab anunciaría
"ver cómo funciona" y el tap no presentaría nada».

**El único `.standard` que queda tiene ahora su porqué en el código**: corre en la ventana de
entrada, con el descriptor recién activado y el cajón todavía sin existir, y es de ahí de donde
`SessionDefaults.seededDeviceKeys` copia al nacer el cajón. Bajarlo deja a la visita en el Welcome
sobre un store secundario vacío.

**Y `GroupsOrganizerOnboarding` ya estaba en el cajón** sin que nadie lo hubiera anotado: escribe
por `writer.setLocal` → `PreferenceSyncService.local`, que es computed sobre la puerta desde
`35c1a016`. Era el lector de `ContentView` el que preguntaba por otra persona justo después.

### La red: por qué el escáner de grafías NO habría visto esto

**Antes del fix la key se nombraba en 26 sitios; después se nombra en 26.** El conteo por grafías
—que es la red que este ticket pedía en su criterio de hecho— habría pasado en verde con el bug
dentro, porque lo que cambió no fue cuántos sitios son sino **contra qué dominio hablan**.

⇒ la key entra en el `watched` (conteo 26, desglose por fichero al lado) **y** se añade una suite
que censa el DOMINIO fichero por fichero: 10 sitios en el cajón, 1 en el del dueño. La mutación de
devolver un solo lector a `.standard` pone en rojo los dos tests, por los dos lados.

De paso, `watchedKeysAreClassified` exigía que toda key vigilada estuviera en `person`. Era la
exigencia equivocada y habría impedido meter ésta en el `watched`: `hasCompletedOnboarding` es del
TELÉFONO en las fronteras —por eso está en `deviceExceptions`— y aun así es la más dispersa del
árbol. Pasa a exigir que esté **clasificada**, que es lo que el inventario pide de verdad.

## Decisión 2 · el consent legacy se custodia y se repone

`GroupsConsentState.custodyOwnerRecord(in:)` / `restoreOwnerRecord(in:)`, con el slot
`groups.consent.owner.custody` que **nadie más lee** — `readSnapshot()` no lo mira, así que una
custodia viva no le presta a la visita un permiso que no dio.

Tres cosas que el ticket no traía y que la implementación tuvo que resolver:

1. **Se custodian las TRES keys, no las dos legacy.** El ticket dejaba fuera el snapshot SELLADO
   porque `GroupsConsentRegistrar.handleSignIn` lo repone en cada arranque. **Medido: ese camino es
   no-op sin sesión Yala viva** (`refreshFromServer` sale por su primer `guard`), y Grupos va al
   100 % sin exigir Modo Nube ⇒ el dueño que cerró sesión perdía su snapshot con el síntoma
   idéntico al del legacy. Custodiar media frontera con el mismo mecanismo habría dejado el arreglo
   contradiciéndose ante la misma persona.
2. **El orden es el mecanismo entero**: custodiar va JUSTO ANTES de `purge()` en la entrada (que es
   quien borra) y reponer va DESPUÉS de `purge()` en la salida (que se lleva lo de la visita).
   Invertir cualquiera de los dos da exit 65.
3. **La idempotencia va por PRESENCIA del slot.** La frontera se re-ejecuta entera tras un kill, y
   para entonces lo que hay en las tres keys puede ser ya de la visita: sobrescribir la custodia con
   eso perdería el registro del dueño por el camino que existe para conservarlo.

El `clear()` de `SecondarySessionBoundaryPurge` **NO se retira**: custodiar y borrar son las dos
mitades, no alternativas — sin el `clear()` la visita hereda el consent legacy sin sello. Un
source-scan lo fija por si alguien lee la custodia como su sustituto.

## Documentación caducada corregida por el camino

`GroupsConsentState` y `GroupsConsentDecisionLogic` sostenían su argumento de seguridad sobre una
premisa falsa: «no existe ningún dominio de `UserDefaults` por sesión (`PreferenceSyncService.local`
es `.standard` hardcodeado)». Caducó el 2026-08-26. La conclusión no cambia —quien no pasa por la
puerta es `GroupsConsentState`, que sigue en `.standard` a pelo— pero el motivo escrito era falso.
La regla de `.claude/rules/swiftdata-cloudkit.md` **ya estaba corregida desde el 13-ago**: eran los
dos ficheros de código los que se habían quedado atrás, que es el reparto contrario al habitual.

## La revisión adversarial cazó un fallo mío, y era el mismo daño que la custodia impide

Se corrió una revisión adversarial sobre el diff **congelado** (ya commiteado) atacando cuatro
frentes: lectores desalineados, momento de resolución de la puerta, la custodia y su interacción con
la siembra. Cada hallazgo se verificó contra el árbol antes de aceptarlo.

### CONFIRMADO y arreglado · un kill entre reponer y desarmar dejaba al dueño SIN consent

`restoreOwnerRecord` vaciaba el slot como primer efecto, y eso **rompía la kill-safety que el resto
de `performSecondaryWipeIfArmed` declara**: «el arm se limpia AL FINAL, un kill a mitad reintenta el
paso entero». Entre reponer y `clearWipeArm` hay ocho sentencias —incluido un `removePersistentDomain`
y una escritura al App Group, todo pre-mount y bajo el watchdog de lanzamiento—. Un kill ahí:

1. el arm sigue puesto, y `deleteFiles` devuelve `true` (los ficheros ya no están: no-op idempotente);
2. `purge()` vuelve a borrar las tres keys **recién repuestas**;
3. `restoreOwnerConsent` ya no encuentra slot ⇒ **el dueño se queda sin registro, permanentemente**.

Es exactamente el daño que esta custodia existe para impedir, reintroducido por el mecanismo que la
implementa. **Arreglado**: reponer y descartar son dos pasos, y el descarte (`discardOwnerCustody`)
va pegado a `clearWipeArm` — los dos declaran lo mismo, que ya no hay nada que reintentar. Con eso
el ciclo entero es re-ejecutable: cada reintento purga y repone.

Pinneado con dos tests (`restoreIsRepeatable`, `killBetweenRestoreAndDisarmIsRecoverable`) y
**mutación a exit 65 verificada**: devolver el `removeObject` al reponer falla en la aserción del
daño real —`legacyAcceptedAt == 0`—, no en la forma.

### CONFIRMADO y corregido · una afirmación mía que el escáner no puede respaldar

Escribí, en el inventario y en el test, que «el único `.standard` que queda es la ventana de
entrada». Es literalmente cierto sobre la GRAFÍA y engañoso sobre el hecho: quedan tres sitios más
que escriben en el dominio del dueño y que `domainCensus` **no puede ver por diseño**, porque reciben
el dominio por parámetro (el healing y el reset de las dos fronteras, y `CloudSessionSignOut`, éste
además inalcanzable en secundaria por la precedencia de `CloudSignOutFlowLogic.path`). Es la misma
ceguera que `SessionPreferenceKeysWipeScanTests` ya documenta para `DataWipeService`. Corregido en
los dos sitios: ahora se dice qué mide el censo y qué queda fuera.

### CONFIRMADO de forma independiente · el hallazgo del healing

La revisión llegó por su cuenta al mismo defecto que esta sesión ya había extraído a
[[secondary-entry-healing-writes-owner-not-session]]. Añade un matiz medido que el ticket recoge:
**el brick ya existía desde el 26-ago** por la vía del `@AppStorage` de `ContentView:16`, así que
este commit no lo empeora en el síntoma — lo que añade es que ahora ningún lector ve el valor sanado.

### RESIDUALES nuevos, medidos y NO arreglados aquí

- **Reponer el legacy del dueño puede pisar el intent de consent pendiente de la visita.** Con el
  dueño en formato legacy, su siguiente sign-in entra en `adoptLegacyIfNeeded` y llama a
  `GroupsConsentPendingIntent.arm`, que con otra cuenta **sobrescribe** el slot único. Si la visita
  aceptó sin red, su intent desaparece. Daño acotado: ese intent ya era inerte en el móvil del dueño
  (`resumeIfNeeded` con sub-mismatch ni intenta ni descarta) y sólo muerde si ella vuelve de visita.
  Arreglarlo toca `GroupsConsentRegistrar`, otro fichero y otra frontera ⇒ fuera de alcance.
- **Un slot varado envenena la custodia siguiente.** Con el descarte al final del wipe, la única vía
  que queda es una salida que aborte para siempre en el guard de `deleteFiles`, o el tooling
  `DEV_BUILD` de `CloudSyncDebugView`. La custodia es idempotente por presencia, así que la visita
  siguiente no custodiaría nada y la salida repondría el registro viejo del dueño.
- **La re-entrada in-session escribe el flag en dos dominios.** Tras un «vaciar mis datos» el Welcome
  se le reabre a la visita y `SecondarySlotOccupancyLogic` deja pasar a la misma cuenta; ahí la raíz
  ya se montó con descriptor, así que el `@AppStorage` va al cajón y la línea de al lado a `.standard`.
  Inocuo hoy (el reset de la salida se lleva ese `true`), pero el comentario que lo justificaba
  hablaba sólo de la entrada primera. Precisado en el código, sin cambiar comportamiento.

## Verificación

- Build ×2 (`Yala` y `Yala Dev`): SUCCEEDED, **cero warnings nuevos** en los ficheros tocados.
- Unit: **6085 tests en 618 suites**, verde, cero issues (`-parallel-testing-enabled NO`).
- XCUITest: **20 tests en 6 suites** sobre el árbol del merge (OnboardingFlow ·
  OnboardingGroupsOnlyGuard · DeeplinkRouting · PaywallInboxAlertRouting · GroupsSmoke ·
  SecondaryCurrencyPrompt) y **15 en 3 suites** re-corridas tras el arreglo de la custodia — las
  otras tres no se repitieron porque ese arreglo no las toca, y la corrida entera de las 138 la hace
  el CI. En XCUITest la puerta devuelve el dominio del dueño (`isUITesting`), así que estos cambios
  son no-op ahí — **comprobado, no supuesto**.
- **Mutación, 5 verificadas a exit 65**: (1) un lector vuelve a `.standard`; (2) la custodia corre
  después de la purga; (3) sin el guard de idempotencia por presencia; (4) la reposición deja de
  retirar lo que el dueño no tenía; (5) la reposición vuelve a consumir el slot ⇒ el dueño pierde
  su consent tras un kill a mitad del wipe.
- `qa/coverage-index.json`: **11 áreas re-selladas por esta sesión** —sólo aquellas cuya cobertura
  declarada se ejecutó hoy—; el fichero tiene 17 con fecha de hoy porque el merge de `2.1` trajo las
  seis del PR #65; `validate-coverage.sh` → OK, backlog determinista 0.

## Los rojos del CI, clasificados (no heredados de un documento)

El job `tests` del CI sale `success` con la suite de UI en rojo: sus tres pasos son
`continue-on-error` a propósito y el gate duro es `coverage-index`. ⇒ **`tests: pass` no dice que los
tests pasaran**, y el campo `conclusion` que devuelve `gh run view --json jobs` tampoco: con
`continue-on-error` se pinta `success` pase lo que pase. Lo que hay que leer es el `outcome` real,
que el propio workflow vuelca en su paso de aviso.

Medido en este PR: `R_UNIT_PURE: success` · `R_UNIT_CONTEXT: success` · **`R_UI: failure`**.

Los rojos, comparados **run a run** contra `2.1` sin una línea de este trabajo (run `33959280114`),
no citados del ESTADO:

| XCUITest | fallos en `2.1` | fallos aquí |
|---|---|---|
| `EdgeCasesUITests.test_extremeMinimumAmountSaves` | 3 | 3 |
| `InboxConvertToGroupUITests.test_convertDraftToGroupExpense_preservesDraftDate` | 3 | 3 |
| `QuickActionsFavoritesUITests.test_saveAsFavoriteFromTransactionAppearsInList` | 1 | 3 |
| `TransactionsCrudUITests.test_createTransaction` | 3 | 3 |

Denominadores: 127 pass + 10 fail = 137 en `2.1`; 126 + 12 = 138 aquí (un test más, del PR #65).
Son **los mismos cuatro**, ninguno toca preferencias de sesión ni consent, y la diferencia de
`QuickActionsFavorites` es un flaky que allí pasó al reintento y aquí agotó los tres.

⇒ **preexistentes**. Uno tiene causa escrita en [[uitest-compara-fechas-sin-fijar-locale]].

## Lo que queda de este ticket: device-QA, y sale del código

**Pendiente de verificar en device** (staging, donde el percent está al 100): entrar de visita,
completar el onboarding privado y comprobar que el Welcome no se reabre; salir y comprobar que el
dueño recupera el permiso de Grupos sin volver a ver su pantalla. El caso que más importa es el del
dueño **sin sesión Yala viva**, que es el único que no se auto-repara por servidor.

**Extraído a tickets propios, con su medición:**

- [[welcome-privacy-branch-has-no-secondary-door]] — la vía 2. Ya no es un bug de datos: con el
  cajón y con `258a90c3`, la rama no daña. Lo que queda es la pregunta de producto («qué se le
  enseña») más el seed de categorías que se promete y no se hace.
- [[secondary-entry-healing-writes-owner-not-session]] — **hallazgo nuevo de esta sesión**, y de la
  misma familia: el kill-recovery de la entrada repara los flags en `.standard` mientras la siembra
  ya copió el valor viejo al cajón con su sentinel puesto ⇒ el healing existe para impedir el
  Welcome sobre store vacío y hoy no lo impide. Es la vía 5 vista desde el otro lado.

**Sigue donde estaba**: la vía 4 en [[secondary-groups-off-wipes-owner]] (código hecho, device-QA
pendiente).
