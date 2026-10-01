---
id: neutral-boot-hands-owner-prefs-to-whoever-signs-in-next
status: qa
priority: medium
area: "sesiones, settings, sync"
created: 2026-09-14
updated: 2026-10-01
qa-status: needs-testing
source: "medido al reponer el guard del iCloud-KV (`icloud-kv-prefs-cross-sessions-on-a-lent-phone`): la mitad que esa puerta no puede cerrar"
---

# Tras «Cerrar sesión», quien entra por un grupo hereda las preferencias del dueño

## El síntoma, en lenguaje de usuario

Me prestan un móvil. Su dueño cierra sesión y yo entro con mi cuenta de grupos. Desde ese día ya no le
cambio nada a él —eso lo cerró el ticket hermano—, pero **la app me llega en su idioma, con su moneda si
entré como organizador, y con sus ajustes** (Panel, avisos, primer día de la semana, decimales…).

## Lo medido (2026-09-14, árbol `f548ac94`)

- «Cerrar sesión» arma el boot-wipe; el arranque siguiente borra las preferencias locales
  (`DataWipeService.resetForSignOutWipe`), limpia el eje 1 y la marca del neutro solo-grupos
  (`SwiftDataConfiguration.performSignOutWipeIfArmed`).
- En ese MISMO arranque, `PreferenceSyncService.bootstrap()` (paso 0) aplica las 36 claves del iCloud-KV
  del Apple ID a `UserDefaults`. Sin ninguna de las dos marcas, `OwnerKeyValueGate` está abierta — y tiene
  que estarlo, ver abajo.
- Después la persona elige «Vengo por un grupo». Las dos altas pisan en local solo lo suyo:
  - invitación (`GroupInviteOnboardingView.performSilentSetup`): nombre, divisa y periodo;
  - organizador (`GroupsOrganizerOnboarding.writePreferences`): nombre y periodo, y la divisa **solo si
    no hay** — y hay: es la del dueño.
- Todo lo demás se queda: `appLanguageOverride` (la app entera en el idioma del dueño), la configuración del
  Panel, `budgetAlertsEnabled`, `groupSettlementRemindersEnabled`, `firstWeekday`, `decimalPlaces`,
  `userProfileIcon`…

## Por qué la puerta del iCloud-KV no lo cierra

En ese arranque **nadie ha elegido todavía**: la puerta no puede saber si va a entrar el dueño o otra
persona. Y cerrar por ausencia rompe a toda la población de producción:

- `ICloudAccountSummary.isFullyPrefilled` exige `userName`, y ese nombre llega por esta aplicación: sin
  ella, «Restaurar desde iCloud» nunca iría directo a la app.
- El alta personal escribe sus preferencias y `signalOnboardingCompleted` ANTES de encender el eje: con la
  puerta cerrada no llegarían al iCloud-KV, y el merge del arranque siguiente —remoto gana— devolvería los
  valores viejos encima de los recién elegidos.

## Decisión que falta (de Jürgen)

1. **Aceptarlo y dejarlo escrito.** Coste: el prestado ve el idioma y los ajustes del dueño.
2. **Resetear las 36 en local al empezar un alta solo-grupos** (las dos puertas, antes de escribir lo
   suyo). Es el instante en que se sabe que la sesión no es del Apple ID. Coste: quien es solo-grupos en
   SU propio teléfono empieza con los valores por defecto del dispositivo.
3. **No aplicar en el arranque neutro y aplicar al nacer la sesión privada** (restaurar, alta personal).
   Coste: `isFullyPrefilled` tiene que leer el nombre de otra fuente, y hace falta un re-aplicado en el
   nacimiento del eje — un camino que hoy no existe.

Recomendación de Frank: **2**. Es la única que decide en el momento en que el dato de identidad existe, y no
toca a la sesión privada.

## Criterios de aceptación

- [x] Decidida la opción: **2** (Jürgen, en el encargo del 2026-10-01).
- [x] Si 2 o 3: quien entra por un grupo tras un «Cerrar sesión» ajeno no ve ninguna de las 36 preferencias
      del dueño, y «Restaurar» sigue yendo directo a la app. En unit; falta verlo en un iPhone (abajo).

## Hecho (2026-10-01)

Opción 2. Las dos altas solo-grupos retiran en LOCAL las 36 `PrefSyncKey` justo después de armar el neutro y
antes de escribir lo suyo (`GroupsOnlySignUpPreferenceReset`), y reinician las copias en memoria: el espejo de
`AppPreferences` (relee por presencia, así que quitar la key no bastaba), el modo solo-gastos y el enfoque de
`SessionState`, el idioma (`languageDidChange`) y los espejos de widgets. Con las 8 del Panel se va su centinela
per-device, para que el Panel arranque con el curado de una instalación nueva.

Medido antes del arreglo con un test sobre stores aislados: tras el alta del organizador quedaban **33** keys del
dueño y su divisa. Después, ninguna.

Dos cosas del mismo objeto, decididas en el Paso 0:

- **La divisa del organizador ya no es condicional.** La única que podía haber era la del dueño; ahora es siempre
  la de la región. El test G4 que fijaba «no se pisa» se invirtió.
- **La hoja del invitado ya no siembra el nombre del perfil a quien no tiene cuenta.** Tras «Cerrar sesión» ese
  nombre era el del dueño, y si el invitado no tocaba el campo entraba al grupo con él.

No se toca: la puerta del iCloud-KV (sigue abierta en el arranque neutro), Restaurar, el alta personal.

## Device-QA (iPhone, no frena el merge)

Montaje: un iPhone con Yala en sesión privada y preferencias propias visibles —idioma de la app en otro idioma
(Perfil → Idioma), primer día de la semana en domingo, decimales a 0, algún widget del Panel oculto—, y un enlace
de invitación a un grupo de otra cuenta.

1. Perfil → «Cerrar sesión». La app vuelve a la bienvenida.
2. Abre el enlace de invitación y, cuando la app lo pida, entra con **otra** cuenta (Google o Apple).
3. En la hoja de bienvenida al grupo, mira el campo del nombre.
   - Esperado: sale **vacío**, no con tu nombre. Escribe uno y toca «Unirme».
4. Ya dentro:
   - Esperado: la app en el idioma del **teléfono**, no en el que pusiste; en Ajustes, semana empezando en
     lunes y dos decimales.
5. Repite 1-4 entrando por «Vengo por un grupo → Crear un grupo» (organizador).
   - Esperado: lo mismo, y la moneda del grupo nuevo es la de la región del teléfono, no la tuya.
6. Control: «Cerrar sesión» otra vez y elige «Restaurar desde iCloud» con tu cuenta.
   - Esperado: entra directo a la app con tu nombre y tus preferencias de antes.
