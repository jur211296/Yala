---
id: remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark
status: backlog
priority: high
area: "sesiones, modo-nube, settings"
created: 2026-09-14
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
- [ ] O bien: se mide que esa población está vacía y el ticket se cierra con el número.
- [ ] El docblock de `PrivateSessionMark.backfillIfNeeded` queda al día con lo que se decida.
