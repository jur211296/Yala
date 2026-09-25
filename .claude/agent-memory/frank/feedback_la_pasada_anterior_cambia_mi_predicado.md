---
name: la-pasada-anterior-cambia-mi-predicado
description: En un paso que se reintenta, lo que escribió la pasada FALLIDA cambia en qué casilla cae cada fila — el 25-sep dos de mis filtros daban resultados distintos según hubiera fallado el push
metadata:
  type: feedback
---

**Antes de filtrar en un paso reintentable, pregunta qué dejó escrito la pasada anterior que falló, y si
mueve alguna fila de un lado a otro de tu predicado.**

**Why:** el 2026-09-25 (#246, adopt) la review adversarial cazó dos veces lo mismo en mi arreglo:
- filtré el casado a «filas que TRAEN identidad» (las sin identidad eran «de este teléfono»). Pero el
  backfill de la pasada 1 ya les había dado identidad: en la pasada 2 caían del otro lado. El mismo
  teléfono casaba o no según hubiera fallado el push;
- restringí la restauración a «identidades que el backend conoce». La pasada 1 había encolado una en el
  outbox y el push falló: aún no estaba en el backend, y la fila subía con las dos.
Ningún test mío lo veía porque todos corrían UNA pasada.

**How to apply:** en todo efecto retomable (adopt, reconcile, snapshot), lista lo que la pasada escribe
ANTES de su primer `await` que puede fallar (backfill, testigos, outbox, registro, marcas), y para cada
filtro nuevo escribe un test de DOS pasadas con la primera fallando (`stub.pushStatus = 500`).
Relacionado: [[una-ventana-dura-lo-que-su-reintento]], [[mi-puerta-bloquea-lo-que-su-propio-flujo-dejo]].
