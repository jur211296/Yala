---
id: remote-onboarding-signal-ignores-the-session-axis
status: backlog
priority: medium
area: "sesiones, modo-nube, onboarding"
created: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lente de producto"
---

# La señal de «onboarding terminado» del Apple ID también la obedece cualquier sesión

## El síntoma, en lenguaje de usuario

Estoy a mitad del alta en el móvil que me prestaron, entrando por una invitación de grupo. El dueño
termina SU alta en su iPad. Mi pantalla de alta se cierra sola y me sale **«✓ Listo, tus datos están
aquí»**. No son mis datos y yo no he terminado nada.

## Lo medido (2026-09-14)

Es la **misma forma de bug** que `remote-wipe-signal-honored-by-any-session`, en el bloque de al lado del
mismo fichero, y ese ticket no la tocó a propósito (otro objeto, y no borra datos).

- El «Caso B» de `PreferenceSyncService.checkForRemoteWipeSignal` (`lastOnboardingTimestamp`) **no pasa
  por `RemoteWipeSignalDecider` ni por el eje de sesión**: postea la notificación y encola el intent.
- `ContentView.handleRemoteOnboardingCompleted` tiene dos guards, `showOnboarding` y
  `hasCompletedOnboarding` — exactamente los dos hechos del DISPOSITIVO que el arreglo del vaciado acaba
  de declarar insuficientes, porque ninguno dice de quién es la sesión.

No borra filas. Lo que hace es cerrar una pantalla de alta ajena y afirmar algo falso.

## Criterios de aceptación

- [ ] Una sesión en la nube o solo-grupos no cierra su onboarding por la señal del Apple ID.
- [ ] Una sesión privada sigue comportándose como hoy.
- [ ] La decisión es pura y testeable, como la del vaciado.
