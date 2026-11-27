---
name: un-lote-de-un-plan-mide-antes-de-buscar-la-causa
description: El último lote de un plan se mide primero sobre lo que dejaron los anteriores; la fuga de memoria del lote 6 ya no existía. Y cómo forzar el camino viejo para comprobarlo.
metadata:
  type: feedback
---

El lote 6 de eficiencia (26-nov-2026) pedía aislar una fuga de ~25 MiB por vuelta. Medida primero en el iPhone 14 sobre
2.3 con los lotes 1-5: plana (108 → 110 MiB en 10 ciclos). Los lotes anteriores ya habían quitado la causa.

**Why:** el informe es de la mañana; cada lote posterior cambia el terreno. Buscar la causa antes de medir habría
producido un «arreglo» sin defecto, alcance no pedido.

**How to apply:** en un lote que «va al final» de un plan, la primera medición es el antes del lote, no el del informe.
Si el síntoma ya no sale porque un lote previo cerró el camino que lo provocaba (volver ya no recarga), fuerza ese camino
con un interruptor temporal SOLO en la copia de medición (`-perfTempRecargaAlVolver`, script en
`despues-eficiencia-6-memoria-por-vuelta/scripts/forzar_recarga_al_volver.py`) y confirma por consola que corrió. Para
fijarlo en test, la huella física (`task_vm_info.phys_footprint`) en el simulador tiene ruido < 0,5 MiB: un contexto
retenido con 4.000 filas da ~1,1 MiB por ciclo en el Panel, así que el tope va en 4 MiB y con mutantes metidos a mano.
Ver [[atribuir-render-con-interruptores]].
