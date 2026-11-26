---
name: perfilar-ciclos-en-el-iphone-con-xctrace
description: Cómo medir en el iPhone 14 «irse a otra app y volver» con xctrace y devicectl, y qué falla (attach, ventana de signposts, consola, informes de iOS, gesto que dispara tirar-para-actualizar)
metadata:
  type: reference
---

Medido el 2026-11-26 en la Max (iPhone 14 por cable, iOS 27.2.1, análisis de calentamiento):

- **Volver sin relanzar**: `devicectl device process launch <bundle>` sin `--terminate-existing` trae la app al frente
  con el MISMO pid (medido). Así se alterna con Safari/Ajustes/Notas desde un guion, con tiempos exactos.
- **`xctrace --attach <pid>` falló dos veces** («Cannot find process for provided pid») justo después de otra grabación,
  y el guion siguió sin traza: 10 min perdidos. Lo fiable es `--launch -- <bundle> <args>`; y abortar si el log no dice
  «Ctrl-C to stop» en 90 s. Ojo: una app lanzada por Instruments puede no suspenderse en fondo; contrástalo con
  Activity Monitor `--all-processes` y la app abierta normal.
- **`os_signpost` en Time Profiler graba solo los últimos ~30 s** (ventana): para una línea de tiempo entera, `print` en
  DEBUG + `devicectl device process launch --console --terminate-existing <bundle> -- -uitest …` (**el `--` es
  obligatorio**: sin él devicectl lee `-uitest` como `-t`).
- **Guardar la traza tarda**: Activity Monitor + Hitches de todos los procesos, ~10 min tras 10 min de grabación. El
  export de SwiftUI de 4 min pesó 5,4 GB de XML: procesar en streaming y cachear solo `string`.
- **`device-mcp-cli scroll` consulta el árbol de accesibilidad** en cada gesto (sube `axauditd` y la CPU de la app);
  para scroll rápido sin sesgo, `device-mcp-cli swipe --from 195,700 --to 195,180 --duration-ms 90` (0,13 s por flick).
  Un flick hacia ABAJO estando arriba del todo dispara «tirar para actualizar» (recálculo completo del Panel).
- **Informes de iOS del teléfono**: `devicectl device info files --domain-type systemCrashLogs` lista `cpu_resource`
  (abuso de CPU) y `0x8BADF00D` en fondo; se copian con `device copy from` y se simbolizan con `atos` y el dSYM de la
  copia de perfilado. Mirarlos antes y después de medir: son evidencia independiente de Instruments.

Relacionado: [[medir-release-en-el-iphone-con-semilla]], [[conducir-el-iphone-real-con-device-mcp]].
