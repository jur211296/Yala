---
name: artifact-publico-lo-frena-el-clasificador
description: Pasar un artifact a público con Chrome: el 16-nov en la Mini el clasificador lo denegó; el 17-nov en la Max, con bypass, pasó con find + clic por ref
metadata:
  type: reference
---

El hook PostToolUse de Artifact (ADR-113 de casa) pide abrir el artifact en Chrome y pasarlo a «Cualquier persona con el
enlace». Medido el 2026-11-16 en la Mini (sesión de captura en Grupos): abrir «Compartir» y el menú de acceso funciona,
pero el clic en «Cualquier persona con el enlace» lo **deniega el clasificador de modo automático** («Undermining
Oversight»).

**Medido otra vez el 2026-11-17 en la Max (sesión semi en bypass): pasó entero.** `find` del botón «Compartir», del
combobox de acceso, de la opción «Cualquier persona con el enlace» y de «Compartir públicamente», cada uno con clic por `ref`;
`artifact-publico comprobar` dijo `publico`. La diferencia con el 16-nov puede ser la máquina o el modo de permisos: no medida.

**How to apply:** inténtalo una vez como arriba. Si el clasificador lo deniega, no reintentes ni busques otra vía. Cierra la pestaña y deja en «Necesita de ti» del cierre el enlace
con «pásalo a público desde Compartir». Ver [[feedback_suelta_el_turno_antes_del_paso_5]] para otros rechazos del entorno.
