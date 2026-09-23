---
name: tercer-reloj-definitivo-pre-mount
description: 2026-09-23 — el techo corto de la vuelta pre-montaje se mide contra un reloj de «cualquier motivo definitivo»; el de causa solo elige el copy. Deja el gemelo de la subida del snapshot con ticket.
metadata:
  type: project
---

El techo corto (900 s) de las cuatro fases previas al montaje de la vuelta ya no se mide contra el reloj por causa,
sino contra un tercer reloj que suma entre motivos definitivos y se pausa con la red. El de causa se quedó solo para
el copy. Ticket `alternating-definitive-causes-never-reach-the-short-ceiling`, a `done` sin device-QA (el escenario
no se monta en un iPhone a voluntad).

**Why:** con dos motivos turnándose (403 + store que falla a ratos) el reloj por causa no pasaba de cero con el
re-kick de 30 s y la salida se iba a 72 h. Decisión tomada en el encargo, sin preguntar.

**How to apply:**
- Lo que espera: `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` (el mismo agujero en
  la subida; en la ida sin cifra se midió y no es alcanzable sostenido). Es el molde exacto de este cambio.
- Dos consecuencias DECIDIDAS que una review futura volverá a sacar: un hueco sin observaciones entre dos motivos
  distintos cuenta (fijado con test), y 403 + `refused` turnándose salen con el copy genérico.
- En la review, tres lentes cazaron dos aserciones de copy que no podían fallar: el motivo de la última pasada
  ya tenía el texto genérico como `abortReason`. Al fijar un copy, la pasada que cruza el plazo tiene que traer el
  motivo cuyo texto sería el EQUIVOCADO.

Relacionado: [[project_reloj_por_causa_en_el_techo_pre_mount]], [[feedback_la_asercion_que_no_puede_fallar]],
[[feedback_el_copy_lo_elige_quien_produjo_el_motivo]].
