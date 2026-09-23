---
name: project_drain_reloj_no_se_duplica
description: PR del 23-sep (drain-duplicates-the-unit-clock-…): el drain ya no duplica el reloj por unidad; a done sin device-QA, seis tickets nuevos de la review.
metadata:
  type: project
---

Cerrado sin device-QA (una base local ilegible no se provoca en un iPhone). Cierra la familia de
[[project_apply_no_pisa_sin_salvaguardas]] en el lado del drain. Decisiones de noche, por la opción robusta:
leer antes de escribir (no escribir y deshacer), retirar los `upsert`/`delete` tolerantes, rollback solo en
los pasos 6-7, espejo retirado si falla el save del outbox, y `drainOnce` → `Bool` con sus seis lectores
comprobándolo (hallazgo medio de la review, en mi fix: [[mi-rollback-quita-lo-que-otros-leian]]).

Lo que quedó con ticket y por qué no entró: relojes ya duplicados en disco (low), deriva del reloj que corta
la traducción con `true` (low, parar el pull días es otra decisión), cursor del primer drain que guarda bajo
autor del motor (low), drain de Grupos sin rollback (low), reparación de ids a medias (medium), outbox de prefs
que sobrescribe un fichero ilegible (medium).

**Why:** el encargo prohibía reabrir alcance; los seis son de otro camino o pre-existentes.
**How to apply:** si Jürgen pregunta por qué un drain abortado deja el pull en `.transient`: es el intercambio de #216
extendido al drain, escrito en la regla «Y el drain tampoco».
