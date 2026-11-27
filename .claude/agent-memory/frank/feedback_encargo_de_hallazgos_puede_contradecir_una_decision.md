---
name: encargo-de-hallazgos-puede-contradecir-una-decision
description: un encargo armado con «pendientes» de sesiones viejas puede pedir lo contrario de una decisión de Jürgen posterior; la vigente manda y no es pregunta vital
metadata:
  type: feedback
---

Antes de implementar un punto de un encargo de «hallazgos de cierres», fecha su origen y busca en `docs/DECISIONS.md`
una decisión posterior sobre lo mismo. Si la hay, manda la vigente: no se toca código, se fija con una prueba y se dice
en el cierre.

**Why:** el 27-nov el encargo «flujo de caja duplicado y promedios» pedía congelar las líneas por promedio, copiando un
pendiente de la S5 del replanteo (18-nov). El 19-nov Jürgen había decidido lo contrario («límites móviles»). El propio
encargo remitía a `docs/DECISIONS.md`, y allí estaba la respuesta.

**How to apply:** no es pregunta vital ni checkpoint nocturno: la decisión ya está tomada. Anótalo en el Paso 0 y en
«Decidido sin consultar». Relacionado: [[decision-de-ticket-viejo-puede-estar-tomada]],
[[lote-de-decisiones-puede-estar-ya-incorporado]].
