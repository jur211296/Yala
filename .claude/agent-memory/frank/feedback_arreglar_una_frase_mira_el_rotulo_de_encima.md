---
name: arreglar-una-frase-mira-el-rotulo-de-encima
description: Al arreglar una frase que contradice a lo de debajo, recorre también el rótulo y la cifra del mismo bloque con el caso límite (neto cero): el rótulo afirmaba lo mismo.
metadata:
  type: feedback
---

Al corregir una frase que contradice a la pantalla, comprueba también **las otras piezas del mismo bloque** (rótulo gris,
cifra), en el caso límite que la lógica nueva abre. En el lote 06 de Grupos (2026-11-10) arreglé la frase pequeña de
Saldos («Tú no le debes nada a nadie» sobre «Tú pagas a Ana») y dejé el rótulo: con el neto en cero y deudas cruzadas
seguía diciendo «Estás a mano en este grupo» encima de «Tú pagas a Ana». Jürgen lo cazó tras el gate, como «aviso que
quedó».

**Why:** el cruce de deudas es justo lo que hace que el neto mienta; todo lo que lea el neto hereda la mentira, no solo
la frase del ticket.

**How to apply:** antes de cerrar un arreglo de copy por contradicción, lista cada texto del bloque que lee la misma
cifra y pásale el caso límite (cero, empate, un solo lado). Relacionado: [[la-etiqueta-nueva-afirma-en-cada-fila]],
[[partir-una-cifra-hereda-la-ambiguedad-del-total]].
