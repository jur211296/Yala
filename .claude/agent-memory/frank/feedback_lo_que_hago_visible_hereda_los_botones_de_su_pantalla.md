---
name: lo-que-hago-visible-hereda-los-botones-de-su-pantalla
description: Una fila nueva que protege algo (la marca de aprobación en Archivados) hereda todas las acciones de la pantalla donde aparece; «Eliminar» y «Devolver a pendientes» en lote la destruían.
metadata:
  type: feedback
---

**Cuando un arreglo deja un registro nuevo que PROTEGE algo, recorre todas las acciones de la pantalla donde ese
registro aparece, las de fila y las de lote, antes de dar el diseño por cerrado.**

**Why:** el 2026-09-27 la marca de aprobación de una liquidación (un borrador aprobado nuevo) salía en Archivados del
Inbox. La revisé contra el re-puente, la convergencia y el espejo, y no contra la pantalla: la lente de dinero de la
review encontró que «Devolver a pendientes» en lote la convertía en un pendiente que se aprobaba otra vez (dinero doble)
y que «Eliminar» en lote se llevaba la protección en silencio. El deslizamiento de la fila no las ofrecía; el modo
selección sí. Y el filtro de Archivados escondía el rechazo sin cuenta, que con el re-puente respetándolo quedaba
irreversible.

**How to apply:** al introducir un estado nuevo en un modelo que ya tiene UI (un status, un flag, un registro
«marca»), lista las acciones que esa UI ofrece sobre él —swipe, tap, modo selección/lote, menús contextuales— y los
filtros que deciden si se ve. Para cada una: ¿destruye la protección?, ¿la duplica?, ¿la esconde sin salida? Es la
versión UI de [[un-verbo-nuevo-hereda-las-prohibiciones-del-viejo]] y de [[el-otro-control-va-al-mismo-sitio]].
