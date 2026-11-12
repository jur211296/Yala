---
name: auditoria-ux-lote-propone-no-implementa
description: Auditoría UX 2.2 por lotes — se PROPONE, no se implementa UX; solo bugs claros, cada uno con su card; informe.md + HTML acumulado + una card por mejora
metadata:
  type: feedback
---

En la auditoría UX de 2.2, un lote **no implementa cambios de UX: los propone**. Solo se arreglan **bugs claros**, y
cada bug va en **su propia card**. Lo que se entrega por lote:

1. Capturas de cada pantalla del flujo, del simulador, en `~/Claude/entregas/<sesión>/capturas/` con nombres claros;
   si aplica, maqueta de la propuesta.
2. `~/Claude/entregas/<sesión>/informe.md`: mejoras numeradas (L<n>-1, L<n>-2…), cada una con problema, tipo de
   usuario (lente), captura, opciones A/B/C y la recomendada.
3. Una card por mejora: «espera decisión», assignee **jurgen**, versión 2.2, con sus opciones.
4. Sección del lote en el HTML acumulado `~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html`
   (autocontenido, índice arriba, imágenes en `img/` con prefijo `l<n>-`, legible en el móvil), **sin borrar los
   lotes anteriores**: el fichero lleva marcadores `LOTE:N:INICIO/FIN` e `INDICE:N:INICIO/FIN`.

**Why:** el 2026-10-13 (lote 1) el encargo y el brief decían «implementa lo acotado» y yo ya había implementado 12
cambios de copy en 16 idiomas. Jürgen lo corrigió a mitad de sesión: quiere decidir él cada mejora viendo
opciones, no encontrárselas hechas. Hubo que revertir y rehacer el entregable.

**How to apply:** si un encargo de lote dice «implementa lo acotado», manda esta corrección (es posterior y de
Jürgen). Lo implementado y revertido no se pierde: renderízalo en el simulador y úsalo como **maqueta de la opción
recomendada** (así se hizo en el lote 1). Relacionado: [[disena-en-lienzo-antes-de-construir]].
