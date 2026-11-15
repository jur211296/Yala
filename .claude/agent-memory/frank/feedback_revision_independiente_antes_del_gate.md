---
name: revision-independiente-antes-del-gate
description: En un lote con reglas de fechas o de dinero, un agente revisor con el código (no con mi conclusión) antes del gate caza fallos que mis tests no tenían
metadata:
  type: feedback
---

En pagos recurrentes S1 (14-nov, nocturno) el detector tenía 29 tests en verde y la prueba en el iPhone iba bien.
Un solo agente revisor, al que le pasé el código y la regla pero no mi veredicto, devolvió 11 hallazgos y 9 eran
reales: el día 31 guardado como 30 para siempre, el próximo cobro mal tras un cobro corrido de mes, «PRIME GYM»
propuesto como Prime Video (el catálogo de marcas casa por prefijo), devoluciones contadas como cobros, un aviso con
fecha ya pasada, el permiso de notificaciones que el editor sí pide.

**Why:** mis tests probaban los casos que yo había pensado; el revisor buscó los bordes que la regla no nombra.
Costó ~5 min de reloj en paralelo con la build del iPhone.

**How to apply:** cuando el lote decide fechas, importes o qué se crea a partir del historial, lanza un revisor
independiente (general-purpose, solo lectura, «no compiles ni uses el simulador») en paralelo con la prueba en
aparato, y escribe un test por hallazgo antes del gate. Para l10n o polish visual no hace falta. Ver
[[review-adversarial]].
