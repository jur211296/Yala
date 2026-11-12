---
name: una-carrera-se-prueba-con-el-ultimo-escritor
description: Antes de arreglar una «carrera» entre lecturas async, demuestra con el código VIEJO que el último escritor puede leer el dato malo; si su lectura y su escritura van en el mismo tramo síncrono, no hay carrera y la causa es el dato.
metadata:
  type: feedback
---

Antes de diseñar el arreglo de una carrera entre lecturas asíncronas, recorre con el código VIEJO quién escribe el
último y QUÉ LEE en ese momento. Si su lectura del estado guardado y su escritura van en el mismo tramo síncrono, una
lectura que termina después ya ve lo bueno: el orden no puede dejar el estado malo, y la causa está en el DATO que lee.

**Why:** 2026-10-22, card 7c97 (renovar desde «Tu suscripción terminó»). Diagnostiqué una carrera entre la lectura de
la compra y la de volver a primer plano, y monté turnos por lectura con su unit, su scan y 6 mutantes muertos. La
review adversarial lo tumbó en una lectura: con la lista vacía, la lectura tardía ya leía el derecho recién guardado;
la única forma de dejar Free era que StoreKit listara la suscripción vieja caducada, y ahí el orden no ayudaba. Además
descartar lecturas abría un hueco con los reembolsos. Los mutantes muertos no probaban nada: validaban el cableado de
un arreglo a la causa equivocada.

**How to apply:** en un bug de «el estado se pisa», escribe la secuencia concreta con el código viejo (quién empieza,
dónde está cada `await`, qué lee cada uno al escribir) antes de proponer orden, colas o turnos. Si no sale un orden
malo, busca qué entrada hace que la lógica pura dé el resultado malo y arregla la regla: eso además da un unit que
discrimina sin seams. Relacionado: [[instrumentar-gana-a-razonar]], [[la-premisa-del-encargo-tambien-se-mide]],
[[el-test-fija-el-bug-como-contrato]] (aquí `entitlementCaducado_borraLastVerified` fijaba el bug).
