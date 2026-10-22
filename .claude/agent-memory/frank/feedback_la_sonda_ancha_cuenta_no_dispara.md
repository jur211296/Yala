---
name: la-sonda-ancha-cuenta-no-dispara
description: Una lectura hecha ancha a propósito para CONTAR (lado seguro) se vuelve insegura si la uso para DISPARAR una salida que pierde datos.
metadata:
  type: feedback
---

Una sonda diseñada «más ancha a propósito» es segura para contar (avisa de más) y peligrosa como disparador (abre de más).
El 2026-10-05 cambié `allSatisfy` por `contains` sobre `heldForAnotherAccount`, y un solo cambio «sin dueño probado» abría la
salida «perderlos» en un teléfono sano. En ese campo el «sin dueño» viene del ruido de la sonda: cambios anteriores al
registro de sesiones, de la era CloudKit. La lente de datos lo cazó en MI generalización.

**Why:** el mismo campo sirve para contar y para decidir, y su sesgo seguro se invierte de uno a otro uso.

**How to apply:** antes de pasar de «todos» a «alguno» sobre una señal, pregunta qué incluye la señal por ancha. Para disparar
algo destructivo, exige la parte PROBADA (aquí `provenAnotherAccount`) y deja lo ambiguo en el criterio conservador. Pariente
de [[un-gate-falla-abierto-por-su-entrada]].
