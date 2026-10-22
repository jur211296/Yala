---
name: un-numero-sustituto-lo-cumple-otra-cosa
description: Cuando un número hace de sustituto de una decisión («3 rechazos» por tres ocasiones, «2 cambios» por esos dos cambios), otra realidad lo cumple igual — cuéntalo en la unidad de la decisión, no en la del mecanismo
metadata:
  type: feedback
---

**Un número que resume una decisión se cumple con cosas que la decisión no quería.** Antes de dar por
bueno un umbral o una aceptación por cifra, pregúntate qué OTRA realidad suma lo mismo.

**Why:** el 2026-09-15 (teléfono sin App Attest) la review adversarial cazó dos veces esta forma en mi
código, y las dos las había dado por buenas al escribirlas:

- **«Al menos 3 rechazos»** quería decir tres ocasiones. Yo contaba **peticiones**, y un solo gesto
  dispara ráfagas: la membresía reintenta tres veces y el cierre reintenta cada 2 s durante 45 s. Un
  fallo de segundos cumplía el mínimo, y un gesto ayer más otro hoy daban el veredicto terminal.
  Arreglo: como mucho uno por hora.
- **«Aceptar perder 2 cambios»** quería decir **esos** dos. Yo guardaba la **cifra**, y el cierre retoma
  más tarde: si uno subía y aparecía otro, la cifra seguía en 2 y el nuevo se perdía sin que ningún
  aviso lo contara. Era justo lo que la decisión de Jürgen pedía evitar: confirmación explícita.
  Arreglo: lo aceptado son las filas que enseñó el aviso.

**How to apply:**

- Al escribir un umbral de N eventos, **cuenta cuántos eventos produce UN gesto** (reintentos, bucles,
  re-emisiones) antes de fijar N. Si un gesto produce varios, el contador no mide lo que dice medir.
- Al guardar una confirmación que se usa **después** de un `await`, guarda la **identidad** de lo que el
  aviso enseñó, no su tamaño. La pregunta de control: «¿qué puede cambiar entre el aviso y el gesto?».
- El test lleva el caso de **la misma cifra con otro contenido** (`[b, c]` contra `[a, b]`). Sin él, la
  versión por cifra sale verde.

Relacionado: [[review-adversarial-caza-lo-mio]], [[mi-fix-hereda-la-forma-del-bug]].
