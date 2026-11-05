---
id: cold-launch-panel-first-content-waits-for-the-bootstrap
status: done
priority: medium
area: "performance, launch, panel"
created: 2026-10-30
updated: 2026-11-05
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

## Hecho (lote P2, 2026-11-05)

Las tres causas del desglose:
- El freno del Panel deja calcular con la app en primer plano aunque aún no esté activa (`isApplicationInForeground`,
  `applicationState != .background`). El watchdog del snapshot no se reabre: el paso a segundo plano lo sigue frenando
  `setBackground(true)`, que `PanelView` llama ya en `.inactive`, y un arranque directo en segundo plano da `.background`.
- La espera de 150 ms es fija desde la primera petición: el `incrementDataVersion()` del final del arranque se suma al
  cálculo pendiente en vez de reiniciarlo.
- La caché de widgets ya no se reconstruye en el paso 9 en el acto: se pide y se hace un segundo después (ticket
  `widget-cache-rebuild-blocks-the-main-thread`).
- Medido en el simulador (5 arranques en frío, medianas): arranque hasta datos en el Panel 4,67 → 3,62 s; desde la
  aparición del Panel 2,23 → 1,56 s.
- Tests: `PanelReturnFreshnessViewModelTests` (`requestDuringTheWindow_joinsIt`, `foregroundBrake`).

## Cómo medirlo en el iPhone

`LoadTimeMarks` solo escribe en DEBUG (en Release es no-op), así que la medida en el teléfono va con el scheme
`Yala Dev` instalado desde Xcode, con datos de volumen:
1. Conecta el iPhone, elige el scheme **Yala Dev** y el iPhone como destino, y dale a Run (⌘R).
2. En la Mac abre **Consola**, elige el iPhone en la barra lateral, escribe `app.yala.perf` en el buscador y pulsa
   Iniciar.
3. Cierra Yala del todo (deslizar en el multitarea) y ábrela; luego cambia a Estadísticas y vuelve al Panel, cinco veces.
4. Las líneas `PERF arranque`, `PERF panel` y `PERF widgets` traen los milisegundos. En el simulador, con el mismo
   corpus: arranque 4,67 → 3,62 s; volver al Panel 0,71 → ~0,22 s; caché de widgets una reconstrucción por arranque
   en vez de dos (medianas de 5, PR del lote P2).
