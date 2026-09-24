---
id: stall-clock-charges-a-closed-app-gap-to-a-one-off-cause
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-23
source: "review adversarial de `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last` (2026-09-23), lente de persistencia"
---

# Un fallo de UNA pasada justo antes de cerrar la app cobra todas las horas que la app estuvo cerrada

## El problema, en lenguaje de usuario

Estoy volviendo a iCloud. En una pasada, iCloud contesta «no autenticado» —pasa a veces, y se arregla solo— y justo
entonces cierro Yala. La abro tres horas después. En cuanto vuelve a aparecer ese mismo aviso pasajero, la vuelta se
cancela en el acto, como si llevara tres horas con la cuenta rota.

## Por qué pasa (medido en el código el 2026-09-23, no en un teléfono)

Todos los techos de la familia usan `CauseStallClock`. Su regla dice que un tramo ABIERTO sigue contando hasta la
siguiente observación, también si entre medias la app está cerrada: el hueco «no observado» cuenta. Está decidido y
fijado con test en la vuelta previa al montaje (`reversePreMountDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts`).

En la espera de subida muerde más, porque la señal que abre el tramo **vive en memoria**:
`iCloudSyncService.mirrorReportedNotAuthenticated` y `lastExportErrorAt` no sobreviven al relanzamiento. Así que:

1. Pasada con `icloudUnusable`: se abre el tramo del reloj de «cualquier motivo definitivo».
2. Yala cerrada 3 h.
3. Primera pasada tras relanzar: la señal ya no está, el motivo es `unknown` o `icloudOff`, y esa observación CIERRA
   el tramo sumando las 3 h.
4. El siguiente `notAuthenticated` de una pasada encuentra 3 h acumuladas y sale en el acto, con el texto específico.

**Y una segunda cara, sin matar el proceso** (lente de lógica de la misma review): `mirrorReportedNotAuthenticated`
solo se apaga con un export que termina bien, y en segundo plano el espejo no exporta. Pasada con `icloudUnusable`,
Yala en segundo plano 20 min, y la primera pasada al volver lee la bandera todavía puesta: mismo motivo, el tramo
suma los 1200 s y sale en el acto aunque la cuenta ya esté bien. No es una regresión: antes pasaba igual con el reloj
de avance.

Es el mismo bug-class que cerró `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`, con el orden al revés.

## Qué habría que decidir

- ¿Un tramo cuenta solo hasta la ÚLTIMA observación que lo confirmó, y no hasta la que lo cierra? Es lo robusto, pero
  cambia `CauseStallClock` para las cinco etapas que lo usan (vuelta previa al montaje, espera de subida, subida del
  snapshot, pasos de la ida, efecto del adopt) y contradice la decisión fijada con test en la primera.
- ¿O persistir la señal de CloudKit para que la primera pasada tras relanzar vea lo mismo que la última antes de cerrar?

Tiene que ser una decisión para toda la familia: «un solo mecanismo para todos los motivos».

## Relacionado

- `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`: la review que lo cazó.
- `alternating-definitive-causes-never-reach-the-short-ceiling`: el que fijó que el hueco no observado cuenta.
