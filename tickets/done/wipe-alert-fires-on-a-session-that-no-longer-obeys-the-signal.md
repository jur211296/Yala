---
id: wipe-alert-fires-on-a-session-that-no-longer-obeys-the-signal
status: done
priority: high
area: "sesiones, onboarding, copy"
created: 2026-09-14
updated: 2026-09-14
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

- [x] El aviso que ve una sesión que no obedece la señal no afirma hechos sobre una cuenta que no es suya.
- [x] Si se mantiene un aviso, su acción no expulsa al onboarding a quien no lo pidió. — no se mantiene
      ninguno: al callar el aviso, su botón queda inalcanzable para esa población (medido: el alert tiene
      un único call-site en producción).

## Lo entregado (2026-09-14, PR)

Decisión de Jürgen: **opción 1, callar**. El guard va en `ContentView`, dentro de la tarea de gracia y
**pegado al único punto de `Yala/` que enciende el aviso**, leyendo el eje DESPUÉS del `sleep` de 5 s
porque el aviso afirma un hecho sobre AHORA.

**El predicado es el que ya existe** —`DestructiveScopeLogic.wipeSignalObeyedByThisSession`, tercera
superficie del mismo eje— y no uno propio del aviso. Las tres responden la misma pregunta («¿los datos
de este teléfono son los del Apple ID?») y el signo de su error coincide: hacia `true` se daña, hacia
`false` solo se calla. Un predicado paralelo divergiría del que gobierna el borrado en el commit
siguiente, en silencio.

## LA PREMISA DE ESTE TICKET ERA FALSA, y lo importante es a quién alcanza de verdad

El ticket atribuía el aviso al espejo de CloudKit de un teléfono prestado. **Esa celda hoy no lo
ejercita, por los dos lados** (medido el 2026-09-14):

- un solo-grupos dado de alta desde el 2026-09-10 monta `.neutralNoMirror`
  (`SwiftDataConfiguration.shouldMountNeutralDurable`): no hay espejo que le baje las filas;
- uno anterior a esa fecha sí tiene espejo, pero el backfill del eje le escribe
  `hasPrivateSession = true` (`PrivateSessionMark.backfillIfNeeded`), así que este guard **no lo calla**.
  Ese caso lo cierra el EJE, y tiene su ticket:
  `remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark`.

**Quien sí llega, y es el caso común: el aviso AUTO-INFLIGIDO tras «Vaciar datos» en solo-grupos.**
`UserDataResetView.handleWipeAllData` no cancela la gracia —es el único de los cinco borrados
deliberados que no lo hace— y el `onChange` no mira `isWipingData`, que además se apaga a los ~800 ms.
En la celda privada el barrido se lleva `hasCompletedOnboarding` y el guard de arriba cierra solo; en
solo-grupos `applyWipeLanding(.groupsShell)` lo REPONE a mano. Resultado: **a quien acababa de vaciar
sus propios datos la app le decía cinco segundos después que se los habían borrado desde otro
dispositivo**, y el botón lo expulsaba al onboarding. La causa de fondo —que ese camino no cancele la
gracia— queda en `wipe-data-does-not-cancel-the-remote-wipe-grace`: hoy la tapa el eje, no está cerrada.

También llega la ventana entre que una sesión solo-grupos nace y su neutro entra en vigor (la marca del
mount actúa en el arranque siguiente; la del eje, ya), y su simétrica tras desarmar el neutro.

Y una hipótesis mía que **quedó refutada**: pensé que la población mayor era el modo nube, donde el
canal de la cuenta aplica tombstones y borra `Account`/`Category` locales
(`SyncApplyEngine.applyToEntity`, caso `.tombstone`). El mecanismo es real, pero `storageMode` es
**siempre `.icloud` hoy** (Modo Nube DARK, `accountEntitlementCompiledDefault = false`; `.cloud` solo
lo escribe el cutover). Sin población en producción.

## El riesgo aceptado, con nombre

Jürgen lo dio por sabido: **un hueco transitorio real de CloudKit en esa celda también se calla**. Lo
que pierde esa persona es información, no datos — y el botón que se va con el aviso era el peor de los
dos caminos (el genérico de degradación, sin `isWipingData`, sin aterrizaje elegido y sin toast). En
solo-grupos, además, la shell es `.groupsFocused`: las pantallas que se vacían ni siquiera están
montadas, y Grupos sigue funcionando entero (`checkHasPersonalData` cuenta solo `Account`/`Category`
no-sistema). Medido: `hasPersonalData` no alimenta ninguna vista, así que callar no deja ningún
callejón sin salida.

Segundo residual, por el término `storageMode`: una sesión privada dentro de la ventana del cutover
deja de ver el aviso en la única celda donde era verdad
(`storage-mode-is-a-proxy-for-the-mirror-in-the-wipe-signal`). Hoy sin población; se enciende con el
Modo Nube. Los dos residuales se cierran en el EJE, nunca en esta línea.

## La red

El camino no es invocable (`onChange` en el `body` de una `View`) y no hay seam de uitest que haga
desaparecer las filas bajo el proceso vivo — el hueco que ya registra
`remote-wipe-receiver-has-no-behaviour-test`. Así que `RemoteWipeSignalWiringTests` fija el **TRAMO
ENTERO** normalizado (dormir → leer el eje → decidir → encender, sin nada entre medias) más el conteo
de **ASIGNACIONES** al flag, no del literal `= true`: viaja como `@Binding` a `ShellDataAlertsModifier`
y desde allí un `= loQueSea` lo encendería sin eje.

**7 mutantes, 7 muertos. Dos los cazó la review sobre MIS tests**, y el primero es el que importa: la
versión inicial solo fijaba que el `guard` fuera pegado al encendido, así que **mover la LECTURA por
encima del `sleep` pasaba en VERDE con el eje decidido cinco segundos antes** — el mutante que probé a
mano cayó por accidente, porque arrastró el `sleep` a la sentencia medida. El segundo: un escritor nuevo
por el binding no se contaba.

Y un defecto que yo mismo introduje y la corrida destapó: mi lectura del eje queda ANTES en el fichero
que la del drenaje, y el escáner existente buscaba solo la primera aparición — habría dejado al drenaje
sin red **en verde**, porque las dos sentencias son literalmente idénticas. Ahora verifica todas.

## Lo que la review dejó abierto, con ticket

- `remote-wipe-alert-skips-the-router` (**high**): el aviso se enciende desde una tarea de 5 s con
  `@State` directo en vez de pasar por el router —su hermano, el intent, sí pasa— y ese flag es blocker
  de la matriz de readiness. Si UIKit descarta la presentación, la app no vuelve a mostrar ningún aviso.
- `wipe-data-does-not-cancel-the-remote-wipe-grace` (medium): la causa de fondo del caso común.
- `shell-and-wipe-alert-read-the-session-axis-differently` (medium): la shell lee el eje con la lectura
  laxa y el aviso con la estricta.
- Widget, Siri y notificaciones siguen sirviendo datos del dueño cuando el borrado no pasa por
  `DataWipeService`: medido y anotado en
  `after-session-redesign-review-widgets-siri-applepay-and-web-copy`.
