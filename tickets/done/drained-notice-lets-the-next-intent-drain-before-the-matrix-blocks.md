---
id: drained-notice-lets-the-next-intent-drain-before-the-matrix-blocks
status: done
priority: high
area: "routing, presentaciones"
owner: frank
created: 2026-10-13
updated: 2026-10-13
source: "QA nocturna de 2.1, run 38426514839 (card tablero-ui-test-del-aviso-de-borrado-remoto-keep-iqsr)"
---

# Al drenar un aviso, la cola soltaba el siguiente antes de que la matriz se cerrara

## Qué le pasaba a una persona

Con un aviso del shell y otro detrás en la cola —el de «tus datos fueron eliminados de iCloud» o el de la bandeja, y
la oferta de prueba detrás—, a veces salían los dos a la vez sobre la misma pantalla. Solo uno llegaba a verse: o el
aviso no aparecía, o tras contestarlo la oferta no salía nunca, y con ella nada de lo que viniera después en esa
sesión.

## Lo medido (2026-10-13)

- En la nocturna de 2.1 (iOS 26.5) `RemoteWipeNoticeRoutingUITests.test_notice_keepWaiting_…` cayó 3 de 3 y
  `test_noticeThatNeverMounts_…` 1 vez. En local (iOS 27.0) la suite pasa 12/12, también con 9 núcleos cargados.
- Rama de diagnóstico desechable con `NSLog` en el drenaje, la matriz y la red, corrida en el CI con solo esta suite
  y su control `PaywallInboxAlertRoutingUITests`, ×4 iteraciones en 3 runners. Reprodujo los dos rojos (1/12 cada
  uno) y el control (3/12). En 8 de ~60 arranques la oferta salió de la cola con la matriz ya tapada:

  ```
  19.732 drainedCV remoteWipeNotice
  19.748 drain notice: hasPersonalData=false … onboarding=true mark=true      ← la condición viva sube
  19.786 drainCV … blocker=remoteWipeAlert                                    ← la matriz ya lo ve…
  19.796 drainedCV trialOffer                                                  ← …pero el router seguía «listo»
  19.798 applyReadiness blocker=remoteWipeAlert                                ← el markUnready llega tarde
  ```

## Causa

El manejador del intent drenado sube su condición viva, y la matriz solo se entera por el `onChange` de
`ReadinessGateObservers`. Pero `drainNext` ya ha subido la `revision`, y en 26.5 el `onChange(of: revision)` corría
antes que ese observador: drenaba el siguiente con el consumidor todavía marcado listo. Es el residual que anotó la
review de `queued-offer-after-dismiss-flakes-on-a-cold-simulator` («el bump de `drainNext` también ocurre dentro del
`onChange(revision)`»), con otra cara.

## Arreglo

`drainContentViewIntents` lleva `defer { updateContentViewReadiness() }` tras sacar el intent: lo que el manejador
encienda bloquea en esa misma vuelta (y publica `shellModalBlocker` para Panel y MainTab). Liberar sigue aplazado una
vuelta, así que no añade drenajes. Pin: `ContentViewReadinessReleaseWiringTests#drain_blocksWithWhatItsHandlerRaised_
beforeTheNextRevisionTick`, con mutante (quitar el `defer` → 2 aserciones en rojo).

## Verificación

Ver el cuerpo del PR: la misma rama de diagnóstico con el arreglo, en el CI 26.5, y la suite en local 27.0.

## Fuera

Los manejadores que encienden su bloqueo dentro de un `Task` (la invitación ya confirmada) siguen pasando por el
observador; no hay rojo medido. El hermano de MainTab va en `maintab-drain-publishes-its-sheet-after-contentview-may-drain`.

Su caso contrario —un intent que no presenta nada y deja al siguiente esperando— sigue en
`drained-intent-that-presents-nothing-may-strand-the-next`: el `defer` no lo cambia, porque sin bloqueo solo programa
una liberación que ya estaba hecha (`markReady` no sube la `revision` si el consumidor ya estaba listo).
