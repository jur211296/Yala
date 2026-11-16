---
name: el-golden-a-mano-hereda-tu-modelo-del-dato
description: Paridad web↔app «verde» con entradas escritas a mano no prueba que lees lo que escribe la app; mide la forma real de las filas en staging antes de fiarte.
metadata:
  type: feedback
---

Grupos de Yala web pasó su golden de paridad, sus unit y su e2e de staging, y en el iPhone salía «Todo saldado» con deuda,
«Sin nombre» y «? pagó» (barrido final de 2.3, arreglado el 2026-11-15). Todo lo verde usaba entradas escritas a mano con
la `member_key` cruda —el golden lo decía en su cabecera, «con las claves de miembro del backend»— y la app escribe otra
cosa en esas columnas. El e2e incluso fijaba la forma rota como contrato (`paid_by_member_key: ana.clave`).

**Why:** un fixture escrito a mano codifica la idea que tenía quien lo escribió de cómo es el dato; si esa idea está mal,
el test y el código coinciden en el error. Una consulta de solo lectura a staging (filas reales que escribió la app) lo
habría cazado el primer día: 57 de 57 referencias vivas tenían la forma derivada.

**How to apply:** al portar a la web (u otro cliente) algo que lee filas que escribe la app, antes de dar la paridad por
buena, compara con una consulta a staging cómo están escritas de verdad las columnas que cruzas (claves, ids, mayúsculas).
Y que el golden compartido lleve un caso que la app verifique con su código de producción, no solo cifras derivadas de
entradas inventadas. Relacionado: [[un-seam-que-fuerza-el-predicado-deja-ciegos-los-tests]].
