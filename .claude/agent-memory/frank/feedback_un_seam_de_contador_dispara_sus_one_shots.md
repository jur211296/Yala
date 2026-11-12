---
name: un-seam-de-contador-dispara-sus-one-shots
description: Un seam que fija un contador (registros guardados) tiene que dejar también los one-shots que ese contador ya habría quemado, o salen encima de lo que se prueba.
metadata:
  type: feedback
---

Fijar `transactionsSavedCount = 5` con un seam (`-uitest-transactions-saved`) para probar el aviso del 4.º registro
no basta: alguien con 5 registros ya vio el respaldo del permiso de notificaciones (sale en el 3.º) y ya completó el
primer gasto del checklist. Sin marcar esos dos, al guardar salían la hoja del permiso y el «¿Era de prueba?», y el test
del aviso caía por algo que en un teléfono real no pasa.

**Why:** 2026-10-22, lote decidido 2.2 · 02: tres corridas en rojo hasta verlo en el vídeo del `.xcresult`
([[ver-un-fallo-de-xcuitest-en-video]]).

**How to apply:** al escribir un seam que adelanta un contador o un estado, lista qué one-shots se queman por el camino
(primers, checklist, ofertas de hito, reseña) y déjalos en el estado que tendrían. Relacionado:
[[un-seam-que-deja-algo-pendiente-contamina-al-siguiente-test]].
