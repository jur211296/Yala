---
name: una-premisa-corregida-no-reabre-el-camino
description: Refutar UNA de las razones por las que algo se paró no autoriza a seguir: hay que re-medir las otras; el 10-sep corregí la objeción 2 de un bloqueo y las otras dos seguían vivas
metadata:
  type: feedback
---

**Cuando corrijas una premisa que justificaba un bloqueo, mide TODAS las demás antes de reabrir el
camino.** Una objeción refutada no vuelve viable lo que estaba parado: solo quita una de las razones.

**Why:** el 2026-09-10 la mitad 2 de la puerta de Grupos estaba parada por dos objeciones medidas
(D3 del ticket padre). Medí que la segunda era falsa **para el camino de archivos** —«borrar lo local
con el espejo montado borra también iCloud» es cierto de `wipeAllUserData`, que borra FILAS, y falso
del borrado pre-mount, que borra ARCHIVOS— y con eso le propuse a Jürgen reabrir el diseño. Él eligió
la vía y la implementé entera. La review adversarial encontró que **las otras dos objeciones seguían
en pie**, más una tercera que nadie había visto: la espera de export no existe y no se puede
construir con las señales de hoy; y el borrado que iba a reusar arrastra superficies que la promesa no
cubre. Resultado: el camino volvió a quedar bloqueado, esperando exactamente la pieza que la matriz
ya le asignaba a otro paso.

El coste no fue el trabajo tirado —la base quedó en la rama y sirve— sino haber llevado a Jürgen una
decisión de producto («¿relanzamiento o swap?») cuando la pregunta real era otra («¿existe siquiera
un borrado usable?»). Esa segunda pregunta se contesta antes de preguntar nada, y se contesta leyendo
el mecanismo, no el ticket.

**How to apply:** ante un ticket con estado `blocked` o con un «se paró porque…», lista sus razones y
trátalas como una conjunción: hace falta refutar TODAS para reabrir. Y antes de proponer un camino,
comprueba que **cada pieza que ese camino necesita existe y es usable desde ahí** — sobre todo si la
matriz o el runbook ya le asignan esa pieza a otro paso, que es la señal más fuerte de que la
dependencia es real. Relacionado: [[el-mecanismo-que-reuso-trae-sus-precondiciones]] y
[[la-premisa-del-encargo-tambien-se-mide]].

**Y así se hizo bien el 2026-09-11.** Antes de escribir una línea, las tres razones del bloqueo se
volvieron a medir una por una contra el árbol de hoy, en una tabla con su coordenada: la espera de export
YA EXISTE (paso 9), el boot-wipe SÍ es reusable pero solo por la puerta del coordinador, y el arm SÍ
desarma al abortar en `.icloud`. Las tres refutadas ⇒ el camino se reabre. Esa tabla es lo primero del
Paso 0 y cuesta veinte minutos; escribirla es lo que separa «reabrir» de «volver a chocar».
