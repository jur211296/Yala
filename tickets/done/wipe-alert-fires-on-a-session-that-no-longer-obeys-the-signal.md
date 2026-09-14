---
id: wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal
status: backlog
priority: high
area: "sesiones, onboarding, copy"
created: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lentes de producto y de caminos"
---

# En un móvil prestado sale «Tus datos fueron eliminados de iCloud», y el botón expulsa al onboarding

## El síntoma, en lenguaje de usuario

Beto usa el móvil que le prestó Ana, con su propia cuenta de grupos. Ana vacía sus datos desde su iPad.
A los cinco segundos, a Beto le sale un aviso: **«Datos no disponibles — Tus datos fueron eliminados de
iCloud. Puedes empezar de cero o esperar a que vuelvan a sincronizarse.»** No son sus datos y él no tiene
ningún iCloud en juego. Y si toca «Empezar de cero», la app lo manda al onboarding.

## Lo medido (2026-09-14)

El aviso **no cuelga de la señal del Apple ID**: cuelga de que las filas desaparezcan del store local.
`ContentView` observa `hasPersonalData` (cuenta `Account` y `Category` no-sistema) y, cuando cae de `true`
a `false`, arranca `wipeGraceTask`; a los 5 s enciende `showRemoteWipeAlert`
(`ShellDataAlertsModifier`). Quien baja esas filas es el espejo de CloudKit, no la señal — y el espejo
está montado precisamente en la celda que este arreglo eximió (ticket
`groups-only-second-launch-mounts-icloud-mirror`, ya en QA).

**Lo introduce el arreglo del receptor**, y se ve en el orden del código: la cancelación de la gracia vive
DESPUÉS del `guard decision.shouldProcess`:

```swift
guard decision.shouldProcess else { return }
wipeGraceTask?.cancel()      // ← ya no se alcanza en E/F
showRemoteWipeAlert = false
```

Antes, el canal KV llegaba primero, cancelaba la gracia y el vaciado era silencioso. Ahora esa
compensación no corre y aparece un alert que nadie había probado en esa celda.

Y el botón destructivo (`hasCompletedOnboarding = false`, más el borrado de dos sentinelas de semilla) es
el camino GENÉRICO de degradación, peor que el orquestado que se perdió: sin `isWipingData`, sin
aterrizaje elegido, sin toast.

## Lo que hay que decidir (Jürgen)

Qué se le enseña a esa persona. No es obvio:

1. **Nada**: callar el alert cuando la sesión no obedece la señal. Riesgo: el alert tiene OTRA causa
   legítima —un hueco transitorio de CloudKit— y callarlo escondería un problema real.
2. **Otro texto**, que no afirme «tus datos» ni hable de iCloud, y sin botón destructivo.
3. **Dejarlo**: asumir que la combinación (móvil prestado + espejo montado + el dueño vacía) es rara.

## Criterios de aceptación

- [ ] El aviso que ve una sesión que no obedece la señal no afirma hechos sobre una cuenta que no es suya.
- [ ] Si se mantiene un aviso, su acción no expulsa al onboarding a quien no lo pidió.
