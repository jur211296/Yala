---
name: un-arreglo-de-carga-puede-no-verse-en-el-primer-contenido
description: Quitar recálculos y escrituras que ocurren DESPUÉS de pintar no mueve el «tiempo hasta contenido»; mídelo con Time Profiler por función, attach y no --launch
metadata:
  type: feedback
---

Medir carga por vista con dos métricas, no con una. El «tiempo hasta contenido» (`LoadTimeMarks` + `LoadTimesUITests`)
NO ve los arreglos que quitan trabajo posterior al primer pintado: el 2026-10-30 quité dos pasadas del Panel, dos
escrituras de una preferencia sincronizada y ~140 ms de `ls()`, y la tabla salió plana (6,20→6,02 s, ruido). Lo que sí
lo enseñó fue el coste inclusivo POR FUNCIÓN en Time Profiler (0,31→0,19 s de cálculo, 0,23→0 de reconciliar, 0,14→0
de traducir). El total del perfil varía demasiado entre arranques (2,5–3,4 s) para compararlo.

**Why:** el primer contenido del Panel lo frena el orden del arranque (cálculo descartado con la app inactiva, debounce
reiniciado por el `incrementDataVersion` final) y el pintado de SwiftUI, no el cálculo.

**How to apply:**
- `xctrace record --launch` deja la app sin llegar a primer plano: el Panel ni calcula. Lanzar con `simctl launch` y
  `xctrace record --attach <pid>`; el `--output` tiene que ser un nombre nuevo cada vez (si existe, falla y el export
  lee el viejo sin avisar).
- Parser del export `time-profile`: frames directamente bajo `tagged-backtrace`, con `id`/`ref` que hay que resolver.
- Hitos `HITO t=` por paso del bootstrap con el inicio del proceso por `sysctl(KERN_PROC_PID)` dieron el desglose del
  arranque en una corrida; se retiran antes del commit.
- `-uitest-reset` borra `defaultCurrencyCode` y el widget cae a USD: fijar `-defaultCurrencyCode PEN` o se mide otro bug.
- Relacionado: [[instrumentar-gana-a-razonar]], [[el-control-que-no-recorre-el-camino-no-descarta]].
