---
id: remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark
status: done
priority: high
area: "sesiones, modo-nube, settings"
created: 2026-09-14
updated: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de caminos y alcance"
---

# El arreglo del vaciado remoto no alcanza a quien entró por un grupo antes del 10 de septiembre

## El síntoma, en lenguaje de usuario

Presté mi móvil en agosto y mi amigo entró en Yala por una invitación de grupo: solo usa la parte de
grupos. Hoy yo vacío mis datos desde mi iPad. **Su teléfono se vacía igual** — pierde su perfil y sus
preferencias— aunque el arreglo de `remote-wipe-signal-honored-by-any-session` existe justo para impedir
eso.

## Lo medido (2026-09-14)

El eje de sesión que decide si se obedece la señal sale de `PrivateSessionMark`. En el parque existente
esa marca no está escrita, así que la deriva el backfill de arranque
(`PrivateSessionMark.backfillIfNeeded`, `AppBootstrapper` paso 0.0-bis):

```swift
guard hasCompletedOnboarding else { return false }
guard raw(defaults) == nil else { return false }
set(!hasGroupsOnlyNeutralMount, defaults)
```

`hasGroupsOnlyNeutralMount` sale de `StorageModePersistence.groupsOnlyNeutralMountKey`, **que existe
desde el 2026-09-10**. Un alta solo-grupos anterior a esa fecha:

- no tiene esa marca ⇒ `hasGroupsOnlyNeutralMount == false`;
- tiene `hasCompletedOnboarding == true` (lo escribe `GroupsOrganizerOnboarding.writePreferences`);
- ⇒ el backfill le escribe `hasPrivateSession = true`, con `storageMode == .icloud`;
- ⇒ `wipeSignalObeyedByThisSession` da **`true`** y obedece la señal exactamente como antes.

## Por qué esto no es «el residual conocido de siempre»

Lo era. El docblock de `backfillIfNeeded` ya declaraba ese hueco y lo llamaba **«el barato de los dos»**
— y lo era mientras el único consumidor de `confirmedPrivateSession` fuese el EMISOR, donde equivocarse
hacia `true` solo significa emitir una señal que nadie pidió.

Desde que el RECEPTOR lee el mismo eje, el mismo residual gobierna un BORRADO. Ya no es barato: a esa
población se le sigue vaciando el teléfono por orden de otro dispositivo. El docblock quedó corregido en
el mismo PR; lo que falta es cerrar el hueco.

## El mismo residual gobierna ahora un AVISO, no solo el borrado (2026-09-14)

`wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal` puso el mismo eje delante del aviso
«Tus datos fueron eliminados de iCloud» de la gracia de 5 s. Para esta población el eje sigue dando
`true`, así que **el aviso también les sigue saliendo**, con su botón que expulsa al onboarding. No se
parcheó allí a propósito: un predicado local al aviso divergiría del que gobierna el borrado, y es
justo lo que ese ticket evita delegando. Se cierra aquí, en el eje, o no se cierra.

## Qué hay que decidir / investigar

1. **¿Hay otra señal que distinga un solo-grupos anterior al 10-sep?** Candidatos a medir: filas
   `SplitGroup` con `isBackendGroup` y cero `Account` no-sistema; la ausencia de corpus personal con
   sesión de grupos viva. Cuidado: derivar el eje de una AUSENCIA es lo que la cabecera de
   `PrivateSessionMark` prohíbe explícitamente, y por buenas razones.
2. **¿O se acota por el otro lado?** El receptor podría exigir además que el store NO sea el de una
   sesión de grupos viva sin corpus personal — pero eso es un predicado nuevo, no el eje 1.
3. **¿O se asume?** Contar cuántas altas solo-grupos hay entre el encendido de Grupos y el 10-sep
   (métricas) puede decir que la población es cero y cerrar el ticket midiendo.

## Criterios de aceptación

- [ ] Un dispositivo solo-grupos dado de alta antes del 2026-09-10 no obedece la señal de vaciado.
- [x] O bien: **se mide que esa población está vacía y el ticket se cierra con el número.** ← esta rama.
- [x] El docblock de `PrivateSessionMark.backfillIfNeeded` queda al día con lo que se decida.

## Cierre (2026-09-14) — población CERO, con el número

**Decisión de Jürgen (2026-09-14):** no existen altas solo-grupos anteriores al 10-sep; se cierra
midiendo, sin predicado nuevo en el receptor ni señal inventada. Estas son las cuatro mediciones, que
son independientes entre sí: si una se equivocara, las otras tres siguen en pie.

**1 · Telemetría propia de producción** (Analytics Engine, dataset `yala_metrics`, retención de 90 días
⇒ cubre entera la vida del camino, nacido el 2026-08-11 en `5fc75b94`):

| evento | detail | total |
|---|---|---|
| `register` | `groupsOrganizer` (alta de organizador) | **0** |
| `register` | `groupInvite` (alta por invitación) | **0** |
| `register` | `initial` (alta personal, onboarding de 8 pasos) | 5 |
| `register` | `migration` (alta en la nube) | 1 |

Las dos altas solo-grupos emiten ese KPI —`GroupsOrganizerOnboarding.completeSetup`,
`GroupInviteOnboardingView.performSilentSetup`— y `MetricsService.start()` corre incondicional en el
cold launch (`AppBootstrapper:159`): no hay opt-in ni consentimiento que lo apague, solo `-uitest`.
Control negativo (un `detail` inexistente) → 0 filas; control positivo → el censo devuelve filas con
fechas reales, así que el filtro y el dataset funcionan.

**2 · El backend de Grupos al que apunta un build de release.** `CloudBackendConfig:43-49` cablea la
rama `#else` a producción (`kefvaiymtgytemwbltlz`), y `DEV_BUILD` solo lo define la config `Debug-Dev`
⇒ TestFlight habla con producción. Ahí: `auth.users` = 0, `profiles` = 0, `split_groups` = 0,
`group_members` = 0, `group_invites` = 0, `groups_consents` = 0. Control positivo de la misma consulta:
31 migraciones aplicadas y 30 tablas en `public`, leídas como rol `postgres` (sin RLS que oculte nada).
Y las dos altas **exigen sesión remota antes de escribir**: `GroupsGateLogic.nextStep:145-146` corta en
`.presentSignIn` sin ella, así que sin identidad en esa tabla no hubo alta.

**3 · El universo de distribución.** La versión pública más alta en la App Store es **2.0.4**
(6-jul-2026), anterior al camino. El alta solo-grupos solo viajó en los builds **11** (18-ago), **12**
(22-ago) y **13** (9-sep), todos de TestFlight, y TestFlight tiene **3 testers**: 2 con la app instalada
y 1 invitado que nunca instaló.

**4 · Esto no ha corrido nunca en el teléfono de nadie.** Ningún build distribuido contiene
`PrivateSessionMark`: el 13 se cortó el 9-sep (`039a12ed`) y el eje llegó el 12-sep. El backfill que
escribiría la marca equivocada no se ha ejecutado jamás fuera de un simulador.

## Qué queda en el árbol

- El docblock de `PrivateSessionMark.backfillIfNeeded` dice ahora las cuatro mediciones, la decisión y
  **qué reabriría la población**; `DestructiveScopeLogic.wipeSignalObeyedByThisSession` y el comentario
  del aviso en `ContentView` dejan de remitir a un ticket abierto.
- **La red:** `PrivateSessionMarkWiringTests.bothGroupsOnlySignUpsWriteTheAxisAndArmTheNeutralMount`.
  La celda del bug necesita la marca del eje AUSENTE, y hoy las dos altas solo-grupos la escriben en el
  acto además de armar el mount neutro — por eso el backfill ni la mira. El test fija las dos escrituras,
  su orden y el **censo de armadores (3)**, así que un alta nueva que se olvide de cualquiera de las dos
  rompe el test en vez de repoblar la celda en silencio. 3 mutantes, 3 muertos.

## Lo que se midió y NO era un bug (no abre ticket)

- **La invitación marca `hasCompletedOnboarding` para todo `outcome != .declined`** (`ContentView:2839`),
  incluidos los abandonos. No alcanza la celda: `GroupInviteOnboardingLogic.step:100`
  (`guard hasTappedJoin`) hace inalcanzables las pantallas de abandono sin haber pasado antes por
  `performSilentSetup`, que arma el neutro y apaga el eje.
- **El relevo de humano (`wipeLocalGroupsDomain`) deja el eje ausente**, pero sus tres call-sites corren
  con `resetsPreferences == true` y `removeUserPreferenceKeys` borra `hasCompletedOnboarding` ⇒ el gate
  del backfill cierra.

## Rojo heredado que este PR arregla

`PrivateSessionMarkWiringTests` afirmaba **6** lecturas de `confirmedPrivateSession` y en `origin/2.1`
ya había **7**: el PR #164 añadió la re-lectura del drenaje del aviso
(`ContentView.presentRemoteWipeNoticeIfStillTrue`) sin subir el contador. Medido ejecutando la suite, no
por aritmética. Queda en 7, con el reparto explicado: cada vez que este eje gobierna algo asíncrono se
lee en los dos extremos de la espera (borrado: detección + drenaje · aviso: petición + drenaje · cierre
por Apple ID: pre-filtro + re-lectura tras el `await`).
