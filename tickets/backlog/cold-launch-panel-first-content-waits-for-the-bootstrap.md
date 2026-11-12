---
id: cold-launch-panel-first-content-waits-for-the-bootstrap
status: backlog
priority: medium
area: "performance, launch, panel"
created: 2026-10-30
updated: 2026-10-30
card: tablero-el-primer-contenido-del-panel-espera-a-q-h1hy
source: "encargo eficiencia-carga-por-vista (S27e), hitos de arranque medidos en el simulador"
---

# El primer contenido del Panel espera a que termine el arranque

## Qué pasa

Desglose medido el 2026-10-30 (simulador iPhone 17 Pro, iOS 27.0, corpus `rendimiento`, 2.337 movimientos, hitos de
`LoadTimeMarks` por paso del arranque; tiempos desde que nace el proceso, un arranque típico):

| hito | t |
|---|---|
| contenedor de datos listo | ~1,7 s |
| `PanelView.onAppear` | ~2,3 s |
| primer cálculo del Panel **descartado**: la app aún está `.inactive` (`scheduleRecalculation`, `isApplicationActive`) | ~2,3 s |
| pasos síncronos del arranque (caché de widgets 0,27 s incluida) | 2,7–3,2 s |
| la escena pasa a activa → se pide el cálculo | ~3,2 s |
| `incrementDataVersion()` al final del arranque **cancela y reprograma** ese cálculo (+150 ms) | ~3,8 s |
| cálculo del Panel (recarga + widgets) | 4,0–4,35 s |
| primer pintado con datos | ~4,4–5,1 s |

Tres cosas se suman: el cálculo no corre mientras la app está inactiva, el arranque ocupa el hilo principal con
trabajo síncrono, y el aviso de datos del final del arranque reinicia el debounce. Después, el pintado del Panel con
datos tarda 0,5–0,8 s más (SwiftUI y Charts, sin un punto caliente propio).

## Por qué no se arregló en el encargo

Cambiar cuándo calcula el Panel en el arranque toca el `guard` contra el watchdog del snapshot en segundo plano
(`0x8BADF00D`) y el orden del bootstrap, que tiene muchas dependencias medidas (`swiftui-ds.md`, «Presentaciones»).
No es un arreglo pequeño sin cambiar comportamiento.

## Ideas, sin medir

- Calcular con la app `.inactive` si el proceso está en primer plano (no en `.background`).
- No reprogramar el cálculo pendiente si el aviso de datos del arranque no trae datos nuevos.
- Sacar del hilo principal los pasos síncronos del arranque (la caché de widgets: ticket
  `widget-cache-rebuild-blocks-the-main-thread`).

## Hecho cuando

El primer contenido del Panel en frío baja de forma medible con `LoadTimesUITests`, sin reabrir el watchdog.
