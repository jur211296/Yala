---
name: el-generico-del-molde-no-es-generico-aqui
description: Al copiar un mecanismo «con el molde de X», el texto que allí era neutro puede afirmar un plazo o una causa en la etapa nueva; léelo antes de llamarlo genérico.
metadata:
  type: feedback
---

Al trasladar el tercer reloj de la vuelta a la subida del snapshot (2026-09-23) di por hecho que `stalled` era «el
genérico», como `preMountStalled` en la vuelta. No lo era: su texto decía «lleva días sin avanzar», y con el cambio
salía a los 15 min. Lo cazaron dos lentes de la review; Jürgen eligió un motivo propio (`mixedCauses`).

**Why:** el molde trae el mecanismo, no el significado de los textos de la etapa destino. Un copy escrito para un solo
productor (el techo de 72 h) afirma cosas de ese productor.

**How to apply:** cuando un cambio haga que un motivo existente salga desde un camino NUEVO, abre su string en
`es-419` y pregúntate si sigue siendo verdad en ese camino (plazo, culpable, acción). Si no, es decisión de copy: se
pregunta. Relacionado: [[feedback_el_copy_lo_elige_quien_produjo_el_motivo]], [[feedback_el_molde_no_traslada_sus_precondiciones]].
