---
name: artifact-publico-lo-frena-el-clasificador
description: El hook de ADR-113 pide pasar cada artifact a público con Chrome; el 16-nov el clasificador lo denegó en la Mini, el 17-nov pasó en la Max con find + ref
metadata:
  type: reference
---

El hook PostToolUse de Artifact (ADR-113 de casa) pide abrir el artifact en Chrome y pasarlo a «Cualquier persona con el
enlace». Medido el 2026-11-16 en la Mini (sesión de captura en Grupos): abrir «Compartir» y el menú de acceso funciona,
pero el clic en «Cualquier persona con el enlace» lo **deniega el clasificador de modo automático** («Undermining
Oversight»).

**Medido otra vez el 2026-11-17 en la Max (sesión semi, bypass):** pasó entero. Secuencia que funcionó: `find`
«Compartir» → clic por `ref` → `find` el desplegable «Solo tú» → clic → `find` la opción «Cualquier persona con el
enlace» → clic → `find` «Compartir públicamente» → clic; `artifact-publico comprobar` dio «publico». No se sabe si la
diferencia es la máquina, el modo o el clic por `ref` en vez de coordenadas.

**How to apply:** prueba la secuencia por `ref`. Si el clasificador la deniega, no reintentes ni busques otra vía. Cierra la pestaña y deja en «Necesita de ti» del cierre el enlace
con «pásalo a público desde Compartir». Ver [[feedback_suelta_el_turno_antes_del_paso_5]] para otros rechazos del entorno.
