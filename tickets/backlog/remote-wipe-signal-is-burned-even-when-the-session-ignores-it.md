---
id: remote-wipe-signal-is-burned-even-when-the-session-ignores-it
status: backlog
priority: medium
area: "sesiones, modo-nube"
created: 2026-09-14
source: "review adversarial de `remote-wipe-signal-honored-by-any-session`, lentes de caminos y de producto"
---

# La señal de vaciado se consume aunque la sesión la ignore, y no vuelve

## Lo medido (2026-09-14)

`PreferenceSyncService.checkForRemoteWipeSignal` marca la señal como procesada **antes** de preguntar si
esta sesión la obedece:

```swift
if remoteWipe > 0 && remoteWipe > localWipe {
    local.set(remoteWipe, forKey: WipeKey.localWipe)   // ← incondicional
    …
    guard decision.shouldProcess else { return }
```

Eso es deliberado y hace que el caso «no obedezco» sea idempotente. El efecto que no se atendió es que
**quema la señal para siempre**: `remoteWipe > localWipe` no vuelve a cumplirse nunca.

Dos consecuencias:

1. **La segunda evaluación no es una red en la dirección que parece.** El docblock de
   `RemoteWipeSignalDecider` dice que `ContentView.handleRemoteWipeSignal` re-evalúa con valores vivos.
   Cierto — pero solo puede CERRAR la puerta: si la detección no encoló el intent, no hay nada que
   drenar. Un eje transitoriamente equivocado en el punto de detección no se retrasa, se pierde.
2. **Cambiar de sesión después no la recupera.** Un dispositivo que ignora la señal y luego pasa a sesión
   privada («Activar Yala completo», devolver un móvil prestado, «Volver a iCloud») ya no se vaciará
   nunca por esa señal.

## Dónde muerde de verdad

En la ventana del cutover a `.cloud` y en la reversa: ahí la sesión es privada, las filas SON las del
Apple ID, y el dispositivo deja de obedecer durante minutos u horas (ver el ticket hermano
`storage-mode-is-a-proxy-for-the-mirror-in-the-wipe-signal`). Con este comportamiento, esa ventana deja de
ser un retraso y se convierte en una pérdida permanente de la señal.

## Opciones

1. **Marcar solo cuando la decisión es definitiva** (fresh-install, o sesión que no obedece con el eje ya
   asentado) y dejar la señal viva cuando el eje pueda estar en tránsito. Pide distinguir «no obedezco» de
   «todavía no sé», que hoy el decisor no separa.
2. **Registrar la señal ignorada** en una key propia, para que un cambio posterior a sesión privada pueda
   consultarla. Reintroduce la pregunta de cuánto tiempo vive, y un vaciado que llega tarde asusta.
3. **Dejarlo**: asumir que quien no obedecía tampoco tenía datos del Apple ID que vaciar.

## Criterios de aceptación

- [ ] Decidido qué pasa con una señal que llegó durante una ventana transitoria del eje.
- [ ] El docblock de `RemoteWipeSignalDecider` dice lo que la segunda evaluación puede y no puede hacer.
