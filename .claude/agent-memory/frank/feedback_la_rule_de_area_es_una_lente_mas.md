---
name: la-rule-de-area-es-una-lente-mas
description: La rule que se carga sola hay que leerla CONTRA mi diff — y ANTES de medir: el 12-sep repetí un error que su última entrada describía literalmente
metadata:
  type: feedback
---

**Cuando una `.claude/rules/` se carga sola al tocar un fichero, la leo contra MI diff, no como
contexto de fondo. Es una lente más, y barata.**

**Why:** el 2026-09-08, en `chat-rows-sealed-before-the-fix-have-no-repair-path`, `currency-fx.md`
apareció al editar el barrido de tasas. Su sección «Una tasa inservible es una tasa AUSENTE» decía
que un `0` guardado pasa por dato y en el destino devuelve `0`, que parece un número real. Mi función
nueva derivaba la tasa de un cociente y, con el monto convertido en `0`, habría escrito
`exchangeRate = 0` — **la forma exacta del bug del módulo, reproducida dentro de su arreglo**. Las
**tres** lentes adversariales que corrí en paralelo no lo vieron: miraban el diseño, los tests y las
premisas de mis comentarios, y ese defecto solo se ve sabiendo cómo falla ese módulo en concreto.

**How to apply:** al ver el aviso de que una rule se cargó, dedicarle una pasada explícita
preguntando «¿mi diff hace alguna de las cosas que esto prohíbe?». Sus secciones suelen estar
escritas como formas de fallo, no como estilo, así que se contrastan una a una en un minuto. Es
complementaria de la review adversarial, no redundante: la rule sabe del **módulo**, las lentes saben
del **cambio**.

Y la rule también dice qué escribir después: el gotcha durable del área va ahí (en el mismo PR, que
`.claude/` va por PR), no al ticket ni a esta memoria. Ver
[[feedback_review_adversarial_caza_lo_mio]] y [[feedback_lentes_adversariales_se_contradicen]].


## Y se lee ANTES de medir, no solo contra el diff (2026-09-12)

Corrí `-only-testing:YalaUITests/GroupsAssociationRowUITests` con `-scheme Yala` y leí los **5 rojos**
como una posible regresión mía: 70 s por caso, fallo en un helper compartido, tests que no había tocado.
Estuve a punto de irme al disco (que además estaba bajo el umbral, o sea, un sospechoso creíble).

**La última entrada de `testing.md` describía exactamente eso**, con fecha del día anterior, y terminaba
diciendo «antes de culpar al entorno de un rojo de XCUITest, comprueba con qué scheme lo lanzaste». Yo
había abierto ese fichero esa misma sesión — por el índice, buscando otra cosa.

⇒ **la rule del área que vas a MEDIR se lee antes de la primera corrida**, no solo cuando toca revisar el
diff. Y en un fichero indexado, mirar el índice no es leerlo: las entradas nuevas están al final y el
índice no dice cuáles son de esta semana. Un `tail -6` cuesta nada.
