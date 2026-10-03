---
name: el-final-del-scroll-se-mide-hasta-que-para
description: Medir «al final del scroll» en XCUITest — N arrastres fijos no llegan con 2 años de datos ni con AX5; arrastrar hasta que la pantalla deje de cambiar, semilla corta, y el arrastre en la columna del botón (no en la barra lateral)
metadata:
  type: feedback
---

«Al final del scroll» se mide arrastrando **hasta que dos capturas seguidas sean iguales** (con `sleep(2)` entre
arrastre y captura para que pare la inercia), no con un número fijo de arrastres. Y la lista larga va con semilla
`minimal`.

**Why:** 2026-10-03, ticket de los botones flotantes. Diez arrastres no llegaban al final de Registros con `realista`
(2.326 registros) ni con `minimal` a AX5 (filas de 200 pt): las primeras mediciones dieron «tapado» a mitad de lista y
casi se cuelan como el «antes». Además, en el iPad horizontal un arrastre en x = 0,15 cae en la **barra lateral** y no
mueve nada: la captura sale arriba del todo, sin error. Y las capturas del propio ticket (Planificación, Grupos en el
iPad mini) eran a mitad de scroll, que es justo lo que un margen no arregla.

**How to apply:** antes de leer una medición «al final», mira la captura: la última fila tiene que ser la más antigua
(«Saldo inicial» con `minimal`). Arrastra en x = marco del botón flotante − 150 pt, que cae en su misma columna. Coste:
con techo de 40 arrastres, ~6 min por caso si la pantalla nunca se estabiliza (un spinner la mueve). Relacionado:
[[la-premisa-del-encargo-tambien-se-mide]], [[mis-mediciones-fallan-por-el-filtro]].
