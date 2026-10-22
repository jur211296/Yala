---
name: mutantes-sin-diagnose-y-con-copia
description: En iOS 27 cada mutante muerto dispara un `simctl diagnose` de 600 s; y matar la tanda deja el mutante puesto en el árbol.
metadata:
  type: feedback
---

Las tandas de mutantes llevan `-collect-test-diagnostics never`, y tras CUALQUIER corte se compara cada fichero
contra su copia de seguridad antes de seguir.

**Why:** el 2026-09-30 (#306) la primera tanda de 11 mutantes agotó los 30 min del background: cada mutante que
MUERE hace fallar la corrida y `xcodebuild` lanza `simctl diagnose --timeout=600`, así que un mutante bien cazado
cuesta ~12 min con la máquina en reposo (load 1,3 — parece colgado). Con el flag, 17 mutantes en ~45 min. Y las dos
veces que se cortó la tanda (timeout del background, y TaskStop), el `finally` de Python no corrió: quedó un mutante
aplicado en producción (`if true {`), que un `git diff` para la review habría capturado como código real.

**Volvió a pasar el 2026-10-05** con las dos mitades a la vez: lancé la tanda SIN el flag y dentro de un `Monitor`, que
caduca a los 30 min y mata el script — quedó puesto el mutante 4 (un `.filter` borrado). La tanda va con `nohup` en un
Bash de fondo, nunca colgada de un `Monitor`, y el flag se comprueba en el script antes de lanzar.

**No es solo de mutantes** (2026-10-06, #373): cualquier `xcodebuild test` con un rojo lo paga — una repetición de
4 tests tardaba 10 min 34 s y con el flag 1 min 23 s. Por eso el paso pure-logic del CI lo lleva.

**How to apply:** guarda copias en el scratchpad antes de lanzar, `cmp` contra ellas al terminar y tras cada corte,
y nunca `git checkout` para restaurar (ver [[el-script-de-mutantes-revierte-mi-trabajo]]). Si una corrida de un
solo mutante pasa de 5 min, mira si hay un `simctl diagnose` hijo del `xcodebuild` antes de pensar en un cuelgue.
El paquete de la review se construye desde las copias, no desde el árbol ([[la-review-y-los-mutantes-no-comparten-arbol]]).
