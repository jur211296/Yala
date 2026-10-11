---
id: personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy
status: qa
priority: low
area: "modo-nube, sync, copy"
created: 2026-09-26
updated: 2026-10-05
source: "review adversarial de `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending` (2026-09-26, lente del cierre)"
---

# Si el teléfono no consigue guardar nunca, cerrar sesión en la nube dice «espera unos segundos» para siempre

## El problema, en lenguaje de usuario

Muy raro. Si este teléfono no consigue guardar un cambio tuyo para subirlo —siempre, no una vez—, cerrar sesión en la nube
te dice «Un momento más… espera unos segundos y vuelve a intentarlo» cada vez, y esperar no lo arregla. Si además el
teléfono no tiene App Attest, desaparece la opción de cerrar sesión perdiendo esos cambios.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- Desde `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending`, el push-all del cierre en la nube relee el History
  tras cada ciclo: lo que el drain no capturó bloquea, en vez de dejar que el borrado se lo lleve. Da vueltas hasta el tope
  y bloquea con `.transient`.
- Si el drain aborta en TODAS las vueltas —un `save` del outbox que falla siempre, un reloj por unidad o un testigo que no
  se deja leer (`RelayTombstoneReadFailure`)—, el cambio no llega nunca al outbox y cada intento acaba igual. El texto de
  `.transient` promete segundos.
- El teléfono sin App Attest: la sonda convierte su `.attestUnavailable` en `.transient`, a propósito (no se puede aceptar
  perder lo que el aviso no enseña). Con un drain que nunca termina, eso quita la salida de pérdida para siempre.
- `CloudSyncRuntime.performCycle` descarta el `Bool` de `drainOnce` (paso 1). Guardarlo como testigo del ciclo, como
  `lastCycleFailedUpload`, permitiría separar este caso con su propio motivo.

## Por dónde va

Un testigo del ciclo «el drain no terminó» (bajado al entrar en cada ciclo, leído CON el outcome, como los otros dos) y,
con él, un motivo y un texto propios que no prometan segundos. Decidir con Jürgen si el teléfono sin App Attest debe tener
alguna salida en ese estado (hoy: ninguna, y tampoco la tenía el gemelo de Grupos).

## Criterios de aceptación

- [x] Con un drain que aborta en todas las vueltas, el aviso no dice «espera unos segundos».
- [x] El caso pasajero (algo escrito tras el drain) sigue curándose solo con otra vuelta.

## 2026-09-28 · también con la sesión caducada

Desde `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`, `personalVerdictAfterProbe` relee el History
también con `.sessionExpired`, porque su aviso ofrece perder las filas que cuenta. Con un drain que aborta siempre, esa sesión
caducada sale como «un momento más» (`.transient`) en vez de «vuelve a entrar»: pierde la puerta de «Iniciar sesión» (el paso
1 no para el motor con `.transient`) y la salida de perderlos. No se pierde nada; la persona oye «espera» para siempre. Mismo
arreglo que el del attest (review adversarial, lentes 1 y 2).

## 2026-10-05 · Entregado (decisión A de Jürgen del 2026-10-04)

**Qué cambia para la persona.** Si este teléfono no consigue preparar para subir algún cambio tuyo en ninguna vuelta,
cerrar sesión en la nube ya no dice «un momento más, espera unos segundos». Dice que esos cambios siguen guardados y no se
pierden, y que cierres y abras Yala o la actualices. Si además el teléfono no tiene App Attest, o tu sesión caducó y no
puedes volver a entrar, vuelve la salida de siempre —exportar tus movimientos y cerrar sesión perdiéndolos— y el aviso
cuenta también esos cambios que no se pudieron preparar. Con la sesión caducada vuelve además la puerta de «Iniciar
sesión» en «Dónde viven tus datos».

**Cómo.** Un testigo del ciclo (`CloudSyncRuntime.stoppedWithUnfinishedCapture(for:)`: el drain del paso 1 no terminó o
cortó la traducción), motivo y texto propios (`BlockReason.personalCaptureUnfinished`, `settings.signOutCaptureUnfinished`
en los 16 locales), y lo que se perdería en dos mitades (`CloudSignOutFlowLogic.PersonalLoss`: filas del outbox + cambios
del History por clave, `CloudSyncEngine.uncapturedPersonalChangeKeys`). Lo aceptado cubre cada mitad por separado, y con la
pérdida aceptada el recuento final relee el History pegado al borrado. Decisiones en el PR.

**Fuera, con ticket:** el gemelo de Grupos (`groups-drain-that-always-aborts-takes-the-loss-exit-away`: su texto ya no
prometía segundos, pero el teléfono sin attest y la sesión caducada pierden igual su salida).

## Guion de device-QA

No se puede provocar en un iPhone de verdad sin un build con un fallo inyectado: el drain solo se atasca con un store que
no deja guardar. Lo que sí se puede mirar, con un build de TestFlight y una cuenta en la nube:

1. **Regresión del caso normal.** En un iPhone con la nube activa, apunta un movimiento y, sin esperar, ve a Perfil →
   «Cerrar sesión». Esperado: cierra como siempre (o, si salta, «Un momento más» y al reintentar a los segundos cierra).
2. **Teléfono sin App Attest** (si tienes uno con la racha terminal, el aviso fijo «Este teléfono no puede sincronizar tus
   datos» en el Panel): apunta un movimiento y cierra sesión. Esperado: el aviso «Este teléfono no puede sincronizar tus
   datos» con la cifra de cambios, «Exportar» y «Cerrar sesión y perderlos». Toca «Ahora no»: no se pierde nada.
3. **Sesión caducada** (cuenta cuya sesión expiró): cierra sesión con un movimiento pendiente. Esperado: el aviso de «Tu
   sesión caducó» con la cifra, y en «Dónde viven tus datos» la tarjeta con «Iniciar sesión».

El texto nuevo («Algunos de tus últimos cambios no se pudieron preparar…») solo se ve con el fallo inyectado; lo fijan los
tests unitarios (`CloudStuckDrainPersonalLossLogicTests`, los `signOutPushAll_*` de `CloudSyncRuntimeTests`).
