---
name: el-cierre-en-segundo-plano-se-reproduce-en-frio
description: Para reproducir el 0x8BADF00D de Yala en segundo plano en el iPhone 14, abrir en frío y salir a los 3 s (4 de 5); los ciclos en caliente no lo dan
metadata:
  type: feedback
---

Midiendo el lote 3 de eficiencia (26-nov-2026, iPhone 14, 16 k movimientos, ya con el lote 1 dentro), 10 ciclos en
caliente con «tirar para actualizar» y salida a los 2-5 s dieron **0 cierres**: cada recálculo (~7 s) cabe en los 10 s del
vigilante. Lo que cerraba Yala era **abrirla en frío y salir a los 3 s**: 4 de 5, con el hilo en la foto de los widgets
detrás del cálculo del arranque. El informe del calor no había visto la foto de los widgets como culpable.

**Why:** con el lote 1 la vuelta ya no recalcula, así que el escenario del encargo («10 ciclos, salidas a los 2-5 s») por
sí solo no tenía «antes» que arreglar; sin la pasada en frío el lote habría medido 0 contra 0.

**How to apply:** para el vigilante en segundo plano, mide primero en frío con salida rápida (`frio.sh` del lote 3 en
`docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-3-no-morir-en-segundo-plano/scripts/`), y lee la pila del
`.ips` antes de decidir qué cortar. Los argumentos de `devicectl … launch` van tras `--` (si no, Yala no arranca y no avisa).
Ver [[el-guion-de-ciclos-dispara-tirar-para-actualizar]], [[medir-release-en-el-iphone-con-semilla]].
