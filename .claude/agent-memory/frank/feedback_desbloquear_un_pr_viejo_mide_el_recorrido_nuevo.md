---
name: desbloquear-un-pr-viejo-mide-el-recorrido-nuevo
description: Al traer la base a un PR parado días, lo que el PR enciende puede apagarlo un flujo nuevo de la base, y el mecanismo nuevo trae decisiones menores en la tabla de su ticket done
metadata:
  type: feedback
---

Al desbloquear un PR que llevaba días en conflicto, el merge limpio no basta: hay que recorrer el camino del usuario
que la base añadió después. El 15-nov, la nota de salud del lote 1 nacía «encendida por defecto», pero el cierre del
tutorial de la bienvenida 2.3 (12-nov, un día después) deja a la vista solo la cuenta y «Últimos registros»: un usuario
nuevo no la ve. Y el bump de versión del release (2.2 → 2.3) puso rojo `WhatsNewLaunchUITests`, que esperaba la hoja de 2.2.

**Why:** el encargo lo marcaba «inferido, sin probar»; solo la captura del XCUITest de la bienvenida lo confirmó. Dos
decisiones de Jürgen chocaban y ninguna sabía de la otra.

**How to apply:** tras el merge, corre el XCUITest que recorre el flujo nuevo de la base hasta la pantalla del PR y mira
su captura. Si chocan dos decisiones y no hay riesgo de datos, gana la más reciente y específica, y la otra va a una card
con la pregunta (nocturno: no es decisión vital). Relacionado: [[la-premisa-del-encargo-tambien-se-mide]].

**Segundo caso (16-nov, «Tu IA registra en Yala»):** el encargo pedía mover el PR a la cola común de la D9, y la D9 sí lo
cubría; lo que chocaba era una decisión técnica MENOR de la sesión que implementó esa cola (P5 del lote 1 de la web: «no
preguntar a la cola en cada vuelta»), escrita en la tabla del ticket `done`, no en DECISIONS. El PR viejo preguntaba en
cada vuelta. Se casó a la misma cadencia (cada 2 min, como la pregunta a la web) sin preguntar. **How to apply:** al
cambiar un PR viejo a un mecanismo de la base, lee la tabla de decisiones del ticket que lo construyó (`tickets/done/`),
no solo el ADR de arriba.
