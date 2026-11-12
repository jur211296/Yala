---
name: la-etiqueta-nueva-afirma-en-cada-fila
description: Un dato que añado a una etiqueta o un texto por fila (gasto/ingreso) se afirma también en las filas raras; recorrer ajustes, transferencias y patas de grupo antes de cerrar.
metadata:
  type: feedback
---

Al arreglar la etiqueta de VoiceOver de las filas de Registros (lote 8, B6) añadí el tipo «Gasto/Ingreso»
derivado de la categoría. Los tests de la frase pasaron y el gate también; al recapturar, el árbol de
accesibilidad leía **«Saldo inicial, Gasto, S/ 5,000.00»**: un saldo inicial positivo tiene una categoría
que no es de ingreso. El arreglo de un bug metió una afirmación falsa que antes no existía.

**Why:** 2026-10-14. Lo cazó leer el árbol entero de una lista con ajustes y transferencias, no los tests:
los tests probaban cómo se une la frase, no qué se afirma de cada tipo de fila.

**How to apply:** cuando un cambio añade un dato que se AFIRMA por fila (tipo, signo, moneda, estado), léelo
en una lista con las filas raras: ajustes de saldo, transferencias, patas de grupo, otra divisa. El perfil
`grupos` las trae todas al final de la lista. Relacionado: [[el-copy-que-propongo-hereda-las-prohibiciones-del-vecino]].
