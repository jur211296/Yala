---
name: arreglar-la-funcion-no-cura-a-los-atascados
description: Un fix de backend que corrige la transición deja dentro a quien el bug ya dejó en el estado malo; busca el predicado de esas filas y repáralas en la misma migración.
metadata:
  type: feedback
---

Al arreglar una función que DEJA filas en un estado malo, pregunta qué pasa con las filas que ya están ahí. g17_01
(2026-10-09) cambiaba el claim para no borrar `reverted_at`, y la lente de consumidores cazó que las cuentas ya
atascadas seguían recibiendo `not_complete`: el canario del criterio nunca habría llegado a cero.

**Why:** el diff de la función se prueba con filas sintéticas nuevas; las viejas no pasan por ningún test.
**How to apply:** en toda migración que corrige una transición, busca un predicado EXACTO del estado que solo deja el bug
(aquí `groups_only` + `personal_claimed_at` + sin `reverted_at`), repara en la misma migración y pruébalo en el banco con
una fila atascada y dos controles que no se tocan. Y sin acceso a la base, un golden contra staging mide el bug en la
función viva sin DDL. Relacionado: [[credencial-pendiente-se-aparca]].
