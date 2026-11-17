---
name: gate-tras-el-tope-de-pruebas-ui
description: Si el tope de 30 min de pruebas de interfaz se agota en capturas, correr el /gate completo es menor y va en «Decidido sin consultar»; no se pregunta.
metadata:
  type: feedback
---

Con el presupuesto de pruebas de interfaz gastado en capturas antes/después, el `/gate` completo se corre igual, sin preguntar,
y se anota en «Decidido sin consultar» del cierre.

**Why:** Jürgen, 16-nov (hero claro): «A: corre el gate completo. Es menor y está dentro del encargo; anótalo en
«Decidido sin consultar»». Sin gate no hay commit; parar a preguntar solo retrasa.

**How to apply:** el tope de ADR-107 frena pruebas EXTRA (reintentos, exploración); el gate del propio encargo no es
extra. Para ahorrar tiempo de verdad, sacar las capturas con un XCUITest temporal fuera de git que recorra todo de una vez.
Relacionado: [[sesion-de-rediseno]], [[el-gate-en-serie-tambien-contra-ti]].
