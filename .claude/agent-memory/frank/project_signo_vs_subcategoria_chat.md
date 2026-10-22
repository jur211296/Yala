---
name: signo-vs-subcategoria-en-el-chat
description: PR #106 — el borrador del chat ya no puede nacer gasto con subcategoría de ingreso; el ticket señalaba 1 sitio y el patrón tenía 6; falta device-QA (simulable) y quedan 2 tickets, uno high de proceso.
metadata:
  type: project
---

**PR #106**, rama `encargo/2026-09-08-chat-draft-sign-can-contradict-its-subcategory`. Cierra
`chat-draft-sign-can-contradict-its-subcategory` (ahora en `tickets/qa/`), que nació de la review
adversarial del signo del chat.

**La decisión que pedía el AC, y que ya no hay que volver a tomar: manda el tipo del borrador
(`isExpense`), no la categoría recordada.** No fue una elección de gusto: los otros cuatro puntos
del borrador del chat ya lo asumían —el menú del card filtra por él y ni siquiera ofrece cambiar el
tipo, `updateDraft` rechaza contra él, `matchSubcategoryByHint` filtra por él, `saveDraft` firma con
él—. El quinto (el fallback por comercio) era el único que no. El criterio vive en
`DraftBuilder.matchesNature` con su porqué en el docblock, así que **si vuelve a aparecer la
pregunta, la respuesta está en el código, no aquí.**

## Por qué está donde está

- **Falta device-QA, y éste SÍ es simulable** — al revés que el de #99 y el de la «≈». Receta:
  aprobar 5 veces desde la Bandeja un ingreso con la misma nota de comercio (eso siembra la memoria
  con `countApproved: 5`, que es el umbral de `autoAssign`), dictar después al chat un gasto con esa
  nota, y comprobar que el borrador **pide** subcategoría en vez de nacer con la de ingreso.
- **El PR lo mergea Jürgen** salvo que pida otra cosa; el encargo de esta sesión sí lo pidió.

## Lo que deja abierto

1. `merchant-memory-suggests-across-natures-in-three-more-places` (**medium**) — Apple Pay, la voz y
   el prefill de la hoja de la Bandeja tienen el mismo cruce y no pasan por `DraftBuilder`. Lleva
   dentro una decisión: si el filtro sube a `MerchantMemoryService.suggest`, que es un solo sitio con
   seis llamadores, o se repite en cada superficie.
2. `el-hook-que-prohibe-atribuir-a-una-ia-no-corre-en-este-repo` (**high, necesita decisión suya**) —
   ver [[trailer-de-commit-nunca-en-yala]]. Salió de camino, no del ticket.

## Lo que NO se hizo, y por qué (para no volver a proponerlo)

**No hay red en `saveDraft`.** El AC lo permitía («o `saveDraft` rechaza»), y se eligió el origen:
el copy de error que ya existe dice que la subcategoría «ya no existe», que aquí sería mentira, y uno
nuevo son 16 locales. Residual medido y aceptado: un borrador cruzado ya serializado en la sesión del
día sobrevive a una actualización de la app. Vida máxima, la sesión de ese día.

**El barrido de #103 no interfiere:** su criterio exige `categoryIsIncome == false` y esta
combinación es justo la contraria, así que ni la ve. Y las filas viejas con este cruce (anteriores
al fix del signo) quedaron como ingresos positivos coherentes: no hay corpus que reparar.

Relacionado: [[alcance-minimo-salvo-incoherencia]] — el corte por la firma del helper salió de aquí.
