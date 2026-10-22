---
name: mi-rollback-quita-lo-que-otros-leian
description: Añadir un rollback a un camino que dejaba cambios SUCIOS cambia lo que leen los fetch posteriores del mismo contexto; la suciedad a veces era la protección.
metadata:
  type: feedback
---

Un `context.rollback()` nuevo no solo evita que un autosave flushee basura: también borra lo que los
lectores posteriores del MISMO contexto estaban viendo, porque un fetch de SwiftData incluye los cambios
pendientes. Si alguien decidía leyendo eso, mi rollback le quita el dato.

**Why:** el 2026-09-23 añadí el rollback al drain (`drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`).
Antes, un save del outbox fallido dejaba sus filas sucias, y el guard D-1 de `applyPage`, que lee el outbox,
las veía y protegía la edición del usuario. Con el rollback el pull aplicaba la página con el guard vacío y
pisaba la edición. Suite verde; lo cazó una lente de la review que preguntó «¿quién lee lo que deshaces?».
El arreglo fue que `drainOnce` diga si terminó y que sus seis lectores no sigan con `false`.

**How to apply:** antes de añadir un rollback (o de limpiar cualquier estado «sucio»), enumera quién lee
ese contexto o ese estado DESPUÉS en el mismo flujo, y si alguno decide con ello, dale una señal explícita
de que la operación no terminó. Relacionado: [[mi-arreglo-rompe-la-premisa-de-otro-guard]],
[[mi-arreglo-quita-la-salida-que-habia]].
