---
name: mismo-efecto-que-hereda-todos-sus-efectos
description: Un encargo que dice «mismo efecto que el toggle X» hereda TODO lo que X hace, no solo lo que el encargo nombra; medir los consumidores de X antes de escribir el aviso
metadata:
  type: feedback
---

**«Haz que A tenga el mismo efecto que X» se mide recorriendo a TODOS los lectores de X, no solo al que nombra
el encargo.** El 2026-10-03 el encargo decía «al archivar, excluir de estadísticas (mismo efecto que el toggle)»
para arreglar el total del Panel. La lente de sumas encontró que `excludeFromStatistics` también **oculta los
movimientos en Registros** y los quita de Estadísticas en todos los periodos pasados. Mi aviso decía «deja de
sumar en tus totales y estadísticas»: era verdad a medias. Y el downgrade, que archiva en lote, habría ocultado
el historial de cuentas que el usuario no eligió archivar, sin nada que lo deshiciera al volver a Pro.

**Why:** Jürgen decide sobre el efecto que conoce. El efecto que no nombró es justo el que el usuario va a
notar y el que él no aprobó explícitamente.

**How to apply:**
- Antes de escribir el copy de un «mismo efecto que X», `grep` del campo de X en `Yala/` y lista cada pantalla
  que cambia. El aviso dice todas las que se ven.
- Aplica el efecto donde el usuario lo pide con su gesto; donde lo aplica la app sola (downgrade, sistema), y es
  un flag persistente sin vuelta atrás, no lo extiendas: ticket de decisión. Relacionado:
  [[alcance-minimo-salvo-incoherencia]], [[el-copy-que-promete-se-recorre]].
