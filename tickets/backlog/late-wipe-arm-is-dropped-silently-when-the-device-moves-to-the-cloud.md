---
id: late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud
status: backlog
priority: medium
area: "modo-nube, onboarding"
created: 2026-09-27
source: "review adversarial de `private-gate-back-from-found-keeps-a-resumed-arm` (2026-09-27, lente del arranque); leído en código, la ventana NO reproducida"
---

# Un borrado de iCloud pendiente se olvida sin avisar si el dispositivo pasa a la nube

## El síntoma, en lenguaje de usuario

Pido borrar mis datos viejos de iCloud desde el aviso «Encontramos datos tuyos». El borrado no llega a empezar (iCloud
sigue bajando datos) y la app lo reintentará en el próximo arranque. Antes de eso me paso a la nube desde Ajustes. Mis
datos viejos suben a mi cuenta de la nube, y el borrado que pedí desaparece sin que nadie me lo diga. iCloud sigue lleno.

## Lo medido (2026-09-27, leyendo código)

- `performICloudCorpusWipe` no borra mientras el import del espejo está en vuelo, y lo devuelve como fallo `.untouched`.
  El arranque deja el arm puesto para reintentar (`ContentView.runLateICloudMirrorCheck`).
- Ni la migración a la nube (`MigrationWorkExecutor`) ni el adopt miran el arm.
- Desde `private-gate-back-from-found-keeps-a-resumed-arm`, un arranque en `.cloud` retira el arm sin borrar ni preguntar
  (`lateWipeLaunch` → `.retireInCloud`). Antes lo reanudaba con `.handover` sobre los datos de la cuenta de la nube, que era
  peor: esto es el residual, no una regresión.

## Qué hay que decidir

1. ¿La migración a la nube se bloquea o avisa con un borrado de iCloud pendiente?
2. ¿O el arranque en la nube avisa («Tenías un borrado de iCloud pendiente») en vez de retirarlo en silencio?

## Criterios de aceptación

- [ ] Quien pidió borrar su iCloud privado y pasa a la nube se entera de que ese borrado no se hizo.

## Relacionados

- [[private-gate-back-from-found-keeps-a-resumed-arm]]
- [[late-icloud-notice-exit-after-a-failed-wipe-leaves-the-blind-resume-armed]]
