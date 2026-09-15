---
id: neutral-boot-hands-owner-prefs-to-whoever-signs-in-next
status: backlog
priority: medium
area: "sesiones, settings, sync"
created: 2026-09-14
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

- [ ] Decidida la opción.
- [ ] Si 2 o 3: quien entra por un grupo tras un «Cerrar sesión» ajeno no ve ninguna de las 36 preferencias
      del dueño, y «Restaurar» sigue yendo directo a la app.
