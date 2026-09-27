---
id: late-icloud-notice-wipe-cancelled-after-it-committed-skips-its-exit
status: backlog
priority: low
area: "modo-nube, onboarding"
created: 2026-09-27
source: "búsqueda de instancias del mismo patrón en `private-gate-remote-wipe-can-strand-its-arm`, 2026-09-27"
---

# El borrado del aviso tardío puede terminar y quedarse sin su salida si su tarea se cancela después

## El síntoma (inferido, sin reproducir)

Contesto «Borrar» en el aviso de «Tu iCloud tiene datos de antes». El borrado termina, pero la hoja no se cierra
por su camino: el arm y el testigo del espejo tardío se quedan puestos, y el arranque siguiente reanuda un borrado
que ya estaba hecho.

## Lo medido (2026-09-27, rama `encargo/2026-09-27-private-gate-remote-wipe-can-strand-its-arm`)

`LateICloudMirrorNoticeView.runPhase` tiene el mismo `guard !Task.isCancelled else { return }` **después** de
`await performWipe()` que la puerta privada tenía hasta ese ticket. Su scope es `.handover`
(`ContentView`, `performWipe: { await performICloudCorpusWipe(.handover) }`), que llama a
`DataWipeService.wipeAllUserData` con `resetsPreferences: true` y se lleva `hasCompletedOnboarding`. La hoja cuelga
del anchor de `ContentView` con el cover del Welcome **bajado**, así que el `onChange(of: hasCompletedOnboarding)` no
sale por su guard `!showWelcomeFlow` y llama a `presentNextOnboardingScreen()` a mitad del borrado.

**Inferido, no medido:** que esa presentación desmonte la hoja y cancele su `.task(id: phase)` antes de que el
`await` vuelva. Si pasa, no corren `clearPrivateChoseWithoutICloud`, `clearICloudCorpusWipeLeftHalfway`,
`clearICloudCorpusWipeArm` ni `onWiped()`.

## Por qué es `low`

Se cura solo: con el arm puesto, `ContentView.runLateICloudMirrorCheck` reanuda en el arranque siguiente
(`lateWipeLaunch` → `.resume`), el borrado es idempotente (zona vacía, sin filas) y su rama de éxito limpia lo mismo.
Y el Welcome sale igual, porque el propio borrado ya se llevó `hasCompletedOnboarding`. No hay pérdida de datos ni
callejón: hay un borrado repetido en el arranque siguiente.

## Por dónde va

El corte de `WelcomePrivateICloudGateLogic.gateWipeSettles`: la cancelación solo manda si el borrado no llegó a
escribir. Antes, medir si la hoja se desmonta de verdad (una traza en su `onDisappear` basta en el simulador con el
seam del aviso).

## Actualización (2026-09-27, review de `late-notice-of-a-welcome-private-session-purges-groups-joined-later`)

Desde ese ticket, «Empezar de cero» del aviso con el corpus es `.importedRows` en todas las sesiones: ya no se lleva
`hasCompletedOnboarding`, así que el disparador descrito arriba (el `onChange` a mitad del borrado) deja de ocurrir en ese
camino. Pero si la hoja se desmonta por otra causa tras un borrado que terminó, el «por qué es `low`» ya no vale entero:
la persona se queda en la app con lo personal vacío y el arm puesto, y el arranque siguiente reanuda el borrado **sobre lo
que haya creado entretanto**. Sigue acotado por `interactiveDismissDisabled` y por no haber botón de cerrar en `.wiping`.
